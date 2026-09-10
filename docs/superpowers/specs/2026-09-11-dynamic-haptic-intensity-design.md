# Design: Real-time Audio Volume-Responsive Dynamic Haptic Intensity

## 1. Overview & Objective
Replace the manual static "Haptic Pattern" toggle (Light / Medium / Strong) with a 100% automated, real-time volume-responsive haptic intensity system.
When audio beats are detected, the system dynamically calculates the haptic intensity tier based on the relative energy headroom of the trigger event, delivering tactile contrast between gentle bass notes and heavy drum kicks.

---

## 2. Architecture & Design

### A. Dynamic Intensity Partitioning Algorithm (`HapticEngine.swift`)
The haptic intensity is derived dynamically from the trigger energy $E$ relative to the configured threshold $T$:

$$\text{Headroom} = \max(0.01, 1.0 - T)$$

- **Tier 1 (Light - rawPatternId 1)**:
  $$T \le E < T + \text{Headroom} \times 0.33$$
  Subtle, crisp click for gentle beats and background rhythm.
- **Tier 2 (Medium - rawPatternId 2)**:
  $$T + \text{Headroom} \times 0.33 \le E < T + \text{Headroom} \times 0.67$$
  Standard tactile response for snare hits, vocal attacks, and moderate beats.
- **Tier 3 (Strong - rawPatternId 5)**:
  $$E \ge T + \text{Headroom} \times 0.67$$
  Deep, punchy Force-Click sensation for heavy kick drum drops and peak transients.

### B. Configuration & Model Cleanup (`HapticBeatConfig.swift`)
- Remove fixed `pattern: HapticPattern` from user-configurable settings.
- Retain `HapticPattern` enum for internal actuator dispatching (`.light`, `.medium`, `.strong`).

### C. UI & Visual Feedback Refinement (`MenuBarView.swift`)
- Remove the manual segmented `HapticPattern` picker from `MenuBarView`.
- In the matrix header / status area, indicate `DYNAMIC INTENSITY` mode.
- Scale the haptic flash animation and shockwave radius proportionally according to the triggered intensity tier (Light = subtle 60px ripple, Medium = 100px ripple, Strong = 140px punchy ripple).

---

## 3. Data Flow
1. `AudioStreamProcessor` calculates band energy and onset delta.
2. `SpatialTouchGate` verifies physical touch coincidence.
3. `HapticEngine.trigger(energy: energy)` calculates the dynamic `HapticPattern` for the given energy.
4. `actuator.actuate(pattern: dynamicPattern)` fires the corresponding Taptic Engine profile (1, 2, or 5).
5. Callback `onHapticTrigger(pattern)` passes the chosen pattern to `HapticBeatViewModel` for UI shockwave scaling.

---

## 4. Testing & Verification Plan
1. **Unit Tests in `HapticEngineTests.swift`**:
   - `testDynamicPatternSelection_LowEnergy_SelectsLight`
   - `testDynamicPatternSelection_MidEnergy_SelectsMedium`
   - `testDynamicPatternSelection_HighEnergy_SelectsStrong`
   - `testTriggerActuatesWithSelectedDynamicPattern`
2. **Regression Verification**:
   - Verify all 32 existing tests pass (`swift test`).
3. **Build & Manual Testing**:
   - `swift build` passes with 0 warnings.
   - Run `swift run HapticBeat` and test with varying volume tracks.
