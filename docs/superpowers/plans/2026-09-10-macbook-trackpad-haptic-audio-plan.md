# MacBook Trackpad Haptic Audio (`HapticBeat`) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar application that analyzes system audio output in real-time and triggers synchronized haptic feedback pulses on MacBook Force Touch trackpads.

**Architecture:** A lightweight Swift package featuring an Accelerate/vDSP-based real-time audio spectrum analyzer, a hardware-throttled haptic actuation engine bridging macOS MultitouchSupport C-API, a ScreenCaptureKit audio stream receiver, and a SwiftUI status bar controller with reactive level meters and sensitivity sliders.

**Tech Stack:** Swift 6, macOS AppKit / SwiftUI, Accelerate (vDSP), ScreenCaptureKit, MultitouchSupport (Private C Framework), XCTest.

## Global Constraints
- Target platform: macOS 13.0+ (Ventura, Sonoma, Sequoia or newer) on Apple Silicon / Intel Mac with Force Touch Trackpad.
- Build system: Swift Package Manager (`Package.swift`).
- Strict TDD: Every component must follow Red-Green-Refactor cycle with automated unit test verification before committing.
- Audio latency ceiling: < 10ms processing latency per buffer.
- Actuator safety: Minimum cooldown threshold (50ms - 250ms) to prevent hardware thermal/rate throttling and buzzing.

---

## File Structure

- `Package.swift`: Swift Package Manager manifest declaring `HapticBeatCore` library, `HapticBeat` executable, and `HapticBeatCoreTests`.
- `Sources/HapticBeatCore/Models/HapticBeatConfig.swift`: Configuration state, threshold, band, and cooldown settings.
- `Sources/HapticBeatCore/DSP/AudioDSPAnalyzer.swift`: Accelerate vDSP FFT, band energy integration, and onset/transient peak detector.
- `Sources/HapticBeatCore/Haptics/HapticActuatorProtocol.swift`: Protocol abstraction for trackpad actuation.
- `Sources/HapticBeatCore/Haptics/MockHapticActuator.swift`: In-memory mock for headless testing.
- `Sources/HapticBeatCore/Haptics/MultitouchActuator.swift`: C-bridge to `/System/Library/PrivateFrameworks/MultitouchSupport.framework`.
- `Sources/HapticBeatCore/Haptics/HapticEngine.swift`: Cooldown management, pattern dispatch, and trigger arbitration.
- `Sources/HapticBeatCore/Audio/AudioStreamProcessor.swift`: Audio buffer ingestion, format conversion, and DSP routing.
- `Sources/HapticBeat/HapticBeatApp.swift`: SwiftUI status bar app entry point and popover UI.
- `Tests/HapticBeatCoreTests/AudioDSPAnalyzerTests.swift`: Unit tests for FFT band discrimination, transient detection, and silence handling.
- `Tests/HapticBeatCoreTests/HapticEngineTests.swift`: Unit tests for cooldown throttling, pattern dispatch, and disabled state.
- `Tests/HapticBeatCoreTests/HapticBeatConfigTests.swift`: Unit tests for configuration clamps and defaults.

---

### Task 1: Project Scaffolding & Package Setup

**Files:**
- Create: `Package.swift`
- Create: `Sources/HapticBeatCore/HapticBeatCore.swift`
- Create: `Tests/HapticBeatCoreTests/HapticBeatCoreTests.swift`

**Interfaces:**
- Produces: Base SPM package with executable and test targets compiling cleanly.

- [ ] **Step 1: Write Package.swift and smoke test**
- [ ] **Step 2: Run `swift test` to verify baseline test runner**
- [ ] **Step 3: Commit scaffolding**

---

### Task 2: Configuration Model (`HapticBeatConfig`) [TDD]

**Files:**
- Create: `Sources/HapticBeatCore/Models/HapticBeatConfig.swift`
- Test: `Tests/HapticBeatCoreTests/HapticBeatConfigTests.swift`

**Interfaces:**
- Produces: `struct HapticBeatConfig`, `enum FrequencyBand`, `enum HapticPattern`

