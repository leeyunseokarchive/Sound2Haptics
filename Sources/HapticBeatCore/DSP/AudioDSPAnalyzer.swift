import Foundation
import Accelerate

public struct AudioAnalysisResult: Sendable {
    public let bandEnergy: Float
    public let totalEnergy: Float
    public let lowEnergy: Float
    public let midEnergy: Float
    public let highEnergy: Float
    public let stereoPan: Float
    public let isTrigger: Bool
    public let onsetDelta: Float

    public init(
        bandEnergy: Float,
        totalEnergy: Float,
        lowEnergy: Float = 0.0,
        midEnergy: Float = 0.0,
        highEnergy: Float = 0.0,
        stereoPan: Float = 0.0,
        isTrigger: Bool,
        onsetDelta: Float
    ) {
        self.bandEnergy = bandEnergy
        self.totalEnergy = totalEnergy
        self.lowEnergy = lowEnergy
        self.midEnergy = midEnergy
        self.highEnergy = highEnergy
        self.stereoPan = stereoPan
        self.isTrigger = isTrigger
        self.onsetDelta = onsetDelta
    }
}

public final class AudioDSPAnalyzer: @unchecked Sendable {
    public let fftSize: Int
    private let halfSize: Int
    private let log2n: vDSP_Length
    private let fftSetup: FFTSetup

    private var window: [Float]
    private var windowedSamples: [Float]
    private var realBuffer: [Float]
    private var imagBuffer: [Float]
    private var magnitudes: [Float]

    private var previousBandEnergy: Float = 0.0

    public init(fftSize: Int = 1024) {
        self.fftSize = fftSize
        self.halfSize = fftSize / 2
        self.log2n = vDSP_Length(log2(Double(fftSize)))

        guard let setup = vDSP_create_fftsetup(self.log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to initialize Accelerate FFTSetup")
        }
        self.fftSetup = setup

        self.window = [Float](repeating: 0.0, count: fftSize)
        self.windowedSamples = [Float](repeating: 0.0, count: fftSize)
        self.realBuffer = [Float](repeating: 0.0, count: halfSize)
        self.imagBuffer = [Float](repeating: 0.0, count: halfSize)
        self.magnitudes = [Float](repeating: 0.0, count: halfSize)

        vDSP_hann_window(&self.window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
    }

    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    public func reset() {
        previousBandEnergy = 0.0
    }

    private func energyForRange(minFreq: Float, maxFreq: Float, binResolution: Float) -> Float {
        let minBin = max(0, min(halfSize - 1, Int(minFreq / binResolution)))
        let maxBin = max(minBin, min(halfSize - 1, Int(maxFreq / binResolution)))
        let binCount = maxBin - minBin + 1
        guard binCount > 0 else { return 0.0 }
        var sum: Float = 0.0
        magnitudes.withUnsafeBufferPointer { magPtr in
            let slice = magPtr.baseAddress!.advanced(by: minBin)
            vDSP_sve(slice, 1, &sum, vDSP_Length(binCount))
        }
        return min(1.0, sqrt(sum))
    }

    public func process(
        samples: [Float],
        sampleRate: Float,
        config: HapticBeatConfig,
        stereoPan: Float = 0.0
    ) -> AudioAnalysisResult {
        guard samples.count >= fftSize, sampleRate > 0 else {
            return AudioAnalysisResult(
                bandEnergy: 0.0,
                totalEnergy: 0.0,
                lowEnergy: 0.0,
                midEnergy: 0.0,
                highEnergy: 0.0,
                stereoPan: stereoPan,
                isTrigger: false,
                onsetDelta: 0.0
            )
        }

        // Total RMS energy
        var totalEnergy: Float = 0.0
        vDSP_rmsqv(samples, 1, &totalEnergy, vDSP_Length(fftSize))

        if totalEnergy < 0.0001 {
            previousBandEnergy = 0.0
            return AudioAnalysisResult(
                bandEnergy: 0.0,
                totalEnergy: 0.0,
                lowEnergy: 0.0,
                midEnergy: 0.0,
                highEnergy: 0.0,
                stereoPan: stereoPan,
                isTrigger: false,
                onsetDelta: 0.0
            )
        }

        // Apply Hann window
        vDSP_vmul(samples, 1, window, 1, &windowedSamples, 1, vDSP_Length(fftSize))

        // Convert to Split Complex
        realBuffer.withUnsafeMutableBufferPointer { realPtr in
            imagBuffer.withUnsafeMutableBufferPointer { imagPtr in
                var splitComplex = DSPSplitComplex(
                    realp: realPtr.baseAddress!,
                    imagp: imagPtr.baseAddress!
                )

                windowedSamples.withUnsafeBytes { rawBuffer in
                    let complexPtr = rawBuffer.bindMemory(to: DSPComplex.self)
                    vDSP_ctoz(complexPtr.baseAddress!, 2, &splitComplex, 1, vDSP_Length(halfSize))
                }

                // 1D Forward FFT (In-place)
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

                // Power spectrum: |real|^2 + |imag|^2
                vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
            }
        }

        // Scale factor: 4.0 / (N^2) for true amplitude squared
        var scale: Float = 4.0 / Float(fftSize * fftSize)
        vDSP_vsmul(magnitudes, 1, &scale, &magnitudes, 1, vDSP_Length(halfSize))

        // Frequency resolution per FFT bin
        let binResolution = sampleRate / Float(fftSize)

        // Sub-band energies for 2D spatial visualizer
        let lowEnergy = energyForRange(minFreq: 20.0, maxFreq: 150.0, binResolution: binResolution)
        let midEnergy = energyForRange(minFreq: 151.0, maxFreq: 2000.0, binResolution: binResolution)
        let highEnergy = energyForRange(minFreq: 2000.0, maxFreq: 20000.0, binResolution: binResolution)

        // Target configured band energy
        let normalizedBandEnergy = energyForRange(
            minFreq: config.frequencyBand.minFrequency,
            maxFreq: config.frequencyBand.maxFrequency,
            binResolution: binResolution
        )

        // Transient onset detection
        let delta = normalizedBandEnergy - previousBandEnergy
        let meetsThreshold = normalizedBandEnergy >= config.threshold
        let isTransient = (delta >= config.onsetSensitivity) || (previousBandEnergy < 0.05 && meetsThreshold)

        let isTrigger = meetsThreshold && isTransient

        previousBandEnergy = normalizedBandEnergy

        return AudioAnalysisResult(
            bandEnergy: normalizedBandEnergy,
            totalEnergy: min(1.0, totalEnergy * 2.0),
            lowEnergy: lowEnergy,
            midEnergy: midEnergy,
            highEnergy: highEnergy,
            stereoPan: stereoPan,
            isTrigger: isTrigger,
            onsetDelta: max(0.0, delta)
        )
    }
}
