import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import ImageIO
import Sound2HapticsCore

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

@MainActor
func exportAssets() {
    print("Exporting Sound2Haptics assets (UI preview, trackpad preview, demo GIF)...")
    let assetsDir = URL(fileURLWithPath: "assets", isDirectory: true)
    try? FileManager.default.createDirectory(at: assetsDir, withIntermediateDirectories: true)

    let vm = HapticBeatViewModel()
    vm.config.isEnabled = true
    vm.currentBandEnergy = 0.76
    vm.lowEnergy = 0.85
    vm.midEnergy = 0.52
    vm.highEnergy = 0.31
    vm.stereoPan = -0.25
    vm.activeTouches = [
        TrackpadTouch(id: 1, x: 0.32, y: 0.45),
        TrackpadTouch(id: 2, x: 0.75, y: 0.62)
    ]
    vm.lastTriggeredPattern = .strong
    vm.isHapticFlashing = true

    struct PreviewWrapper: View {
        @ObservedObject var viewModel: HapticBeatViewModel
        var body: some View {
            MenuBarView(viewModel: viewModel)
                .padding(16)
                .frame(width: 370)
                .background(Color(nsColor: .windowBackgroundColor))
                .preferredColorScheme(.dark)
        }
    }

    // 1. Static UI Preview
    let uiView = PreviewWrapper(viewModel: vm)
    let hosting = NSHostingView(rootView: uiView)
    hosting.appearance = NSAppearance(named: .darkAqua)
    let fitting = hosting.fittingSize
    let exportSize = NSSize(width: max(370, fitting.width), height: max(550, fitting.height))
    hosting.frame = NSRect(origin: .zero, size: exportSize)
    hosting.layoutSubtreeIfNeeded()
    if let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) {
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: assetsDir.appendingPathComponent("ui_preview.png"))
            print("--> Exported: assets/ui_preview.png (\(pngData.count) bytes)")
        }
    }

    // 2. Trackpad Detail Preview
    struct TrackpadWrapper: View {
        @ObservedObject var viewModel: HapticBeatViewModel
        var body: some View {
            AppleTrackpadView(viewModel: viewModel)
                .padding(16)
                .frame(width: 370)
                .background(Color(nsColor: .windowBackgroundColor))
                .preferredColorScheme(.dark)
        }
    }
    let tpView = TrackpadWrapper(viewModel: vm)
    let tpHosting = NSHostingView(rootView: tpView)
    tpHosting.appearance = NSAppearance(named: .darkAqua)
    let tpFitting = tpHosting.fittingSize
    tpHosting.frame = NSRect(origin: .zero, size: NSSize(width: max(370, tpFitting.width), height: max(220, tpFitting.height)))
    tpHosting.layoutSubtreeIfNeeded()
    if let rep = tpHosting.bitmapImageRepForCachingDisplay(in: tpHosting.bounds) {
        tpHosting.cacheDisplay(in: tpHosting.bounds, to: rep)
        if let pngData = rep.representation(using: .png, properties: [:]) {
            try? pngData.write(to: assetsDir.appendingPathComponent("trackpad_preview.png"))
            print("--> Exported: assets/trackpad_preview.png (\(pngData.count) bytes)")
        }
    }

    // 3. Demo Animated GIF
    let gifURL = assetsDir.appendingPathComponent("demo.gif") as CFURL
    let frameCount = 20
    if let destination = CGImageDestinationCreateWithURL(gifURL, UTType.gif.identifier as CFString, frameCount, nil) {
        let fileProps = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFLoopCount as String: 0]]
        CGImageDestinationSetProperties(destination, fileProps as CFDictionary)
        let frameProps = [kCGImagePropertyGIFDictionary as String: [kCGImagePropertyGIFDelayTime as String: 0.08]]

        for i in 0..<frameCount {
            let t = Double(i) / Double(frameCount)
            let kick = Float(pow(sin(t * .pi * 2), 4))
            let isBeat = kick > 0.4

            vm.currentBandEnergy = 0.2 + kick * 0.75
            vm.lowEnergy = 0.15 + kick * 0.8
            vm.midEnergy = Float(0.3 + 0.3 * sin(t * .pi * 4))
            vm.highEnergy = Float(0.2 + 0.25 * cos(t * .pi * 4))
            vm.stereoPan = Float(sin(t * .pi * 2) * 0.6)

            let touchX = Float(0.5 + 0.3 * sin(t * .pi * 2))
            let touchY = Float(0.5 + 0.25 * cos(t * .pi * 2))
            vm.activeTouches = [TrackpadTouch(id: 1, x: touchX, y: touchY)]

            vm.isHapticFlashing = isBeat
            if kick > 0.7 {
                vm.lastTriggeredPattern = .strong
            } else if kick > 0.35 {
                vm.lastTriggeredPattern = .medium
            } else {
                vm.lastTriggeredPattern = .light
            }

            let fHosting = NSHostingView(rootView: PreviewWrapper(viewModel: vm))
            fHosting.appearance = NSAppearance(named: .darkAqua)
            fHosting.frame = NSRect(origin: .zero, size: exportSize)
            fHosting.layoutSubtreeIfNeeded()
            if let fRep = fHosting.bitmapImageRepForCachingDisplay(in: fHosting.bounds) {
                fHosting.cacheDisplay(in: fHosting.bounds, to: fRep)
                if let cg = fRep.cgImage {
                    CGImageDestinationAddImage(destination, cg, frameProps as CFDictionary)
                }
            }
        }
        if CGImageDestinationFinalize(destination) {
            print("--> Exported: assets/demo.gif (\(frameCount) frames, infinite loop)")
        }
    }
    exit(0)
}

if CommandLine.arguments.contains("--export-assets") {
    MainActor.assumeIsolated {
        exportAssets()
    }
}

let delegate = AppDelegate()
app.delegate = delegate
app.run()
