<div align="center">

[한국어](README.md) | **English**

<img src="assets/logo.png" width="160" alt="Sound2Haptics Logo — Trackpad Cat">

### **Touch Your Music: Real-time Audio-to-Haptic Engine for MacBook Trackpads**

Transforms your MacBook Force Touch trackpad into an acoustic tactile canvas.  
Captures macOS system audio (Music, YouTube, Games, Movies) without virtual audio cables (no BlackHole needed), translating frequency band energies and stereo panning into precise, localized Taptic Engine clicks right under your fingertips.

**`swift run Sound2Haptics`**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Platform: macOS 14.0+](https://img.shields.io/badge/Platform-macOS%2014.0%2B-black.svg?logo=apple)](https://www.apple.com/macos/)
[![Hardware: Force Touch Trackpad](https://img.shields.io/badge/Hardware-Force%20Touch%20Trackpad-blue.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests: 36/36 Passing](https://img.shields.io/badge/Tests-36%2F36%20passed-brightgreen.svg)]()
[![Driver-Free](https://img.shields.io/badge/Virtual%20Driver-Zero%20(No%20BlackHole)-success.svg)]()

**[▶ Demo (GIF)](#live-demonstration) · [Architecture](#architecture--how-it-works) · [Getting Started](#installation--quickstart) · [Course Report](docs/AI_Software_Lab_Week2_Report.md)**

<br/>

<img src="assets/demo.gif" width="460" alt="Sound2Haptics Live Demo Animation: Real-time Frequency Spectrum & Trackpad Haptic Actuation">

</div>

---

## 📑 Documentation & Research

| Document | Description |
|---|---|
| [Lab Development & Troubleshooting Report](docs/AI_Software_Lab_Week2_Report.md) | Comprehensive engineering journey, 10 key problem resolutions, and architectural decisions |
| [Dynamic Haptic Specification](docs/superpowers/specs/2026-09-11-dynamic-haptic-intensity-design.md) | Volume-headroom proportional dynamic 3-tier haptic pattern arbitration algorithm |
| [Haptic Engine Implementation Plan](docs/superpowers/plans/2026-09-11-dynamic-haptic-intensity-plan.md) | TDD roadmap for the audio pipeline and ViewModel refactoring |
| [C ABI Multitouch Specification](Sources/Sound2HapticsCore/Multitouch/MultitouchTracker.swift) | Memory layout offsets reverse-engineered from Apple's private `MultitouchSupport` framework |

---

## 💡 Why Sound2Haptics?

MacBook Force Touch trackpads contain the most sophisticated electromagnetic **Taptic Engine** in the laptop industry. Yet, this hardware is predominantly relegated to mundane system clicks and file drag feedback.

Traditional music visualizers only stimulate the **visual** sense, while existing haptic solutions demand costly vibration vests ($300+) or invasive kernel-level virtual audio drivers (BlackHole, Soundflower) that compromise system security and user convenience.

**Sound2Haptics requires zero drivers and zero external hardware: it unlocks tactile musical immersion directly on your MacBook trackpad.**

### 📊 Comparison with Existing Approaches

| Feature | Stock macOS | Virtual Driver Setup (BlackHole) | Third-Party Haptic Gear | **Sound2Haptics** |
|---|---|---|---|---|
| **Driver Installation** | None | Kernel/Virtual Audio Driver Required | Custom Driver & App Required | **Zero Driver (Native Tap)** |
| **Additional Cost** | $0 | $0 | $300 - $500 | **$0 (Built-in Hardware)** |
| **Audio Capture Latency** | N/A | Buffer loopback (~50ms) | Bluetooth wireless lag (>40ms) | **CoreAudio Tap (<5ms)** |
| **Signal Processing** | N/A | High CPU overhead | Separate hardware DSP | **Apple Accelerate vDSP FFT** |
| **Spatial 2D Separation** | None | 1D Left/Right Only | Fixed motor positions | **2D Trackpad Coordinate 1:1 Mapping** |
| **Dynamic Intensity** | Fixed click | Amplitude-proportional vibration | Preset vibration motors | **3-Tier Volume Headroom Response** |

---

## 🎬 Live Demonstration

<div align="center">

| macOS Menu Bar Popover UI | Aluminum Virtual Trackpad & Ripples |
|:---:|:---:|
| <img src="assets/ui_preview.png" width="340" alt="Sound2Haptics Menu Bar Popover"> | <img src="assets/trackpad_preview.png" width="340" alt="Aluminum Virtual Trackpad"> |
| *Apple HIG Bento Card layout & 4-Band Acoustic Level Pills* | *Frosted glass touch rings and dynamic white ripples* |

</div>

- **Native Apple HIG Design**: Replaced generic high-contrast neon styling with authentic unibody bead-blasted aluminum textures and macOS frosted glass materials.
- **4-Segment Acoustic Level Pills**: Sub-Bass (20-80Hz), Bass (80-250Hz), Mid (250-4000Hz), and Treble (4-20kHz) energies displayed via clean capsule meters.
- **Real-Time Touch Rings & Ripples**: Coordinates `(x, y)` are tracked with zero latency; upon beat trigger, subtle acoustic haptic ripples expand outward from your finger.

---

## ⚙️ Architecture & How It Works

```mermaid
flowchart TD
    A["macOS System Audio<br/>(Music, YouTube, Game, Movie)"] -->|Zero-Driver Tap| B["CoreAudio Process Tap<br/>ScreenCaptureKit Audio Source"]
    B -->|48kHz PCM Buffer| C["AudioStreamProcessor"]
    
    subgraph DSP ["Apple Accelerate vDSP Real-Time DSP"]
        C -->|1024-pt FFT| D["AudioDSPAnalyzer"]
        D --> E["Frequency Band Energy Integration<br/>(SubBass, Bass, Mid, Treble)"]
        D --> F["Stereo Channel Separation & Pan Calculation"]
        D --> G["Transient Onset Peak Detection"]
    end

    subgraph Hardware ["Trackpad Multitouch Ingestion"]
        H["MacBook Trackpad"] -->|Private C ABI| I["MultitouchTracker<br/>(MTRegisterContactFrameCallback)"]
        I -->|1:1 Normalized Coords (x, y)| J["SpatialTouchGate"]
    end

    E & F & G --> K["Dynamic Headroom Arbiter"]
    K -->|Light / Medium / Strong Arbitration| L["HapticEngine"]
    
    J -->|Touch Position & Band Match Verification| L
    L -->|Cooldown Throttle Enforcement| M["MultitouchActuator<br/>(MTActuatorActuate)"]
    M -->|Physical Click!| N["MacBook Force Touch Taptic Engine"]
```

---

## 🎯 Spatial & Frequency Mapping

Sound2Haptics models the trackpad surface as a 2D acoustic plane:

```
┌──────────────────────────────────────────────┐
│  High / Treble (Cymbals, hi-hats, vocal top) │  (Y: 0.66 ~ 1.00)
├──────────────────────────────────────────────┤
│  Mid-Range (Vocals, piano, guitars, snares)  │  (Y: 0.33 ~ 0.66)
├──────────────────────────────────────────────┤
│  Sub-Bass / Bass (Kick drums, 808 bass, sfx) │  (Y: 0.00 ~ 0.33)
└──────────────────────────────────────────────┘
  Left Panning (X: 0~0.5)      Right Panning (X: 0.5~1.0)
```

- **Stereo Panning**: Audio panned to the left will only actuate when your finger rests on the left half of the trackpad.
- **Multitouch Bifurcation**: Placing one finger at the bottom (bass) and another at the top (treble) routes independent tactile pulses to each finger as both instruments play!

---

## 🚀 Installation & Quickstart

### Prerequisites
- **macOS**: Sonoma (14.0) or later
- **Hardware**: MacBook with Force Touch Trackpad (Apple Silicon M1/M2/M3/M4 or Intel)
- **Toolchain**: Xcode 15+ or Swift 5.9+ / Swift 6.0

### Build & Run

```bash
# 1. Clone repository
git clone https://github.com/leeyunseokarchive/Sound2Haptics.git
cd Sound2Haptics

# 2. Run unit tests (36 tests)
swift test

# 3. Launch Menu Bar App
swift run Sound2Haptics
```

Click the waveform icon (`waveform.circle.fill`) in the macOS menu bar to configure settings.

### Diagnostics & CLI Flags

```bash
# Test physical Force Touch trackpad click
swift run Sound2Haptics --test-actuator

# Run synthetic kick drum FFT & haptic simulation
swift run Sound2Haptics --demo-dsp

# Capture live system audio for 3 seconds
swift run Sound2Haptics --test-capture

# Export UI previews and animated demo GIF
swift run Sound2Haptics --export-assets
```

---

## 🧪 Testing & Verification

Built strictly following TDD (Test-Driven Development) principles:

```bash
$ swift test
Test Suite 'All tests' passed at 2026-09-11 02:23:25.
	 Executed 36 tests, with 0 failures (0 unexpected) in 0.025 seconds
```

---

## 📜 License

Distributed under the [MIT License](LICENSE).
Built for everyone who loves Apple's Force Touch hardware and great music.
