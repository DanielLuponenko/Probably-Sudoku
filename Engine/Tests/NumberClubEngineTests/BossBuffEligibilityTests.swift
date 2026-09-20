import XCTest
@testable import ProbablySudokuEngine

final class BossBuffEligibilityTests: XCTestCase {
    private func encounter(_ boss: BossModifier) throws -> Game {
        var game = Game(seed: "boss-buff-eligibility")
        game.run.slot = .boss
        game.run.pendingBoss = boss
        try game.startPuzzle()
        return game
    }
    private func give(_ id: String, game: inout Game) -> OwnedBuff {
        let buff = OwnedBuff(defID: id, pricePaid: 0)
        game.run.buffs.append(buff)
        return buff
    }

    func testEmbargoAllowsPreparationBeforeAttemptAndReactiveUseAfterward() throws {
        var game = try encounter(.embargo)
        let paper = give(Buffs.paperCrane, game: &game)
        let before = try game.encoded()
        _ = try game.beginBuff(id: paper.id)
        let decision = try XCTUnwrap(game.run.pendingItemDecisions.first)
        XCTAssertTrue(try game.resolveItemDecision(id: decision.id, selected: nil))
        // Decision serial advances, but cancellation leaves every resource and
        // the boss window intact. It must not count as a placement attempt.
        XCTAssertFalse(game.puzzle!.bossState.placementStarted)
        XCTAssertEqual(game.run.buffs.map(\.id), [paper.id])
        XCTAssertEqual(game.puzzle!.handCards, try Game(decoding: before).puzzle!.handCards)
        let p = try XCTUnwrap(game.puzzle)
        let square = try XCTUnwrap(p.board.blanks.first { p.board.correctDigit(at: $0) != p.hand[0] })
        _ = try game.place(handIndex: 0, at: square)
        XCTAssertTrue(game.puzzle!.bossState.placementStarted)
        XCTAssertFalse(BuffRuntime.canUse(buffID: paper.id, run: game.run))
        let stable = try game.encoded()
        XCTAssertThrowsError(try game.beginBuff(id: paper.id))
        XCTAssertEqual(try game.encoded(), stable)
        game.run.puzzle?.pendingBase = 50
        BuffRuntime.recordPoints(id: "fixture.earned", points: 50, eligible: true, originalPlacement: true,
                                 puzzle: &game.run.puzzle!)
        let rain = give(Buffs.rainCheck, game: &game)
        XCTAssertTrue(BuffRuntime.canUse(buffID: rain.id, run: game.run))
        _ = try game.endTurn()
        XCTAssertFalse(game.puzzle!.bossState.placementStarted)
        XCTAssertTrue(BuffRuntime.canUse(buffID: paper.id, run: game.run))
    }

    func testRejectedAttemptAndTossDoNotCloseEmbargo() throws {
        var game = try encounter(.embargo)
        let given = try XCTUnwrap(Square.all.first { !game.puzzle!.board.isBlank($0) })
        let before = try game.encoded()
        XCTAssertThrowsError(try game.place(handIndex: 0, at: given))
        XCTAssertEqual(try game.encoded(), before)
        _ = try game.toss(handIndex: 0)
        XCTAssertFalse(game.puzzle!.bossState.placementStarted)
        let allowed = give(Buffs.insurance, game: &game)
        XCTAssertTrue(BuffRuntime.canUse(buffID: allowed.id, run: game.run))
    }

