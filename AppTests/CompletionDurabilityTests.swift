import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Model-level completion ownership with in-memory storage only. No profile,
/// run file, iCloud account, or achievement reporter is changed by this suite.
@MainActor
final class CompletionDurabilityTests: XCTestCase {
    func testFailedUnlockWriteKeepsCompletionReceiptUntilSuccessfulRetry() throws {
        let game = completedGame()
        var mayRecord = false
        var recordAttempts = 0
        var clears = 0
        var saved: Game?
        let persistence = GameModel.Persistence(save: { game, _ in
            saved = game
            return true
        }, recordCompletion: { book, obstacle in
            XCTAssertEqual(book, game.run.book)
            XCTAssertEqual(obstacle, game.run.obstacle)
            recordAttempts += 1
            return mayRecord
        }, clear: {
            clears += 1
            saved = nil
            return true
        }, recordsPlayerProfile: false)
        let model = GameModel(resuming: game, persistence: persistence)
        XCTAssertEqual(model.page, .results)
        XCTAssertGreaterThan(recordAttempts, 0)
        XCTAssertEqual(saved?.run.outcome, .bookCompleted)
        let coins = model.coins

        for _ in 0..<2 {
            XCTAssertFalse(model.abandonRun())
            XCTAssertFalse(model.wantsMenu)
            XCTAssertEqual(clears, 0)
            XCTAssertEqual(saved?.run.outcome, .bookCompleted)
            XCTAssertNotNil(model.bookCompletionSummary)
        }
        mayRecord = true
        XCTAssertTrue(model.abandonRun())
        XCTAssertTrue(model.wantsMenu)
        XCTAssertEqual(clears, 1)
        XCTAssertNil(saved)
        XCTAssertEqual(model.coins, coins, "Saving the unlock must not pay the puzzle again")
        let acknowledgedAttempts = recordAttempts
        XCTAssertTrue(model.abandonRun())
        XCTAssertEqual(recordAttempts, acknowledgedAttempts)
        XCTAssertEqual(clears, 1)
    }

    func testRelaunchOfReceiptRetriesUnlockWithoutAnotherPayout() throws {
        let game = completedGame()
        var stored: Data?
        let failing = GameModel.Persistence(save: { value, _ in
            stored = try? value.encoded()
            return stored != nil
        }, recordCompletion: { _, _ in false }, clear: { XCTFail("Cannot clear unrecorded completion"); return false },
        recordsPlayerProfile: false)
        let first = GameModel(resuming: game, persistence: failing)
        XCTAssertFalse(first.abandonRun())
        let receipt = try Game(decoding: XCTUnwrap(stored))
        var recorded = 0
        var cleared = 0
        let working = GameModel.Persistence(save: { _, _ in true }, recordCompletion: { _, _ in
            recorded += 1
            return true
        }, clear: { cleared += 1; return true }, recordsPlayerProfile: false)
        let resumed = GameModel(resuming: receipt, persistence: working)
        XCTAssertEqual(recorded, 1)
        XCTAssertEqual(resumed.coins, game.run.coins)
        XCTAssertEqual(resumed.puzzle?.bankedPayout, game.puzzle?.bankedPayout)
        XCTAssertTrue(resumed.abandonRun())
        XCTAssertEqual(recorded, 1)
        XCTAssertEqual(cleared, 1)
    }

    private func completedGame() -> Game {
        var game = Game(seed: "durable-completion", book: .smallVictories, obstacle: .shortHanded)
        game.qaCompleteBook()
        XCTAssertEqual(game.run.outcome, .bookCompleted, "Durability checks require an actual terminal receipt")
        XCTAssertEqual(game.puzzle?.phase, .cashedOut)
        return game
    }
}
