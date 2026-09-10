import Foundation

public enum FrequencyBand: String, CaseIterable, Sendable {
    case bass
    case mid
    case full

    public var minFrequency: Float {
        switch self {
        case .bass: return 20.0
        case .mid: return 151.0
        case .full: return 20.0
        }
    }

    public var maxFrequency: Float {
        switch self {
        case .bass: return 150.0
        case .mid: return 2000.0
        case .full: return 20000.0
        }
    }

    public var displayName: String {
        switch self {
        case .bass: return "Bass (20-150Hz)"
        case .mid: return "Mid (150-2kHz)"
        case .full: return "Full Spectrum"
        }
    }

    public var shortName: String {
        switch self {
        case .bass: return "Bass"
        case .mid: return "Mid"
        case .full: return "Full"
        }
    }

    public var rangeDescription: String {
        switch self {
        case .bass: return "20-150Hz"
        case .mid: return "151-2kHz"
        case .full: return "20-20kHz"
        }
    }
}

public enum HapticPattern: String, CaseIterable, Sendable {
    case light
    case medium
    case strong

    public var rawPatternId: Int32 {
        switch self {
        case .light: return 1
        case .medium: return 2
        case .strong: return 5
        }
    }

    public var displayName: String {
        switch self {
        case .light: return "Light"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
}

public struct HapticBeatConfig: Sendable {
    public var isEnabled: Bool

    private var _threshold: Float
    public var threshold: Float {
        get { _threshold }
        set { _threshold = min(max(newValue, 0.05), 0.95) }
    }

    private var _cooldownMs: Double
    public var cooldownMs: Double {
        get { _cooldownMs }
        set { _cooldownMs = min(max(newValue, 30.0), 500.0) }
    }

    public var frequencyBand: FrequencyBand
    public var pattern: HapticPattern

    private var _onsetSensitivity: Float
    public var onsetSensitivity: Float {
        get { _onsetSensitivity }
        set { _onsetSensitivity = min(max(newValue, 0.01), 0.5) }
    }

    private var _inputGain: Float
    public var inputGain: Float {
        get { _inputGain }
        set { _inputGain = min(max(newValue, 0.1), 2.0) }
    }

    public init(
        isEnabled: Bool = true,
        threshold: Float = 0.25,
        cooldownMs: Double = 90.0,
        frequencyBand: FrequencyBand = .bass,
        pattern: HapticPattern = .medium,
        onsetSensitivity: Float = 0.04,
        inputGain: Float = 1.0
    ) {
        self.isEnabled = isEnabled
        self._threshold = min(max(threshold, 0.05), 0.95)
        self._cooldownMs = min(max(cooldownMs, 30.0), 500.0)
        self.frequencyBand = frequencyBand
        self.pattern = pattern
        self._onsetSensitivity = min(max(onsetSensitivity, 0.01), 0.5)
        self._inputGain = min(max(inputGain, 0.1), 2.0)
    }
}
