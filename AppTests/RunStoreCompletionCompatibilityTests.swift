import XCTest
import Foundation
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Exercise the exact storage encoder/loader, but only with synthetic bytes.
/// Never call RunStore.save/loadRun/clearRun or use the player's filesystem.
final class RunStoreCompletionCompatibilityTests: XCTestCase {
    func testCompletedReceiptSurvivesRepeatedStorageRoundTripsWithoutAnotherPayoutOrPuzzle() throws {
        var game = try finalWin()
        _ = try game.cashOut()
        let paid = try canonicalStoredState(game)
        let paidCoins = game.run.coins
        let finalBoard = game.puzzle?.board.placed
        let fouled = game.puzzle?.bossTurn?.fouled

        for _ in 0..<3 {
            let stored = try XCTUnwrap(RunStore.dataForStorage(of: game))
            game = try XCTUnwrap(RunStore.game(from: stored))
            XCTAssertEqual(game.run.outcome, .bookCompleted)
            XCTAssertEqual(game.puzzle?.phase, .cashedOut)
            XCTAssertTrue(game.isOver)
            XCTAssertNil(game.shop)
            XCTAssertThrowsError(try game.cashOut())
            XCTAssertThrowsError(try game.startPuzzle())
            XCTAssertFalse(game.advance())
            game.openShop()
            XCTAssertEqual(game.run.coins, paidCoins)
            XCTAssertEqual(game.puzzle?.board.placed, finalBoard)
            XCTAssertEqual(game.puzzle?.bossTurn?.fouled, fouled)
            XCTAssertEqual(try canonicalStoredState(game), paid)
        }
    }

    func testLegacyPaidFinalBoardAndDiscardedBoardShopReachTheCompletedReceiptLoader() throws {
        var paid = try finalWin()
        _ = try paid.cashOut()
        for discardedBoard in [false, true] {
            var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: paid.encoded()) as? [String: Any])
            legacy.removeValue(forKey: "outcome")
            if discardedBoard {
                legacy.removeValue(forKey: "puzzle")
                legacy["shop"] = ["offers": [], "rerollCost": 2, "rerollsUsed": 0]
            }
            let bytes = try JSONSerialization.data(withJSONObject: legacy)
            let game = try XCTUnwrap(RunStore.game(from: bytes),
                                    "Engine-normalized legacy completion must not be discarded")
            XCTAssertEqual(game.run.outcome, .bookCompleted)
            XCTAssertEqual(game.run.book, paid.run.book)
            XCTAssertEqual(game.run.obstacle, paid.run.obstacle)
            XCTAssertEqual(game.run.coins, paid.run.coins)
            XCTAssertEqual(game.run.bestPuzzleScore, paid.run.bestPuzzleScore)
            XCTAssertEqual(game.run.streams.shop.state, paid.run.streams.shop.state)
            XCTAssertNil(game.shop)
            if discardedBoard { XCTAssertNil(game.puzzle) }
            else { XCTAssertEqual(game.puzzle?.board.placed, paid.puzzle?.board.placed) }
            let restored = try XCTUnwrap(RunStore.game(from: try RunStore.dataForStorage(of: game)))
            XCTAssertEqual(restored.puzzle?.bossTurn?.fouled, game.puzzle?.bossTurn?.fouled)
            XCTAssertEqual(try canonicalStoredState(restored), try canonicalStoredState(game))