    func testEmbargoRestrictsOwnedPreparationButEncoreCanRepeatALegalEffect() throws {
        var game = try encounter(.embargo)
        let insurance = give(Buffs.insurance, game: &game)
        _ = try game.beginBuff(id: insurance.id)
        let p = try XCTUnwrap(game.puzzle)
        let wrong = try XCTUnwrap(p.board.blanks.first { p.board.correctDigit(at: $0) != p.hand[0] })
        _ = try game.place(handIndex: 0, at: wrong)
        XCTAssertTrue(game.puzzle!.bossState.placementStarted)
        XCTAssertFalse(game.puzzle!.armedFlags.contains(.insurance))
        let encore = give(Buffs.carbonReceipt, game: &game)
        let direct = give(Buffs.insurance, game: &game)
        game = try Game(decoding: game.encoded())
        XCTAssertFalse(BuffRuntime.canUse(buffID: direct.id, run: game.run))
        XCTAssertTrue(BuffRuntime.canUse(buffID: encore.id, run: game.run))
        _ = try game.beginBuff(id: encore.id)
        XCTAssertTrue(game.puzzle!.armedFlags.contains(.insurance))
        XCTAssertEqual(game.run.buffs.map(\.id), [direct.id])
        let saved = try game.encoded()
        XCTAssertThrowsError(try game.beginBuff(id: encore.id))
        XCTAssertEqual(try game.encoded(), saved)
        // Generated effects still cannot duplicate an already armed ability.
        game.run.puzzle?.buffState.usedOnce.remove(Buffs.carbonReceipt)
        let another = give(Buffs.carbonReceipt, game: &game)
        XCTAssertFalse(BuffRuntime.canUse(buffID: another.id, run: game.run))
    }

    func testRoyaltyCancelledChoiceCostsNothingThenCountsExactCommitOnce() throws {
        var game = try encounter(.royaltyContract)
        game.run.puzzle?.target = 1001
        game.run.puzzle?.bossState.royaltyStartingTarget = 1001
        let buff = give(Buffs.paperCrane, game: &game)
        XCTAssertEqual(BossBuffRules.targetIncrease(puzzle: game.puzzle), 51)
        _ = try game.beginBuff(id: buff.id)
        var decision = try XCTUnwrap(game.run.pendingItemDecisions.first)
        XCTAssertTrue(decision.detail.contains("51"))
        XCTAssertTrue(try game.resolveItemDecision(id: decision.id, selected: nil))
        XCTAssertEqual(game.puzzle!.target, 1001)
        XCTAssertEqual(game.puzzle!.bossState.royaltyCount, 0)
        _ = try game.beginBuff(id: buff.id)
        game = try Game(decoding: game.encoded())
        decision = try XCTUnwrap(game.run.pendingItemDecisions.first)
        XCTAssertTrue(try game.resolveItemDecision(id: decision.id, selected: [decision.options[0].id]))
        XCTAssertEqual(game.puzzle!.target, 1052)
        XCTAssertEqual(game.puzzle!.bossState.royaltyCount, 1)
        XCTAssertTrue(game.run.buffs.isEmpty)
        let saved = try game.encoded()
        XCTAssertFalse(try game.resolveItemDecision(id: decision.id, selected: [decision.options[0].id]))
        XCTAssertEqual(try game.encoded(), saved)
    }

    func testRoyaltyEncoreCountsOuterCopyOnceAndCapsThreeIncrements() throws {
        var game = try encounter(.royaltyContract)
        let target = game.puzzle!.target
        let increment = BossBuffRules.targetIncrease(puzzle: game.puzzle)
        let lucky = give(Buffs.luckyDip, game: &game)
        _ = try game.beginBuff(id: lucky.id)
        let encore = give(Buffs.carbonReceipt, game: &game)
        _ = try game.beginBuff(id: encore.id)
        XCTAssertEqual(game.puzzle!.bossState.royaltyCount, 2)
        XCTAssertEqual(game.puzzle!.target, target + 2 * increment)
        for _ in 0..<3 {
            let ink = give(Buffs.freshInk, game: &game)
            _ = try game.beginBuff(id: ink.id)
        }
        XCTAssertEqual(game.puzzle!.bossState.royaltyCount, 3)
        XCTAssertEqual(game.puzzle!.target, target + 3 * increment)
        game.run.puzzle?.phase = .keepFilling
        let overtime = give(Buffs.overtime, game: &game)
        _ = try game.beginBuff(id: overtime.id)
        XCTAssertEqual(game.puzzle!.target, target + 3 * increment)
    }

