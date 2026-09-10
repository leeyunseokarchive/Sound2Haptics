import SwiftUI
import HapticBeatCore

public struct MenuBarView: View {
    @ObservedObject var viewModel: HapticBeatViewModel

    public init(viewModel: HapticBeatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // MARK: - Header
            HStack(spacing: 8) {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.cyan)

                VStack(alignment: .leading, spacing: 1) {
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
            .padding(.bottom, 2)

            // MARK: - 2D Trackpad Matrix Visualizer (Hero)
            TrackpadMatrixView(viewModel: viewModel)

            // MARK: - Live Energy Meter & Threshold
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("Band Energy")
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
                .frame(height: 10)
            }

            // MARK: - Capture Button
            Button(action: {
                viewModel.toggleCapture()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isCapturing ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(viewModel.isCapturing ? .red : .green)
                    Text(viewModel.isCapturing ? "Stop System Capture" : "Start System Capture")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isCapturing ? .red.opacity(0.8) : .blue)

            // MARK: - Permission Warning Banner
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

            // MARK: - Target Frequency Band
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Target Frequency Band")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(viewModel.config.frequencyBand.rangeDescription)
                        .font(.caption2)
                        .foregroundColor(.cyan)
                }

                Picker("Band", selection: $viewModel.config.frequencyBand) {
                    ForEach(FrequencyBand.allCases, id: \.self) { band in
                        Text(band.shortName).tag(band)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            // MARK: - Threshold Slider
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

            // MARK: - Input Gain (Volume) Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.cyan)
                        Text("Input Gain (Volume)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.0f%% (%.1fx)", viewModel.config.inputGain * 100, viewModel.config.inputGain))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundColor(viewModel.config.inputGain > 1.2 ? .orange : .secondary)
                }
                Slider(value: $viewModel.config.inputGain, in: 0.10...2.0, step: 0.05)

                Text("Scale loud music down to avoid saturation, or boost quiet tracks.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
            }

            // MARK: - Haptic Intensity
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
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            Divider()

            // MARK: - Footer Actions
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.testHapticClick()
                }) {
                    Label("Test Click", systemImage: "hand.tap")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                if viewModel.triggerCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 9))
                            .foregroundColor(.yellow)
                        Text("Beats: \(viewModel.triggerCount)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(4)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(width: 360)
    }
}

// MARK: - 2D Trackpad Matrix Visualizer (Option 1: Organic Glow Radar)
public struct TrackpadMatrixView: View {
    @ObservedObject var viewModel: HapticBeatViewModel

