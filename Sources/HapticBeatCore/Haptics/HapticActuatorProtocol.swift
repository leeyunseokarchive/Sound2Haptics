import Foundation

public protocol HapticActuatorProtocol: AnyObject, Sendable {
    var isAvailable: Bool { get }
    func actuate(pattern: HapticPattern) -> Bool
}
