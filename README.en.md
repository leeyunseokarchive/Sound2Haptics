<div align="center">

[한국어](README.md) | **English**

<img src="assets/logo.png" width="160" alt="Sound2Haptics Logo — Trackpad Cat">

### **Feel the beat right under your fingertips on your MacBook trackpad.**

Play music or videos, and your trackpad taps back to the rhythm, pitch, and stereo position of the sound.  
No virtual audio drivers like BlackHole needed — just launch the app and it works right away.

**`swift run Sound2Haptics`**

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?logo=swift)](https://swift.org)
[![Platform: macOS 14.0+](https://img.shields.io/badge/Platform-macOS%2014.0%2B-black.svg?logo=apple)](https://www.apple.com/macos/)
[![Hardware: Force Touch Trackpad](https://img.shields.io/badge/Hardware-Force%20Touch%20Trackpad-blue.svg)]()
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests: 36/36 Passing](https://img.shields.io/badge/Tests-36%2F36%20passed-brightgreen.svg)]()
[![Driver-Free](https://img.shields.io/badge/Virtual%20Driver-Zero%20(No%20BlackHole)-success.svg)]()

**[Live Demo](#live-demo) · [Why Sound2Haptics](#why-sound2haptics) · [How It Works](#how-it-works) · [Getting Started](#getting-started) · [Lab Report](docs/AI_Software_Lab_Week2_Report.md)**

<br/>

<img src="assets/demo.gif" width="460" alt="Sound2Haptics Demo Animation">

</div>

---

## Live Demo

<div align="center">

| macOS Menu Bar Popover | Aluminum Virtual Trackpad |
|:---:|:---:|
| <img src="assets/ui_preview.png" width="340" alt="Sound2Haptics Menu Bar Popover"> | <img src="assets/trackpad_preview.png" width="340" alt="Aluminum Virtual Trackpad"> |
| *4-band audio frequency meters and dynamic status badge* | *Real-time touch point tracking and tactile beat ripple* |

</div>

- **Native Apple Feel**: Designed with clean unibody aluminum styling and frosted glass materials instead of harsh neon colors.
- **4-Band Frequency Meters**: Displays live energy levels across sub-bass (20-80Hz), bass (80-250Hz), mids (250-4000Hz), and treble (4-20kHz).
- **Smooth Touch Tracking**: Follows your fingers across the trackpad surface in real time, pulsing white ripples on every beat.

---

## Why Sound2Haptics?

The Force Touch trackpad on modern MacBooks isn't a mechanical button. An electromagnetic vibration actuator (Taptic Engine) pushes back against your finger to simulate a physical click.

It is one of the most precise haptic motors in any laptop, but it mostly sits idle doing standard file clicks. Sound2Haptics turns that hardware into an acoustic canvas so you can literally feel your music.

Other solutions typically require messy virtual audio loopback drivers (BlackHole, Soundflower) or expensive dedicated vibration gear ($300+). Sound2Haptics runs completely standalone on macOS with zero extra drivers.

### Comparison

| Feature | Stock macOS | Virtual Driver Setup | Third-Party Haptic Gear | Sound2Haptics |
|---|---|---|---|---|
| **Driver Installation** | None | BlackHole/Soundflower required | Custom driver required | **None (Zero Driver)** |
| **Extra Cost** | $0 | $0 | $300 - $500 | **$0 (Uses built-in hardware)** |
| **Audio Latency** | N/A | Buffer loopback delay (~50ms) | Bluetooth wireless lag (>40ms) | **Direct native capture (<5ms)** |
| **Spatial Separation** | None | 1D Left/Right only | Fixed motor locations | **2D trackpad coordinate mapping** |
| **Haptic Intensity** | Single static click | Amplitude-proportional vibration | Preset vibration patterns | **Automatic 3-tier headroom response** |

---

## How It Works

```mermaid
flowchart TD
    A["macOS System Audio<br/>(Music, YouTube, Games, Movies)"] -->|Native Capture| B["CoreAudio Process Tap<br/>ScreenCaptureKit"]
    B -->|48kHz PCM Buffer| C["AudioStreamProcessor"]
    
    subgraph DSP ["Apple Accelerate vDSP"]
        C -->|1024-pt FFT| D["AudioDSPAnalyzer"]
        D --> E["4 Frequency Bands<br/>(Sub-Bass, Bass, Mid, Treble)"]
        D --> F["Stereo Panning Analysis"]
        D --> G["Beat Onset Detection"]
    end

    subgraph Hardware ["Trackpad Multitouch"]
        H["MacBook Trackpad"] -->|Private C ABI| I["MultitouchTracker"]
        I -->|Finger Coordinates (x, y)| J["SpatialTouchGate"]
    end

    E & F & G --> K["Dynamic Intensity Arbiter"]
    K -->|Light / Medium / Strong| L["HapticEngine"]
    
    J -->|Verify Touch Zone Matches Audio| L
    L -->|Throttle Cooldown| M["MultitouchActuator"]
    M -->|Physical Click!| N["MacBook Taptic Engine"]
```

1. **Audio Tap**: Captures system audio cleanly using macOS native CoreAudio Process Tap without third-party audio drivers.
2. **Frequency Splitting**: Runs a 1024-point vDSP FFT in 0.1ms to separate low bass thumps from high vocal/cymbal transients.
3. **Finger Tracking**: Reads finger coordinates directly from macOS `MultitouchSupport` framework with exact sub-millisecond precision.
4. **Haptic Actuation**: When sound frequency and stereo position align with where your finger touches, the Taptic Engine fires a clean, crisp click scaled to volume headroom (Light, Medium, or Strong).

---

## Spatial & Frequency Mapping

```
┌──────────────────────────────────────────────┐
│  Treble / High (Cymbals, hi-hats, vocals)    │  (Top 1/3)
├──────────────────────────────────────────────┤
│  Mid-Range (Vocals, guitars, piano, snares)  │  (Middle 1/3)
├──────────────────────────────────────────────┤
│  Bass / Sub-Bass (Kick drums, 808s, sfx)     │  (Bottom 1/3)
└──────────────────────────────────────────────┘
  Left Audio (X: 0.0 ~ 0.5)      Right Audio (X: 0.5 ~ 1.0)
```

- **Stereo Panning**: Sounds panned to the left only actuate under fingers on the left side of the trackpad.
- **Multi-Touch Support**: Put one finger at the bottom (bass) and another at the top (treble) to feel independent beats on each finger simultaneously.
- **Adaptive Strength**: Quiet tracks trigger a gentle tap (`Light`), while heavy bass drops actuate a firm force click (`Strong`).

---

## Getting Started

### Requirements
- macOS Sonoma (14.0) or later
- MacBook with Force Touch Trackpad (Apple Silicon or Intel)
- Xcode Command Line Tools (`xcode-select --install`)

### Run Locally

Clone and launch in three quick commands:

```bash
git clone https://github.com/leeyunseokarchive/Sound2Haptics.git
cd Sound2Haptics
swift run Sound2Haptics
```

Click the waveform icon in your macOS menu bar to open the settings panel.

### CLI Diagnostic Commands

Test individual subsystems directly from your terminal:

```bash
# Verify the physical trackpad actuator clicks
swift run Sound2Haptics --test-actuator

# Run a simulated kick drum through FFT and haptic dispatch
swift run Sound2Haptics --demo-dsp

# Capture and analyze live audio for 3 seconds
swift run Sound2Haptics --test-capture

# Generate high-res UI previews and demo GIF
swift run Sound2Haptics --export-assets
```

---

## Tests & Verification

```bash
$ swift test
Test Suite 'All tests' passed at 2026-09-11 02:27:42.
	 Executed 36 tests, with 0 failures (0 unexpected) in 0.026 seconds
```

All 36 unit tests pass in 0.026s, verifying DSP band discrimination, C ABI memory layout alignment, spatial touch gating, and debounce throttling.

---

## License

Distributed under the [MIT License](LICENSE).
