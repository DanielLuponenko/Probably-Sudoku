import XCTest
@testable import ProbablySudoku

final class ProceduralSoundTests: XCTestCase {
    func testEveryOriginalCueIsDeterministicShortAndBelowFullScale() {
        for sound in GameSound.allCases {
            let samples = ProceduralSound.samples(for: sound)
            XCTAssertEqual(samples, ProceduralSound.samples(for: sound), sound.rawValue)
            XCTAssertGreaterThan(samples.count, 1_000, sound.rawValue)
            XCTAssertLessThan(samples.count, ProceduralSound.sampleRate, sound.rawValue)
            XCTAssertTrue(samples.contains(where: { $0 != 0 }), sound.rawValue)
            XCTAssertLessThanOrEqual(samples.map { abs(Int($0)) }.max() ?? 0, 19_661, sound.rawValue)
            XCTAssertEqual(samples.first, 0, sound.rawValue)
            XCTAssertLessThanOrEqual(abs(Int(samples.last ?? 0)), 20, sound.rawValue)
        }
    }

    func testWaveDataHasPCMHeaderAndDistinctPerCuePayloads() {
        let waves = GameSound.allCases.map { ProceduralSound.wavData(for: $0) }
        XCTAssertEqual(Set(waves).count, GameSound.allCases.count)
        for (sound, data) in zip(GameSound.allCases, waves) {
            XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
            XCTAssertEqual(String(data: data[8..<16], encoding: .ascii), "WAVEfmt ")
            XCTAssertEqual(String(data: data[36..<40], encoding: .ascii), "data")
            XCTAssertEqual(data.count, 44 + ProceduralSound.samples(for: sound).count * 2)
            XCTAssertEqual(Array(data[20..<24]), [1, 0, 1, 0]) // PCM mono
            XCTAssertEqual(Array(data[34..<36]), [16, 0]) // 16-bit
        }
    }

    func testPageTurnKeepsItsEnergyInWarmPaperRatherThanHighFrequencyHash() {
        let spectrum = pageTurnSpectrum()
        let total = spectrum.reduce(0) { $0 + $1.power }
        func fraction(from low: Double, to high: Double) -> Double {
            spectrum.filter { $0.frequency >= low && $0.frequency < high }
                .reduce(0) { $0 + $1.power } / total
        }
        XCTAssertGreaterThan(total, 0)
        XCTAssertGreaterThan(fraction(from: 180, to: 1_600), 0.70)
        XCTAssertLessThan(fraction(from: 3_000, to: 11_026), 0.04,
                          "A page must not return to the old sustained broadband hiss.")
        XCTAssertLessThan(fraction(from: 6_000, to: 11_026), 0.008)
        let centroid = spectrum.reduce(0) { $0 + $1.frequency * $1.power } / total
        XCTAssertGreaterThan(centroid, 500, "Keep enough fibre detail to read as paper.")
        XCTAssertLessThan(centroid, 1_400)
        XCTAssertLessThan((spectrum.map(\.power).max() ?? 0) / total, 0.13,
                          "No single ringing/chirping tone should dominate the sheet.")
    }

    func testPageTurnHasSoftEdgesFlexibleBodyAndASeparateQuietLanding() {
        let samples = ProceduralSound.samples(for: .paperTurn).map { Double($0) / Double(Int16.max) }
        let rate = Double(ProceduralSound.sampleRate)
        func window(_ start: Double, _ end: Double) -> ArraySlice<Double> {
            samples[Int(start * rate)..<min(samples.count, Int(end * rate))]
        }
        func rms(_ start: Double, _ end: Double) -> Double {
            let slice = window(start, end)
            return sqrt(slice.reduce(0) { $0 + $1 * $1 } / Double(slice.count))
        }
        XCTAssertEqual(Double(samples.count) / rate, 0.46, accuracy: 1 / rate)
        XCTAssertTrue(window(0, 0.012).allSatisfy { $0 == 0 })
        XCTAssertTrue(window(0.451, 0.46).allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(rms(0.035, 0.115), 0.035, "The lifted edge should be audible.")
        let flex = rms(0.14, 0.29)
        let landing = rms(0.335, 0.43)
        XCTAssertGreaterThan(flex, 0.04)
        XCTAssertLessThan(rms(0.30, 0.325), flex / 3, "Let the sheet relax before contact.")
        XCTAssertGreaterThan(landing, 0.02)
        XCTAssertLessThan(landing, flex * 0.9, "Landing is softer than the moving sheet.")
        let largestStep = zip(samples, samples.dropFirst()).map { abs($0 - $1) }.max() ?? 0
        XCTAssertLessThan(largestStep, 0.14, "No sharp sample jumps or crackling edges.")
        XCTAssertLessThan(samples.map(abs).max() ?? 0, 0.45)
        XCTAssertLessThan(abs(samples.reduce(0, +) / Double(samples.count)), 0.001)
    }

    /// Windowed, averaged Goertzel bins: no hardware audio, FFT framework, or
    /// file access. The thresholds describe spectral shape, not listening quality.
    private func pageTurnSpectrum() -> [(frequency: Double, power: Double)] {
        let samples = ProceduralSound.samples(for: .paperTurn).map { Double($0) / Double(Int16.max) }
        let size = 512
        let phaseStep = 2 * Double.pi / Double(size - 1)
        var windows: [[Double]] = []
        for offset in stride(from: 0, through: samples.count - size, by: size) {
            var window: [Double] = []
            for index in 0..<size {
                let weight = 0.5 - 0.5 * cos(phaseStep * Double(index))
                window.append(samples[offset + index] * weight)
            }
            windows.append(window)
        }
        var spectrum: [(frequency: Double, power: Double)] = []
        for bin in 0...size / 2 {
            let coefficient = 2 * cos(2 * Double.pi * Double(bin) / Double(size))
            var power = 0.0
            for window in windows {
                var recent = 0.0
                var older = 0.0
                for sample in window {
                    let next = sample + coefficient * recent - older
                    older = recent
                    recent = next
                }
                power += max(0, recent * recent + older * older - coefficient * recent * older)
            }
            spectrum.append((Double(bin * ProceduralSound.sampleRate) / Double(size), power))
        }
        return spectrum
    }
}
