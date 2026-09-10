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
    processor.onHapticTrigger = { _ in
        counter.increment()
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

let delegate = AppDelegate()
app.delegate = delegate
app.run()
