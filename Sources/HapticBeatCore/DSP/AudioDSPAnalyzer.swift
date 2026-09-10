import Foundation
import Accelerate

public struct AudioAnalysisResult: Sendable {
    public let bandEnergy: Float
    public let totalEnergy: Float
    public let isTrigger: Bool
    public let onsetDelta: Float

    public init(bandEnergy: Float, totalEnergy: Float, isTrigger: Bool, onsetDelta: Float) {
        self.bandEnergy = bandEnergy
        self.totalEnergy = totalEnergy
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

    public func process(samples: [Float], sampleRate: Float, config: HapticBeatConfig) -> AudioAnalysisResult {
        guard samples.count >= fftSize, sampleRate > 0 else {
            return AudioAnalysisResult(bandEnergy: 0.0, totalEnergy: 0.0, isTrigger: false, onsetDelta: 0.0)
        }

        // Total RMS energy
        var totalEnergy: Float = 0.0
        vDSP_rmsqv(samples, 1, &totalEnergy, vDSP_Length(fftSize))

        if totalEnergy < 0.0001 {
            previousBandEnergy = 0.0
            return AudioAnalysisResult(bandEnergy: 0.0, totalEnergy: 0.0, isTrigger: false, onsetDelta: 0.0)
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
        let minBin = max(0, min(halfSize - 1, Int(config.frequencyBand.minFrequency / binResolution)))
        let maxBin = max(minBin, min(halfSize - 1, Int(config.frequencyBand.maxFrequency / binResolution)))

        let binCount = maxBin - minBin + 1
        var bandSum: Float = 0.0
        if binCount > 0 {
            magnitudes.withUnsafeBufferPointer { magPtr in
                let slice = magPtr.baseAddress!.advanced(by: minBin)
                vDSP_sve(slice, 1, &bandSum, vDSP_Length(binCount))
            }
        }

        // Normalized band energy (sqrt of power sum)
        let normalizedBandEnergy = min(1.0, sqrt(bandSum))

        // Transient onset detection
        let delta = normalizedBandEnergy - previousBandEnergy
        let meetsThreshold = normalizedBandEnergy >= config.threshold
        let isTransient = (delta >= config.onsetSensitivity) || (previousBandEnergy < 0.05 && meetsThreshold)

        let isTrigger = meetsThreshold && isTransient

        previousBandEnergy = normalizedBandEnergy

        return AudioAnalysisResult(
            bandEnergy: normalizedBandEnergy,
            totalEnergy: min(1.0, totalEnergy * 2.0),
            isTrigger: isTrigger,
            onsetDelta: max(0.0, delta)
        )
    }
}
