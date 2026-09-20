import XCTest
@testable import ProbablySudokuEngine

/// Constants below are worked independently in docs/scoring-v2.md, not derived
/// by calling the production resolver to manufacture an expected result.
final class OrderedScoringTests: XCTestCase {
    private func game(_ bookmarks: [String] = []) throws -> Game {
        var game = Game(seed: "ordered-arithmetic-v2")
        try game.startPuzzle()
        game.run.puzzle?.target = 9_000_000
        for bookmark in bookmarks { game.give(ad: bookmark) }
        return game
    }
    private func place(_ digit: Digit, in game: inout Game) throws -> PlacementOutcome {
        let square = try XCTUnwrap(game.blank(wanting: digit))
        return try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
    }

    func testOrderChangesArithmeticAndLedgerShowsEachRunningMultiplier() throws {
        for (ids, expected, intermediate) in [
            (["bm_op_ed", "bm_stop_the_presses"], 300, [2.0, 6.0]),
            (["bm_stop_the_presses", "bm_op_ed"], 200, [3.0, 4.0])
        ] {
            var game = try game(ids)
            _ = try place(.five, in: &game)
            let preview = try XCTUnwrap(game.puzzle).pendingScoringLedger
            XCTAssertEqual(preview.total, expected)
            XCTAssertEqual(preview.operations.map(\.sourceID), ids)
            XCTAssertEqual(preview.operations.map(\.after.mult), intermediate)
            XCTAssertEqual(preview.operations.map(\.sourceInstanceID), game.run.bookmarks.map { $0.id.uuidString })
            let turn = try game.endTurn()
            XCTAssertEqual(turn.pointsGained, expected)
            XCTAssertEqual(game.puzzle?.score, expected)
            XCTAssertEqual(turn.scoringLedger?.total, expected)
            XCTAssertEqual(game.puzzle?.lastScoringLedger, turn.scoringLedger)
        }
    }

