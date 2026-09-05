import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// In-memory games only: no test writes to a player's local/cloud run.
final class RewardedRescueSessionTests: XCTestCase {
    func testPlayingPuzzleCannotStartARewardPresentation() throws {
        var game = Game(seed: "rescue-playing")
        try game.startPuzzle()
        var session = RewardedRescueSession()
        XCTAssertNil(session.begin(for: game))
        XCTAssertFalse(session.isActive)
    }

    func testOnlyMatchingEarnedCallbackGrantsExactlyOnce() throws {
        var game = try pendingGame()
        let originalBudget = try XCTUnwrap(game.puzzle?.turnsMax)
        var session = RewardedRescueSession()
        let ticket = try XCTUnwrap(session.begin(for: game))
        XCTAssertNil(session.begin(for: game))
        XCTAssertFalse(session.receive(UUID(), game: &game))
        XCTAssertTrue(session.receive(ticket, game: &game))
        XCTAssertFalse(session.receive(ticket, game: &game))
        XCTAssertEqual(game.puzzle?.turnsMax, originalBudget + 3)
        XCTAssertEqual(game.puzzle?.turnsRemaining, 3)
        XCTAssertTrue(session.hasEarned(ticket))
        XCTAssertTrue(session.finish(ticket, game: game))
        XCTAssertFalse(session.finish(ticket, game: game))
        XCTAssertNil(session.begin(for: game))
    }

    func testDismissalWithoutRewardKeepsTheSavedPuzzleAndOffer() throws {
        let game = try pendingGame()
        let before = try game.encoded()
        var session = RewardedRescueSession()
        let ticket = try XCTUnwrap(session.begin(for: game))
        XCTAssertFalse(session.finish(ticket, game: game))
        XCTAssertEqual(try game.encoded(), before)
        XCTAssertTrue(game.canClaimRewardedRescue)
        XCTAssertNotNil(session.begin(for: game))
    }

    func testAbandonInvalidationRejectsLateRewardEvenForSameSeed() throws {
        var game = try pendingGame()
        var session = RewardedRescueSession()
        let oldTicket = try XCTUnwrap(session.begin(for: game))
        session.invalidate()
        game = try pendingGame()
        let newTicket = try XCTUnwrap(session.begin(for: game))
        XCTAssertFalse(session.receive(oldTicket, game: &game))
        XCTAssertFalse(session.finish(oldTicket, game: game))
        XCTAssertTrue(session.isActive)
        XCTAssertTrue(session.receive(newTicket, game: &game))
    }

    func testCallbackCannotRewardAnotherBook() throws {
        var game = try pendingGame()
        var session = RewardedRescueSession()
        let ticket = try XCTUnwrap(session.begin(for: game))
        game = try pendingGame(seed: "different-book")
        XCTAssertFalse(session.receive(ticket, game: &game))
        XCTAssertFalse(session.finish(ticket, game: game))
        XCTAssertTrue(game.canClaimRewardedRescue)
    }

    func testPendingAndEarnedSavesResumeWithoutLosingOrRepeatingReward() throws {
        let pending = try pendingGame()
        var game = try Game(decoding: pending.encoded())
        var session = RewardedRescueSession()
        let ticket = try XCTUnwrap(session.begin(for: game))
        XCTAssertTrue(session.receive(ticket, game: &game))
        // Simulate termination after earned callback but before dismissal.
        let resumed = try Game(decoding: game.encoded())
        XCTAssertNil(resumed.run.outcome)
        XCTAssertEqual(resumed.puzzle?.phase, .playing)
        XCTAssertEqual(resumed.puzzle?.turnsRemaining, 3)
        XCTAssertEqual(resumed.puzzle?.rewardedRescueUsed, true)
        var newSession = RewardedRescueSession()
        XCTAssertNil(newSession.begin(for: resumed))
        let resumedBoard = try XCTUnwrap(resumed.puzzle?.board)
        let pendingBoard = try XCTUnwrap(pending.puzzle?.board)
        XCTAssertEqual(resumedBoard.solution, pendingBoard.solution)
        XCTAssertEqual(resumedBoard.isGiven, pendingBoard.isGiven)
        XCTAssertEqual(resumedBoard.placed, pendingBoard.placed)
        XCTAssertEqual(resumedBoard.filledBy, pendingBoard.filledBy)
        XCTAssertEqual(resumed.puzzle?.hand, pending.puzzle?.hand)
        XCTAssertEqual(resumed.puzzle?.score, pending.puzzle?.score)
    }

    @MainActor
    func testFrozenResultCannotRequestOrAcceptReward() throws {
        let model = GameModel(frozen: try pendingGame(), page: .results)
        XCTAssertFalse(model.canOfferRewardedRescue)
        XCTAssertNil(model.beginRewardedRescue())
        XCTAssertFalse(model.receiveRewardedRescue(UUID()))
        XCTAssertEqual(model.puzzle?.phase, .outOfTurns)
    }

    private func pendingGame(seed: String = "rescue-session") throws -> Game {
        var game = Game(seed: seed)
        try game.startPuzzle()
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        return game
    }
}
