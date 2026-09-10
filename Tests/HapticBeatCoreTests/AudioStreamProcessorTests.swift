import XCTest
@testable import HapticBeatCore

private final class TestCollector<T>: @unchecked Sendable {
    private var values: [T] = []
    private let lock = NSLock()

    func append(_ value: T) {
        lock.lock()
        defer { lock.unlock() }
        values.append(value)
    }

    var all: [T] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return values.count
    }

    var last: T? {
        lock.lock()
        defer { lock.unlock() }
        return values.last
    }
}

final class AudioStreamProcessorTests: XCTestCase {
    let sampleRate: Float = 48000.0

    func testPipelineEndToEndWithBassTone() {
        let mockActuator = MockHapticActuator()
        let config = HapticBeatConfig(isEnabled: true, threshold: 0.3, cooldownMs: 50.0, frequencyBand: .bass)
        let analyzer = AudioDSPAnalyzer(fftSize: 1024)
        let engine = HapticEngine(actuator: mockActuator, config: config)
        let processor = AudioStreamProcessor(analyzer: analyzer, engine: engine)

        let collector = TestCollector<AudioAnalysisResult>()
        processor.onAnalysis = { result in
            collector.append(result)
        }

        // Generate 60Hz sine wave (1024 samples)
        let bassWave = (0..<1024).map { i in
            0.8 * sin(2.0 * .pi * 60.0 * Float(i) / 48000.0)
        }

        processor.feedMonoAudio(samples: bassWave, sampleRate: sampleRate)

        XCTAssertEqual(collector.count, 1)
        XCTAssertGreaterThan(collector.all[0].bandEnergy, 0.3)
        XCTAssertTrue(collector.all[0].isTrigger)
        XCTAssertEqual(mockActuator.actuateCount, 1)
    }

    func testChunkedStreamingAccumulatesCorrectly() {
        let mockActuator = MockHapticActuator()
        let config = HapticBeatConfig(threshold: 0.3, frequencyBand: .bass)
        let analyzer = AudioDSPAnalyzer(fftSize: 1024)
        let engine = HapticEngine(actuator: mockActuator, config: config)
        let processor = AudioStreamProcessor(analyzer: analyzer, engine: engine)

        let collector = TestCollector<AudioAnalysisResult>()
        processor.onAnalysis = { res in collector.append(res) }

        // Feed 256 samples 3 times (768 total) -> less than 1024, should not trigger analysis yet
        let chunk256 = [Float](repeating: 0.5, count: 256)
        processor.feedMonoAudio(samples: chunk256, sampleRate: sampleRate)
        processor.feedMonoAudio(samples: chunk256, sampleRate: sampleRate)
        processor.feedMonoAudio(samples: chunk256, sampleRate: sampleRate)
        XCTAssertEqual(collector.count, 0)

        // Feed 4th chunk (1024 total) -> should trigger analysis now!
        processor.feedMonoAudio(samples: chunk256, sampleRate: sampleRate)
        XCTAssertEqual(collector.count, 1)
    }

    func testStereoInterleavedDownmix() {
        let mockActuator = MockHapticActuator()
        let processor = AudioStreamProcessor(
            analyzer: AudioDSPAnalyzer(fftSize: 1024),
            engine: HapticEngine(actuator: mockActuator)
        )

        let collector = TestCollector<AudioAnalysisResult>()
        processor.onAnalysis = { res in collector.append(res) }

        // 1024 stereo frames = 2048 interleaved samples (L=0.8, R=0.8)
        var stereo = [Float](repeating: 0.0, count: 2048)
        for i in 0..<1024 {
            let val = 0.8 * sin(2.0 * .pi * 60.0 * Float(i) / 48000.0)
            stereo[i * 2] = val
            stereo[i * 2 + 1] = val
        }

        processor.feedInterleavedAudio(samples: stereo, channelCount: 2, sampleRate: sampleRate)
        XCTAssertNotNil(collector.last)
        XCTAssertGreaterThan(collector.last!.bandEnergy, 0.3)
    }
}
