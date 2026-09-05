import XCTest
@testable import ProbablySudokuEngine

final class HandClueTests: XCTestCase {
    private func game() throws -> Game {
        var game = Game(seed: "hand-clue", book: .noPressure)
        try game.startPuzzle()
        return game
    }

    func testRevealUsesHeldDigitWithoutPlayingOrScoringIt() throws {
        var game = try game()
        let before = game.puzzle!
        let coins = game.run.coins
        let square = try game.revealClue(handIndex: 0)
        let after = game.puzzle!
        XCTAssertEqual(after.board.correctDigit(at: square), before.hand[0])
        XCTAssertTrue(after.board.isBlank(square))
        XCTAssertEqual(after.board.placed, before.board.placed)
        XCTAssertEqual(after.hand, before.hand)
        XCTAssertEqual(Digit.allCases.map { after.pool[$0] }, Digit.allCases.map { before.pool[$0] })
        XCTAssertEqual(after.pendingBase, before.pendingBase)
        XCTAssertEqual(after.score, before.score)
        XCTAssertEqual(after.turnNumber, before.turnNumber)
        XCTAssertEqual(game.run.coins, coins)
        XCTAssertEqual(after.cluesRemaining, before.cluesRemaining - 1)
        XCTAssertTrue(after.clueReveals.contains(square))
        after.assertConservation()
    }

    func testReinspectionIsFreeAndPaidRevealSurvivesSaveLoad() throws {
        var game = try game()
        let square = try game.revealClue(handIndex: 0)
        XCTAssertEqual(try game.revealClue(handIndex: 0), square)
        XCTAssertEqual(game.puzzle?.cluesRemaining, 0)
        var restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.puzzle?.clueReveals, [square])
        XCTAssertEqual(try restored.revealClue(handIndex: 0), square)
        XCTAssertEqual(restored.puzzle?.cluesRemaining, 0)
    }

    func testPlacingRevealedNumberUsesTheCardAndClueScoring() throws {
        var game = try game()
        let square = try game.revealClue(handIndex: 0)
        let digit = game.puzzle!.hand[0]
        let count = game.puzzle!.hand.count
        let outcome = try game.place(handIndex: 0, at: square)
        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.points, 0)
        XCTAssertEqual(game.puzzle?.board[square], digit)
        XCTAssertEqual(game.puzzle?.board.filledBy[square.index], .clue)
        XCTAssertEqual(game.puzzle?.hand.count, count - 1)
        XCTAssertFalse(game.puzzle!.clueReveals.contains(square))
        game.puzzle!.assertConservation()
    }

    func testOnyxStillRestoresRevealedPlacementPoints() throws {
        var game = try game()
        let square = try game.revealClue(handIndex: 0)
        let digit = game.puzzle!.hand[0]
        game.give(marker: Markers.onyx, on: [square])
        XCTAssertEqual(try game.place(handIndex: 0, at: square).points, 10 * digit.rawValue)
    }

    func testBarredDestinationsAndBlockedCardsDoNotSpendAClue() throws {
        var game = try game()
        let digit = game.puzzle!.hand[0]
        var turn = BossTurnState()
        turn.blockedHandIndices = [0]
        game.run.puzzle?.bossTurn = turn
        XCTAssertThrowsError(try game.revealClue(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .numberBlocked)
        }
        XCTAssertEqual(game.puzzle?.cluesRemaining, 1)
        turn.blockedHandIndices = []
        turn.greyed = Set(game.puzzle!.board.blanks.filter {
            game.puzzle!.board.correctDigit(at: $0) == digit
        })
        game.run.puzzle?.bossTurn = turn
        XCTAssertThrowsError(try game.revealClue(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .noClueDestination)
        }
        XCTAssertEqual(game.puzzle?.cluesRemaining, 1)
        XCTAssertTrue(game.puzzle!.clueReveals.isEmpty)
    }

    func testPaywallAndEveryNonPlayablePhaseRejectHints() throws {
        var game = try game()
        game.run.puzzle?.boss = .paywall
        XCTAssertThrowsError(try game.revealClue(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .cluesDisabled)
        }
        game.run.puzzle?.boss = nil
        for phase: PuzzlePhase in [.won, .outOfTurns, .failed, .cashedOut] {
            game.run.puzzle?.phase = phase
            let before = try game.encoded()
            XCTAssertThrowsError(try game.revealClue(handIndex: 0))
            XCTAssertEqual(try game.encoded(), before)
        }
    }

    func testOldSaveWithoutRevealsStillLoads() throws {
        let game = try game()
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(json["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "clueReveals")
        json["puzzle"] = puzzle
        let restored = try Game(decoding: JSONSerialization.data(withJSONObject: json))
        XCTAssertTrue(restored.puzzle!.clueReveals.isEmpty)
        XCTAssertEqual(restored.puzzle?.hand, game.puzzle?.hand)
        XCTAssertEqual(restored.puzzle?.board.placed, game.puzzle?.board.placed)
    }
}
