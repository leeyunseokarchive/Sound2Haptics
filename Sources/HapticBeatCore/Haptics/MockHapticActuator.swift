import Foundation

public final class MockHapticActuator: HapticActuatorProtocol, @unchecked Sendable {
    private let lock = NSLock()
    public var isAvailable: Bool = true
    public private(set) var actuateCount: Int = 0
    public private(set) var recordedPatterns: [HapticPattern] = []

    public init(isAvailable: Bool = true) {
        self.isAvailable = isAvailable
    }

    public func actuate(pattern: HapticPattern) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard isAvailable else { return false }
        actuateCount += 1
        recordedPatterns.append(pattern)
        return true
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        actuateCount = 0
        recordedPatterns.removeAll()
    }
}