    func testEligibilityIsPureAndRejectsMissingBuildRequirements() throws {
        let run = RunState(seed: "eligibility-streams")
        let before = try Game(run: run).encoded()
        let candidates = BossEligibility.candidates(run: run)
        XCTAssertFalse(candidates.contains(.embargo))
        XCTAssertFalse(candidates.contains(.dryPress))
        XCTAssertFalse(candidates.contains(.publicist))
        XCTAssertFalse(candidates.contains(.wordCount))
        XCTAssertFalse(candidates.contains(.royaltyContract))
        XCTAssertTrue(candidates.contains(.backPage))
        XCTAssertEqual(try Game(run: run).encoded(), before)
        for _ in 0..<5 { XCTAssertEqual(BossEligibility.candidates(run: run), candidates) }
    }

    func testEligibleAnnouncementPersistsThroughInventoryRemovalAndPreparation() throws {
        var run = RunState(seed: "announcement-retained")
        run.bossRosterVersion = 1 // This suite verifies the frozen legacy pool.
        run.slot = .boss
        run.buffs = [OwnedBuff(defID: Buffs.insurance, pricePaid: 0)]
        XCTAssertTrue(BossEligibility.candidates(run: run).contains(.embargo))
        run.pendingBoss = .embargo
        run.buffs = []
        var restored = try Game(decoding: Game(run: run).encoded())
        XCTAssertEqual(restored.run.pendingBoss, .embargo)
        let streams = restored.run.streams
        try restored.startPuzzle()
        XCTAssertEqual(restored.puzzle!.boss, .embargo)
        XCTAssertEqual(restored.run.streams.boss.state, streams.boss.state)
    }

    func testRichBuildPreparationIsDeterministicWithoutChangingAnySavedStream() throws {
        var run = RunState(seed: "rich-boss-preparation", book: .noPressure)
        run.bossRosterVersion = 1 // This suite verifies the frozen legacy pool.
        run.level = 2
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.localGossip, boughtAtLevel: 1, pricePaid: 0),
                         OwnedBookmark(defID: Bookmarks.crosswordDaily, boughtAtLevel: 1, pricePaid: 0)]
        run.buffs = [OwnedBuff(defID: Buffs.insurance, pricePaid: 0),
                     OwnedBuff(defID: Buffs.luckyDip, pricePaid: 0)]
        run.markers = [OwnedMarker(defID: Markers.crimson, boughtAtLevel: 1, pricePaid: 0,
                                   squares: [Square(0), Square(40)])]
        let before = try Game(run: run).encoded()
        let started = Date()
        let candidates = BossEligibility.candidates(run: run)
        print("Rich boss eligibility preparation: \(Date().timeIntervalSince(started)) seconds")
        XCTAssertTrue(candidates.contains(.wordCount))
        XCTAssertTrue(candidates.contains(.embargo))
        XCTAssertTrue(candidates.contains(.royaltyContract))
        XCTAssertEqual(BossEligibility.candidates(run: run), candidates)
        XCTAssertEqual(try Game(run: run).encoded(), before)
    }

    func testFinalEligibilityNeedsActualSourcesAndHandBudget() throws {
        var run = RunState(seed: "final-build-gates", obstacle: .none)
        run.bossRosterVersion = 1 // This suite verifies the frozen legacy pool.
        run.level = 9
        run.slot = .boss
        XCTAssertFalse(BossEligibility.candidates(run: run).contains(.lateCourier))
        XCTAssertFalse(BossEligibility.candidates(run: run).contains(.bindery))
        run.buffs = [OwnedBuff(defID: Buffs.luckyDip, pricePaid: 0)]
        XCTAssertTrue(BossEligibility.candidates(run: run).contains(.lateCourier))
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.opEd, boughtAtLevel: 1, pricePaid: 0),
                         OwnedBookmark(defID: Bookmarks.theSundaySupplement, boughtAtLevel: 1, pricePaid: 0)]
        XCTAssertTrue(BossEligibility.candidates(run: run).contains(.bindery))
        XCTAssertTrue(BossEligibility.candidates(run: run).contains(.pageCutter))
        XCTAssertEqual(run.effectiveTurns(boss: .pageCutter), run.effectiveTurns(boss: nil) + 4)
    }

    func testUnknownBossIDFailsInsteadOfSilentlyReplacingEncounter() {
        XCTAssertThrowsError(try JSONDecoder().decode(BossModifier.self, from: Data("\"futureUnknownBoss\"".utf8)))
    }
}
