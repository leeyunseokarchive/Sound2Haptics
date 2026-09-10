import SwiftUI
import Sound2HapticsCore

public struct MenuBarView: View {
    @ObservedObject var viewModel: HapticBeatViewModel

    public init(viewModel: HapticBeatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 28, height: 28)

                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentColor)
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("Sound2Haptics")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Force Touch Audio Haptics")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Subtle beat flash indicator
                Circle()
                    .fill(viewModel.isHapticFlashing ? Color.accentColor : Color.primary.opacity(0.15))
                    .frame(width: 7, height: 7)
                    .scaleEffect(viewModel.isHapticFlashing ? 1.3 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: viewModel.isHapticFlashing)

                Toggle("", isOn: $viewModel.config.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .scaleEffect(0.85)
            }
            .padding(.bottom, 2)

            // MARK: - Apple-Style Virtual Trackpad
            AppleTrackpadView(viewModel: viewModel)

            // MARK: - Live Energy & Dynamic Status Card
            VStack(alignment: .leading, spacing: 8) {
                // Header with dynamic intensity badge
                HStack {
                    HStack(spacing: 5) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Dynamic Response")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Real-time triggered tier badge
                    Text(viewModel.lastTriggeredPattern.displayName.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(viewModel.isHapticFlashing ? .primary : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewModel.isHapticFlashing ? Color.accentColor.opacity(0.2) : Color.primary.opacity(0.06))
                        )
                }

                // Clean Apple Energy Meter with Threshold marker
                VStack(alignment: .leading, spacing: 4) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height

                        ZStack(alignment: .leading) {
                            // Track
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.primary.opacity(0.06))

                            // Live energy fill
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.accentColor.opacity(0.85))
                                .frame(width: max(0, min(w, w * CGFloat(viewModel.currentBandEnergy))))
                                .animation(.interactiveSpring(response: 0.1, dampingFraction: 0.8), value: viewModel.currentBandEnergy)

                            // Threshold hairline notch
                            Rectangle()
                                .fill(Color.primary.opacity(0.6))
                                .frame(width: 1.5, height: h)
                                .offset(x: max(0, min(w - 1.5, w * CGFloat(viewModel.config.threshold))))
                        }
                    }
                    .frame(height: 5)

                    HStack {
                        Text(String(format: "Energy: %.0f%%", viewModel.currentBandEnergy * 100))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "Threshold: %.0f%%", viewModel.config.threshold * 100))
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )

            // MARK: - Capture Button
            Button(action: {
                viewModel.toggleCapture()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isCapturing ? "stop.circle.fill" : "record.circle")
                    Text(viewModel.isCapturing ? "Stop Audio Capture" : "Start Audio Capture")
                        .font(.system(size: 12, weight: .medium))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 26)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isCapturing ? Color.red.opacity(0.85) : Color.accentColor)

            // MARK: - Permission Warning Banner
            if !viewModel.hasPermission {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 5) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 11))
                        Text("Screen & Audio Recording Permission Required")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    Text("macOS requires system recording permission to capture audio.")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    Button("Open System Settings") {
                        viewModel.openPrivacySettings()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }

            // MARK: - Controls Group Card (Bento Style)
            VStack(spacing: 10) {
                // Target Frequency Band
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Frequency Focus")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(viewModel.config.frequencyBand.rangeDescription)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Picker("Band", selection: $viewModel.config.frequencyBand) {
                        ForEach(FrequencyBand.allCases, id: \.self) { band in
                            Text(band.shortName).tag(band)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }

                Divider()
                    .opacity(0.5)

                // Sensitivity (Threshold)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Sensitivity")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(String(format: "%.0f%%", viewModel.config.threshold * 100))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    Slider(value: $viewModel.config.threshold, in: 0.05...0.95, step: 0.05)
                        .controlSize(.small)
                }

                Divider()
                    .opacity(0.5)

                // Input Level (Gain)
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        HStack(spacing: 4) {
                            Image(systemName: "speaker.wave.2")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text("Input Level")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.1fx", viewModel.config.inputGain))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                    Slider(value: $viewModel.config.inputGain, in: 0.10...2.0, step: 0.05)
                        .controlSize(.small)
                }
            }
            .padding(10)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
            )

            // MARK: - Footer Actions
            HStack(spacing: 8) {
                Button(action: {
                    viewModel.testHapticClick()
                }) {
                    Label("Test Tap", systemImage: "hand.tap")
                        .font(.system(size: 10, weight: .medium))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if viewModel.triggerCount > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.accentColor)
                        Text("\(viewModel.triggerCount)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .background(Color.primary.opacity(0.04))
                    .cornerRadius(4)
                }

                Spacer()

                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .frame(width: 340)
    }
}

// MARK: - Apple-Style Realistic Virtual Trackpad
public struct AppleTrackpadView: View {
    @ObservedObject var viewModel: HapticBeatViewModel

