import Foundation
import CoreFoundation

public final class MultitouchActuator: HapticActuatorProtocol, @unchecked Sendable {
    private typealias DeviceListFunc = @convention(c) () -> CFArray?
    private typealias GetIDFunc = @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias CreateActuatorFunc = @convention(c) (UInt64) -> UnsafeMutableRawPointer?
    private typealias OpenFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias CloseFunc = @convention(c) (UnsafeMutableRawPointer) -> Int32
    private typealias ActuateFunc = @convention(c) (UnsafeMutableRawPointer, Int32, UInt32, Float, Float) -> Int32

    private let lock = NSLock()
    private var frameworkHandle: UnsafeMutableRawPointer?
    private var actuatorPtr: UnsafeMutableRawPointer?
    private var openFn: OpenFunc?
    private var closeFn: CloseFunc?
    private var actuateFn: ActuateFunc?

    public private(set) var isAvailable: Bool = false

    public init() {
        setupActuator()
    }

    deinit {
        lock.lock()
        defer { lock.unlock() }
        if let actuator = actuatorPtr, let close = closeFn {
            _ = close(actuator)
        }
        if let handle = frameworkHandle {
            dlclose(handle)
        }
    }

    private func setupActuator() {
        lock.lock()
        defer { lock.unlock() }

        guard let handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_LAZY) else {
            isAvailable = false
            return
        }
        self.frameworkHandle = handle

        guard let devListSym = dlsym(handle, "MTDeviceCreateList"),
              let getIDSym = dlsym(handle, "MTDeviceGetDeviceID"),
              let createActSym = dlsym(handle, "MTActuatorCreateFromDeviceID"),
              let openSym = dlsym(handle, "MTActuatorOpen"),
              let closeSym = dlsym(handle, "MTActuatorClose"),
              let actuateSym = dlsym(handle, "MTActuatorActuate") else {
            isAvailable = false
            return
        }

        let devListFn = unsafeBitCast(devListSym, to: DeviceListFunc.self)
        let getIDFn = unsafeBitCast(getIDSym, to: GetIDFunc.self)
        let createActFn = unsafeBitCast(createActSym, to: CreateActuatorFunc.self)
        self.openFn = unsafeBitCast(openSym, to: OpenFunc.self)
        self.closeFn = unsafeBitCast(closeSym, to: CloseFunc.self)
        self.actuateFn = unsafeBitCast(actuateSym, to: ActuateFunc.self)

        guard let devList = devListFn() else {
            isAvailable = false
            return
        }

        let count = CFArrayGetCount(devList)
        for i in 0..<count {
            if let dev = CFArrayGetValueAtIndex(devList, i) {
                let devPtr = UnsafeMutableRawPointer(mutating: dev)
                var devID: UInt64 = 0
                _ = getIDFn(devPtr, &devID)
                if let actuator = createActFn(devID) {
                    if let open = self.openFn, open(actuator) == 0 {
                        self.actuatorPtr = actuator
                        self.isAvailable = true
                        return
                    }
                }
            }
        }

        isAvailable = false
    }

    public func actuate(pattern: HapticPattern) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard isAvailable, let actuator = actuatorPtr, let actuate = actuateFn else {
            return false
        }

        let result = actuate(actuator, pattern.rawPatternId, 0, 0.0, 0.0)
        return result == 0
    }
}
