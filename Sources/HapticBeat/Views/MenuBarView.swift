import SwiftUI
import HapticBeatCore

public struct MenuBarView: View {
    @ObservedObject var viewModel: HapticBeatViewModel

    public init(viewModel: HapticBeatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 2) {
                    Text("HapticBeat")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Trackpad Audio Haptics")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Beat pulse indicator
                Circle()
                    .fill(viewModel.isHapticFlashing ? Color.cyan : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(viewModel.isHapticFlashing ? Color.cyan.opacity(0.8) : Color.clear, lineWidth: 3)
                            .scaleEffect(viewModel.isHapticFlashing ? 1.8 : 1.0)
                            .opacity(viewModel.isHapticFlashing ? 0.0 : 1.0)
                            .animation(.easeOut(duration: 0.2), value: viewModel.isHapticFlashing)
                    )

                Toggle("", isOn: $viewModel.config.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
            }
            .padding(.bottom, 4)

            Divider()

            // Audio Level Meter & Threshold
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Energy Level")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%% / Threshold: %.0f%%", viewModel.currentBandEnergy * 100, viewModel.config.threshold * 100))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // Background track
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.08))

                        // Live energy fill
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.7), .blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.currentBandEnergy))))
                            .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: viewModel.currentBandEnergy)

                        // Threshold marker line
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 2, height: geo.size.height)
                            .offset(x: geo.size.width * CGFloat(viewModel.config.threshold))
                    }
                }
                .frame(height: 12)
            }

            // Capture Status Banner / Button
            HStack {
                Button(action: {
                    viewModel.toggleCapture()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isCapturing ? "stop.circle.fill" : "record.circle")
                            .foregroundColor(viewModel.isCapturing ? .red : .green)
                        Text(viewModel.isCapturing ? "Stop System Capture" : "Start System Capture")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isCapturing ? .red.opacity(0.8) : .blue)
            }

            // Permission Warning Banner (if ScreenCaptureKit is denied)
            if !viewModel.hasPermission {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Screen & Audio Permission Required")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    Text("macOS requires screen/audio recording permission to capture system sound.")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("Open System Settings") {
                        viewModel.openPrivacySettings()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(6)
            }

            Divider()

            // Frequency Band Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Target Frequency Band")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Picker("Band", selection: $viewModel.config.frequencyBand) {
                    ForEach(FrequencyBand.allCases, id: \.self) { band in
                        Text(band.displayName).tag(band)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Sensitivity (Threshold) Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Threshold (Sensitivity)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f%%", viewModel.config.threshold * 100))
                        .font(.caption2)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.config.threshold, in: 0.05...0.95, step: 0.05)
            }

            // Cooldown Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cooldown Interval")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%.0f ms", viewModel.config.cooldownMs))
                        .font(.caption2)
                        .monospacedDigit()
                }
                Slider(value: $viewModel.config.cooldownMs, in: 30.0...300.0, step: 10.0)
            }

            // Haptic Pattern Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("Haptic Intensity")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Picker("Pattern", selection: $viewModel.config.pattern) {
                    ForEach(HapticPattern.allCases, id: \.self) { pattern in
                        Text(pattern.displayName).tag(pattern)
                    }
                }
                .pickerStyle(.segmented)
            }

            Divider()

            // Testing and utility buttons
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.testHapticClick()
                }) {
                    Label("Test Click", systemImage: "hand.tap")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    viewModel.toggleSyntheticBeatDemo()
                }) {
                    Label(viewModel.isSyntheticPlaying ? "Stop Demo" : "120BPM Demo", systemImage: viewModel.isSyntheticPlaying ? "pause.fill" : "play.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .tint(viewModel.isSyntheticPlaying ? .orange : .secondary)

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
    }
}
