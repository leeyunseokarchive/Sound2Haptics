# MacBook Trackpad Audio Haptic Feedback Utility (`HapticBeat`) Design Spec

## 1. Overview & Goals
`HapticBeat` is a native macOS menu bar utility that translates real-time system audio (music, movies, games, YouTube) into synchronized haptic feedback on MacBook Force Touch trackpads.

By analyzing system audio streams with Apple Accelerate (vDSP) and triggering low-latency haptic pulses via macOS MultitouchSupport, users experience visceral, rhythmic tactile feedback directly at their fingertips.

## 2. Core Constraints & Technical Realities

| Constraint | Reality | Architectural Solution |
|---|---|---|
| **AppKit Background Limitation** | `NSHapticFeedbackManager` only works when the app's window is the active first responder. In background/menu bar mode, it silently drops feedback. | Use private C framework `MultitouchSupport.framework` (`MTActuatorCreateFromDeviceID`, `MTActuatorOpen`, `MTActuatorActuate`) which operates globally regardless of window focus. |
| **Trackpad Actuator Physics** | The Force Touch trackpad is an electromagnetic linear resonant actuator designed for discrete click simulation. High-frequency continuous vibration (>40Hz) causes thermal throttling, rattling noise, or driver safety cutoff. | Implement an intelligent Transient / Onset Detector with a configurable hardware Cooldown Throttler (default 90ms), translating audio into crisp, rhythmic click pulses (kick/bass beats) rather than continuous buzzing. |
| **System Audio Capture** | macOS does not allow reading system audio output without elevated permissions or virtual devices. | Utilize macOS 13+ `ScreenCaptureKit` (`SCStream`) configured for audio-only stream capture, avoiding the need for third-party virtual audio cables (BlackHole). |
| **Latency Sensitivity** | Tactile feedback desynchronized from audio (>30ms) ruins immersion. | Process PCM audio buffers on a dedicated high-priority queue with in-memory vDSP sliding window FFT. Processing latency target: < 5ms. |

## 3. System Architecture & Components

```
┌─────────────────────────────────────────────────────────┐
│              macOS System Audio Stream                  │
└──────────────────────────┬──────────────────────────────┘
                           │ (ScreenCaptureKit PCM Buffer)
                           ▼
┌─────────────────────────────────────────────────────────┐
│               AudioStreamProcessor                      │
│ - Buffer format normalization (Float32, mono downmix)   │
│ - Circular FIFO buffer management                       │
└──────────────────────────┬──────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────┐
│               AudioDSPAnalyzer (vDSP)                   │
│ - Accelerate vDSP FFT (1024-point Hann window)          │
│ - Band energy integration (Bass: 20-150Hz, Mid: 150-2kHz│
│ - Transient onset detection (ΔEnergy > Threshold)       │
└──────────────────────────┬──────────────────────────────┘
                           │ (Beat Trigger Event)
                           ▼
┌─────────────────────────────────────────────────────────┐
│               HapticEngine                              │
│ - Cooldown interval throttle (e.g. 90ms debounce)       │
│ - Dynamic intensity mapping (Light, Medium, Strong)     │
│ - MultitouchSupport C-Bridge (`MTActuatorActuate`)       │
└─────────────────────────────────────────────────────────┘
```

### Component Details

#### 3.1 AudioDSPAnalyzer
- **Input**: Linear PCM float32 samples (sampling rate $F_s \in \{44100, 48000\}$).
- **Processing**:
  - Apply 1024-sample Hann window.
  - Forward real-to-complex FFT via `vDSP_fft_zrip`.
  - Calculate power spectrum magnitudes.
  - Calculate frequency bin indices for targeted band:
    $$\text{bin} = \left\lfloor \frac{f \cdot N}{F_s} \right\rfloor$$
  - Integrate energy in band (e.g., $20\text{Hz} \sim 150\text{Hz}$ for Bass).
  - Compute normalized energy $E \in [0.0, 1.0]$.
  - Compare $E$ against user `threshold`:
    $$\text{Trigger} = (E \ge \text{threshold}) \land (E - E_{\text{prev}} > \text{onsetSensitivity})$$

