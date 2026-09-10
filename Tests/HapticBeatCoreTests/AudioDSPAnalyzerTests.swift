import XCTest
@testable import HapticBeatCore

final class AudioDSPAnalyzerTests: XCTestCase {
    let sampleRate: Float = 48000.0
    let fftSize = 1024

    private func generateSineWave(frequency: Float, sampleRate: Float, count: Int, amplitude: Float = 1.0) -> [Float] {
        return (0..<count).map { i in
            amplitude * sin(2.0 * .pi * frequency * Float(i) / sampleRate)
        }
    }

    func testSilenceProducesZeroEnergy() {
        let analyzer = AudioDSPAnalyzer(fftSize: fftSize)
        let silence = [Float](repeating: 0.0, count: fftSize)
        let config = HapticBeatConfig(threshold: 0.2)

        let result = analyzer.process(samples: silence, sampleRate: sampleRate, config: config)
        XCTAssertEqual(result.bandEnergy, 0.0, accuracy: 0.001)
        XCTAssertEqual(result.totalEnergy, 0.0, accuracy: 0.001)
        XCTAssertFalse(result.isTrigger)
    }

    func testPure60HzSineWaveTriggersBassBandNotMid() {
        let analyzer = AudioDSPAnalyzer(fftSize: fftSize)
        let bassWave = generateSineWave(frequency: 60.0, sampleRate: sampleRate, count: fftSize, amplitude: 0.8)

        // Bass config
        let bassConfig = HapticBeatConfig(threshold: 0.2, frequencyBand: .bass)
        let bassResult = analyzer.process(samples: bassWave, sampleRate: sampleRate, config: bassConfig)
        XCTAssertGreaterThan(bassResult.bandEnergy, 0.3)
        XCTAssertTrue(bassResult.isTrigger)

        // Mid config with same bass wave
        analyzer.reset()
        let midConfig = HapticBeatConfig(threshold: 0.2, frequencyBand: .mid)
        let midResult = analyzer.process(samples: bassWave, sampleRate: sampleRate, config: midConfig)
        XCTAssertLessThan(midResult.bandEnergy, 0.1)
        XCTAssertFalse(midResult.isTrigger)
    }

    func testPure1000HzSineWaveTriggersMidBandNotBass() {
        let analyzer = AudioDSPAnalyzer(fftSize: fftSize)
        let midWave = generateSineWave(frequency: 1000.0, sampleRate: sampleRate, count: fftSize, amplitude: 0.8)

        // Mid config
        let midConfig = HapticBeatConfig(threshold: 0.2, frequencyBand: .mid)
        let midResult = analyzer.process(samples: midWave, sampleRate: sampleRate, config: midConfig)
        XCTAssertGreaterThan(midResult.bandEnergy, 0.3)
        XCTAssertTrue(midResult.isTrigger)

        // Bass config with same 1000Hz wave
        analyzer.reset()
        let bassConfig = HapticBeatConfig(threshold: 0.2, frequencyBand: .bass)
        let bassResult = analyzer.process(samples: midWave, sampleRate: sampleRate, config: bassConfig)
        XCTAssertLessThan(bassResult.bandEnergy, 0.1)
        XCTAssertFalse(bassResult.isTrigger)
    }

    func testThresholdRejection() {
        let analyzer = AudioDSPAnalyzer(fftSize: fftSize)
        let quietBass = generateSineWave(frequency: 60.0, sampleRate: sampleRate, count: fftSize, amplitude: 0.1)
        let highThresholdConfig = HapticBeatConfig(threshold: 0.8, frequencyBand: .bass)

        let result = analyzer.process(samples: quietBass, sampleRate: sampleRate, config: highThresholdConfig)
        XCTAssertFalse(result.isTrigger)
    }
}
