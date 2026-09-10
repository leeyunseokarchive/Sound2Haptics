import XCTest
@testable import Sound2HapticsCore

final class SpatialTouchGateTests: XCTestCase {
    let config = HapticBeatConfig(threshold: 0.25)

    func testLeftPannedAudio_WithRightTouch_DoesNotActuate() {
        let leftResult = AudioAnalysisResult(
            bandEnergy: 0.8,
            totalEnergy: 0.8,
            lowEnergy: 0.8,
            stereoPan: -0.85,
            isTrigger: true,
            onsetDelta: 0.3
        )

        let rightTouch = [TrackpadTouch(id: 1, x: 0.85, y: 0.2)] // Right side, Low zone
        let shouldActuate = SpatialTouchGate.evaluate(touches: rightTouch, result: leftResult, config: config)

        XCTAssertFalse(shouldActuate, "Left-panned sound must not actuate when finger is on the right side")
    }

    func testLeftPannedAudio_WithLeftTouch_Actuates() {
        let leftResult = AudioAnalysisResult(
            bandEnergy: 0.8,
            totalEnergy: 0.8,
            lowEnergy: 0.8,
            stereoPan: -0.85,
            isTrigger: true,
            onsetDelta: 0.3
        )

        let leftTouch = [TrackpadTouch(id: 1, x: 0.15, y: 0.2)] // Left side, Low zone
        let shouldActuate = SpatialTouchGate.evaluate(touches: leftTouch, result: leftResult, config: config)

        XCTAssertTrue(shouldActuate, "Left-panned sound must actuate when finger is on the left side")
    }

    func testRightPannedAudio_WithRightTouch_Actuates() {
        let rightResult = AudioAnalysisResult(
            bandEnergy: 0.7,
            totalEnergy: 0.7,
            lowEnergy: 0.7,
            stereoPan: 0.80,
            isTrigger: true,
            onsetDelta: 0.3
        )

        let rightTouch = [TrackpadTouch(id: 1, x: 0.80, y: 0.2)]
        let shouldActuate = SpatialTouchGate.evaluate(touches: rightTouch, result: rightResult, config: config)

        XCTAssertTrue(shouldActuate, "Right-panned sound must actuate when finger is on the right side")
    }

    func testMultiTouch_BothLeftAndRightFingers_ActuatesForBothChannels() {
        let twoFingers = [
            TrackpadTouch(id: 1, x: 0.15, y: 0.2), // Left
            TrackpadTouch(id: 2, x: 0.85, y: 0.2)  // Right
        ]

        let leftResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8, lowEnergy: 0.8,
            stereoPan: -0.9, isTrigger: true, onsetDelta: 0.3
        )
        let rightResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8, lowEnergy: 0.8,
            stereoPan: 0.9, isTrigger: true, onsetDelta: 0.3
        )

        XCTAssertTrue(SpatialTouchGate.evaluate(touches: twoFingers, result: leftResult, config: config),
                      "Multi-touch spanning left and right must actuate for left sound")
        XCTAssertTrue(SpatialTouchGate.evaluate(touches: twoFingers, result: rightResult, config: config),
                      "Multi-touch spanning left and right must actuate for right sound")
    }

    func testFrequencyYAxis_BassWithBottomTouch_Actuates() {
        let bassResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8,
            lowEnergy: 0.8, midEnergy: 0.05, highEnergy: 0.02,
            stereoPan: 0.0, isTrigger: true, onsetDelta: 0.3
        )

        let bottomTouch = [TrackpadTouch(id: 1, x: 0.5, y: 0.15)] // Low (Bass) zone
        XCTAssertTrue(SpatialTouchGate.evaluate(touches: bottomTouch, result: bassResult, config: config),
                      "Bass sound must actuate for finger in the bottom zone")
    }

    func testFrequencyYAxis_BassWithTopTouch_DoesNotActuate() {
        let bassResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8,
            lowEnergy: 0.8, midEnergy: 0.05, highEnergy: 0.02,
            stereoPan: 0.0, isTrigger: true, onsetDelta: 0.3
        )

        let topTouch = [TrackpadTouch(id: 1, x: 0.5, y: 0.85)] // High (Treble) zone
        XCTAssertFalse(SpatialTouchGate.evaluate(touches: topTouch, result: bassResult, config: config),
                       "Bass sound must not actuate when finger is solely in the top (treble) zone")
    }

    func testMultiTouch_TopAndBottomFingers_ActuatesForBothBassAndTreble() {
        let topAndBottomTouches = [
            TrackpadTouch(id: 1, x: 0.5, y: 0.15), // Low zone
            TrackpadTouch(id: 2, x: 0.5, y: 0.85)  // High zone
        ]

        let bassResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8,
            lowEnergy: 0.8, midEnergy: 0.0, highEnergy: 0.0,
            stereoPan: 0.0, isTrigger: true, onsetDelta: 0.3
        )
        let trebleResult = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8,
            lowEnergy: 0.0, midEnergy: 0.0, highEnergy: 0.8,
            stereoPan: 0.0, isTrigger: true, onsetDelta: 0.3
        )

        XCTAssertTrue(SpatialTouchGate.evaluate(touches: topAndBottomTouches, result: bassResult, config: config),
                      "Top + Bottom touches must actuate for bass")
        XCTAssertTrue(SpatialTouchGate.evaluate(touches: topAndBottomTouches, result: trebleResult, config: config),
                      "Top + Bottom touches must actuate for treble")
    }

    func testNoTouches_DoesNotActuate() {
        let result = AudioAnalysisResult(
            bandEnergy: 0.8, totalEnergy: 0.8, lowEnergy: 0.8,
            stereoPan: 0.0, isTrigger: true, onsetDelta: 0.3
        )
        XCTAssertFalse(SpatialTouchGate.evaluate(touches: [], result: result, config: config),
                       "No touches must not actuate in touch-gated mode")
    }
}