#### 3.2 HapticEngine & MultitouchSupport Bridging
- **Actuator Interface Protocol**: `HapticActuatorProtocol`
  - `func actuate(pattern: HapticPattern) -> Bool`
- **Real Implementation**: `MultitouchActuator`
  - Dynamically links or bridges `MTActuatorCreateFromDeviceID`, `MTActuatorOpen`, `MTActuatorActuate`, `MTActuatorClose`.
  - Haptic patterns:
    - 1: Subtle Click (Level change / soft)
    - 2: Standard Click (Generic force click)
    - 5 / 6: Firm Click (Impact / heavy beat)
- **Mock Implementation**: `MockHapticActuator`
  - Records timestamps and pattern invocations for unit testing without physical trackpad hardware.
- **Cooldown Throttler**:
  - Maintains `lastActuationTime`. If `currentTime - lastActuationTime < cooldownInterval`, drop trigger to protect hardware and avoid buzzing.

#### 3.3 Settings & State Management
- `HapticBeatConfig`:
  - `isEnabled`: Bool (default true)
  - `threshold`: Float (0.05 to 0.95, default 0.45)
  - `cooldownMs`: Double (50.0 to 250.0, default 90.0)
  - `frequencyBand`: Enum (`bass` [20-150Hz], `mid` [150-2000Hz], `full` [20-20000Hz])
  - `pattern`: Enum (`light`, `medium`, `strong`)
- Observable state for SwiftUI reactive updates.

#### 3.4 MenuBar UI (SwiftUI)
- Status bar item with waveform icon.
- Popover:
  - Toggle Switch: On/Off.
  - Live Audio Level Meter showing real-time energy bar with visual threshold marker.
  - Beat indicator dot (flashes cyan/amber when haptic fires).
  - Sliders:
    - **Sensitivity (Threshold)**
    - **Cooldown (ms)**
  - Segmented Picker: **Frequency Band** (Bass / Mid / Full)
  - Segmented Picker: **Haptic Intensity** (Light / Medium / Strong)
  - Quick Test Button: "Test Haptic Click"

## 4. Error Handling & Edge Cases
1. **ScreenCaptureKit Permission Denied**:
   - Catch permission error during `SCShareableContent.current`.
   - Display clear guidance modal in UI with button: "Open System Settings -> Privacy & Security -> Screen & System Audio Recording".
2. **Unsupported Hardware (No Force Touch Trackpad / Mac Mini / Mac Pro)**:
   - Detect if `MTActuatorCreateFromDeviceID` returns `nil` or 0 actuators.
   - Display fallback status: "No Force Touch Trackpad detected. Audio analysis active in visual-only mode."
3. **Audio Sample Rate Variance**:
   - Dynamically adapt FFT bin calculation when audio stream switches between 44.1kHz, 48kHz, or 96kHz.

## 5. Testing & TDD Strategy
- **Unit Test Suite**:
  1. `AudioDSPAnalyzerTests`:
     - Test with synthesized 60Hz pure sine wave $\rightarrow$ verifies high energy in Bass band, low energy in Mid band.
     - Test with synthesized 1000Hz sine wave $\rightarrow$ verifies low energy in Bass band, high energy in Mid band.
     - Test silence / zero buffer $\rightarrow$ verifies 0 energy and no trigger.
     - Test threshold boundary logic.
  2. `HapticEngineTests`:
     - Test debounce / cooldown: Rapid burst of 10 triggers in 30ms with 90ms cooldown must result in exactly 1 actuation.
     - Test actuation pattern mapping (light vs medium vs strong).
     - Test disabled state: Triggers while `isEnabled = false` must produce 0 actuations.
  3. `HapticBeatConfigTests`:
     - Test configuration bounds and persistence.
- **Verification Commands**:
  - `swift test` $\rightarrow$ 100% passing tests with 0 warnings.
  - `swift build` $\rightarrow$ clean compilation of executable and test targets.
