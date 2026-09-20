import XCTest
@testable import ProbablySudokuEngine

/// QA selectors must exercise the same encounter thresholds as the app and
/// must not lose real tokens when an animation review changes boss mid-turn.
final class BossEncounterQATests: XCTestCase {
    private func playing(_ boss: BossModifier) throws -> Game {
        var game = Game(seed: "boss-qa-conserved-switch")
        game.run.slot = .boss
        game.run.pendingBoss = boss
        try game.startPuzzle()
        return game
    }

    func testSwitchingBossReturnsTheExactPledgedCopy() throws {
        var game = try playing(.collateral)
        let card = try XCTUnwrap(game.puzzle?.handCards.first)
        XCTAssertTrue(game.pledgeBossCard(cardID: card.id))
        game.qaSetBoss(.bookends)
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertNil(puzzle.bossState.encounter.pledgedCard)
        XCTAssertEqual(puzzle.handCards.filter { $0.id == card.id }, [card])
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
    }

    func testQAStandingLimitsAndWinUseLastEditionsActualBank() throws {
        var game = try playing(.bookends)
        game.qaSetBoss(.lastEdition)
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(puzzle.target, BossEncounterRules.startingTarget(base: game.run.target, boss: .lastEdition))
        XCTAssertEqual(puzzle.turnsMax, 1)
        XCTAssertEqual(puzzle.handSize, game.run.effectiveHandSize(boss: .lastEdition))
        game.qaMeetTarget()
        XCTAssertEqual(game.puzzle?.bossState.encounter.banksUsed, 1)
        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertFalse(try XCTUnwrap(game.puzzle).canKeepFilling)
        XCTAssertNoThrow(try game.cashOut())
    }

    func testQATargetPopulatesBothSplitLedgers() throws {
        var game = try playing(.splitEdition)
        game.qaMeetTarget()
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertTrue(BossEncounterRules.targetSatisfied(puzzle: puzzle))
        XCTAssertEqual(puzzle.bossState.encounter.editionScores, BossEncounterRules.editionTargets(puzzle: puzzle))
        XCTAssertEqual(puzzle.phase, .won)
        XCTAssertNoThrow(try game.cashOut())
    }

    func testQAFullFillConsumesHeldPledgeWithoutLosingConservation() throws {
        var game = try playing(.collateral)
        XCTAssertTrue(game.pledgeBossCard(cardID: try XCTUnwrap(game.puzzle?.handCards.first?.id)))
        game.qaFillBoard()
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertTrue(puzzle.board.isFull)
        XCTAssertNil(puzzle.bossState.encounter.pledgedCard)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
    }
    func testHistoricalScoreAboveAwardCeilingStillPaysWrongPlacementPenalty() throws {
        var game = try playing(.returnSlip)
        game.run.puzzle?.score = ScoreMath.ceiling + 1_000
        let before = try XCTUnwrap(game.puzzle)
        let digit = try XCTUnwrap(before.hand.first)
        let wrong = try XCTUnwrap(before.board.blanks.first { before.board.correctDigit(at: $0) != digit })
        let outcome = try game.place(handIndex: 0, at: wrong)
        XCTAssertFalse(outcome.correct)
        XCTAssertEqual(game.puzzle?.score, before.score - outcome.penalty)
    }

    func testLastEditionEscapementCannotIncreaseItsDisplayedTurnBudget() throws {
        var game = try playing(.lastEdition)
        let puzzle = try XCTUnwrap(game.puzzle)
        let digit = try XCTUnwrap(puzzle.hand.first)
        let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) == digit })
        game.run.markers = [OwnedMarker(defID: Markers.escapement, boughtAtLevel: 1,
            pricePaid: 0, squares: [square])]
        game.run.markerState.escapementProgress = 2
        MarkerRuntime.synchronizeOwnership(run: &game.run)
        _ = try game.place(handIndex: 0, at: square)
        XCTAssertEqual(game.puzzle?.turnsMax, 1)
        XCTAssertEqual(game.run.markerState.escapementProgress, 2, "A disabled extra Turn does not consume saved progress")
    }

    func testSellingAnItemLocksPreparationChoicesForBothNewBosses() throws {
        for boss in [BossModifier.collateral, .splitEdition] {
            var game = try playing(boss)
            game.qaGrantBuff(Buffs.insurance)
            _ = try game.sell(kind: .buff, index: 0)
            XCTAssertTrue(try XCTUnwrap(game.puzzle).bossState.encounter.turnCommitted)
            XCTAssertFalse(game.chooseBossEdition(1))
            XCTAssertFalse(game.pledgeBossCard(cardID: try XCTUnwrap(game.puzzle?.handCards.first?.id)))
        }
    }

    func testHistoricalWonSaveKeepsItsAlreadyEarnedCashOut() throws {
        var game = try playing(.bookends)
        game.run.bossRosterVersion = 1
        game.run.puzzle?.phase = .won
        game = try Game(decoding: game.encoded())
        XCTAssertTrue(try XCTUnwrap(game.puzzle).canKeepFilling)
        XCTAssertNoThrow(try game.cashOut())
        XCTAssertThrowsError(try game.cashOut())
    }

}
