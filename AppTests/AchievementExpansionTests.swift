import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

/// Rules are exercised with in-memory engine outcomes. No profile singleton,
/// player save, cloud write or Apple report is touched by this suite.
@MainActor
final class AchievementExpansionTests: XCTestCase {
    func testCatalogAddsTwelveUniqueAwardsAndKeepsTheRegisteredNineteen() {
        XCTAssertEqual(AchievementCatalog.all.count, 31)
        XCTAssertEqual(Set(AchievementCatalog.all.map(\.id)).count, 31)
        XCTAssertEqual(AchievementCatalog.all.filter(\.isRegisteredWithGameCenter).count, 19)
        XCTAssertEqual(AchievementCatalog.all.filter { !$0.isRegisteredWithGameCenter }.count, 12)
        XCTAssertTrue(AchievementCatalog.all.allSatisfy { !$0.title.isEmpty && !$0.detail.isEmpty })
    }

    func testPaperworkDescribesAnAvailableCoinPurchaseWithoutChangingItsIdentity() throws {
        let definition = try XCTUnwrap(AchievementCatalog.definition(for: "buy-subscription"))
        XCTAssertEqual(definition.title, "Paperwork")
        XCTAssertEqual(definition.detail, "Buy a Bookmark with coins in the Shop.")
        XCTAssertEqual(definition.gameCenterID, "com.numberclub.app.achievement.buy_subscription")
        XCTAssertTrue(definition.isRegisteredWithGameCenter)
        XCTAssertFalse(AchievementCatalog.all.contains { $0.detail.localizedCaseInsensitiveContains("subscription") })

        var run = RunState(seed: "paperwork-live-shop")
        run.coins = 50
        Shop.open(&run)
        let offer = try XCTUnwrap(run.shop?.offers.first { $0.def.kind == .bookmark })
        let before = run.coins
        try Shop.buy(&run, slot: offer.slot)
        XCTAssertEqual(run.coins, before - offer.price)
        XCTAssertTrue(AchievementRules.purchase(kind: offer.def.kind, bookmarkCount: run.bookmarks.count)
            .contains("buy-subscription"))
    }

    func testLegacySubscriptionKindAndOtherPurchasesDoNotAwardPaperwork() {
        for kind in [ItemKind.subscription, .buff, .marker] {
            XCTAssertFalse(AchievementRules.purchase(kind: kind, bookmarkCount: 0).contains("buy-subscription"))
        }
        XCTAssertEqual(AchievementRules.purchase(kind: .marker, bookmarkCount: 0), ["buy-marker"])
        XCTAssertEqual(AchievementRules.purchase(kind: .buff, bookmarkCount: 4), [])
        XCTAssertTrue(AchievementRules.purchase(kind: .bookmark, bookmarkCount: 5).contains("five-bookmarks"))
    }

    func testCorrectPlacementAwardsInkHappensAndWrongPlacementAwardsNothing() throws {
        var game = try freshGame()
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let wrongIndex = try XCTUnwrap(game.puzzle?.hand.firstIndex { $0 != digit })
        let wrong = try game.place(handIndex: wrongIndex, at: square)
        XCTAssertFalse(wrong.correct)
        XCTAssertTrue(AchievementRules.placement(wrong, duringKeepFilling: false).isEmpty)
        let correct = try placeCorrect(&game, at: square)
        XCTAssertTrue(AchievementRules.placement(correct, duringKeepFilling: false).contains("first-correct-placement"))
    }

    func testSingleRowCompletionDoesNotAwardDoubleOrTripleClear() throws {
        var game = try freshGame()
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let square = try XCTUnwrap(blanks.first { target in
            blanks.contains { $0.col == target.col && $0.row != target.row }
                && blanks.contains { $0.box == target.box && $0.row != target.row }
        })
        for other in blanks where other.row == square.row && other != square {
            try fillForSetup(&game, at: other)
        }
        let outcome = try placeCorrect(&game, at: square)
        XCTAssertEqual(outcome.lineClears, [.row])
        let awards = AchievementRules.placement(outcome, duringKeepFilling: false)
        XCTAssertTrue(awards.contains("first-line-clear"))
        XCTAssertFalse(awards.contains("double-clear"))
        XCTAssertFalse(awards.contains("three-way-clear"))
    }

    func testDoubleClearUsesTwoDistinctUnitTypes() throws {
        var game = try freshGame()
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let square = try XCTUnwrap(blanks.first { target in
            blanks.contains { $0.box == target.box && $0.row != target.row && $0.col != target.col }
        })
        for other in blanks where (other.row == square.row || other.col == square.col) && other != square {
            try fillForSetup(&game, at: other)
        }
        var outcome = try placeCorrect(&game, at: square)
        XCTAssertEqual(Set(outcome.lineClears), [.row, .col])
        XCTAssertTrue(AchievementRules.placement(outcome, duringKeepFilling: false).contains("double-clear"))
        XCTAssertFalse(AchievementRules.placement(outcome, duringKeepFilling: false).contains("three-way-clear"))

        outcome.lineClears = [.row, .row]
        XCTAssertFalse(AchievementRules.placement(outcome, duringKeepFilling: false).contains("double-clear"),
                       "Repeated presentation of one unit must not become a compound clear.")
    }