- [ ] **Step 1: Write failing test for config defaults and boundary clamps**
- [ ] **Step 2: Run test to verify it fails (Red)**
- [ ] **Step 3: Implement HapticBeatConfig with valid ranges and defaults (Green)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 3: Audio DSP Analyzer (`AudioDSPAnalyzer`) [TDD]

**Files:**
- Create: `Sources/HapticBeatCore/DSP/AudioDSPAnalyzer.swift`
- Test: `Tests/HapticBeatCoreTests/AudioDSPAnalyzerTests.swift`

**Interfaces:**
- Consumes: `HapticBeatConfig`
- Produces: `class AudioDSPAnalyzer`:
  - `func process(samples: [Float], sampleRate: Float) -> AudioAnalysisResult`
  - `struct AudioAnalysisResult`: `bandEnergy: Float`, `isTrigger: Bool`

- [ ] **Step 1: Write failing tests for 60Hz pure sine wave (Bass) vs 1000Hz (Mid) vs silence**
- [ ] **Step 2: Run test to verify it fails (Red)**
- [ ] **Step 3: Implement vDSP FFT, bandpass energy bin integration, and onset threshold check (Green)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 4: Haptic Actuator & Cooldown Throttler (`HapticEngine`) [TDD]

**Files:**
- Create: `Sources/HapticBeatCore/Haptics/HapticActuatorProtocol.swift`
- Create: `Sources/HapticBeatCore/Haptics/MockHapticActuator.swift`
- Create: `Sources/HapticBeatCore/Haptics/MultitouchActuator.swift`
- Create: `Sources/HapticBeatCore/Haptics/HapticEngine.swift`
- Test: `Tests/HapticBeatCoreTests/HapticEngineTests.swift`

**Interfaces:**
- Consumes: `HapticBeatConfig`
- Produces: `class HapticEngine`:
  - `func trigger(energy: Float, timestamp: Double) -> Bool`

- [ ] **Step 1: Write failing tests for rapid fire debounce/cooldown and pattern translation**
- [ ] **Step 2: Run test to verify it fails (Red)**
- [ ] **Step 3: Implement HapticEngine and MultitouchActuator C-bindings (Green)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 5: Audio Stream Buffer Ingestion (`AudioStreamProcessor`) [TDD]

**Files:**
- Create: `Sources/HapticBeatCore/Audio/AudioStreamProcessor.swift`
- Test: `Tests/HapticBeatCoreTests/AudioStreamProcessorTests.swift`

**Interfaces:**
- Consumes: `AudioDSPAnalyzer`, `HapticEngine`
- Produces: `class AudioStreamProcessor`:
  - `func feedAudio(samples: [Float], sampleRate: Float)`

- [ ] **Step 1: Write failing test verifying pipeline from audio input to haptic actuation**
- [ ] **Step 2: Run test to verify it fails (Red)**
- [ ] **Step 3: Implement AudioStreamProcessor wiring DSP and Haptics (Green)**
- [ ] **Step 4: Run test to verify it passes**
- [ ] **Step 5: Commit**

---

### Task 6: SwiftUI Status Bar UI & App Integration

**Files:**
- Create: `Sources/HapticBeat/HapticBeatApp.swift`
- Create: `Sources/HapticBeat/Views/MenuBarView.swift`
- Create: `Sources/HapticBeat/Audio/ScreenCaptureKitAudioSource.swift`

**Interfaces:**
- Combines all modules into a fully functional macOS Menu Bar Application with real-time UI controls and feedback.

- [ ] **Step 1: Build MenuBarView with sensitivity sliders, frequency picker, and live visualizer**
- [ ] **Step 2: Connect ScreenCaptureKit audio tap with fallback and permission guidance**
- [ ] **Step 3: Verify build (`swift build`) and compile executable target**
- [ ] **Step 4: Commit**

---

### Task 7: Full Verification & Assignment Report

- [ ] **Step 1: Run full test suite (`swift test`) and inspect all assertions**
- [ ] **Step 2: Generate comprehensive Lab Week-2 Report documenting challenges, root causes, and solutions**
- [ ] **Step 3: Commit all artifacts**
