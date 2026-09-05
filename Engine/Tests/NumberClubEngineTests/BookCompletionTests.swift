import XCTest
@testable import ProbablySudokuEngine

final class BookCompletionTests: XCTestCase {
    func testCashOutRecordsTheHighestPuzzleScore() throws {
        var game = Game(seed: "book-record")
        try game.startPuzzle()
        game.qaMeetTarget()
        let firstScore = try XCTUnwrap(game.puzzle?.score)
        _ = try game.cashOut()
        XCTAssertEqual(game.run.bestPuzzleScore, firstScore)

        game.openShop()
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        game.qaMeetTarget()
        let secondScore = try XCTUnwrap(game.puzzle?.score)
        _ = try game.cashOut()

        XCTAssertEqual(game.run.bestPuzzleScore, max(firstScore, secondScore))
    }

    func testQACompletionUsesTheNormalTerminalCashOut() {
        var game = Game(seed: "book-complete")
        game.qaCompleteBook()

        XCTAssertEqual(game.run.outcome, .bookCompleted)
        XCTAssertEqual(game.run.level, 9)
        XCTAssertEqual(game.run.slot, .boss)
        XCTAssertGreaterThan(game.run.bestPuzzleScore, 0)
        XCTAssertEqual(game.puzzle?.phase, .cashedOut)
        XCTAssertNil(game.shop)
    }

    func testFinalCashOutCompletesBookOnceAndRetainsFinalBoardWithoutShop() throws {
        for keepFilling in [false, true] {
            var game = Game(seed: "final-cashout-\(keepFilling)")
            game.run.level = 9
            game.run.slot = .boss
            try game.startPuzzle()
            game.qaMeetTarget()
            if keepFilling { try game.keepFilling() }
            let score = try XCTUnwrap(game.puzzle?.score)
            let coins = game.run.coins
            let shopStream = game.run.streams.shop.state
            let payout = try game.cashOut()

            XCTAssertEqual(game.run.outcome, .bookCompleted)
            XCTAssertEqual(game.puzzle?.phase, .cashedOut)
            XCTAssertEqual(game.puzzle?.score, score)
            XCTAssertEqual(game.run.bestPuzzleScore, score)
            XCTAssertEqual(game.run.coins, coins + payout.total)
            XCTAssertNil(game.shop)
            XCTAssertThrowsError(try game.cashOut())
            game.openShop()
            XCTAssertFalse(game.advance())
            XCTAssertThrowsError(try game.startPuzzle())
            XCTAssertEqual(game.run.coins, coins + payout.total)
            XCTAssertEqual(game.run.streams.shop.state, shopStream)
            XCTAssertEqual(game.puzzle?.phase, .cashedOut)
            XCTAssertNil(game.shop)

            let restored = try Game(decoding: game.encoded())
            XCTAssertEqual(restored.run.outcome, .bookCompleted)
            XCTAssertEqual(restored.run.coins, game.run.coins)
            XCTAssertEqual(restored.puzzle?.score, score)
            XCTAssertNil(restored.shop)
        }
    }

    func testEarlierWinsStillHaveShopsIncludingFirstTwoPuzzlesOfFinalLevel() throws {
        for (level, slot) in [(8, PuzzleSlot.boss), (9, .easy), (9, .medium)] {
            var game = Game(seed: "nonfinal-cashout-\(level)-\(slot)")
            game.run.level = level
            game.run.slot = slot
            try game.startPuzzle()
            game.qaMeetTarget()
            _ = try game.cashOut()
            XCTAssertNil(game.run.outcome)
            game.openShop()
            XCTAssertNotNil(game.shop)
            XCTAssertNil(game.puzzle)
            XCTAssertTrue(game.advance())
        }
    }

