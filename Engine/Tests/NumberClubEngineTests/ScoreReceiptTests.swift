import XCTest
@testable import ProbablySudokuEngine

final class ScoreReceiptTests: XCTestCase {
    private func game() throws -> Game {
        var game = Game(seed: "receipt")
        try game.startPuzzle()
        game.give(ad: "bm_local_gossip")
        game.give(ad: "bm_morning_edition")
        game.give(ad: "bm_evening_edition")
        return game
    }

    func testActualPlacementAndEndTurnContributionsAreSeparate() throws {
        var game = try game()
        let square = try XCTUnwrap(game.blank(wanting: .nine))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .nine)), at: square)
        let receipt = try XCTUnwrap(outcome.scoreReceipts.first)
        XCTAssertEqual(receipt.base, 90)
        XCTAssertEqual(receipt.points, 120)
        XCTAssertEqual(receipt.contributions.map(\.sourceID), ["bm_local_gossip"])
        XCTAssertEqual(receipt.contributions.first?.flat, 30)
        let turn = try game.endTurn()
        XCTAssertEqual(turn.contributions.map(\.sourceID), ["bm_morning_edition"])
        XCTAssertEqual(turn.contributions.first?.directScore, 100)
        XCTAssertEqual(turn.pointsGained, 220)
        XCTAssertEqual(game.puzzle?.score, 220)
    }

    func testAutomaticTurnCarriesReceiptWithoutReplayingPayout() throws {
        var game = try game()
        var puzzle = try XCTUnwrap(game.puzzle)
        for digit in puzzle.hand { puzzle.pool.put(digit) }
        puzzle.hand = []
        let square = try XCTUnwrap(puzzle.board.blanks.first)
        let digit = puzzle.board.correctDigit(at: square)
        XCTAssertTrue(puzzle.pool.take(digit))
        puzzle.hand = [digit]
        game.run.puzzle = puzzle
        let outcome = try game.place(handIndex: 0, at: square)
        let turn = try XCTUnwrap(outcome.automaticTurn)
        XCTAssertEqual(turn.contributions.first?.sourceID, "bm_morning_edition")
        XCTAssertEqual(turn.contributions.first?.directScore, 100)
        XCTAssertEqual(game.puzzle?.score, digit.rawValue * 10 + 30 + 100)
        XCTAssertEqual(game.puzzle?.turnNumber, 2)
    }

    func testSleepingAndInapplicableBookmarksDoNotProduceReceipts() throws {
        var game = try game()
        game.run.puzzle?.bossTurn = BossTurnState()
        game.run.puzzle?.bossTurn?.disabledBookmark = 0
        let square = try XCTUnwrap(game.blank(wanting: .nine))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .nine)), at: square)
        XCTAssertTrue(try XCTUnwrap(outcome.scoreReceipts.first).contributions.isEmpty)
        XCTAssertEqual(outcome.points, 90)
    }

    func testTurnTenReportsBothDirectAwardsAndDoesNotMultiplyThem() throws {
        var game = try game()
        game.run.puzzle?.turnNumber = 10
        game.run.puzzle?.pendingBase = 100
        game.run.puzzle?.pendingMult = 3
        let turn = try game.endTurn()
        XCTAssertEqual(turn.contributions.map(\.directScore), [100, 300])
        XCTAssertEqual(turn.pointsGained, 700)
        XCTAssertEqual(turn.multiplier, 3)
    }

    func testKeepFillingDoesNotClaimFrozenScoreBonuses() throws {
        var game = try game()
        game.run.puzzle?.phase = .keepFilling
        let square = try XCTUnwrap(game.blank(wanting: .nine))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .nine)), at: square)
        XCTAssertTrue(outcome.scoreReceipts.isEmpty)
        let turn = try game.endTurn()
        XCTAssertTrue(turn.contributions.isEmpty)
        XCTAssertEqual(turn.pointsGained, 0)
    }

    func testBookBonusAndMultiplierAreAttributedInResolverOrder() throws {
        var game = Game(seed: "book-receipt", book: .overthinking)
        try game.startPuzzle()
        game.give(ad: "bm_local_gossip")
        game.give(ad: "bm_op_ed")
        let square = try XCTUnwrap(game.blank(wanting: .nine))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .nine)), at: square)
        let receipt = try XCTUnwrap(outcome.scoreReceipts.first)
        XCTAssertEqual(receipt.contributions.map(\.sourceID), ["book-benefit", "bm_local_gossip", "bm_op_ed"])
        XCTAssertEqual(receipt.contributions.map(\.flat), [10, 30, 0])
        XCTAssertEqual(receipt.contributions.last?.multAdd, 1)
        XCTAssertEqual(receipt.points, 130)
        XCTAssertEqual(game.puzzle?.pendingScore, 260)
    }
}
