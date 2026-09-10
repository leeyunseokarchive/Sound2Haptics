import XCTest
@testable import HapticBeatCore

final class MultitouchTrackerTests: XCTestCase {

    // Definition matching the C ABI of MultitouchSupport.framework on macOS arm64
    struct RawTouchSample {
        var frame: Int32 = 1
        var timestamp: Double = 100.0
        var pathIndex: Int32 = 0
        var state: UInt32 = 4 // Touching
        var fingerID: Int32 = 1
        var handID: Int32 = 1
        var posX: Float = 0.85
        var posY: Float = 0.20
        var velX: Float = 0.0
        var velY: Float = 0.0
        var zTotal: Float = 1.0
        var field9: Int32 = 0
        var angle: Float = 0.0
        var majorAxis: Float = 1.0
        var minorAxis: Float = 1.0
        var absPosX: Float = 100.0
        var absPosY: Float = 50.0
        var absVelX: Float = 0.0
        var absVelY: Float = 0.0
        var field14: Int32 = 0
        var field15: Int32 = 0
        var zDensity: Float = 1.0
    }

    func testMTTouchRawMemoryLayoutOffsets() {
        // Verify C ABI offset requirements
        XCTAssertEqual(MemoryLayout<RawTouchSample>.size, 96)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.stride, 96)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.pathIndex), 16)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.state), 20)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.fingerID), 24)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.handID), 28)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.posX), 32)
        XCTAssertEqual(MemoryLayout<RawTouchSample>.offset(of: \.posY), 36)
    }

    func testParseTouches_ExtractsAccurateCoordinatesAndState() {
        var touches = [
            // Touch 0: Finger on Right-Bottom (pathIndex = 0, state = 4 Touching)
            RawTouchSample(
                frame: 10,
                timestamp: 100.1,
                pathIndex: 0,
                state: 4,
                fingerID: 10,
                handID: 1,
                posX: 0.85,
                posY: 0.20
            ),
            // Touch 1: Finger on Left-Top (pathIndex = 1, state = 3 MakeTouch)
            RawTouchSample(
                frame: 10,
                timestamp: 100.1,
                pathIndex: 1,
                state: 3,
                fingerID: 20,
                handID: 1,
                posX: 0.15,
                posY: 0.75
            ),
            // Touch 2: Finger lifted (pathIndex = 2, state = 5 BreakTouch) -> Should NOT be included
            RawTouchSample(
                frame: 10,
                timestamp: 100.1,
                pathIndex: 2,
                state: 5,
                fingerID: 30,
                handID: 1,
                posX: 0.50,
                posY: 0.50
            )
        ]

        touches.withUnsafeMutableBytes { rawBuf in
            guard let basePtr = rawBuf.baseAddress else {
                XCTFail("Failed to get baseAddress")
                return
            }

            let parsed = MultitouchTracker.parseTouches(from: basePtr, numTouches: 3)

            XCTAssertEqual(parsed.count, 2, "State 5 (BreakTouch) should be excluded, leaving 2 touches")

            // Verify Touch 0
            XCTAssertEqual(parsed[0].id, 10, "FingerID must match offset 24")
            XCTAssertEqual(parsed[0].x, 0.85, accuracy: 0.001, "X coordinate must match offset 32")
            XCTAssertEqual(parsed[0].y, 0.20, accuracy: 0.001, "Y coordinate must match offset 36")

            // Verify Touch 1
            XCTAssertEqual(parsed[1].id, 20, "FingerID must match offset 24")
            XCTAssertEqual(parsed[1].x, 0.15, accuracy: 0.001, "X coordinate must match offset 32")
            XCTAssertEqual(parsed[1].y, 0.75, accuracy: 0.001, "Y coordinate must match offset 36")
        }
    }
}
