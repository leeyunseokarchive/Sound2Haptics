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

    public func dynamicPattern(for energy: Float) -> HapticPattern {
        let headroom = max(0.01, 1.0 - config.threshold)
        let tier1 = config.threshold + headroom * 0.33
        let tier2 = config.threshold + headroom * 0.67

        if energy < tier1 {
            return .light
        } else if energy < tier2 {
            return .medium
        } else {
            return .strong
        }
    }

    @discardableResult
    public func trigger(energy: Float, timestamp: Double? = nil) -> Bool {
        return triggerWithPattern(energy: energy, timestamp: timestamp) != nil
    }

    public func triggerWithPattern(energy: Float, timestamp: Double? = nil) -> HapticPattern? {
        lock.lock()
        defer { lock.unlock() }

        guard config.isEnabled else {
            return nil
        }

        let now = timestamp ?? ProcessInfo.processInfo.systemUptime
        let cooldownSeconds = config.cooldownMs / 1000.0

        if now - lastActuatedTime < cooldownSeconds {
            return nil
        }

        let pattern = dynamicPattern(for: energy)
        let success = actuator.actuate(pattern: pattern)
        if success {
            lastActuatedTime = now
            return pattern
        }
        return nil
    }


    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastActuatedTime = 0.0
    }
}
