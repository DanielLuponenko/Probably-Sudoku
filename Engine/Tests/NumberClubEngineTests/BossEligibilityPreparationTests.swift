import XCTest
@testable import ProbablySudokuEngine

final class BossEligibilityPreparationTests: XCTestCase {
    private func richRun(markers: Bool = true) -> RunState {
        var run = RunState(seed: "lazy-boss-layout-proof", book: .noPressure)
        run.bossRosterVersion = 1 // This suite verifies the frozen legacy pool.
        run.level = 2
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.localGossip, boughtAtLevel: 1, pricePaid: 0),
                         OwnedBookmark(defID: Bookmarks.crosswordDaily, boughtAtLevel: 1, pricePaid: 0)]
        run.buffs = [OwnedBuff(defID: Buffs.insurance, pricePaid: 0), OwnedBuff(defID: Buffs.luckyDip, pricePaid: 0)]
        if markers {
            run.markers = [OwnedMarker(defID: Markers.crimson, boughtAtLevel: 1, pricePaid: 0,
                                      squares: [Square(0), Square(40)])]
        }
        return run
    }

    /// Visible givens vary, but every fixture has the requested exact number
    /// of givens and a conserved public digit layout. Eligibility never needs
    /// this test-only solution to make a placement correctness decision.
    private func board(givens: Int, coverMarker: Bool) -> GeneratedPuzzle {
        let solution = (0..<81).map { Digit(($0 / 9 * 3 + $0 / 27 + $0 % 9) % 9 + 1)! }
        var indices = Array(0..<81).filter { $0 != 0 && $0 != 40 }
        if coverMarker { indices.insert(0, at: 0) }
        let given = Set(indices.prefix(givens))
        return GeneratedPuzzle(solution: solution, isGiven: (0..<81).map(given.contains))
    }

    private func advance(_ stream: inout RandomStream, for difficulty: Difficulty) {
        let count = difficulty == .easy ? 1 : difficulty == .medium ? 3 : 5
        for _ in 0..<count { _ = stream.next() }
    }

    private func allBossInputs(_ run: RunState, slots: [PuzzleSlot]) -> [UInt32] {
        var paths = [run.streams.board]
        for slot in slots {
            let played = paths.map { original in
                var next = original
                advance(&next, for: slot.difficulty)
                return next
            }
            paths += played
        }
        return paths.map(\.state)
    }

    func testUnconditionalOpeningEffectsAndRepeatedLocalBonusNeedNoLayoutGeneration() throws {
        var run = richRun(markers: false)
        let before = try Game(run: run).encoded()
        var calls = 0
        let actual = BossEligibility.candidates(run: run) { _, _, givens in
            calls += 1
            return self.board(givens: givens, coverMarker: false)
        }
        XCTAssertEqual(calls, 0)
        let layouts = [false, true].map { Board(board(givens: run.book.givens(for: .boss), coverMarker: $0)) }
        let expected = BossModifier.legacyRegularBosses.filter { boss in
            !boss.isExpanded || layouts.allSatisfy { BossEligibility.isEligible(boss, run: run, board: $0) }
        }
        XCTAssertEqual(actual, expected, "Fast proofs must keep the existing catalogue order and exact eligibility")
        XCTAssertEqual(try Game(run: run).encoded(), before)
        var expectedStream = run.streams.boss
        let expectedRoll = expected[expectedStream.int(expected.count)]
        let oldStreams = run.streams
        XCTAssertEqual(BossEligibility.roll(run: &run), expectedRoll)
        XCTAssertEqual(run.streams.boss.state, expectedStream.state)
        XCTAssertEqual(run.streams.board.state, oldStreams.board.state)
        XCTAssertEqual(run.streams.pool.state, oldStreams.pool.state)
        XCTAssertEqual(run.streams.shop.state, oldStreams.shop.state)
    }

    func testRejectingLastLayoutDependentCandidateStopsBeforeAnyOrdinaryPredecessorGeneration() throws {
        let run = richRun()
        let before = try Game(run: run).encoded()
        var difficulties: [Difficulty] = []
        let actual = BossEligibility.candidates(run: run) { stream, difficulty, givens in
            difficulties.append(difficulty)
            self.advance(&stream, for: difficulty)
            return self.board(givens: givens, coverMarker: true)
        }
        XCTAssertEqual(difficulties, [.boss], "One disqualifying board settles Dry Press for every future route")
        XCTAssertFalse(actual.contains(.dryPress))
        XCTAssertTrue(actual.contains(.wordCount))
        XCTAssertTrue(actual.contains(.embargo))
        XCTAssertTrue(actual.contains(.royaltyContract))
        XCTAssertEqual(try Game(run: run).encoded(), before)
    }

    func testAllFourFutureRoutesAreCheckedAndLastRouteCanDisqualifyTheBoss() throws {
        let run = richRun()
        let expectedInputs = allBossInputs(run, slots: [.easy, .medium])
        let lastInput = try XCTUnwrap(expectedInputs.last)
        var bossInputs: [UInt32] = []
        var ordinary: [Difficulty] = []
        let before = try Game(run: run).encoded()
        let actual = BossEligibility.candidates(run: run) { stream, difficulty, givens in
            let source = stream.state
            if difficulty == .boss { bossInputs.append(source) }
            else { ordinary.append(difficulty) }
            self.advance(&stream, for: difficulty)
            return self.board(givens: givens, coverMarker: difficulty == .boss && source == lastInput)
        }
        XCTAssertEqual(bossInputs, expectedInputs, "Check skip/skip, play/skip, skip/play and play/play in unchanged order")
        XCTAssertEqual(ordinary.filter { $0 == .easy }.count, 1, "Shared route prefixes are solved once")
        XCTAssertEqual(ordinary.filter { $0 == .medium }.count, 2)
        let layouts = expectedInputs.map { Board(board(givens: run.book.givens(for: .boss), coverMarker: $0 == lastInput)) }
        let expected = BossModifier.legacyRegularBosses.filter { boss in
            !boss.isExpanded || layouts.allSatisfy { BossEligibility.isEligible(boss, run: run, board: $0) }
        }
        XCTAssertEqual(actual, expected)
        XCTAssertFalse(actual.contains(.dryPress))
        XCTAssertEqual(try Game(run: run).encoded(), before)
    }

    func testQualifyingLayoutsKeepEveryRemainingRouteAndNeverAdvanceTheSavedStreams() throws {
        for (slot, remaining) in [(PuzzleSlot.easy, [PuzzleSlot.easy, .medium]),
                                  (.medium, [.medium]), (.boss, [])] {
            var run = richRun()
            run.slot = slot
            let expectedInputs = allBossInputs(run, slots: remaining)
            let before = try Game(run: run).encoded()
            var inputs: [UInt32] = []
            let actual = BossEligibility.candidates(run: run) { stream, difficulty, givens in
                if difficulty == .boss { inputs.append(stream.state) }
                self.advance(&stream, for: difficulty)
                return self.board(givens: givens, coverMarker: false)
            }
            XCTAssertEqual(inputs, expectedInputs)
            XCTAssertTrue(actual.contains(.dryPress))
            XCTAssertEqual(try Game(run: run).encoded(), before)
        }
    }

    func testGeneratorFailureCannotApproveAnUnverifiedPositionalBoss() {
        let run = richRun()
        let actual = BossEligibility.candidates(run: run) { _, difficulty, _ in
            throw EngineError.generationFailed(difficulty: difficulty, attempts: 200)
        }
        XCTAssertFalse(actual.contains(.dryPress))
        XCTAssertTrue(actual.contains(.embargo), "An unarmed Insurance is legal on every fresh nonempty layout")
        XCTAssertTrue(actual.contains(.publicist), "Local Gossip's repeated flat effect has no positional requirement")
    }

    func testFiniteAndConditionalOpeningBuffsAreNotPromotedByUnconditionalProofs() {
        var run = richRun(markers: false)
        run.bookmarks = []
        run.buffs = [OwnedBuff(defID: Buffs.birdSeed, pricePaid: 0)]
        run.runItemState[Buffs.birdSeed] = Double(run.level)
        let actual = BossEligibility.candidates(run: run) { stream, difficulty, givens in
            self.advance(&stream, for: difficulty)
            return self.board(givens: givens, coverMarker: false)
        }
        XCTAssertFalse(actual.contains(.embargo))
        XCTAssertFalse(actual.contains(.royaltyContract))
        run.buffs = [OwnedBuff(defID: Buffs.rainCheck, pricePaid: 0)]
        let reactive = BossEligibility.candidates(run: run) { stream, difficulty, givens in
            self.advance(&stream, for: difficulty)
            return self.board(givens: givens, coverMarker: false)
        }
        XCTAssertFalse(reactive.contains(.royaltyContract), "A fresh puzzle has no earned Points to fund Rain Check")
    }
}
