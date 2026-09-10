# HapticBeat 🎧 ➔ 📳

**HapticBeat** is a native macOS menu bar utility that translates real-time system audio (music, movies, games, YouTube) into tactile haptic pulses on MacBook Force Touch trackpads.

---

## Features
- **Real-Time System Audio Capture**: Captures audio streams using macOS 13+ `ScreenCaptureKit` without needing third-party virtual audio cables.
- **Ultra-Low Latency DSP**: Powered by Apple `Accelerate (vDSP)` 1024-point FFT. Computes frequency band energy and transient onsets in under 5ms.
- **Background Global Haptics**: Uses a private `MultitouchSupport` C-bridge to actuate the Force Touch trackpad even while other apps (Safari, Chrome, games) are in focus.
- **Intelligent Cooldown Throttling**: Hardware-safe debounce logic (configurable 30ms - 300ms) to ensure crisp, rhythmic beats without buzzing or throttling.
- **Sleek Menu Bar Interface (SwiftUI)**: Live audio energy gauge, threshold marker, frequency band selector (Bass, Mid, Full), sensitivity sliders, and a built-in 120BPM synthetic kick drum demo.

---

## How to Build & Run

### 1. Run Unit Tests (100% Pass)
```bash
swift test
```

### 2. Test Physical Trackpad Actuator Click via CLI
```bash
swift run HapticBeat --test-actuator
```

### 3. Run Audio DSP & Haptic Pipeline Simulation
```bash
swift run HapticBeat --demo-dsp
```

### 4. Launch the Menu Bar App
```bash
swift run HapticBeat
```
Click the waveform icon (`waveform.circle.fill`) in the macOS top menu bar to open the control panel.

---

## Lab Week-2 Course Report
The full assignment report detailing the problem definition, discrepancies encountered, root causes, and TDD engineering solutions is available at:
`docs/AI_Software_Lab_Week2_Report.md`.