    func testLegacyFinalPaidShopRestoresAsCompletedWithoutPayingAgain() throws {
        var legacy = RunState(seed: "legacy-final-shop")
        legacy.level = 9
        legacy.slot = .boss
        legacy.pendingBoss = nil
        legacy.coins = 137
        legacy.bestPuzzleScore = 2_100_000
        Shop.open(&legacy)
        let shopStream = legacy.streams.shop.state
        let decoded = try JSONDecoder().decode(RunState.self, from: JSONEncoder().encode(legacy))
        XCTAssertEqual(decoded.outcome, .bookCompleted)
        XCTAssertNil(decoded.shop)
        for var restored in [Game(run: legacy), Game(run: decoded)] {
            XCTAssertEqual(restored.run.outcome, .bookCompleted)
            XCTAssertEqual(restored.run.coins, 137)
            XCTAssertEqual(restored.run.bestPuzzleScore, 2_100_000)
            XCTAssertEqual(restored.run.streams.shop.state, shopStream)
            XCTAssertNil(restored.shop)
            XCTAssertNil(restored.puzzle, "Legacy Shop saves had already discarded the board")
            XCTAssertThrowsError(try restored.cashOut())
            restored.openShop()
            XCTAssertFalse(restored.advance())
            XCTAssertEqual(restored.run.coins, 137)
            XCTAssertNil(restored.shop)
        }
    }

    func testLegacyFinalCashedOutBoardIsRetainedButUnpaidWinIsNotCompleted() throws {
        var game = Game(seed: "legacy-final-paid")
        game.run.level = 9
        game.run.slot = .boss
        try game.startPuzzle()
        game.qaMeetTarget()
        var unpaid = try Game(decoding: game.encoded())
        XCTAssertNil(unpaid.run.outcome)
        XCTAssertEqual(unpaid.puzzle?.phase, .won)
        unpaid.openShop()
        XCTAssertNil(unpaid.shop)
        XCTAssertFalse(unpaid.advance())
        XCTAssertNil(unpaid.run.outcome, "Navigation cannot award an unpaid final victory")
        XCTAssertEqual(unpaid.puzzle?.phase, .won)

        _ = try Actions.cashOut(&game.run) // Legacy payout did not set outcome.
        XCTAssertNil(game.run.outcome)
        let paidCoins = game.run.coins
        var restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.run.outcome, .bookCompleted)
        XCTAssertEqual(restored.puzzle?.phase, .cashedOut)
        XCTAssertEqual(restored.run.coins, paidCoins)
        XCTAssertThrowsError(try restored.cashOut())
        XCTAssertEqual(restored.run.coins, paidCoins)
    }

    func testFinalPendingRescueAndFailedSaveAreNeverPromotedToCompleted() throws {
        for phase in [PuzzlePhase.outOfTurns, .failed] {
            var game = Game(seed: "final-not-won-\(phase)")
            game.run.level = 9
            game.run.slot = .boss
            try game.startPuzzle()
            game.run.puzzle?.phase = phase
            game.run.outcome = phase == .failed ? .failed : nil
            var restored = try Game(decoding: game.encoded())
            XCTAssertEqual(restored.run.outcome, game.run.outcome)
            XCTAssertEqual(restored.puzzle?.phase, phase)
            XCTAssertThrowsError(try restored.cashOut())
            XCTAssertFalse(restored.advance())
            restored.openShop()
            XCTAssertNil(restored.shop)
            XCTAssertEqual(restored.run.outcome, game.run.outcome)
            XCTAssertEqual(restored.puzzle?.phase, phase)
        }
    }

    func testPreCompletionRecordSaveDefaultsBestScoreToZero() throws {
        let run = RunState(seed: "legacy-book")
        let encoded = try JSONEncoder().encode(run)
        var object = try XCTUnwrap(try JSONSerialization.jsonObject(with: encoded)
            as? [String: Any])
        object.removeValue(forKey: "bestPuzzleScore")
        let legacyData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        XCTAssertEqual(try JSONDecoder().decode(RunState.self, from: legacyData).bestPuzzleScore, 0)
    }
}
