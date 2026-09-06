import XCTest
@testable import ProbablySudokuEngine

final class KeepFillingCompletionTests: XCTestCase {
    func testFullClearEndsKeepFillingAndCannotReenterOrAwardItsBonusAgain() throws {
        var game = try wonGame()
        let frozenScore = try XCTUnwrap(game.puzzle?.score)
        try game.keepFilling()
        var lineClears = 0
        var fullClears = 0
        for square in try XCTUnwrap(game.puzzle?.board.blanks) {
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let index = try XCTUnwrap(game.stackHand(with: digit))
            let outcome = try game.place(handIndex: index, at: square)
            lineClears += outcome.lineClears.count
            fullClears += outcome.fullClear ? 1 : 0
        }

        let completed = try XCTUnwrap(game.puzzle)
        XCTAssertTrue(completed.board.isFull)
        XCTAssertEqual(completed.phase, .won)
        XCTAssertGreaterThan(completed.turnsRemaining, 0)
        XCTAssertEqual(completed.score, frozenScore)
        XCTAssertEqual(fullClears, 1)
        XCTAssertEqual(completed.keepFillingCoins, lineClears + 3)
        completed.assertConservation()
        let fullState = try game.encoded()

        XCTAssertThrowsError(try game.keepFilling())
        XCTAssertEqual(try game.encoded(), fullState, "A full board must remain on its unpaid results.")
        XCTAssertThrowsError(try game.endTurn())
        XCTAssertEqual(game.puzzle?.keepFillingCoins, lineClears + 3)

        let coins = game.run.coins
        let payout = try game.cashOut()
        XCTAssertEqual(payout.keepFillingBank, lineClears + 3)
        XCTAssertEqual(game.run.coins, coins + payout.total)
        XCTAssertThrowsError(try game.cashOut())
        XCTAssertEqual(game.run.coins, coins + payout.total)
        game.openShop()
        XCTAssertNotNil(game.shop)
        XCTAssertNil(game.run.outcome)
    }

    func testWonPuzzleWithoutRemainingTurnsCannotEnterKeepFilling() throws {
        var game = try wonGame()
        let turnsMax = try XCTUnwrap(game.puzzle?.turnsMax)
        game.run.puzzle?.turnNumber = turnsMax + 1
        XCTAssertFalse(try XCTUnwrap(game.puzzle?.board.isFull))
        let before = try game.encoded()

        XCTAssertThrowsError(try game.keepFilling())

        XCTAssertEqual(try game.encoded(), before)
        XCTAssertNoThrow(try game.cashOut())
    }

    func testLegacyFullKeepFillingSaveRestoresOnlyItsPhaseWithoutReplayingRewards() throws {
        var game = try wonGame()
        try game.keepFilling()
        game.qaFillBoard()
        game.run.puzzle?.keepFillingCoins = 17
        // Older builds offered Keep Filling again after Full Clear, saving an
        // impossible playable board. Its already-earned bank must be preserved.
        game.run.puzzle?.phase = .keepFilling
        let legacy = try game.encoded()
        var expected = try XCTUnwrap(JSONSerialization.jsonObject(with: legacy) as? [String: Any])
        var expectedPuzzle = try XCTUnwrap(expected["puzzle"] as? [String: Any])
        expectedPuzzle["phase"] = PuzzlePhase.won.rawValue
        expected["puzzle"] = expectedPuzzle

        var restored = try Game(decoding: legacy)

        XCTAssertEqual(restored.puzzle?.phase, .won)
        let actual = try XCTUnwrap(JSONSerialization.jsonObject(with: restored.encoded()) as? [String: Any])
        XCTAssertEqual(actual as NSDictionary, expected as NSDictionary,
                       "Restore changes only the stranded phase, not score, bank, board or RNG.")
        XCTAssertEqual(try Game(decoding: restored.encoded()).encoded(), try restored.encoded())
        let payout = try restored.cashOut()
        XCTAssertEqual(payout.keepFillingBank, 17)
        XCTAssertThrowsError(try restored.cashOut())
    }

    func testWonAndActiveKeepFillingSavesWithBlanksStayUnchanged() throws {
        var game = try wonGame()
        for phase in [PuzzlePhase.won, .keepFilling] {
            if phase == .keepFilling { try game.keepFilling() }
            let before = try game.encoded()
            let restored = try Game(decoding: before)
            XCTAssertEqual(restored.puzzle?.phase, phase)
            XCTAssertFalse(try XCTUnwrap(restored.puzzle?.board.isFull))
            XCTAssertEqual(try restored.encoded(), before)
        }
    }

    private func wonGame() throws -> Game {
        var game = Game(seed: "keep-filling-completion")
        try game.startPuzzle()
        game.qaMeetTarget()
        return game
    }
}
