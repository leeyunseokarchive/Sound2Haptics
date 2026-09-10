# Dynamic Haptic Intensity Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the static manual haptic intensity picker and implement an automated real-time volume/energy-responsive dynamic haptic intensity system using macOS Taptic Engine profiles.

**Architecture:** Calculate dynamic intensity tier (Light, Medium, Strong) in `HapticEngine` from incoming trigger energy relative to the configured threshold headroom, and scale UI luminescence and shockwave radii accordingly.

**Tech Stack:** Swift 6, AppKit, SwiftUI, Accelerate framework, MultitouchSupport private framework, XCTest.

## Global Constraints
- Target platform: macOS 14.0+ arm64
- Zero external package dependencies (Apple SDK native)
- Thread-safe state isolation with `@unchecked Sendable` and `NSLock`
- 100% test pass rate on `swift test`

---

### Task 1: Core Dynamic Intensity Partitioning & TDD Unit Tests

**Files:**
- Modify: `Sources/HapticBeatCore/Haptics/HapticEngine.swift`
- Modify: `Sources/HapticBeatCore/Models/HapticBeatConfig.swift`
- Test: `Tests/HapticBeatCoreTests/HapticEngineTests.swift`

**Interfaces:**
- Produces: `HapticEngine.dynamicPattern(for energy: Float) -> HapticPattern`
- Modifies: `HapticEngine.trigger(energy: Float, timestamp: Double? = nil) -> Bool` (passes dynamically calculated pattern to `actuator.actuate(pattern:)`)

- [ ] **Step 1: Write failing unit tests in `HapticEngineTests.swift`**
Add tests verifying `.light`, `.medium`, and `.strong` selection based on threshold headroom:
```swift
func testDynamicPatternSelection_LowEnergy_SelectsLight() {
    let config = HapticBeatConfig(threshold: 0.25)
    let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
    // Headroom = 0.75; Tier1 = 0.25 + 0.25 = 0.50
    XCTAssertEqual(engine.dynamicPattern(for: 0.35), .light)
}

func testDynamicPatternSelection_MidEnergy_SelectsMedium() {
    let config = HapticBeatConfig(threshold: 0.25)
    let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
    // Tier2 = 0.25 + 0.50 = 0.75
    XCTAssertEqual(engine.dynamicPattern(for: 0.60), .medium)
}

func testDynamicPatternSelection_HighEnergy_SelectsStrong() {
    let config = HapticBeatConfig(threshold: 0.25)
    let engine = HapticEngine(actuator: MockHapticActuator(), config: config)
    XCTAssertEqual(engine.dynamicPattern(for: 0.85), .strong)
}
```

- [ ] **Step 2: Run tests to verify failure**
Run: `swift test --filter HapticEngineTests`
Expected: FAIL (`dynamicPattern` not found)

- [ ] **Step 3: Implement `dynamicPattern(for:)` in `HapticEngine.swift`**
```swift
public func dynamicPattern(for energy: Float) -> HapticPattern {
    let headroom = max(0.01, 1.0 - config.threshold)
    let tier1 = config.threshold + headroom * 0.33
    let tier2 = config.threshold + headroom * 0.67

    if energy < tier1 {
        return .light
    } else if energy < tier2 {
        return .medium
    } else {
        return .strong
    }
}
```
Update `trigger(energy:timestamp:)` to pass `dynamicPattern(for: energy)`:
```swift
let pattern = dynamicPattern(for: energy)
let success = actuator.actuate(pattern: pattern)
```

- [ ] **Step 4: Run tests to verify they pass**
Run: `swift test --filter HapticEngineTests`
Expected: PASS

---

### Task 2: Pipeline Integration & Dynamic Shockwave Model

**Files:**
- Modify: `Sources/HapticBeatCore/Audio/AudioStreamProcessor.swift`
- Modify: `Sources/HapticBeat/ViewModels/HapticBeatViewModel.swift`

**Interfaces:**
- Modifies: `AudioStreamProcessor.onHapticTrigger: ((HapticPattern) -> Void)?`
- Modifies: `HapticBeatViewModel.lastTriggeredPattern: HapticPattern`

- [ ] **Step 1: Pass triggered `HapticPattern` from `AudioStreamProcessor` to callback**
Update `onHapticTrigger` callback in `AudioStreamProcessor` to include `HapticPattern`:
```swift
public var onHapticTrigger: ((HapticPattern) -> Void)?
```
When `hapticEngine.trigger(energy:)` succeeds, forward the chosen pattern to `onHapticTrigger?(pattern)`.

- [ ] **Step 2: Update `HapticBeatViewModel` state**
Add `@Published public var lastTriggeredPattern: HapticPattern = .medium` to `HapticBeatViewModel`.
Store the received pattern when `onHapticTrigger` fires.

- [ ] **Step 3: Verify build**
Run: `swift build`
Expected: Build passes.

---

### Task 3: UI Simplification & Dynamic Visual Feedback

**Files:**
- Modify: `Sources/HapticBeat/Views/MenuBarView.swift`

- [ ] **Step 1: Remove manual `HapticPattern` Picker**
Remove the `Picker("Haptic Pattern", selection: ...)` from `MenuBarView.swift`.

- [ ] **Step 2: Add Dynamic Intensity Indicator & Scale Shockwave**
In `TrackpadMatrixView`:
- In the header or status readout, show `DYNAMIC` badge.
- Scale the shockwave ripple radius and stroke width based on `viewModel.lastTriggeredPattern`:
  - `.light`: width 60, scale 1.2
  - `.medium`: width 100, scale 1.6
  - `.strong`: width 140, scale 2.0

- [ ] **Step 3: Build and verify**
Run: `swift build`
Expected: Build passes with 0 warnings.

---

### Task 4: Regression Testing & Documentation

**Files:**
- Modify: `docs/AI_Software_Lab_Week2_Report.md`
- Modify: `walkthrough.md`

- [ ] **Step 1: Run all unit tests**
Run: `swift test`
Expected: All tests (35+ tests) pass.

- [ ] **Step 2: Update documentation & report**
Document Dynamic Intensity feature in `AI_Software_Lab_Week2_Report.md` and `walkthrough.md`.

- [ ] **Step 3: Verification with running app**
Launch: `swift run HapticBeat`
Test playing music at varying volume levels to confirm tactile dynamic contrast.
