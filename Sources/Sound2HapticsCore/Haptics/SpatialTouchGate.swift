import Foundation

public struct TrackpadTouch: Sendable, Equatable {
    public let id: Int32
    public let x: Float // 0.0 (Left) ... 1.0 (Right)
    public let y: Float // 0.0 (Bottom) ... 1.0 (Top)

    public init(id: Int32 = 0, x: Float, y: Float) {
        self.id = id
        self.x = min(1.0, max(0.0, x))
        self.y = min(1.0, max(0.0, y))
    }
}

public struct SpatialTouchGate: Sendable {
    public static func evaluate(
        touches: [TrackpadTouch],
        result: AudioAnalysisResult,
        config: HapticBeatConfig
    ) -> Bool {
        // If the audio event itself did not trigger, no haptic
        guard result.isTrigger else { return false }

        // If no fingers are touching the trackpad, no touch-gated haptics
        guard !touches.isEmpty else { return false }

        // Check if ANY active finger matches the audio's spatial origin (X pan & Y frequency)
        for touch in touches {
            if matches(touch: touch, result: result, config: config) {
                return true
            }
        }

        return false
    }

    public static func matches(
        touch: TrackpadTouch,
        result: AudioAnalysisResult,
        config: HapticBeatConfig
    ) -> Bool {
        // --- 1. X-Axis: Stereo Panning Matching ---
        let x = touch.x
        let pan = result.stereoPan

        let xMatches: Bool
        if pan < -0.15 {
            // Sound is panned LEFT: finger must be on the left half (with 0.05 tolerance margin)
            xMatches = (x <= 0.55)
        } else if pan > 0.15 {
            // Sound is panned RIGHT: finger must be on the right half (with 0.05 tolerance margin)
            xMatches = (x >= 0.45)
        } else {
            // Sound is CENTER: any finger position matches
            xMatches = true
        }

        guard xMatches else { return false }

        // --- 2. Y-Axis: Frequency Band Matching ---
        let y = touch.y

        // Zones:
        // Bottom (0.0 ... 0.38): Low (Bass, 20-150Hz)
        // Center (0.30 ... 0.70): Mid (Vocals, 151-2kHz)
        // Top    (0.62 ... 1.0): High (Treble, 2k-20kHz)
        let isLowZone = (y <= 0.38)
        let isMidZone = (y >= 0.30 && y <= 0.70)
        let isHighZone = (y >= 0.62)

        // Does the audio event have sufficient energy in the corresponding band?
        // Use threshold scaled by band
        let threshold = config.threshold

        var yMatches = false

        if isLowZone && result.lowEnergy >= threshold {
            yMatches = true
        }
        if isMidZone && result.midEnergy >= threshold {
            yMatches = true
        }
        if isHighZone && result.highEnergy >= threshold {
            yMatches = true
        }

        return yMatches
    }
}