    func testFullClearRetainsExistingAwardsAlongsideNewClearAwards() throws {
        var game = try freshGame()
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let last = try XCTUnwrap(blanks.last)
        for square in blanks.dropLast() { try fillForSetup(&game, at: square) }
        let outcome = try placeCorrect(&game, at: last)
        XCTAssertTrue(outcome.fullClear)
        XCTAssertEqual(AchievementRules.placement(outcome, duringKeepFilling: true),
                       ["first-correct-placement", "first-line-clear", "double-clear", "three-way-clear",
                        "full-clear", "keep-filling-full-clear"])
        XCTAssertFalse(AchievementRules.placement(outcome, duringKeepFilling: false)
            .contains("keep-filling-full-clear"))
    }

    func testDirectClueFullClearUsesThePhaseBeforeTheEngineFinishesKeepFilling() throws {
        var game = Game(seed: "achievement-keep-filling-clue", book: .noPressure)
        try game.startPuzzle()
        game.qaMeetTarget()
        try game.keepFilling()
        let blanks = try XCTUnwrap(game.puzzle?.board.blanks)
        let last = try XCTUnwrap(blanks.last)
        for square in blanks.dropLast() { try fillForSetup(&game, at: square) }
        let wasKeepingFilling = game.puzzle?.phase == .keepFilling
        let outcome = try game.useClue(at: last)

        XCTAssertTrue(wasKeepingFilling)
        XCTAssertTrue(outcome.fullClear)
        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertTrue(AchievementRules.placement(outcome, duringKeepFilling: wasKeepingFilling)
            .contains("keep-filling-full-clear"))
    }

    func testHalfMillionAndOriginalScoreThresholdsAreInclusive() {
        XCTAssertFalse(finish(score: 99_999).contains("hundred-thousand"))
        XCTAssertTrue(finish(score: 100_000).contains("hundred-thousand"))
        XCTAssertFalse(finish(score: 499_999).contains("half-million"))
        XCTAssertTrue(finish(score: 500_000).contains("half-million"))
    }

    func testDoubleTargetUsesExactRatioAndCannotOverflow() {
        XCTAssertFalse(finish(score: 2_999, target: 1_500).contains("double-target"))
        XCTAssertTrue(finish(score: 3_000, target: 1_500).contains("double-target"))
        XCTAssertTrue(finish(score: Int.max, target: 1).contains("double-target"))
        XCTAssertFalse(finish(score: Int.max, target: Int.max).contains("double-target"))
    }

    func testNoAwardsComeFromAnUnwonOrInvalidPuzzle() {
        XCTAssertTrue(finish(score: 1_499, target: 1_500).isEmpty)
        XCTAssertTrue(finish(score: 100_000, target: 0).isEmpty)
        XCTAssertTrue(finish(score: 100_000, target: -1).isEmpty)
    }

    func testAheadOfScheduleAndLastTurnDoNotOverlap() {
        XCTAssertFalse(finish(turns: 4).contains("five-turns-spare"))
        XCTAssertTrue(finish(turns: 5).contains("five-turns-spare"))
        XCTAssertFalse(finish(turns: 1).contains("last-turn-win"))
        XCTAssertTrue(finish(turns: 0).contains("last-turn-win"))
        XCTAssertFalse(finish(turns: -1).contains("last-turn-win"))
        XCTAssertFalse(finish(turns: 5).contains("last-turn-win"))
    }

    func testRealWinningEndTurnAndCashOutUseThePostBankingTurnCount() throws {
        for spareTurns in [0, 1, 4, 5] {
            var game = try freshGame()
            let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
            _ = try placeCorrect(&game, at: square)
            var run = game.run
            var puzzle = try XCTUnwrap(run.puzzle)
            XCTAssertGreaterThan(puzzle.pendingScore, 0)
            // Isolated fixture: this genuine queued placement reaches target
            // when banked on the selected Turn. No player state is touched.
            puzzle.score = puzzle.target - puzzle.pendingScore
            puzzle.turnNumber = puzzle.turnsMax - spareTurns
            run.puzzle = puzzle
            game = Game(run: run)

            _ = try game.endTurn()
            let won = try XCTUnwrap(game.puzzle)
            XCTAssertEqual(won.phase, .won)
            XCTAssertEqual(won.turnsRemaining, spareTurns)
            _ = try game.cashOut()
            XCTAssertEqual(game.puzzle?.phase, .cashedOut)
            let awards = AchievementRules.puzzleFinished(
                score: won.score, target: won.target, wasBoss: won.isBoss,
                hadWrongPlacement: false, usedClue: false,
                tossesUsed: won.tossedThisPuzzle, turnsRemaining: won.turnsRemaining)
            XCTAssertEqual(awards.contains("last-turn-win"), spareTurns == 0)
            XCTAssertEqual(awards.contains("five-turns-spare"), spareTurns >= 5)
        }
    }