    public init(viewModel: HapticBeatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 6) {
            // Trackpad Top Bar
            HStack(alignment: .center) {
                HStack(spacing: 5) {
                    Image(systemName: "hand.point.up.left")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Trackpad")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Touch Count Badge
                if !viewModel.activeTouches.isEmpty {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 4, height: 4)
                        Text("\(viewModel.activeTouches.count) Touch\(viewModel.activeTouches.count > 1 ? "es" : "")")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12))
                    .cornerRadius(4)
                } else {
                    Text("No Touch")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.6))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.primary.opacity(0.03))
                        .cornerRadius(4)
                }

                // Stereo Balance readout
                Text(panText)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.03))
                    .cornerRadius(4)
            }

            // Realistic Trackpad Surface
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let centerX = w / 2.0
                let panOffset = CGFloat(viewModel.stereoPan) * (w * 0.35)

                ZStack {
                    // 1. Unibody Aluminum Base & Shadow
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color(white: 0.18))
                        .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 2)

                    // 2. Matte Glass Touchpad Surface
                    RoundedRectangle(cornerRadius: 13)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.13),
                                    Color(white: 0.10)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .padding(1)
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                                .padding(1)
                        )

                    // 3. Subtle Apple Acoustic Zone Meters (Clean monochrome levels)
                    VStack(spacing: 0) {
                        // High band zone
                        HStack {
                            Text("Treble")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                            Spacer()
                            AcousticLevelPill(energy: viewModel.highEnergy)
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 6)

                        Spacer()

                        // Mid band zone
                        HStack {
                            Text("Vocals")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                            Spacer()
                            AcousticLevelPill(energy: viewModel.midEnergy)
                        }
                        .padding(.horizontal, 10)

                        Spacer()

                        // Low band zone
                        HStack {
                            Text("Bass")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.7))
                            Spacer()
                            AcousticLevelPill(energy: viewModel.lowEnergy)
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 6)
                    }

                    // 4. Subtle Ambient Acoustic Glass Glow (shifts gracefully with Stereo Pan)
                    let totalScale = CGFloat(max(0.05, viewModel.currentTotalEnergy))
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(Double(0.08 + 0.18 * viewModel.currentBandEnergy)),
                                    Color.white.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 2,
                                endRadius: 50
                            )
                        )
                        .frame(width: 40 + 80 * totalScale, height: 40 + 80 * totalScale)
                        .position(x: centerX + panOffset, y: h * 0.5)
                        .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: viewModel.stereoPan)
                        .animation(.interactiveSpring(response: 0.12, dampingFraction: 0.8), value: viewModel.currentTotalEnergy)

                    // 5. Native Apple Pointer Touch Cursors (Frosted Glass Disc)
                    let margin: CGFloat = 16
                    let trackWidth = max(1.0, w - margin * 2)
                    let trackHeight = max(1.0, h - margin * 2)

                    ForEach(viewModel.activeTouches, id: \.id) { touch in
                        let tx = margin + CGFloat(touch.x) * trackWidth
                        let ty = margin + CGFloat(1.0 - touch.y) * trackHeight

                        // Frosted translucent glass disc with soft drop shadow
                        Circle()
                            .fill(Color.white.opacity(0.28))
                            .frame(width: 24, height: 24)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 1.2)
                            )
                            .shadow(color: Color.black.opacity(0.35), radius: 3, y: 1.5)
                            .position(x: tx, y: ty)

                        // Center white tactile core
                        Circle()
                            .fill(Color.white)
                            .frame(width: 5, height: 5)
                            .position(x: tx, y: ty)
                    }

                    // 6. Refined Apple Haptic Glass Ripple (Expanding clean focus ring)
                    if viewModel.isHapticFlashing {
                        let shockX = viewModel.activeTouches.first.map { margin + CGFloat($0.x) * trackWidth } ?? (centerX + panOffset)
                        let shockY = viewModel.activeTouches.first.map { margin + CGFloat(1.0 - $0.y) * trackHeight } ?? (h * 0.72)

                        let (baseSize, strokeW, scaleEnd): (CGFloat, CGFloat, CGFloat) = {
                            switch viewModel.lastTriggeredPattern {
                            case .light:
                                return (45, 1.2, 1.3)
                            case .medium:
                                return (75, 1.8, 1.6)
                            case .strong:
                                return (105, 2.4, 2.0)
                            }
                        }()

                        Circle()
                            .stroke(Color.white.opacity(0.85), lineWidth: strokeW)
                            .frame(width: baseSize, height: baseSize)
                            .position(x: shockX, y: shockY)
                            .scaleEffect(viewModel.isHapticFlashing ? scaleEnd : 0.6)
                            .opacity(viewModel.isHapticFlashing ? 0.0 : 0.85)
                            .animation(.easeOut(duration: 0.22), value: viewModel.isHapticFlashing)
                    }
                }
            }
            .frame(height: 125)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.4))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
    }

    private var panText: String {
        let p = viewModel.stereoPan
        if abs(p) < 0.05 {
            return "Center"
        } else if p < 0 {
            return String(format: "L %.0f%%", abs(p) * 100)
        } else {
            return String(format: "R %.0f%%", p * 100)
        }
    }
}

// MARK: - Clean 4-segment Acoustic Level Pill (macOS Sound bar style)
private struct AcousticLevelPill: View {
    let energy: Float

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4) { index in
                let threshold = Float(index + 1) * 0.25
                RoundedRectangle(cornerRadius: 1)
                    .fill(energy >= threshold ? Color.primary.opacity(0.75) : Color.primary.opacity(0.12))
                    .frame(width: 3, height: 6)
            }
        }
    }
}
