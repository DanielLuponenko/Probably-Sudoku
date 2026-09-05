import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class FinalBookRoutingTests: XCTestCase {
    func testEnteringFinalResultsAutomaticallyPaysAndCompletesExactlyOnce() throws {
        let game = try wonGame(level: 9, slot: .boss)
        let model = GameModel(frozen: game, page: .puzzle)
        let expectedPayout = game.run.payout(for: try XCTUnwrap(game.puzzle))
        let coinsBefore = game.run.coins
        let finalBoard = game.puzzle?.board.placed

        model.showResults()

        XCTAssertEqual(model.page, .results)
        XCTAssertEqual(model.run.outcome, .bookCompleted)
        XCTAssertEqual(model.puzzle?.phase, .cashedOut)
        XCTAssertEqual(model.puzzle?.board.placed, finalBoard)
        XCTAssertEqual(model.lastPayout?.total, expectedPayout.total)
        XCTAssertEqual(model.run.coins, coinsBefore + expectedPayout.total)
        XCTAssertEqual(model.bookCompletionSummary?.bestPuzzleScore, game.puzzle?.score)
        XCTAssertNil(model.shop)
        let paidState = try model.game.encoded()

        for _ in 0..<3 { model.showResults() }

        XCTAssertEqual(try model.game.encoded(), paidState)
        XCTAssertEqual(model.lastPayout?.total, expectedPayout.total)
        XCTAssertNil(model.message)
    }

    func testEnteringOrdinaryOrPenultimateResultsKeepsThePayoutChoice() throws {
        for (level, slot) in [(1, PuzzleSlot.easy), (8, .boss), (9, .easy), (9, .medium)] {
            let game = try wonGame(level: level, slot: slot)
            let model = GameModel(frozen: game, page: .puzzle)

            model.showResults()

            XCTAssertEqual(model.page, .results)
            XCTAssertNil(model.run.outcome)
            XCTAssertNil(model.lastPayout)
            XCTAssertNil(model.bookCompletionSummary)
            XCTAssertEqual(try model.game.encoded(), try game.encoded())
            model.keepFilling()
            XCTAssertEqual(model.page, .puzzle)
            XCTAssertEqual(model.puzzle?.phase, .keepFilling)
        }
    }

    func testResumingUnpaidFinalWinSettlesOnceAndPaidRelaunchNeverPaysAgain() throws {
        let unpaid = try wonGame(level: 9, slot: .boss)
        let payout = unpaid.run.payout(for: try XCTUnwrap(unpaid.puzzle))
        let restored = GameModel(resuming: try Game(decoding: unpaid.encoded()), savesProgress: false)

        XCTAssertEqual(restored.page, .results)
        XCTAssertEqual(restored.run.outcome, .bookCompleted)
        XCTAssertEqual(restored.puzzle?.phase, .cashedOut)
        XCTAssertEqual(restored.run.coins, unpaid.run.coins + payout.total)
        XCTAssertEqual(restored.lastPayout?.total, payout.total)
        XCTAssertNotNil(restored.bookCompletionSummary)
        let paidBytes = try restored.game.encoded()

        for _ in 0..<3 {
            let relaunched = GameModel(resuming: try Game(decoding: paidBytes), savesProgress: false)
            XCTAssertEqual(relaunched.page, .results)
            XCTAssertNil(relaunched.lastPayout, "Restoring a paid receipt must not create a new payout")
            relaunched.showResults()
            XCTAssertEqual(relaunched.run.coins, restored.run.coins)
            XCTAssertEqual(relaunched.puzzle?.phase, .cashedOut)
            XCTAssertEqual(relaunched.puzzle?.board.placed, restored.puzzle?.board.placed)
            XCTAssertEqual(relaunched.puzzle?.bossTurn?.fouled, restored.puzzle?.bossTurn?.fouled)
            XCTAssertEqual(try canonicalPaidState(relaunched.game), try canonicalPaidState(restored.game))
            XCTAssertNil(relaunched.shop)
        }
    }

    func testFrozenFinalSnapshotConstructionDoesNotSettleOrRewriteTheCapturedPage() throws {
        let unpaid = try wonGame(level: 9, slot: .boss)
        let original = try unpaid.encoded()
        for page in [BookPage.puzzle, .results] {
            let snapshot = GameModel(frozen: unpaid, page: page)
            XCTAssertEqual(snapshot.page, page)
            XCTAssertFalse(snapshot.animatesHandArrival)
            XCTAssertNil(snapshot.lastPayout)
            XCTAssertNil(snapshot.bookCompletionSummary)
            XCTAssertEqual(snapshot.puzzle?.phase, .won)
            XCTAssertEqual(try snapshot.game.encoded(), original)
        }
    }

    func testResumingLegacyPaidFinalBoardOrShopShowsCompletionWithoutAnotherPayout() throws {
        var paid = try wonGame(level: 9, slot: .boss)
        _ = try paid.cashOut()
        for discardedBoard in [false, true] {
            var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: paid.encoded()) as? [String: Any])
            legacy.removeValue(forKey: "outcome")
            if discardedBoard {
                legacy.removeValue(forKey: "puzzle")
                legacy["shop"] = ["offers": [], "rerollCost": 2, "rerollsUsed": 0]
            }
            let restoredGame = try Game(decoding: JSONSerialization.data(withJSONObject: legacy))
            let model = GameModel(resuming: restoredGame, savesProgress: false)

            XCTAssertEqual(model.page, .results)
            XCTAssertEqual(model.run.outcome, .bookCompleted)
            XCTAssertEqual(model.run.coins, paid.run.coins)
            XCTAssertEqual(model.run.bestPuzzleScore, paid.run.bestPuzzleScore)
            XCTAssertNil(model.lastPayout)
            XCTAssertNil(model.shop)
            XCTAssertNotNil(model.bookCompletionSummary)
            if discardedBoard { XCTAssertNil(model.puzzle) }
            else { XCTAssertEqual(model.puzzle?.board.placed, paid.puzzle?.board.placed) }
        }
    }

    func testResumingEarlierWinOrExistingFinalKeepFillingDoesNotAutoPay() throws {
        var finalKeepFilling = try wonGame(level: 9, slot: .boss)
        try finalKeepFilling.keepFilling()
        let earlierWin = try wonGame(level: 9, slot: .medium)
        for game in [earlierWin, finalKeepFilling] {
            let model = GameModel(resuming: game, savesProgress: false)
            XCTAssertEqual(model.page, game.puzzle?.phase == .keepFilling ? .puzzle : .results)
            XCTAssertNil(model.run.outcome)
            XCTAssertNil(model.lastPayout)
            XCTAssertEqual(try model.game.encoded(), try game.encoded())
        }
    }

    func testFinalCashOutCannotRouteCompletedBookToAnEmptyShop() throws {
        var run = RunState(seed: "final-book-routing")
        run.level = 9
        run.slot = .boss
        var game = Game(run: run)
        try game.startPuzzle()
        game.qaMeetTarget()
        let model = GameModel(frozen: game, page: .results)
        model.cashOut()
        XCTAssertEqual(model.run.outcome, .bookCompleted)
        let finalScore = model.puzzle?.score
        let finalCoins = model.run.coins
        let shopStream = model.run.streams.shop.state

        for _ in 0..<3 { model.openShop() }

        XCTAssertEqual(model.page, .results)
        XCTAssertEqual(model.run.outcome, .bookCompleted)
        XCTAssertNil(model.shop)
        XCTAssertEqual(model.puzzle?.phase, .cashedOut)
        XCTAssertEqual(model.puzzle?.score, finalScore)
        XCTAssertEqual(model.run.coins, finalCoins)
        XCTAssertEqual(model.run.streams.shop.state, shopStream)
    }

    func testEarlierFinalLevelWinStillRoutesToItsNormalShop() throws {
        var run = RunState(seed: "penultimate-book-routing")
        run.level = 9
        run.slot = .medium
        var game = Game(run: run)
        try game.startPuzzle()
        game.qaMeetTarget()
        let model = GameModel(frozen: game, page: .results)
        model.cashOut()

        model.openShop()

        XCTAssertNil(model.run.outcome)
        XCTAssertEqual(model.page, .shop)
        XCTAssertNotNil(model.shop)
    }

    private func wonGame(level: Int, slot: PuzzleSlot) throws -> Game {
        var run = RunState(seed: "final-results-\(level)-\(slot.rawValue)")
        run.level = level
        run.slot = slot
        var game = Game(run: run)
        try game.startPuzzle()
        game.qaMeetTarget()
        return game
    }

    /// The Shredder's Square-keyed dictionary encodes as an alternating
    /// key/value array; sortedKeys cannot stabilize that array after decoding.
    /// Normalize only that unordered map, preserving every field and all
    /// ordered arrays (board, Hand, Pool and inventory) in the full-state check.
    private func canonicalPaidState(_ game: Game) throws -> Data {
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
