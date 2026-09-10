import Foundation

public final class MockTouchTracker: TouchTrackingSource, @unchecked Sendable {
    private let lock = NSLock()
    private var _touches: [TrackpadTouch] = []
    public var touches: [TrackpadTouch] {
        get {
            lock.lock()
            defer { lock.unlock() }
            return _touches
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            _touches = newValue
        }
    }

    public var isAvailable: Bool = true
    public var isTracking: Bool = false

    public init(touches: [TrackpadTouch] = []) {
        self._touches = touches
    }

    public func setTouches(_ touches: [TrackpadTouch]) {
        self.touches = touches
    }

    public func start() {
        isTracking = true
    }

    public func stop() {
        isTracking = false
        touches = []
    }
}
