import XCTest
@testable import Sound2HapticsCore

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

    func testStereoPanningLeftAndRight() {
        let processor = AudioStreamProcessor()
        let collector = TestCollector<AudioAnalysisResult>()
        processor.onAnalysis = { res in collector.append(res) }

        let count = 1024
        let wave = (0..<count).map { i in 0.8 * sin(2.0 * .pi * 80.0 * Float(i) / 48000.0) }
        let silent = [Float](repeating: 0.0, count: count)

        // Test Left heavy (Left: wave, Right: silent) -> pan should be negative
        processor.feedStereoAudio(left: wave, right: silent, sampleRate: sampleRate)
        XCTAssertNotNil(collector.last)
        XCTAssertLessThan(collector.last!.stereoPan, -0.8)

        // Reset and test Right heavy (Left: silent, Right: wave) -> pan should be positive
        processor.reset()
        processor.feedStereoAudio(left: silent, right: wave, sampleRate: sampleRate)
        XCTAssertNotNil(collector.last)
        XCTAssertGreaterThan(collector.last!.stereoPan, 0.8)
    }

    func testInputGainScaling() {
        let mockActuator = MockHapticActuator()
        let normalConfig = HapticBeatConfig(inputGain: 1.0)
        let processorNormal = AudioStreamProcessor(engine: HapticEngine(actuator: mockActuator, config: normalConfig))

        let collectorNormal = TestCollector<AudioAnalysisResult>()
        processorNormal.onAnalysis = { res in collectorNormal.append(res) }

        let wave = (0..<1024).map { i in 0.5 * sin(2.0 * .pi * 60.0 * Float(i) / 48000.0) }
        processorNormal.feedMonoAudio(samples: wave, sampleRate: sampleRate)

        let halfConfig = HapticBeatConfig(inputGain: 0.5)
        let processorHalf = AudioStreamProcessor(engine: HapticEngine(actuator: mockActuator, config: halfConfig))

        let collectorHalf = TestCollector<AudioAnalysisResult>()
        processorHalf.onAnalysis = { res in collectorHalf.append(res) }

        processorHalf.feedMonoAudio(samples: wave, sampleRate: sampleRate)

        XCTAssertNotNil(collectorNormal.last)
        XCTAssertNotNil(collectorHalf.last)
        XCTAssertGreaterThan(collectorNormal.last!.bandEnergy, collectorHalf.last!.bandEnergy)
    }

    func testSpatialTouchGatedPipeline() {
        let mockActuator = MockHapticActuator()
        let mockTracker = MockTouchTracker()
        let config = HapticBeatConfig(threshold: 0.25, frequencyBand: .bass)
        let engine = HapticEngine(actuator: mockActuator, config: config)
        let processor = AudioStreamProcessor(engine: engine, touchTracker: mockTracker)

        let count = 1024
        let bassWave = (0..<count).map { i in 0.8 * sin(2.0 * .pi * 60.0 * Float(i) / 48000.0) }
        let silent = [Float](repeating: 0.0, count: count)

        // 1. Finger is on RIGHT side (x: 0.85, y: 0.2). Play LEFT-panned bass sound (Left: bassWave, Right: silent)
        mockTracker.touches = [TrackpadTouch(id: 1, x: 0.85, y: 0.2)]
        processor.feedStereoAudio(left: bassWave, right: silent, sampleRate: sampleRate)
        XCTAssertEqual(mockActuator.actuateCount, 0, "Right-side finger touch must NOT actuate on left-panned audio!")

        // 2. Finger moves to LEFT side (x: 0.15, y: 0.2). Play LEFT-panned bass sound
        mockTracker.touches = [TrackpadTouch(id: 1, x: 0.15, y: 0.2)]
        processor.reset()
        processor.feedStereoAudio(left: bassWave, right: silent, sampleRate: sampleRate)
        XCTAssertEqual(mockActuator.actuateCount, 1, "Left-side finger touch MUST actuate on left-panned audio!")

        // 3. Multi-touch: fingers on BOTH Left and Right. Play RIGHT-panned bass sound
        mockTracker.touches = [
            TrackpadTouch(id: 1, x: 0.15, y: 0.2),
            TrackpadTouch(id: 2, x: 0.85, y: 0.2)
        ]
        processor.reset()
        processor.feedStereoAudio(left: silent, right: bassWave, sampleRate: sampleRate)
        XCTAssertEqual(mockActuator.actuateCount, 2, "Multi-touch spanning both sides must actuate on right-panned audio!")
    }
}
