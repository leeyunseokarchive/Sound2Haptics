import XCTest
@testable import HapticBeatCore

final class HapticEngineTests: XCTestCase {
    func testTriggerWithMockActuator() {
        let mock = MockHapticActuator()
        let config = HapticBeatConfig(isEnabled: true, cooldownMs: 90.0, pattern: .medium)
        let engine = HapticEngine(actuator: mock, config: config)

        let success = engine.trigger(energy: 0.6, timestamp: 1.000)
        XCTAssertTrue(success)
        XCTAssertEqual(mock.actuateCount, 1)
        XCTAssertEqual(mock.recordedPatterns.first, .medium)
    }

    func testDynamicPatternSelection_LowEnergy_SelectsLight() {
        let config = HapticBeatConfig(threshold: 0.25)
        let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
        // Headroom = 0.75; Tier1 = 0.25 + 0.25 = 0.50
        XCTAssertEqual(engine.dynamicPattern(for: 0.35), .light)
    }

    func testDynamicPatternSelection_MidEnergy_SelectsMedium() {
        let config = HapticBeatConfig(threshold: 0.25)
        let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
        // Tier2 = 0.25 + 0.50 = 0.75
        XCTAssertEqual(engine.dynamicPattern(for: 0.60), .medium)
    }

    func testDynamicPatternSelection_HighEnergy_SelectsStrong() {
        let config = HapticBeatConfig(threshold: 0.25)
        let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
        // High = >= 0.75
        XCTAssertEqual(engine.dynamicPattern(for: 0.85), .strong)
    }

    func testDynamicTriggerSelectsVaryingPatternsByEnergy() {
        let mock = MockHapticActuator()
        let config = HapticBeatConfig(threshold: 0.25, cooldownMs: 50.0)
        let engine = HapticEngine(actuator: mock, config: config)

        // Beat 1: Gentle bass note (energy 0.35) -> Light
        engine.trigger(energy: 0.35, timestamp: 1.0)
        XCTAssertEqual(mock.recordedPatterns.last, .light)

        // Beat 2: Medium beat (energy 0.60) -> Medium
        engine.trigger(energy: 0.60, timestamp: 1.1)
        XCTAssertEqual(mock.recordedPatterns.last, .medium)

        // Beat 3: Heavy kick drop (energy 0.90) -> Strong
        engine.trigger(energy: 0.90, timestamp: 1.2)
        XCTAssertEqual(mock.recordedPatterns.last, .strong)
    }

    func testDisabledConfigDoesNotActuate() {
        let mock = MockHapticActuator()
        let config = HapticBeatConfig(isEnabled: false)
        let engine = HapticEngine(actuator: mock, config: config)

        let success = engine.trigger(energy: 0.8, timestamp: 1.000)
        XCTAssertFalse(success)
        XCTAssertEqual(mock.actuateCount, 0)
    }

    func testCooldownThrottlingSuppressesRapidBeats() {
        let mock = MockHapticActuator()
        let config = HapticBeatConfig(isEnabled: true, cooldownMs: 90.0) // 90ms cooldown
        let engine = HapticEngine(actuator: mock, config: config)

        // First beat at 1.000s -> should trigger
        let beat1 = engine.trigger(energy: 0.8, timestamp: 1.000)
        XCTAssertTrue(beat1)
        XCTAssertEqual(mock.actuateCount, 1)

        // Rapid second beat at 1.030s (+30ms) -> should be suppressed
        let beat2 = engine.trigger(energy: 0.9, timestamp: 1.030)
        XCTAssertFalse(beat2)
        XCTAssertEqual(mock.actuateCount, 1)

        // Rapid third beat at 1.070s (+70ms) -> should be suppressed
        let beat3 = engine.trigger(energy: 0.95, timestamp: 1.070)
        XCTAssertFalse(beat3)
        XCTAssertEqual(mock.actuateCount, 1)

        // Fourth beat at 1.100s (+100ms >= 90ms) -> should trigger!
        let beat4 = engine.trigger(energy: 0.85, timestamp: 1.100)
        XCTAssertTrue(beat4)
        XCTAssertEqual(mock.actuateCount, 2)
    }

    func testActuatorUnavailableReturnsFalse() {
        let mock = MockHapticActuator()
        mock.isAvailable = false
        let config = HapticBeatConfig(isEnabled: true)
        let engine = HapticEngine(actuator: mock, config: config)

        let success = engine.trigger(energy: 0.8, timestamp: 1.000)
        XCTAssertFalse(success)
        XCTAssertEqual(mock.actuateCount, 0)
    }
}

