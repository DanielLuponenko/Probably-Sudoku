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
}