    func testSnapshotLocksSoldAndReorderedItemsUntilNextTurnAcrossResume() throws {
        var game = try game(["bm_op_ed", "bm_stop_the_presses"])
        let opID = game.run.bookmarks[0].id
        _ = try place(.five, in: &game)
        XCTAssertTrue(try XCTUnwrap(game.puzzle).scoringOrderLocked)
        XCTAssertTrue(game.reorderBookmark(id: opID, to: 1))
        XCTAssertEqual(game.puzzle?.pendingScore, 300)
        game = try Game(decoding: game.encoded())
        XCTAssertEqual(game.puzzle?.pendingScore, 300)
        _ = try game.sell(kind: .bookmark, index: 0) // sells Stop after the batch lock
        XCTAssertEqual(game.puzzle?.pendingScore, 300)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 300)
        _ = try place(.five, in: &game)
        XCTAssertEqual(game.puzzle?.pendingScore, 100) // only Op-Ed now
    }

    func testDuplicateBookmarksAndBuffsHaveSeparateSourceIdentities() throws {
        var game = try game(["bm_op_ed", "bm_op_ed"])
        game.give(buff: Buffs.freshInk)
        game.give(buff: Buffs.freshInk)
        let buffIDs = game.run.buffs.map { $0.id.uuidString }
        _ = try game.useBuff(at: 0)
        _ = try game.useBuff(at: 0)
        _ = try place(.five, in: &game)
        let ledger = try XCTUnwrap(game.puzzle).pendingScoringLedger
        XCTAssertEqual(ledger.total, 350) // (1+2+2+1+1)*50
        XCTAssertEqual(ledger.operations.filter { $0.sourceID == Buffs.freshInk }.map(\.sourceInstanceID), buffIDs)
        XCTAssertEqual(Set(ledger.operations.map(\.sourceInstanceID)).count, 4)
        XCTAssertEqual(try Game(decoding: game.encoded()).puzzle?.pendingScoringLedger, ledger)
    }

    func testInkRoseAndSashimiStagesAreExplicit() throws {
        var game = try game(["bm_op_ed", "bm_stop_the_presses"])
        game.give(buff: Buffs.freshInk)
        _ = try game.useBuff(at: 0)
        game.run.puzzle?.boss = .sashimi
        _ = try place(.five, in: &game)
        XCTAssertEqual(game.puzzle?.pendingScore, 300)
        XCTAssertEqual(game.puzzle?.pendingScoringLedger.operations.map(\.after.mult), [3, 4, 12, 6])
        game.run.puzzle?.itemState[Markers.rose] = 1
        XCTAssertEqual(game.puzzle?.pendingScore, 375) // (1+1+2+1)*3/2*50
    }

    func testFractionalMultiplierRoundsOnlyAtBankAndDirectPayoutsRemainFlat() throws {
        var game = try game([Bookmarks.rollingPresses, "bm_morning_edition", "bm_evening_edition"])
        game.run.puzzle?.itemState[Bookmarks.rollingPresses] = 1
        game.run.puzzle?.pendingBase = 45
        game.run.puzzle?.turnNumber = 10
        game.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        let turn = try game.endTurn()
        XCTAssertEqual(turn.multiplier, 1.5)
        XCTAssertEqual(turn.pointsGained, 467) // floor(45*1.5)+100+300
        XCTAssertEqual(turn.scoringLedger?.operations.filter { $0.kind == .directScore }.map(\.amount), [100, 300])
        var second = try self.game([Bookmarks.rollingPresses])
        second.run.puzzle?.itemState[Bookmarks.rollingPresses] = 1
        second.run.puzzle?.pendingBase = 90
        XCTAssertEqual(try second.endTurn().pointsGained, 135)
    }

    func testOldPendingTurnBanksOnceUnchangedThenMovesToVersionTwo() throws {
        var game = try game(["bm_op_ed", "bm_stop_the_presses"])
        game.run.puzzle?.pendingBase = 50
        game.run.puzzle?.pendingMult = 6
        game.run.puzzle?.itemState[Buffs.freshInk] = 2
        game.run.puzzle?.boss = .sashimi
        game.run.puzzle?.score = 123
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(json["puzzle"] as? [String: Any])
        for key in ["scoringVersion", "turnScoringState", "turnScoringOperations", "lastScoringLedger", "scoringBuffSources", "bookmarkState"] { puzzle.removeValue(forKey: key) }
        json["puzzle"] = puzzle
        game = try Game(decoding: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(game.puzzle?.scoringVersion, 1)
        XCTAssertEqual(game.puzzle?.pendingScore, 200) // legacy (6+2)/2*50
        let turn = try game.endTurn()
        XCTAssertEqual(turn.pointsGained, 200)
        XCTAssertEqual(game.puzzle?.score, 323)
        XCTAssertEqual(game.puzzle?.lastScoringLedger?.version, 1)
        game = try Game(decoding: game.encoded())
        XCTAssertEqual(game.puzzle?.score, 323)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        XCTAssertEqual(game.puzzle?.scoringVersion, 2)
        _ = try place(.five, in: &game)
        XCTAssertEqual(game.puzzle?.pendingScore, 300)
    }

    func testPenaltyLedgerDescribesQueueThenBankAndInsurance() throws {
        for insured in [false, true] {
            var game = try game(["bm_stop_the_presses"])
            _ = try place(.eight, in: &game)
            if insured { game.give(buff: "bf_insurance"); _ = try game.useBuff(at: 0) }
            let target = try XCTUnwrap(game.blank(wanting: .two))
            _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .one)), at: target)
            XCTAssertEqual(game.puzzle?.pendingBase, insured ? 80 : 30)
            XCTAssertEqual(game.puzzle?.pendingScore, insured ? 240 : 90)
            let op = try XCTUnwrap(game.puzzle?.turnScoringOperations.last)
            XCTAssertEqual(op.kind, .penalty)
            XCTAssertEqual(op.before.points, 80)
            XCTAssertEqual(op.after.points, insured ? 80 : 30)
        }
    }

    func testZeroedPlacementDoesNotSpendDoubleDownAndOnyxIsPlacementOnly() throws {
        var game = try game()
        game.give(buff: "bf_double_down")
        _ = try game.useBuff(at: 0)
        game.run.puzzle?.boss = .censor
        game.run.puzzle?.censoredDigit = .five
        let censored = try place(.five, in: &game)
        XCTAssertEqual(censored.points, 0)
        XCTAssertTrue(try XCTUnwrap(game.puzzle).armedFlags.contains(.doubleDown))
        XCTAssertTrue(censored.scoreReceipts.flatMap(\.operations).contains { $0.kind == .zero })
        game.run.puzzle?.boss = nil
        let later = try place(.six, in: &game)
        XCTAssertEqual(later.points, 120)
        XCTAssertFalse(try XCTUnwrap(game.puzzle).armedFlags.contains(.doubleDown))
    }

    private func simultaneousClearFixture() throws -> (Game, Square) {
        var game = try game(["bm_finance_pages", "bm_crossword_daily"])
        var puzzle = try XCTUnwrap(game.puzzle)
        let last = try XCTUnwrap(puzzle.board.blanks.first { square in
            let covered = Set(Geometry.rows[square.row] + Geometry.boxes[square.box])
            return Geometry.cols[square.col].contains { !covered.contains($0) && puzzle.board.isBlank($0) }
        })
        for square in Set(Geometry.rows[last.row] + Geometry.boxes[last.box]).sorted(by: { $0.index < $1.index })
            where square != last && puzzle.board.isBlank(square) {
            let digit = puzzle.board.correctDigit(at: square)
            if !puzzle.pool.take(digit) {
                puzzle.hand.remove(at: try XCTUnwrap(puzzle.hand.firstIndex(of: digit)))
            }
            puzzle.board.fill(square, with: digit, by: .player)
        }
        puzzle.assertConservation()
        game.run.puzzle = puzzle
        return (game, last)
    }

    func testSimultaneousClearDoublerIsNotAHookRetriggerAndCoinsAreActualBalances() throws {
        var (game, last) = try simultaneousClearFixture()
        game.give(buff: "bf_second_print")
        _ = try game.useBuff(at: 0)
        let digit = try XCTUnwrap(game.puzzle).board.correctDigit(at: last)
        let index = try XCTUnwrap(game.stackHand(with: digit))
        let coinsBefore = game.run.coins
        let handBefore = try XCTUnwrap(game.puzzle).hand.count
        let outcome = try game.place(handIndex: index, at: last)
        XCTAssertEqual(outcome.lineClears, [.row, .box])
        XCTAssertEqual(outcome.lineClearPoints, [90, 45])
        XCTAssertEqual(game.puzzle?.pendingBase, digit.rawValue * 10 + 135)
        XCTAssertEqual(game.run.coins, coinsBefore + 2)
        XCTAssertEqual(game.puzzle?.hand.count, handBefore - 1 + 2)
        let money = outcome.scoreReceipts.flatMap(\.operations).filter { $0.kind == .coins }
        XCTAssertEqual(money.map(\.before.coins), [coinsBefore, coinsBefore + 1])
        XCTAssertEqual(money.map(\.after.coins), [coinsBefore + 1, coinsBefore + 2])
        XCTAssertEqual(outcome.scoreReceipts.flatMap(\.operations).filter { $0.sourceID == "bf_second_print" }.count, 1)
    }

    func testOnyxRestoresOnlyCluePlacementAndDoesNotSpendSecondPrint() throws {
        var (game, last) = try simultaneousClearFixture()
        game.give(marker: Markers.onyx, on: [last])
        game.give(buff: "bf_second_print")
        _ = try game.useBuff(at: 0)
        game.run.puzzle?.clueReveals.insert(last)
        let digit = try XCTUnwrap(game.puzzle).board.correctDigit(at: last)
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: last)
        XCTAssertEqual(outcome.points, digit.rawValue * 10)
        XCTAssertEqual(outcome.lineClearPoints, [0, 0])
        XCTAssertTrue(try XCTUnwrap(game.puzzle).armedFlags.contains(.secondPrint))
        XCTAssertEqual(game.puzzle?.board.filledBy[last.index], .clue)
        XCTAssertEqual(outcome.scoreReceipts.flatMap(\.operations).filter { $0.kind == .zero }.count, 2)
    }

    func testKeepFillingCannotBankScoreAgainAndCashOutReceiptRemainsSingle() throws {
        var game = try game(["bm_morning_edition"])
        game.run.puzzle?.target = 100
        _ = try place(.five, in: &game)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 150)
        let prior = game.puzzle?.lastScoringLedger
        try game.keepFilling()
        _ = try place(.six, in: &game)
        XCTAssertEqual(try game.endTurn().pointsGained, 0)
        XCTAssertEqual(game.puzzle?.lastScoringLedger, prior)
        let coins = game.run.coins
        let paid = try game.cashOut()
        XCTAssertEqual(game.run.coins, coins + paid.total)
        XCTAssertThrowsError(try game.cashOut())
        XCTAssertEqual(game.run.coins, coins + paid.total)
    }

    func testSaturationAndHistoricalBankedIntRemainFiniteAndDoNotTrap() throws {
        XCTAssertEqual(ScoreMath.integer(.infinity), ScoreMath.ceiling)
        XCTAssertEqual(ScoreMath.integer(.nan), 0)
        var game = try game(["bm_stop_the_presses"])
        game.run.puzzle?.pendingBase = ScoreMath.ceiling
        let turn = try game.endTurn()
        XCTAssertEqual(turn.pointsGained, ScoreMath.ceiling)
        XCTAssertEqual(game.puzzle?.score, ScoreMath.ceiling)
        var old = try self.game(["bm_morning_edition"])
        old.run.puzzle?.score = Int.max - 10
        XCTAssertEqual(try old.endTurn().pointsGained, 0)
        XCTAssertEqual(old.puzzle?.score, Int.max - 10)
    }

    func testScoreCeilingPreviewMatchesTheActualBankAfterPlacementAndResume() throws {
        for (startingScore, expectedAward) in [(ScoreMath.ceiling - 10, 10),
                                               (ScoreMath.ceiling, 0), (Int.max, 0)] {
            var game = try game(["bm_stop_the_presses", "bm_morning_edition"])
            game.run.puzzle?.score = startingScore
            _ = try place(.five, in: &game)
            let saved = try game.encoded()
            let preview = try XCTUnwrap(game.puzzle).pendingScoringLedger
            XCTAssertEqual(preview.points, 50)
            XCTAssertEqual(preview.multiplier, 3)
            XCTAssertEqual(preview.total, expectedAward)
            XCTAssertEqual(preview.scoreLimitApplied, true)
            XCTAssertEqual(try game.encoded(), saved, "Reading the cap preview cannot alter any random stream or save field")
            game = try Game(decoding: saved)
            XCTAssertEqual(game.puzzle?.pendingScoringLedger, preview)

            let turn = try game.endTurn()
            let ledger = try XCTUnwrap(turn.scoringLedger)
            let bank = try XCTUnwrap(ledger.operations.first { $0.kind == .bank })
            let morning = try XCTUnwrap(ledger.operations.first { $0.sourceID == "bm_morning_edition" && $0.kind == .directScore })
            XCTAssertEqual(bank.amount, Double(preview.total))
            XCTAssertEqual(bank.after.score - bank.before.score, preview.total)
            XCTAssertEqual(morning.amount, 0, "A capped direct bonus must not print phantom points")
            XCTAssertEqual(morning.before.score, morning.after.score)
            XCTAssertEqual(ledger.total, expectedAward)
            XCTAssertEqual(turn.pointsGained, expectedAward)
            XCTAssertEqual(ledger.scoreLimitApplied, true)
            XCTAssertEqual(game.puzzle?.score, startingScore + expectedAward,
                           "Historical scores above the ceiling must never be narrowed")
            XCTAssertEqual(try Game(decoding: game.encoded()).puzzle?.lastScoringLedger, ledger)
        }
    }

    func testDirectAwardsRecordOnlyTheirAvailableRoomInCatalogueOrder() throws {
        for (startingScore, expectedMorning) in [(ScoreMath.ceiling - 40, 40),
                                                 (ScoreMath.ceiling, 0), (Int.max, 0)] {
            var game = try game(["bm_morning_edition", "bm_evening_edition"])
            game.run.puzzle?.score = startingScore
            game.run.puzzle?.turnNumber = 10
            let coins = game.run.coins
            let preview = try XCTUnwrap(game.puzzle).pendingScoringLedger
            XCTAssertEqual(preview.total, 0)
            XCTAssertNil(preview.scoreLimitApplied, "A zero queued product is not limited; direct bonuses apply later")
            game = try Game(decoding: game.encoded())
            // A qualifying placement can leave a zero queue after a paid penalty.
            game.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
            let turn = try game.endTurn()
            let ledger = try XCTUnwrap(turn.scoringLedger)
            let direct = ledger.operations.filter { $0.kind == .directScore }
            XCTAssertEqual(direct.map(\.sourceID), ["bm_morning_edition", "bm_evening_edition"])
            XCTAssertEqual(direct.map(\.amount), [Double(expectedMorning), 0])
            XCTAssertEqual(direct.map { $0.after.score - $0.before.score }, [expectedMorning, 0])
            XCTAssertEqual(ledger.total, expectedMorning)
            XCTAssertEqual(turn.pointsGained, expectedMorning)
            XCTAssertEqual(ledger.scoreLimitApplied, true)
            XCTAssertEqual(game.run.coins, coins, "Score saturation must not invent an economy event")
            XCTAssertEqual(game.puzzle?.score, startingScore + expectedMorning)
        }
    }

    func testScoreLimitMetadataIncludesProductSaturationButNotFractionalRounding() throws {
        var capped = try game(["bm_stop_the_presses"])
        capped.run.puzzle?.pendingBase = ScoreMath.ceiling
        // The order is locked by endTurn for the normal queued-batch path.
        capped.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        let cappedTurn = try capped.endTurn()
        XCTAssertEqual(cappedTurn.scoringLedger?.points, ScoreMath.ceiling)
        XCTAssertEqual(cappedTurn.scoringLedger?.multiplier, 3)
        XCTAssertEqual(cappedTurn.scoringLedger?.total, ScoreMath.ceiling)
        XCTAssertEqual(cappedTurn.scoringLedger?.scoreLimitApplied, true)

        var fractional = try game([Bookmarks.rollingPresses, "bm_morning_edition"])
        fractional.run.puzzle?.itemState[Bookmarks.rollingPresses] = 1
        fractional.run.puzzle?.pendingBase = 45
        fractional.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        let ordinaryTurn = try fractional.endTurn()
        XCTAssertEqual(ordinaryTurn.pointsGained, 167) // floor(45 × 1.5) + 100
        XCTAssertNil(ordinaryTurn.scoringLedger?.scoreLimitApplied)
        XCTAssertEqual(ordinaryTurn.scoringLedger?.operations.first { $0.kind == .directScore }?.amount, 100)
    }

    func testHistoricalLedgerWithoutScoreLimitMetadataRoundTripsUnchanged() throws {
        var game = try game(["bm_morning_edition"])
        game.run.puzzle?.score = ScoreMath.ceiling
        game.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        _ = try game.endTurn()
        var root = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(root["puzzle"] as? [String: Any])
        var oldLedger = try XCTUnwrap(puzzle["lastScoringLedger"] as? [String: Any])
        XCTAssertEqual(oldLedger.removeValue(forKey: "scoreLimitApplied") as? Bool, true)
        puzzle["lastScoringLedger"] = oldLedger
        root["puzzle"] = puzzle
        let restored = try Game(decoding: JSONSerialization.data(withJSONObject: root))
        let ledger = try XCTUnwrap(restored.puzzle?.lastScoringLedger)
        XCTAssertNil(ledger.scoreLimitApplied)
        let roundTrip = try Game(decoding: restored.encoded())
        XCTAssertEqual(roundTrip.puzzle?.lastScoringLedger, ledger)
        XCTAssertEqual(roundTrip.puzzle?.score, ScoreMath.ceiling)
        let encodedLedger = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(ledger)) as? [String: Any])
        XCTAssertNil(encodedLedger["scoreLimitApplied"], "Historical missing metadata remains absent")
        XCTAssertTrue(NSDictionary(dictionary: oldLedger).isEqual(to: encodedLedger))
    }

    func testLedgerPreviewAndEncodingDoNotConsumeAnyRandomStream() throws {
        var game = try game(["bm_op_ed", "bm_stop_the_presses"])
        _ = try place(.five, in: &game)
        let before = try game.encoded()
        let ledger = game.puzzle?.pendingScoringLedger
        for _ in 0..<50 { XCTAssertEqual(game.puzzle?.pendingScoringLedger, ledger) }
        XCTAssertEqual(try game.encoded(), before)
        let saved = try Game(decoding: before)
        XCTAssertEqual(saved.puzzle?.pendingScoringLedger, ledger)
        XCTAssertEqual(try saved.encoded(), before)
    }
}
