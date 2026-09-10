import XCTest
@testable import HapticBeatCore

final class HapticBeatCoreTests: XCTestCase {
    func testVersionString() {
        XCTAssertEqual(HapticBeatCore.version, "1.0.0")
    }
}
