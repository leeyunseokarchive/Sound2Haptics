import XCTest
@testable import Sound2HapticsCore

final class Sound2HapticsCoreTests: XCTestCase {
    func testVersionString() {
        XCTAssertEqual(Sound2HapticsCore.version, "1.0.0")
    }
}