    func testNoOutsideHelpRequiresAllThreeConditions() {
        XCTAssertTrue(finish().contains("no-outside-help"))
        XCTAssertFalse(finish(wrong: true).contains("no-outside-help"))
        XCTAssertFalse(finish(clue: true).contains("no-outside-help"))
        XCTAssertFalse(finish(tosses: 1).contains("no-outside-help"))
        XCTAssertFalse(finish(tosses: -1).contains("no-outside-help"))
    }

    func testResumedPuzzleKeepsProvableAwardsButDoesNotInventCleanHistory() {
        let awards = finish(score: 500_000, turns: 5, completeHistory: false)
        XCTAssertTrue(awards.isSuperset(of: ["half-million", "hundred-thousand", "double-target", "five-turns-spare"]))
        XCTAssertFalse(awards.contains("flawless-boss"))
        XCTAssertFalse(awards.contains("no-clue"))
        XCTAssertFalse(awards.contains("no-outside-help"))
    }

    func testBossThresholdsAndDuplicateEncounterIdentity() {
        XCTAssertTrue(AchievementRules.bossesDefeated(0).isEmpty)
        XCTAssertEqual(AchievementRules.bossesDefeated(1), ["first-boss"])
        XCTAssertEqual(AchievementRules.bossesDefeated(9), ["first-boss"])
        XCTAssertEqual(AchievementRules.bossesDefeated(10), ["first-boss", "beat-ten-bosses"])
        var progress = AchievementProgress()
        for _ in 0..<20 { progress.completedBossEncounterIDs.insert("one-run:1:boss") }
        XCTAssertEqual(AchievementRules.bossesDefeated(progress.completedBossEncounterIDs.count), ["first-boss"])
    }

    func testThreeBooksCountsDistinctKnownVolumesNotUnknownIDsOrRepeatObstacles() {
        var progress = AchievementProgress()
        progress.completedBookVolumes = [999]
        for obstacle in Obstacle.allCases { progress.recordBookCompleted(.probably, obstacle: obstacle) }
        progress.recordBookCompleted(.genuinely, obstacle: .none)
        XCTAssertFalse(AchievementRules.bookCompleted(progress: progress, obstacle: .none).contains("finish-three-books"))
        progress.recordBookCompleted(.smallVictories, obstacle: .none)
        XCTAssertTrue(AchievementRules.bookCompleted(progress: progress, obstacle: .none).contains("finish-three-books"))
    }

    func testHardestObstacleAwardOnlyFiresForTheActualNinthObstacle() {
        var progress = AchievementProgress()
        progress.recordBookCompleted(.probably, obstacle: .finalEdition)
        for obstacle in Obstacle.allCases {
            let awards = AchievementRules.bookCompleted(progress: progress, obstacle: obstacle)
            XCTAssertEqual(awards.contains("obstacle-nine-book"), obstacle == .finalEdition)
            XCTAssertEqual(awards.contains("obstacle-three-book"), obstacle == .shortHandedAndBlocked)
        }
    }

    func testOldPaperworkAndNewAwardsSurviveDecodeAndRepeatedCloudMerge() throws {
        let old = try JSONDecoder().decode(PlayerProfile.self,
            from: Data(#"{"earnedAchievementIDs":["buy-subscription"]}"#.utf8))
        var local = old
        local.earnedAchievementIDs.formUnion(["first-boss", "no-outside-help"])
        var remote = PlayerProfile()
        remote.merge(remote: local)
        remote.merge(remote: old)
        remote.merge(remote: local)
        let restored = try JSONDecoder().decode(PlayerProfile.self, from: JSONEncoder().encode(remote))
        XCTAssertEqual(restored.earnedAchievementIDs, ["buy-subscription", "first-boss", "no-outside-help"])
    }

    private func finish(score: Int = 1_500, target: Int = 1_500, wrong: Bool = false,
                        clue: Bool = false, tosses: Int = 0, turns: Int = 3,
                        completeHistory: Bool = true) -> Set<String> {
        AchievementRules.puzzleFinished(score: score, target: target, wasBoss: true,
                                        hadWrongPlacement: wrong, usedClue: clue,
                                        tossesUsed: tosses, turnsRemaining: turns,
                                        hasCompleteHistory: completeHistory)
    }

    private func freshGame() throws -> Game {
        var game = Game(seed: "achievement-outcome-boundaries")
        try game.startPuzzle()
        return game
    }

    private func fillForSetup(_ game: inout Game, at square: Square) throws {
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        XCTAssertTrue(game.qaPlace(digit: digit, at: square))
    }

    private func placeCorrect(_ game: inout Game, at square: Square) throws -> PlacementOutcome {
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        if game.puzzle?.hand.contains(digit) != true { XCTAssertTrue(game.qaTakeFromPool(digit)) }
        let index = try XCTUnwrap(game.puzzle?.hand.firstIndex(of: digit))
        return try game.place(handIndex: index, at: square)
    }
}
