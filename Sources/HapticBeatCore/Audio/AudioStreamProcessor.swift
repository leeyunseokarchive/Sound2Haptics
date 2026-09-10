import Foundation
import Accelerate

public final class AudioStreamProcessor: @unchecked Sendable {
    private let lock = NSLock()
    public let analyzer: AudioDSPAnalyzer
    public let engine: HapticEngine
    public let touchTracker: TouchTrackingSource

    public var onAnalysis: (@Sendable (AudioAnalysisResult) -> Void)?
    public var onHapticTrigger: (@Sendable (Bool) -> Void)?

    private var sampleAccumulator: [Float] = []
    private var currentStereoPan: Float = 0.0
    public let fftSize: Int

    public init(
        analyzer: AudioDSPAnalyzer = AudioDSPAnalyzer(fftSize: 1024),
        engine: HapticEngine = HapticEngine(),
        touchTracker: TouchTrackingSource = MultitouchTracker.shared
    ) {
        self.analyzer = analyzer
        self.engine = engine
        self.touchTracker = touchTracker
        self.fftSize = analyzer.fftSize
        self.sampleAccumulator.reserveCapacity(analyzer.fftSize * 2)
    }

    public func feedMonoAudio(samples: [Float], sampleRate: Float) {
        guard !samples.isEmpty else { return }

        // Apply input gain scaling
        var gain = engine.config.inputGain
        var scaledSamples = [Float](repeating: 0.0, count: samples.count)
        vDSP_vsmul(samples, 1, &gain, &scaledSamples, 1, vDSP_Length(samples.count))

        lock.lock()
        sampleAccumulator.append(contentsOf: scaledSamples)

        while sampleAccumulator.count >= fftSize {
            let window = Array(sampleAccumulator.prefix(fftSize))
            let hopSize = fftSize / 2
            sampleAccumulator.removeFirst(hopSize)

            let pan = currentStereoPan
            let result = analyzer.process(samples: window, sampleRate: sampleRate, config: engine.config, stereoPan: pan)

            let touches = touchTracker.touches
            var didActuate = false

            let shouldTrigger: Bool
            if !touches.isEmpty {
                // When fingers are touching the trackpad, strictly gate by multi-touch spatial coordinates!
                shouldTrigger = SpatialTouchGate.evaluate(touches: touches, result: result, config: engine.config)
            } else {
                // When hands are off the trackpad (or in automated tests / non-multitouch hardware),
                // fall back to global band trigger.
                shouldTrigger = result.isTrigger
            }

            if shouldTrigger {
                didActuate = engine.trigger(energy: result.bandEnergy)
            }

            let onAnalysisCb = self.onAnalysis
            let onHapticCb = self.onHapticTrigger
            lock.unlock()

            onAnalysisCb?(result)
            if didActuate {
                onHapticCb?(true)
            }

            lock.lock()
        }
        lock.unlock()
    }

    public func feedStereoAudio(left: [Float], right: [Float], sampleRate: Float) {
        let count = min(left.count, right.count)
        guard count > 0 else { return }

        var leftRMS: Float = 0.0
        var rightRMS: Float = 0.0
        vDSP_rmsqv(left, 1, &leftRMS, vDSP_Length(count))
        vDSP_rmsqv(right, 1, &rightRMS, vDSP_Length(count))

        let totalRMS = leftRMS + rightRMS
        if totalRMS > 0.001 {
            lock.lock()
            self.currentStereoPan = min(1.0, max(-1.0, (rightRMS - leftRMS) / totalRMS))
            lock.unlock()
        }

        var mono = [Float](repeating: 0.0, count: count)
        vDSP_vadd(left, 1, right, 1, &mono, 1, vDSP_Length(count))
        var half: Float = 0.5
        vDSP_vsmul(mono, 1, &half, &mono, 1, vDSP_Length(count))

        feedMonoAudio(samples: mono, sampleRate: sampleRate)
    }

    public func feedInterleavedAudio(samples: [Float], channelCount: Int, sampleRate: Float) {
        guard channelCount > 0, !samples.isEmpty else { return }
        if channelCount == 1 {
            lock.lock()
            currentStereoPan = 0.0
            lock.unlock()
            feedMonoAudio(samples: samples, sampleRate: sampleRate)
            return
        }

        if channelCount == 2 {
            let frameCount = samples.count / 2
            var left = [Float](repeating: 0.0, count: frameCount)
            var right = [Float](repeating: 0.0, count: frameCount)
            for i in 0..<frameCount {
                left[i] = samples[i * 2]
                right[i] = samples[i * 2 + 1]
            }
            feedStereoAudio(left: left, right: right, sampleRate: sampleRate)
            return
        }

        let frameCount = samples.count / channelCount
        var mono = [Float](repeating: 0.0, count: frameCount)
        let channelMultiplier: Float = 1.0 / Float(channelCount)

        for frame in 0..<frameCount {
            var sum: Float = 0.0
            for ch in 0..<channelCount {
                sum += samples[frame * channelCount + ch]
            }
            mono[frame] = sum * channelMultiplier
        }

        feedMonoAudio(samples: mono, sampleRate: sampleRate)
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        sampleAccumulator.removeAll(keepingCapacity: true)
        currentStereoPan = 0.0
        analyzer.reset()
        engine.reset()
    }
}
