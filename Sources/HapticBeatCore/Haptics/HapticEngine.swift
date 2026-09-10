import Foundation

public final class HapticEngine: @unchecked Sendable {
    private let lock = NSLock()
    public let actuator: HapticActuatorProtocol
    public var config: HapticBeatConfig

    private var lastActuatedTime: Double = 0.0

    public init(
        actuator: HapticActuatorProtocol = MultitouchActuator(),
        config: HapticBeatConfig = HapticBeatConfig()
    ) {
        self.actuator = actuator
        self.config = config
    }

    public func updateConfig(_ newConfig: HapticBeatConfig) {
        lock.lock()
        defer { lock.unlock() }
        self.config = newConfig
    }

    @discardableResult
    public func trigger(energy: Float, timestamp: Double? = nil) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard config.isEnabled else {
            return false
        }

        let now = timestamp ?? ProcessInfo.processInfo.systemUptime
        let cooldownSeconds = config.cooldownMs / 1000.0

        if now - lastActuatedTime < cooldownSeconds {
            return false
        }

        let success = actuator.actuate(pattern: config.pattern)
        if success {
            lastActuatedTime = now
        }
        return success
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastActuatedTime = 0.0
    }
}
