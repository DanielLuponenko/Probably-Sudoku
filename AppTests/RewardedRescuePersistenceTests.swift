import Foundation
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// All snapshots are synthetic and in memory. No profile, filesystem, cloud,
/// ad SDK or Game Center writes are made by these lifecycle checks.
@MainActor
final class RewardedRescuePersistenceTests: XCTestCase {
    func testEveryBookResumesItsEarnedRewardBeforeAdDismissal() throws {
        for book in Book.allCases {
            let pending = try pendingGame(book: book)
            let model = GameModel(resuming: pending, savesProgress: false)
            XCTAssertEqual(model.page, .results)
            let ticket = try XCTUnwrap(model.beginRewardedRescue())
            XCTAssertTrue(model.receiveRewardedRescue(ticket))
            XCTAssertTrue(model.hasRewardedRescueInFlight)
            XCTAssertEqual(model.page, .results, "The ad still covers the results page")

            let saved = try XCTUnwrap(RunStore.dataForStorage(of: model.gameForPersistence))
            let restored = GameModel(resuming: try XCTUnwrap(RunStore.game(from: saved)),
                                     savesProgress: false)
            XCTAssertEqual(restored.run.book, book)
            XCTAssertEqual(restored.run.obstacle, pending.run.obstacle)
            XCTAssertEqual(restored.run.seed, pending.run.seed)
            XCTAssertEqual(restored.run.level, pending.run.level)
            XCTAssertEqual(restored.run.slot, pending.run.slot)
            XCTAssertEqual(restored.page, .puzzle)
            XCTAssertEqual(restored.puzzle?.turnsRemaining, 3)
            XCTAssertEqual(restored.puzzle?.rewardedRescueUsed, true)
            XCTAssertFalse(restored.hasRewardedRescueInFlight)
            XCTAssertNil(restored.beginRewardedRescue())
            XCTAssertEqual(restored.puzzle?.board.placed, pending.puzzle?.board.placed)
            XCTAssertEqual(restored.puzzle?.hand, pending.puzzle?.hand)
            XCTAssertEqual(restored.score, model.score)
            XCTAssertEqual(try restored.game.encoded(), try model.gameForPersistence.encoded())

            // Another closed/reopened session must neither lose nor refill a
            // turn already spent after earning the rescue.
            restored.endTurn()
            let again = GameModel(resuming: try XCTUnwrap(RunStore.game(
                from: RunStore.dataForStorage(of: restored.gameForPersistence))), savesProgress: false)
            XCTAssertEqual(again.puzzle?.turnsRemaining, 2)
            XCTAssertEqual(again.run.book, book)
            XCTAssertEqual(again.page, .puzzle)
            XCTAssertNil(again.beginRewardedRescue())
        }
    }

    func testClosingBeforeEarnedCallbackPreservesOfferWithoutGivingFreeTurns() throws {
        let pending = try pendingGame(book: .smallVictories)
        let model = GameModel(resuming: pending, savesProgress: false)
        let ticket = try XCTUnwrap(model.beginRewardedRescue())
        let restored = GameModel(resuming: try XCTUnwrap(RunStore.game(
            from: RunStore.dataForStorage(of: model.gameForPersistence))), savesProgress: false)
        XCTAssertEqual(restored.page, .results)
        XCTAssertEqual(restored.puzzle?.turnsRemaining, 0)
        XCTAssertTrue(restored.canOfferRewardedRescue)
        XCTAssertFalse(restored.receiveRewardedRescue(ticket))
        XCTAssertNotNil(restored.beginRewardedRescue())
    }

    func testAdDismissalAndDuplicateDismissalKeepRewardedStateIdentical() throws {
        let model = GameModel(resuming: try pendingGame(book: .bites), savesProgress: false)
        let ticket = try XCTUnwrap(model.beginRewardedRescue())
        XCTAssertTrue(model.receiveRewardedRescue(ticket))
        let earned = try model.gameForPersistence.encoded()
        model.finishRewardedRescue(ticket)
        model.finishRewardedRescue(ticket)
        XCTAssertEqual(model.page, .puzzle)
        XCTAssertFalse(model.hasRewardedRescueInFlight)
        XCTAssertEqual(try model.gameForPersistence.encoded(), earned)
    }

    func testAbandonedTimedBookCannotRemainRunningOrReceiveLateReward() throws {
        var run = RunState(seed: "retired-clock", book: .smallVictories)
        run.slot = .boss
        run.pendingBoss = .tikTak
        var game = Game(run: run)
        try game.startPuzzle()
        let model = GameModel(resuming: game, savesProgress: false)
        let now = ContinuousClock().now
        model.setClockRunning(true, at: now)
        XCTAssertTrue(model.isClockRunning)
        model.abandonRun()
        XCTAssertFalse(model.isClockRunning)
        XCTAssertTrue(model.wantsMenu)
        let retired = try model.gameForPersistence.encoded()
        model.setClockRunning(false, at: now.advanced(by: .seconds(30)))
        model.tickClock(at: now.advanced(by: .seconds(40)))
        XCTAssertEqual(try model.gameForPersistence.encoded(), retired)
        XCTAssertFalse(model.receiveRewardedRescue(UUID()))
    }

    private func pendingGame(book: Book) throws -> Game {
        var game = Game(seed: "resume-after-ad", book: book, obstacle: .shortHanded)
        try game.startPuzzle()
        while game.puzzle?.phase == .playing { _ = try game.endTurn() }
        XCTAssertTrue(game.canClaimRewardedRescue)
        return game
    }
}
