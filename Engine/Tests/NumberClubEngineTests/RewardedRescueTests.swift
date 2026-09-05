import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class RewardedRescueTests: XCTestCase {
    func testFirstTurnExhaustionPausesWithoutEndingTheBook() throws {
        var game = try startedGame()
        XCTAssertFalse(game.canClaimRewardedRescue)
        let originalLimit = try XCTUnwrap(game.puzzle?.turnsMax)
        game.run.puzzle?.turnNumber = originalLimit
        game.run.puzzle?.pendingBase = 123
        game.run.puzzle?.pendingMult = 2

        let result = try game.endTurn()

        XCTAssertTrue(result.turnsExhausted)
        XCTAssertTrue(result.puzzleFailed, "The existing results route must still receive the exhaustion event")
        XCTAssertEqual(result.pointsGained, 246)
        XCTAssertEqual(game.puzzle?.score, 246)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        XCTAssertEqual(game.puzzle?.turnNumber, originalLimit + 1)
        XCTAssertEqual(game.puzzle?.turnsMax, originalLimit)
        XCTAssertEqual(game.puzzle?.turnsRemaining, 0)
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false)
        XCTAssertNil(game.run.outcome)
        XCTAssertFalse(game.isOver)
        XCTAssertTrue(game.canClaimRewardedRescue)
        try assertConservation(game)
    }

    func testClaimAddsExactlyThreeToNormalAndModifiedTurnBudgets() throws {
        let cases: [(Book, Obstacle, BossModifier?, Bool, Int)] = [
            (.probably, .none, nil, false, 10),
            (.bites, .none, nil, false, 11),
            (.probably, .doubleBlocked, nil, false, 9),
            (.probably, .none, .deadline, false, 8),
            (.bites, .doubleBlocked, .deadline, true, 10)
        ]

        for (book, obstacle, boss, extraTurnItems, expectedBudget) in cases {
            var game = try startedGame(book: book, obstacle: obstacle, boss: boss,
                                       extraTurnItems: extraTurnItems)
            XCTAssertEqual(game.puzzle?.turnsMax, expectedBudget)
            try exhaustCurrentBudget(&game)
            XCTAssertTrue(game.canClaimRewardedRescue)

            XCTAssertTrue(game.claimRewardedRescue())

            XCTAssertEqual(game.puzzle?.phase, .playing)
            XCTAssertEqual(game.puzzle?.turnsMax, expectedBudget + 3)
            XCTAssertEqual(game.puzzle?.turnNumber, expectedBudget + 1)
            XCTAssertEqual(game.puzzle?.turnsRemaining, 3)
            XCTAssertEqual(game.puzzle?.rewardedRescueUsed, true)
            XCTAssertFalse(game.canClaimRewardedRescue)
            XCTAssertNil(game.run.outcome)
            try assertConservation(game)
        }
    }

    func testClaimPreservesEntirePendingRunExceptItsThreeIntendedFields() throws {
        var game = try startedGame(book: .bites, obstacle: .doubleBlocked, boss: .handyDandy,
                                   extraTurnItems: true)
        game.give(buff: Buffs.paperCrane)
        game.run.puzzle?.score = 137
        game.run.puzzle?.itemState["rescue.test.state"] = 2.5
        game.run.runItemState["rescue.test.runState"] = 4
        try exhaustCurrentBudget(&game)
        let pending = game
        var expected = pending
        expected.run.puzzle?.turnsMax += 3
        expected.run.puzzle?.rewardedRescueUsed = true
        expected.run.puzzle?.phase = .playing

        XCTAssertTrue(game.claimRewardedRescue())

        XCTAssertEqual(try game.encoded(), try expected.encoded(),
                       "Claim must not redraw, reroll restrictions, bank points, spend coins, or alter inventory")
        XCTAssertEqual(game.run.streams.board.state, pending.run.streams.board.state)
        XCTAssertEqual(game.run.streams.pool.state, pending.run.streams.pool.state)
        XCTAssertEqual(game.run.streams.shop.state, pending.run.streams.shop.state)
        XCTAssertEqual(game.run.streams.boss.state, pending.run.streams.boss.state)
        XCTAssertEqual(game.puzzle?.hand, pending.puzzle?.hand)
        XCTAssertEqual(game.puzzle?.board.placed, pending.puzzle?.board.placed)
        XCTAssertEqual(game.puzzle?.board.filledBy, pending.puzzle?.board.filledBy)
        for digit in Digit.all {
            XCTAssertEqual(game.puzzle?.pool[digit], pending.puzzle?.pool[digit])
        }
        try assertConservation(game)
    }

    func testDuplicateClaimAndLateDeclineDoNotMutateRescuedPuzzle() throws {
        var game = try pendingGame()
        XCTAssertTrue(game.claimRewardedRescue())
        let rescued = try game.encoded()

        XCTAssertFalse(game.claimRewardedRescue())
        XCTAssertFalse(game.declineRewardedRescue())

        XCTAssertEqual(try game.encoded(), rescued)
        XCTAssertEqual(game.puzzle?.turnsRemaining, 3)
        XCTAssertNil(game.run.outcome)
    }

    func testDecliningPendingRescueEndsTheBookExactlyOnce() throws {
        var game = try pendingGame()
        var expected = game
        expected.run.puzzle?.phase = .failed
        expected.run.outcome = .failed

        XCTAssertTrue(game.declineRewardedRescue())

        XCTAssertEqual(try game.encoded(), try expected.encoded())
        XCTAssertTrue(game.isOver)
        XCTAssertFalse(game.canClaimRewardedRescue)
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false)
        let declined = try game.encoded()
        XCTAssertFalse(game.declineRewardedRescue())
        XCTAssertFalse(game.claimRewardedRescue())
        XCTAssertEqual(try game.encoded(), declined)
    }

    func testClaimsAndDeclinesOutsideEligiblePendingStateAreNoOps() throws {
        let pending = try pendingGame()
        var invalidGames = [Game(seed: "rescue-no-puzzle")]
        for phase in [PuzzlePhase.playing, .won, .keepFilling, .failed, .cashedOut] {
            var game = pending
            game.run.puzzle?.phase = phase
            invalidGames.append(game)
        }
        var alreadyUsed = pending
        alreadyUsed.run.puzzle?.rewardedRescueUsed = true
        invalidGames.append(alreadyUsed)
        var notExhausted = pending
        let pendingLimit = try XCTUnwrap(pending.puzzle?.turnsMax)
        notExhausted.run.puzzle?.turnNumber = pendingLimit
        invalidGames.append(notExhausted)
        var targetMet = pending
        let pendingTarget = try XCTUnwrap(pending.puzzle?.target)
        targetMet.run.puzzle?.score = pendingTarget
        invalidGames.append(targetMet)
        var fullBoard = pending
        try fillWithoutScoring(&fullBoard)
        invalidGames.append(fullBoard)
        for outcome in [RunOutcome.failed, .bookCompleted] {
            var game = pending
            game.run.outcome = outcome
            invalidGames.append(game)
        }

        for (index, candidate) in invalidGames.enumerated() {
            var game = candidate
            let before = try game.encoded()
            XCTAssertFalse(game.canClaimRewardedRescue, "Invalid case \(index)")
            XCTAssertFalse(game.claimRewardedRescue(), "Invalid case \(index)")
            XCTAssertFalse(game.declineRewardedRescue(), "Invalid case \(index)")
            XCTAssertEqual(try game.encoded(), before, "Invalid case \(index) must remain untouched")
        }
    }

    func testPendingOfferRejectsGameplayActionsWithoutChangingState() throws {
        var game = try startedGame(book: .noPressure)
        game.give(buff: Buffs.peek)
        try exhaustCurrentBudget(&game)
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let before = try game.encoded()

        XCTAssertThrowsError(try game.place(handIndex: 0, at: square)) {
            XCTAssertEqual($0 as? PlacementError, .puzzleNotPlayable)
        }
        XCTAssertThrowsError(try game.toss(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .puzzleNotPlayable)
        }
        XCTAssertThrowsError(try game.useClue(at: square)) {
            XCTAssertEqual($0 as? PlacementError, .puzzleNotPlayable)
        }
        XCTAssertThrowsError(try game.useBuff(at: 0)) {
            XCTAssertEqual($0 as? PlacementError, .puzzleNotPlayable)
        }
        XCTAssertThrowsError(try game.endTurn())
        XCTAssertThrowsError(try game.cashOut())
        XCTAssertThrowsError(try game.keepFilling())
        XCTAssertEqual(try game.encoded(), before)
    }

    func testAutomaticEndTurnOffersRescueAfterTheLastHandCard() throws {
        var game = try startedGame()
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        var puzzle = try XCTUnwrap(game.puzzle)
        for held in puzzle.hand { puzzle.pool.put(held) }
        puzzle.hand = []
        XCTAssertTrue(puzzle.pool.take(digit))
        puzzle.hand = [digit]
        puzzle.turnNumber = puzzle.turnsMax
        game.run.puzzle = puzzle

        let placement = try game.place(handIndex: 0, at: square)

        XCTAssertTrue(placement.correct)
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        XCTAssertEqual(game.puzzle?.turnNumber, puzzle.turnsMax + 1)
        XCTAssertEqual(game.puzzle?.score, placement.totalPoints)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        XCTAssertEqual(game.puzzle?.hand.count, puzzle.handSize)
        XCTAssertNil(game.run.outcome)
        let pendingHand = game.puzzle?.hand
        let pendingPoolStream = game.run.streams.pool.state
        XCTAssertTrue(game.claimRewardedRescue())
        XCTAssertEqual(game.puzzle?.hand, pendingHand, "The final Turn already refilled the Hand")
        XCTAssertEqual(game.run.streams.pool.state, pendingPoolStream)
        try assertConservation(game)
    }

    func testThreeRescuedTurnsThenSecondExhaustionEndsTheBook() throws {
        var game = try pendingGame()
        XCTAssertTrue(game.claimRewardedRescue())

        for remaining in [2, 1] {
            let turn = try game.endTurn()
            XCTAssertFalse(turn.turnsExhausted)
            XCTAssertFalse(turn.puzzleFailed)
            XCTAssertEqual(game.puzzle?.phase, .playing)
            XCTAssertEqual(game.puzzle?.turnsRemaining, remaining)
            XCTAssertNil(game.run.outcome)
        }
        let finalTurn = try game.endTurn()

        XCTAssertTrue(finalTurn.turnsExhausted)
        XCTAssertTrue(finalTurn.puzzleFailed)
        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertEqual(game.puzzle?.turnsRemaining, 0)
        XCTAssertEqual(game.run.outcome, .failed)
        XCTAssertTrue(game.isOver)
        XCTAssertFalse(game.claimRewardedRescue())
        XCTAssertFalse(game.declineRewardedRescue())
        try assertConservation(game)
    }

    func testRescuedPuzzleCanStillWinAndCashOutNormally() throws {
        var game = try startedGame()
        let target = try XCTUnwrap(game.puzzle?.target)
        game.run.puzzle?.score = target - 10
        try exhaustCurrentBudget(&game)
        XCTAssertTrue(game.claimRewardedRescue())
        let digit = try XCTUnwrap(game.puzzle?.hand.first)
        let square = try XCTUnwrap(game.blank(wanting: digit))

        _ = try game.place(handIndex: 0, at: square)
        _ = try game.endTurn()

        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(game.puzzle?.score), try XCTUnwrap(game.puzzle?.target))
        XCTAssertNil(game.run.outcome)
        let coins = game.run.coins
        let payout = try game.cashOut()
        XCTAssertEqual(game.puzzle?.phase, .cashedOut)
        XCTAssertEqual(game.run.coins, coins + payout.total)
        XCTAssertFalse(game.claimRewardedRescue())

        game.openShop()
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false, "Rescue is once per Puzzle, not once per Book")
        XCTAssertFalse(game.canClaimRewardedRescue)
        try exhaustCurrentBudget(&game)
        XCTAssertTrue(game.canClaimRewardedRescue)
        XCTAssertTrue(game.claimRewardedRescue())
    }

    func testMeetingTargetOnOriginalLastTurnNeverOffersRescue() throws {
        var game = try startedGame()
        let puzzle = try XCTUnwrap(game.puzzle)
        game.run.puzzle?.turnNumber = puzzle.turnsMax
        game.run.puzzle?.pendingBase = puzzle.target

        let turn = try game.endTurn()

        XCTAssertTrue(turn.turnsExhausted)
        XCTAssertFalse(turn.puzzleFailed)
        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false)
        XCTAssertNil(game.run.outcome)
        XCTAssertFalse(game.claimRewardedRescue())
    }

    func testFullBoardBelowTargetFailsWithoutRescueEvenOnLastTurn() throws {
        var game = try startedGame()
        game.run.puzzle?.target = 100_000
        let originalLimit = try XCTUnwrap(game.puzzle?.turnsMax)
        game.run.puzzle?.turnNumber = originalLimit
        let last = try XCTUnwrap(game.puzzle?.board.blanks.last)
        try fillWithoutScoring(&game, leaving: last)
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: last))
        let handIndex = try XCTUnwrap(game.stackHand(with: digit))

        _ = try game.place(handIndex: handIndex, at: last)

        XCTAssertEqual(game.puzzle?.board.isFull, true)
        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertEqual(game.run.outcome, .failed)
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false)
        XCTAssertFalse(game.claimRewardedRescue())
        try assertConservation(game)
    }

    func testTimerFailureDoesNotOfferRescue() throws {
        var game = try startedGame(boss: .tikTak)
        let originalLimit = game.puzzle?.turnsMax

        game.failPuzzle()

        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertEqual(game.run.outcome, .failed)
        XCTAssertEqual(game.puzzle?.rewardedRescueUsed, false)
        XCTAssertFalse(game.claimRewardedRescue())
        XCTAssertFalse(game.declineRewardedRescue())
        XCTAssertEqual(game.puzzle?.turnsMax, originalLimit)
    }

    func testPendingOfferSurvivesSaveAndRestoresClaimability() throws {
        let pending = try pendingGame()
        var restored = try Game(decoding: pending.encoded())

        XCTAssertEqual(restored.puzzle?.phase, .outOfTurns)
        XCTAssertEqual(restored.puzzle?.rewardedRescueUsed, false)
        XCTAssertEqual(restored.puzzle?.turnsRemaining, 0)
        XCTAssertNil(restored.run.outcome)
        XCTAssertFalse(restored.isOver)
        XCTAssertTrue(restored.canClaimRewardedRescue)
        XCTAssertEqual(restored.puzzle?.hand, pending.puzzle?.hand)
        XCTAssertEqual(restored.puzzle?.board.placed, pending.puzzle?.board.placed)
        XCTAssertEqual(restored.run.streams.pool.state, pending.run.streams.pool.state)
        XCTAssertTrue(restored.claimRewardedRescue())
        XCTAssertEqual(restored.puzzle?.turnsRemaining, 3)
        XCTAssertFalse(restored.canClaimRewardedRescue)
        try assertConservation(restored)
    }

    func testUsedRescueSurvivesSaveAndCannotBeGrantedAgain() throws {
        var game = try pendingGame()
        XCTAssertTrue(game.claimRewardedRescue())
        var restored = try Game(decoding: game.encoded())

        XCTAssertEqual(restored.puzzle?.rewardedRescueUsed, true)
        XCTAssertFalse(restored.canClaimRewardedRescue)
        XCTAssertEqual(restored.puzzle?.turnsRemaining, 3)
        XCTAssertFalse(restored.claimRewardedRescue())
        try exhaustCurrentBudget(&restored)
        XCTAssertEqual(restored.puzzle?.phase, .failed)
        XCTAssertEqual(restored.run.outcome, .failed)
        XCTAssertFalse(restored.claimRewardedRescue())
    }

    func testLegacySaveWithoutRescueFieldDefaultsToUnused() throws {
        let original = try startedGame()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(object["puzzle"] as? [String: Any])
        puzzle.removeValue(forKey: "rewardedRescueUsed")
        object["puzzle"] = puzzle
        let legacy = try JSONSerialization.data(withJSONObject: object, options: .sortedKeys)
        var restored = try Game(decoding: legacy)

        XCTAssertEqual(restored.puzzle?.rewardedRescueUsed, false)
        XCTAssertEqual(restored.puzzle?.phase, .playing)
        XCTAssertEqual(restored.puzzle?.board.placed, original.puzzle?.board.placed)
        XCTAssertEqual(restored.puzzle?.hand, original.puzzle?.hand)
        XCTAssertEqual(restored.run.streams.pool.state, original.run.streams.pool.state)
        try exhaustCurrentBudget(&restored)
        XCTAssertEqual(restored.puzzle?.phase, .outOfTurns)
        XCTAssertTrue(restored.claimRewardedRescue())
        XCTAssertEqual(restored.puzzle?.turnsRemaining, 3)
    }

    // MARK: - Deterministic fixtures

    private func startedGame(book: Book = .probably, obstacle: Obstacle = .none,
                             boss: BossModifier? = nil, extraTurnItems: Bool = false) throws -> Game {
        var game = Game(seed: "rewarded-rescue", book: book, obstacle: obstacle)
        if let boss {
            game.run.slot = .boss
            game.run.pendingBoss = boss
        }
        if extraTurnItems {
            game.give(ad: Bookmarks.lateCityFinal)
            game.run.subscriptions.append(OwnedSubscription(defID: Subscriptions.weekendEdition, pricePaid: 0))
        }
        try game.startPuzzle()
        return game
    }

    private func pendingGame() throws -> Game {
        var game = try startedGame()
        try exhaustCurrentBudget(&game)
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns)
        return game
    }

    private func exhaustCurrentBudget(_ game: inout Game) throws {
        // Jump only the counter: production endTurn still banks, refills and
        // advances deterministic restrictions before deciding the outcome.
        let limit = try XCTUnwrap(game.puzzle?.turnsMax)
        game.run.puzzle?.turnNumber = limit
        _ = try game.endTurn()
    }

    private func fillWithoutScoring(_ game: inout Game, leaving last: Square? = nil) throws {
        var puzzle = try XCTUnwrap(game.puzzle)
        for square in puzzle.board.blanks where square != last {
            let digit = puzzle.board.correctDigit(at: square)
            if !puzzle.pool.take(digit) {
                let index = try XCTUnwrap(puzzle.hand.firstIndex(of: digit))
                puzzle.hand.remove(at: index)
            }
            puzzle.board.fill(square, with: digit, by: .player)
        }
        game.run.puzzle = puzzle
        try assertConservation(game)
    }

    private func assertConservation(_ game: Game, file: StaticString = #filePath, line: UInt = #line) throws {
        let puzzle = try XCTUnwrap(game.puzzle, file: file, line: line)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand),
                     file: file, line: line)
    }
}
