import Foundation
import SwiftUI
import Combine
import AppKit
import HapticBeatCore

@MainActor
public final class HapticBeatViewModel: ObservableObject {
    @Published public var config: HapticBeatConfig {
        didSet {
            processor.engine.updateConfig(config)
        }
    }

    @Published public var isCapturing: Bool = false
    @Published public var currentBandEnergy: Float = 0.0
    @Published public var currentTotalEnergy: Float = 0.0
    @Published public var lowEnergy: Float = 0.0
    @Published public var midEnergy: Float = 0.0
    @Published public var highEnergy: Float = 0.0
    @Published public var stereoPan: Float = 0.0
    @Published public var activeTouches: [TrackpadTouch] = []
    @Published public var isHapticFlashing: Bool = false
    @Published public var triggerCount: Int = 0
    @Published public var hasPermission: Bool = true
    @Published public var errorMessage: String? = nil
    @Published public var isSyntheticPlaying: Bool = false

    public let processor: AudioStreamProcessor
    private var audioSource: ScreenCaptureKitAudioSource?
    private var flashTimer: Timer?
    private var demoTimer: Timer?
    private var touchTimer: Timer?

    public init(config: HapticBeatConfig = HapticBeatConfig()) {
        self.config = config
        let analyzer = AudioDSPAnalyzer(fftSize: 1024)
        let engine = HapticEngine(config: config)
        self.processor = AudioStreamProcessor(analyzer: analyzer, engine: engine)

        setupCallbacks()
    }

    deinit {
        touchTimer?.invalidate()
        flashTimer?.invalidate()
        demoTimer?.invalidate()
    }

    private func setupCallbacks() {
        processor.onAnalysis = { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.currentBandEnergy = result.bandEnergy
                self.currentTotalEnergy = result.totalEnergy
                self.lowEnergy = result.lowEnergy
                self.midEnergy = result.midEnergy
                self.highEnergy = result.highEnergy
                self.stereoPan = result.stereoPan
            }
        }

        // 30Hz lightweight touch cursor update for smooth UI tracking
        touchTimer = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.activeTouches = self.processor.touchTracker.touches
            }
        }

        processor.onHapticTrigger = { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.triggerCount += 1
                self.isHapticFlashing = true
                self.flashTimer?.invalidate()
                self.flashTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: false) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.isHapticFlashing = false
                    }
                }
            }
        }
    }

    public func toggleCapture() {
        if isCapturing {
            stopCapture()
        } else {
            startCapture()
        }
    }

    public func startCapture() {
        if audioSource == nil {
            let source = ScreenCaptureKitAudioSource(processor: processor)
            source.onPermissionError = { [weak self] error in
                DispatchQueue.main.async {
                    self?.hasPermission = false
                    self?.errorMessage = error
                    self?.isCapturing = false
                }
            }
            source.onStatusChange = { [weak self] running in
                DispatchQueue.main.async {
                    self?.isCapturing = running
                    if running {
                        self?.hasPermission = true
                        self?.errorMessage = nil
                    }
                }
            }
            self.audioSource = source
        }

        Task {
            await audioSource?.startCapture()
        }
    }

    public func stopCapture() {
        Task {
            await audioSource?.stopCapture()
        }
    }

    public func testHapticClick() {
        _ = processor.engine.actuator.actuate(pattern: config.pattern)
        isHapticFlashing = true
        flashTimer?.invalidate()
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.isHapticFlashing = false
            }
        }
    }

    public func toggleSyntheticBeatDemo() {
        if isSyntheticPlaying {
            demoTimer?.invalidate()
            demoTimer = nil
            isSyntheticPlaying = false
        } else {
            isSyntheticPlaying = true
            // Play a synthetic 60Hz kick drum burst every 500ms (120 BPM)
            demoTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self = self, self.isSyntheticPlaying else { return }
                    self.playSyntheticKick()
                }
            }
        }
    }

    private func playSyntheticKick() {
        let sampleRate: Float = 48000.0
        let frameCount = 1024
        var kick = [Float](repeating: 0.0, count: frameCount)
        for i in 0..<frameCount {
            let t = Float(i) / sampleRate
            let freq = max(45.0, 130.0 * exp(-t * 30.0)) // Pitch drop kick
            let envelope = exp(-t * 20.0) // Amplitude decay
            kick[i] = 0.9 * envelope * sin(2.0 * .pi * freq * t)
        }
        processor.feedMonoAudio(samples: kick, sampleRate: sampleRate)
    }

    public func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }
}
