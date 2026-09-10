import XCTest
@testable import HapticBeatCore

final class HapticBeatConfigTests: XCTestCase {
    func testDefaultConfigValues() {
        let config = HapticBeatConfig()
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(config.threshold, 0.45, accuracy: 0.001)
        XCTAssertEqual(config.cooldownMs, 90.0, accuracy: 0.1)
        XCTAssertEqual(config.frequencyBand, .bass)
        XCTAssertEqual(config.pattern, .medium)
    }

    func testFrequencyBandRanges() {
        XCTAssertEqual(FrequencyBand.bass.minFrequency, 20.0)
        XCTAssertEqual(FrequencyBand.bass.maxFrequency, 150.0)

        XCTAssertEqual(FrequencyBand.mid.minFrequency, 151.0)
        XCTAssertEqual(FrequencyBand.mid.maxFrequency, 2000.0)

        XCTAssertEqual(FrequencyBand.full.minFrequency, 20.0)
        XCTAssertEqual(FrequencyBand.full.maxFrequency, 20000.0)
    }

    func testThresholdClamping() {
        var config = HapticBeatConfig()
        config.threshold = 1.5 // exceeds max 0.95
        XCTAssertEqual(config.threshold, 0.95, accuracy: 0.001)

        config.threshold = -0.2 // below min 0.05
        XCTAssertEqual(config.threshold, 0.05, accuracy: 0.001)
    }

    func testCooldownClamping() {
        var config = HapticBeatConfig()
        config.cooldownMs = 10.0 // below min 30.0
        XCTAssertEqual(config.cooldownMs, 30.0, accuracy: 0.1)

        config.cooldownMs = 1000.0 // above max 500.0
        XCTAssertEqual(config.cooldownMs, 500.0, accuracy: 0.1)
    }

    func testPatternIds() {
        XCTAssertEqual(HapticPattern.light.rawPatternId, 1)
        XCTAssertEqual(HapticPattern.medium.rawPatternId, 2)
        XCTAssertEqual(HapticPattern.strong.rawPatternId, 5)
    }
}
