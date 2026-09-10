import AppKit
import Foundation
import HapticBeatCore

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

if CommandLine.arguments.contains("--test-actuator") {
    print("Testing Force Touch trackpad haptic actuator...")
    let actuator = MultitouchActuator()
    if actuator.isAvailable {
        print("--> Force Touch Trackpad actuator detected! Triggering haptic click...")
        let success = actuator.actuate(pattern: .medium)
        print("--> Actuation status: \(success ? "SUCCESS (Clicked)" : "FAILED")")
        exit(success ? 0 : 1)
    } else {
        print("--> No Force Touch Trackpad actuator detected on this hardware.")
        exit(0)
    }
}

if CommandLine.arguments.contains("--demo-dsp") {
    print("Running DSP and Haptic pipeline demonstration...")
    let mock = MockHapticActuator()
    let config = HapticBeatConfig(threshold: 0.25, frequencyBand: .bass)
    let processor = AudioStreamProcessor(analyzer: AudioDSPAnalyzer(), engine: HapticEngine(actuator: mock, config: config))

    final class SafeCounter: @unchecked Sendable {
        var count = 0
        let lock = NSLock()
        func increment() {
            lock.lock()
            count += 1
            lock.unlock()
        }
        var value: Int {
            lock.lock()
            defer { lock.unlock() }
            return count
        }
    }
    let counter = SafeCounter()
    processor.onAnalysis = { res in
        print(String(format: "[DSP Demo] Frame | Low(Bass): %.0f%% | Mid: %.0f%% | High(Treble): %.0f%% | Pan: %.2f | Trigger: %@", res.lowEnergy * 100, res.midEnergy * 100, res.highEnergy * 100, res.stereoPan, res.isTrigger ? "BEAT!" : "-"))
    }

    for frame in 0..<10 {
        let isKick = (frame == 2 || frame == 7)
        let freq: Float = isKick ? 60.0 : 800.0
        let amp: Float = isKick ? 0.9 : 0.1
        let samples = (0..<1024).map { amp * sin(2.0 * .pi * freq * Float($0) / 48000.0) }
        processor.feedMonoAudio(samples: samples, sampleRate: 48000.0)
    }
    print("--> Simulation complete. Total beat actuations triggered: \(counter.value)")
    exit(0)
}

if CommandLine.arguments.contains("--test-capture") {
    print("Testing ScreenCaptureKit real-time system audio capture...")
    let mock = MockHapticActuator()
    let config = HapticBeatConfig(threshold: 0.15, frequencyBand: .bass)
    let processor = AudioStreamProcessor(analyzer: AudioDSPAnalyzer(), engine: HapticEngine(actuator: mock, config: config))
    let source = ScreenCaptureKitAudioSource(processor: processor)

    final class FrameCounter: @unchecked Sendable {
        var count = 0
        let lock = NSLock()
        func inc() -> Int {
            lock.lock()
            defer { lock.unlock() }
            count += 1
            return count
        }
    }
    let frameCounter = FrameCounter()

    processor.onAnalysis = { res in
        let c = frameCounter.inc()
        if c % 10 == 0 {
            print(String(format: "[Capture Test] Frame #%d | Low: %.0f%% | Mid: %.0f%% | High: %.0f%% | Pan: %+.2f | Trigger: %@", c, res.lowEnergy * 100, res.midEnergy * 100, res.highEnergy * 100, res.stereoPan, res.isTrigger ? "BEAT!" : "-"))
        }
    }

    Task {
        await source.startCapture()
        print("Capturing system audio for 3 seconds...")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        await source.stopCapture()
        print("--> Test complete. Total analyzed frames: \(frameCounter.count), Actuations: \(mock.actuateCount)")
        exit(0)
    }
    RunLoop.main.run()
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
