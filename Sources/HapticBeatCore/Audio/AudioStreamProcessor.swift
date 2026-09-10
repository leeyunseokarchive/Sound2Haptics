import Foundation

public final class AudioStreamProcessor: @unchecked Sendable {
    private let lock = NSLock()
    public let analyzer: AudioDSPAnalyzer
    public let engine: HapticEngine

    public var onAnalysis: (@Sendable (AudioAnalysisResult) -> Void)?
    public var onHapticTrigger: (@Sendable (Bool) -> Void)?

    private var sampleAccumulator: [Float] = []
    public let fftSize: Int

    public init(
        analyzer: AudioDSPAnalyzer = AudioDSPAnalyzer(fftSize: 1024),
        engine: HapticEngine = HapticEngine()
    ) {
        self.analyzer = analyzer
        self.engine = engine
        self.fftSize = analyzer.fftSize
        self.sampleAccumulator.reserveCapacity(analyzer.fftSize * 2)
    }

    public func feedMonoAudio(samples: [Float], sampleRate: Float) {
        lock.lock()
        sampleAccumulator.append(contentsOf: samples)

        while sampleAccumulator.count >= fftSize {
            let window = Array(sampleAccumulator.prefix(fftSize))
            let hopSize = fftSize / 2
            sampleAccumulator.removeFirst(hopSize)

            let result = analyzer.process(samples: window, sampleRate: sampleRate, config: engine.config)

            var didActuate = false
            if result.isTrigger {
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

    public func feedInterleavedAudio(samples: [Float], channelCount: Int, sampleRate: Float) {
        guard channelCount > 0 else { return }
        if channelCount == 1 {
            feedMonoAudio(samples: samples, sampleRate: sampleRate)
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
        analyzer.reset()
        engine.reset()
    }
}
