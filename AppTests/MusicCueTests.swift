import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

final class MusicCueTests: XCTestCase {
    func testAllTwelveBooksHaveAnIntentionalNonBossMusicCue() {
        let expected: [Book: GameMusicCue] = [
            .probably: .bookshop, .genuinely: .bookshop,
            .smallVictories: .bookshop, .wellEarned: .bookshop,
            .noPressure: .quietMargins, .snackBreak: .quietMargins,
            .trustMe: .quietMargins, .bites: .quietMargins,
            .slightlyHarder: .rainyMargins, .overthinking: .rainyMargins,
            .rainyDay: .rainyMargins, .secondThoughts: .rainyMargins
        ]
        XCTAssertEqual(expected.count, 12)
        for book in Book.allCases {
            XCTAssertEqual(GameMusicCue.forBook(book), expected[book], book.rawValue)
            XCTAssertEqual(GameMusicCue.forEncounter(book: book, boss: nil), expected[book])
            XCTAssertFalse([GameMusicCue.redInk, .finalDraft].contains(GameMusicCue.forBook(book)))
        }
    }

    func testEveryBossUsesTheCorrectRegularOrFinalSuiteInEveryBook() {
        XCTAssertEqual(BossModifier.allCases.count, 19)
        XCTAssertEqual(BossModifier.finalBosses.count, 5)
        for book in Book.allCases {
            for boss in BossModifier.allCases {
                XCTAssertEqual(GameMusicCue.forEncounter(book: book, boss: boss),
                               boss.isFinalBoss ? .finalDraft : .redInk,
                               "\(book.rawValue), \(boss.rawValue)")
            }
        }
    }

    func testFiveCueResourcesHaveUniqueStableNames() {
        XCTAssertEqual(GameMusicCue.allCases.count, 5)
        XCTAssertEqual(Set(GameMusicCue.allCases.map(\.rawValue)),
                       ["bookshop-theme", "quiet-margins", "rainy-margins", "red-ink-deadline", "final-draft"])
    }

    func testProceduralEffectsHaveHeadroomNoDCAndSilenceSafeEnds() {
        for sound in GameSound.allCases {
            let samples = normalized(sound)
            let peak = samples.map(abs).max() ?? 0
            let mean = samples.reduce(0, +) / Double(samples.count)
            XCTAssertLessThanOrEqual(peak, 0.7 + 1 / Double(Int16.max), sound.rawValue)
            XCTAssertGreaterThan(peak, 0.05, "\(sound.rawValue) accidentally became silent")
            XCTAssertLessThan(abs(mean), 0.002, "\(sound.rawValue) has a DC offset")
            XCTAssertEqual(samples.first, 0, "\(sound.rawValue) must begin at silence rather than a step")
            XCTAssertEqual(samples.last, 0, "\(sound.rawValue) must return to silence")
            XCTAssertEqual(ProceduralSound.samples(for: sound), ProceduralSound.samples(for: sound),
                           "The fixed effects pool should not depend on live game randomness")
        }
    }

    func testContactSoundsHaveAnImmediateDryOnsetRatherThanALongSineFade() {
        let dry: [GameSound] = [.tilePlace, .menuTap, .scoreTick, .scoreTickHigh, .scoreBank]
        for sound in dry {
            let samples = normalized(sound)
            let onset = Array(samples.prefix(Int(0.012 * Double(ProceduralSound.sampleRate))))
            let decay = Array(samples.dropFirst(Int(0.05 * Double(ProceduralSound.sampleRate))))
            XCTAssertGreaterThan(rms(onset), 0.04, sound.rawValue)
            XCTAssertGreaterThan(rms(onset), rms(decay) * 4,
                                 "\(sound.rawValue) needs contact followed by decay, not a sustained pure tone")
            let firstAudible = samples.firstIndex { abs($0) > 0.02 } ?? samples.count
            XCTAssertLessThan(Double(firstAudible) / Double(ProceduralSound.sampleRate), 0.004,
                              "\(sound.rawValue) should respond within four milliseconds")
        }
    }

    private func normalized(_ sound: GameSound) -> [Double] {
        ProceduralSound.samples(for: sound).map { Double($0) / Double(Int16.max) }
    }

    private func rms(_ samples: [Double]) -> Double {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Double(max(1, samples.count)))
    }
}