    public init(viewModel: HapticBeatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Header Bar
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.portrait.and.arrow.forward")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.cyan)
                    Text("TRACKPAD HAPTIC MATRIX")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Real-time Stereo Panning Readout
                HStack(spacing: 4) {
                    Text("PAN")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)
                    Text(panText)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(abs(viewModel.stereoPan) < 0.1 ? .secondary : .cyan)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)
            }

            // Trackpad Visual Surface
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let centerX = w / 2.0
                let panOffset = CGFloat(viewModel.stereoPan) * (w * 0.35)

                ZStack {
                    // Dark matte glass surface
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.09, blue: 0.13),
                                    Color(red: 0.05, green: 0.06, blue: 0.09)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    viewModel.isHapticFlashing
                                        ? Color.cyan.opacity(0.8)
                                        : Color.white.opacity(0.12),
                                    lineWidth: viewModel.isHapticFlashing ? 1.5 : 1.0
                                )
                                .animation(.easeOut(duration: 0.2), value: viewModel.isHapticFlashing)
                        )

                    // Frequency Zone Labels & Grid
                    VStack(spacing: 0) {
                        // High band zone (Top)
                        HStack {
                            Text("HIGH · TREBLE")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.7))
                            Spacer()
                            Text(String(format: "%.0f%%", viewModel.highEnergy * 100))
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.7))
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 6)

                        Spacer()

                        // Mid band zone (Center)
                        HStack {
                            Text("MID · VOCALS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0).opacity(0.7))
                            Spacer()
                            Text(String(format: "%.0f%%", viewModel.midEnergy * 100))
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color(red: 0.7, green: 0.5, blue: 1.0).opacity(0.7))
                        }
                        .padding(.horizontal, 10)

                        Spacer()

                        // Low band zone (Bottom)
                        HStack {
                            Text("LOW · BASS")
                                .font(.system(size: 8, weight: .bold, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.85))
                            Spacer()
                            Text(String(format: "%.0f%%", viewModel.lowEnergy * 100))
                                .font(.system(size: 8, weight: .semibold, design: .monospaced))
                                .foregroundColor(.orange.opacity(0.85))
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    }

                    // Tactical reticle crosshair and guide lines
                    Path { path in
                        // Center crosshair
                        path.move(to: CGPoint(x: centerX - 8, y: h * 0.5))
                        path.addLine(to: CGPoint(x: centerX + 8, y: h * 0.5))
                        path.move(to: CGPoint(x: centerX, y: h * 0.5 - 8))
                        path.addLine(to: CGPoint(x: centerX, y: h * 0.5 + 8))

                        // High line guide
                        path.move(to: CGPoint(x: 12, y: h * 0.33))
                        path.addLine(to: CGPoint(x: w - 12, y: h * 0.33))

                        // Low line guide
                        path.move(to: CGPoint(x: 12, y: h * 0.67))
                        path.addLine(to: CGPoint(x: w - 12, y: h * 0.67))
                    }
                    .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    // Left & Right stereo boundary markers
                    HStack {
                        Text("L")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(viewModel.stereoPan < -0.2 ? .cyan : Color.white.opacity(0.2))
                            .padding(.leading, 8)
                        Spacer()
                        Text("R")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(viewModel.stereoPan > 0.2 ? .cyan : Color.white.opacity(0.2))
                            .padding(.trailing, 8)
                    }

                    // --- ORGANIC GLOW ORBS ---

                    // 1. High Frequency Node (Treble / Neon Cyan)
                    let highX = centerX + panOffset * 0.7
                    let highY = h * 0.22
                    let highScale = CGFloat(max(0.1, viewModel.highEnergy))
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 14 + 30 * highScale, height: 14 + 30 * highScale)
                        .blur(radius: 7 + 8 * highScale)
                        .opacity(Double(0.2 + 0.8 * viewModel.highEnergy))
                        .position(x: highX, y: highY)
                        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: viewModel.highEnergy)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: viewModel.stereoPan)

                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 4 + 4 * highScale, height: 4 + 4 * highScale)
                        .position(x: highX, y: highY)
                        .opacity(Double(0.3 + 0.7 * viewModel.highEnergy))

                    // 2. Mid Frequency Node (Vocals / Purple-Indigo)
                    let midX = centerX + panOffset * 0.85
                    let midY = h * 0.50
                    let midScale = CGFloat(max(0.1, viewModel.midEnergy))
                    Circle()
                        .fill(Color(red: 0.65, green: 0.35, blue: 1.0))
                        .frame(width: 18 + 40 * midScale, height: 18 + 40 * midScale)
                        .blur(radius: 9 + 10 * midScale)
                        .opacity(Double(0.2 + 0.8 * viewModel.midEnergy))
                        .position(x: midX, y: midY)
                        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.75), value: viewModel.midEnergy)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: viewModel.stereoPan)

                    Circle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 5 + 5 * midScale, height: 5 + 5 * midScale)
                        .position(x: midX, y: midY)
                        .opacity(Double(0.3 + 0.7 * viewModel.midEnergy))

                    // 3. Low Frequency Node (Bass / Warm Amber-Orange)
                    let lowX = centerX + panOffset
                    let lowY = h * 0.78
                    let lowScale = CGFloat(max(0.1, viewModel.lowEnergy))
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.5, blue: 0.1),
                                    Color(red: 0.9, green: 0.2, blue: 0.0).opacity(0.4)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 28
                            )
                        )
                        .frame(width: 22 + 52 * lowScale, height: 22 + 52 * lowScale)
                        .blur(radius: 10 + 12 * lowScale)
                        .opacity(Double(0.25 + 0.75 * viewModel.lowEnergy))
                        .position(x: lowX, y: lowY)
                        .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.75), value: viewModel.lowEnergy)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: viewModel.stereoPan)

                    Circle()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: 6 + 6 * lowScale, height: 6 + 6 * lowScale)
                        .position(x: lowX, y: lowY)
                        .opacity(Double(0.4 + 0.6 * viewModel.lowEnergy))

                    // 4. Haptic Trigger Shockwave Ring
                    if viewModel.isHapticFlashing {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.cyan, .white, .orange],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 90, height: 90)
                            .position(x: lowX, y: lowY)
                            .scaleEffect(viewModel.isHapticFlashing ? 1.5 : 0.6)
                            .opacity(viewModel.isHapticFlashing ? 0.0 : 0.8)
                            .animation(.easeOut(duration: 0.25), value: viewModel.isHapticFlashing)
                    }
                }
            }
            .frame(height: 135)
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var panText: String {
        let p = viewModel.stereoPan
        if abs(p) < 0.05 {
            return "CENTER"
        } else if p < 0 {
            return String(format: "L %.0f%%", abs(p) * 100)
        } else {
            return String(format: "R %.0f%%", p * 100)
        }
    }
}