            // Restoring this receipt supplies the same identified fact on
            // each launch; it never advances another Book or advances twice.
            var progress = RunStore.Progress()
            XCTAssertTrue(progress.recordCompletion(of: game.run.book, obstacle: game.run.obstacle))
            XCTAssertFalse(progress.recordCompletion(of: restored.run.book, obstacle: restored.run.obstacle))
            for book in Book.allCases {
                XCTAssertEqual(progress.unlockedObstacle(for: book).rawValue,
                               book == paid.run.book ? paid.run.obstacle.rawValue + 1 : 1)
            }
        }
    }

    func testUnpaidWinIsPreservedWithoutStorageInventingACompletion() throws {
        let game = try finalWin()
        let restored = try XCTUnwrap(RunStore.game(from: try RunStore.dataForStorage(of: game)))
        XCTAssertNil(restored.run.outcome)
        XCTAssertEqual(restored.puzzle?.phase, .won)
        XCTAssertEqual(restored.run.coins, game.run.coins)
        XCTAssertEqual(restored.puzzle?.board.placed, game.puzzle?.board.placed)
        XCTAssertEqual(restored.puzzle?.bossTurn?.fouled, game.puzzle?.bossTurn?.fouled)
        XCTAssertEqual(try canonicalStoredState(restored), try canonicalStoredState(game))
    }

    func testPendingAndAlreadyClaimedRescueRemainResumableAndNeverBecomeCompletionReceipts() throws {
        var game = try pendingRescue()
        let pendingBytes = try game.encoded()
        game = try XCTUnwrap(RunStore.game(from: try RunStore.dataForStorage(of: game)))
        XCTAssertEqual(try game.encoded(), pendingBytes)
        XCTAssertNil(game.run.outcome)
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        XCTAssertTrue(game.canClaimRewardedRescue)
        XCTAssertTrue(game.claimRewardedRescue())
        let rescuedBytes = try game.encoded()
        game = try XCTUnwrap(RunStore.game(from: try RunStore.dataForStorage(of: game)))
        XCTAssertEqual(try game.encoded(), rescuedBytes)
        XCTAssertNil(game.run.outcome)
        XCTAssertEqual(game.puzzle?.phase, .playing)
        XCTAssertTrue(try XCTUnwrap(game.puzzle).rewardedRescueUsed)
        XCTAssertFalse(game.claimRewardedRescue())
    }

    func testFailedAndDeclinedRescueSavesStayExcludedAndMalformedBytesAreIgnored() throws {
        var failedRun = RunState(seed: "failed-receipt-fixture")
        failedRun.level = 9
        failedRun.slot = .boss
        var failed = Game(run: failedRun)
        try failed.startPuzzle()
        failed.failPuzzle()
        var declined = try pendingRescue()
        XCTAssertTrue(declined.declineRewardedRescue())
        for game in [failed, declined] {
            XCTAssertEqual(game.run.outcome, .failed)
            XCTAssertNil(try RunStore.dataForStorage(of: game))
            XCTAssertNil(RunStore.game(from: try game.encoded()))
        }
        XCTAssertNil(RunStore.game(from: nil))
        XCTAssertNil(RunStore.game(from: Data("not a saved game".utf8)))
    }

    func testConflictLabelDistinguishesCompletionReceiptFromAnUnfinishedBook() throws {
        var completed = try finalWin()
        _ = try completed.cashOut()
        let active = Game(seed: "receipt-conflict-active")
        let conflict = RunStore.Conflict(local: completed, remote: active)
        XCTAssertEqual(conflict.label(for: .local), "Book \(completed.run.book.volume) complete")
        XCTAssertEqual(conflict.label(for: .remote), "Book 1, Level 1, Puzzle 1")
    }

    private func finalWin() throws -> Game {
        var run = RunState(seed: "completed-receipt-fixture", book: .smallVictories, obstacle: .shortHanded)
        run.level = 9
        run.slot = .boss
        var game = Game(run: run)
        try game.startPuzzle()
        run = game.run
        let target = try XCTUnwrap(run.puzzle).target
        run.puzzle?.score = target
        run.puzzle?.phase = .won
        return Game(run: run)
    }

    private func pendingRescue() throws -> Game {
        var game = Game(seed: "receipt-rescue-fixture")
        try game.startPuzzle()
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        return game
    }

    /// Square-keyed dictionaries encode as alternating key/value arrays, so
    /// sortedKeys cannot stabilize The Shredder's map across a decode. Sort
    /// only that unordered map; preserve every value and all ordered arrays.
    private func canonicalStoredState(_ game: Game) throws -> Data {
        var state = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        if var puzzle = state["puzzle"] as? [String: Any],
           var bossTurn = puzzle["bossTurn"] as? [String: Any],
           let fouled = game.puzzle?.bossTurn?.fouled {
            bossTurn["fouled"] = fouled.sorted { $0.key < $1.key }.map {
                ["square": $0.key.index, "expiresOnTurn": $0.value]
            }
            puzzle["bossTurn"] = bossTurn
            state["puzzle"] = puzzle
        }
        return try JSONSerialization.data(withJSONObject: state, options: [.sortedKeys])
    }
}
