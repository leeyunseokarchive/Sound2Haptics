import Foundation
import CoreFoundation

public protocol TouchTrackingSource: Sendable {
    var touches: [TrackpadTouch] { get }
    var isAvailable: Bool { get }
    var isTracking: Bool { get }
    func start()
    func stop()
}

public final class MultitouchTracker: TouchTrackingSource, @unchecked Sendable {
    public static let shared = MultitouchTracker()

    private let lock = NSLock()
    private var _touches: [TrackpadTouch] = []
    public var touches: [TrackpadTouch] {
        lock.lock()
        defer { lock.unlock() }
        if !isTracking { return [] }
        if lastFrameTime > 0 && ProcessInfo.processInfo.systemUptime - lastFrameTime > 0.3 {
            return []
        }
        return _touches
    }


    public private(set) var isAvailable: Bool = false
    public private(set) var isTracking: Bool = false

    private var frameworkHandle: UnsafeMutableRawPointer?
    private var devicePtr: UnsafeMutableRawPointer?

    private typealias MTDeviceCreateListFn = @convention(c) () -> CFArray?
    private typealias MTRegisterContactFn = @convention(c) (UnsafeMutableRawPointer, @convention(c) (Int32, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32) -> Void
    private typealias MTDeviceStartFn = @convention(c) (UnsafeMutableRawPointer, Int32) -> Void
    private typealias MTDeviceStopFn = @convention(c) (UnsafeMutableRawPointer) -> Void

    private var devStopFn: MTDeviceStopFn?

    public init() {
        setupDevice()
    }

    deinit {
        stop()
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }

    private func setupDevice() {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY) else {
            isAvailable = false
            return
        }
        self.frameworkHandle = handle

        guard let createListSym = dlsym(handle, "MTDeviceCreateList"),
              let registerSym = dlsym(handle, "MTRegisterContactFrameCallback"),
              let startSym = dlsym(handle, "MTDeviceStart"),
              let stopSym = dlsym(handle, "MTDeviceStop") else {
            isAvailable = false
            return
        }

        let createList = unsafeBitCast(createListSym, to: MTDeviceCreateListFn.self)
        let registerCb = unsafeBitCast(registerSym, to: MTRegisterContactFn.self)
        let devStart = unsafeBitCast(startSym, to: MTDeviceStartFn.self)
        self.devStopFn = unsafeBitCast(stopSym, to: MTDeviceStopFn.self)

        guard let devList = createList(), CFArrayGetCount(devList) > 0,
              let rawDev = CFArrayGetValueAtIndex(devList, 0) else {
            isAvailable = false
            return
        }

        let dev = UnsafeMutableRawPointer(mutating: rawDev)
        self.devicePtr = dev

        let callback: @convention(c) (Int32, UnsafeMutableRawPointer, Int32, Double, Int32) -> Int32 = { devId, touchPtr, numTouches, timestamp, frame in
            MultitouchTracker.shared.handleFrame(touchPtr: touchPtr, numTouches: numTouches)
            return 0
        }

        registerCb(dev, callback)
        devStart(dev, 0)
        self.isTracking = true
        self.isAvailable = true
    }

    public func start() {
        lock.lock()
        defer { lock.unlock() }
        guard !isTracking, let dev = devicePtr, let handle = frameworkHandle,
              let startSym = dlsym(handle, "MTDeviceStart") else { return }
        let devStart = unsafeBitCast(startSym, to: MTDeviceStartFn.self)
        devStart(dev, 0)
        isTracking = true
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isTracking, let dev = devicePtr, let stopFn = devStopFn else { return }
        stopFn(dev)
        isTracking = false
        _touches = []
    }

    private var lastFrameTime: TimeInterval = 0

    public static func parseTouches(from touchPtr: UnsafeRawPointer, numTouches: Int32) -> [TrackpadTouch] {
        guard numTouches > 0 else { return [] }
        let stride = 96
        var current: [TrackpadTouch] = []

        for i in 0..<Int(numTouches) {
            let base = touchPtr.advanced(by: i * stride)
            // Memory layout for MTTouch on arm64 macOS:
            // offset 0: frame (Int32)
            // offset 4: [padding 4 bytes for 8-byte alignment of double]
            // offset 8: timestamp (Double)
            // offset 16: pathIndex (Int32)
            // offset 20: state (UInt32) [3 = MakeTouch, 4 = Touching]
            // offset 24: fingerID (Int32)
            // offset 28: handID (Int32)
            // offset 32: normalizedVector.position.x (Float: 0.0=Left, 1.0=Right)
            // offset 36: normalizedVector.position.y (Float: 0.0=Bottom, 1.0=Top)
            let state = base.advanced(by: 20).assumingMemoryBound(to: UInt32.self).pointee
            let fingerID = base.advanced(by: 24).assumingMemoryBound(to: Int32.self).pointee
            let x = base.advanced(by: 32).assumingMemoryBound(to: Float.self).pointee
            let y = base.advanced(by: 36).assumingMemoryBound(to: Float.self).pointee

            // States: 3 = MakeTouch, 4 = Touching
            if state == 3 || state == 4 {
                current.append(TrackpadTouch(id: fingerID, x: x, y: y))
            }
        }
        return current
    }

    fileprivate func handleFrame(touchPtr: UnsafeMutableRawPointer, numTouches: Int32) {
        let current = MultitouchTracker.parseTouches(from: touchPtr, numTouches: numTouches)
        let now = ProcessInfo.processInfo.systemUptime
        lock.lock()
        self.lastFrameTime = now
        self._touches = current
        lock.unlock()
    }
}


