import XCTest
@testable import ProbablySudokuEngine

/// Independent review fixtures. The Latin Sudoku and arithmetic constants are
/// written here; expected awards never call Resolver, pendingScore or ScoreMath.
final class IndependentOrderedScoringTests: XCTestCase {
    private func fixture(blanks: Set<Int> = Set(0..<81), bookmarks: [String] = []) throws -> Game {
        var game = Game(seed: "independent-ordered-review")
        try game.startPuzzle()
        let solution = (0..<81).map { index in
            Digit((index / 9 * 3 + index / 27 + index % 9) % 9 + 1)!
        }
        let board = Board(GeneratedPuzzle(solution: solution,
            isGiven: (0..<81).map { !blanks.contains($0) }))
        game.run.puzzle?.board = board
        game.run.puzzle?.pool = Pool(blanksOf: board)
        game.run.puzzle?.hand = []
        game.run.puzzle?.target = 1_000_000
        game.run.bookmarks = bookmarks.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 4) }
        return game
    }

    private func play(_ index: Int, in game: inout Game) throws -> PlacementOutcome {
        let square = Square(index)
        let digit = try XCTUnwrap(game.puzzle).board.correctDigit(at: square)
        let card = try XCTUnwrap(game.stackHand(with: digit))
        return try game.place(handIndex: card, at: square)
    }

    private func keepSpare(in game: inout Game) throws {
        _ = try XCTUnwrap(game.stackHand(with: .nine))
    }

    func testFinalZeroPointCardStillEndsTurnWithoutUnearnedBookmarkBonus() throws {
        for censored in [false, true] {
            var game = try fixture(blanks: [80], bookmarks: ["bm_morning_edition"])
            game.run.puzzle?.target = 100
            if censored {
                game.run.puzzle?.boss = .censor
                game.run.puzzle?.censoredDigit = .eight
            } else {
                game.run.puzzle?.clueReveals.insert(Square(80))
            }
            let action = try play(80, in: &game)
            XCTAssertEqual(action.points, 0)
            XCTAssertEqual(action.lineClearPoints, [0, 0, 0])
            XCTAssertEqual(action.fullClearPoints, 0)
            XCTAssertEqual(action.automaticTurn?.pointsGained, 0)
            XCTAssertEqual(game.puzzle?.score, 0)
            XCTAssertEqual(game.puzzle?.phase, .failed)
            XCTAssertEqual(game.run.outcome, .failed)
            XCTAssertEqual(game.puzzle?.lastScoringLedger?.operations.filter { $0.kind == .directScore }.map(\.amount), [])
        }
    }

    func testHistoricalFinalZeroPointCardPreservesItsEarnedRulesUntilBank() throws {
        for censored in [false, true] {
            var game = try fixture(blanks: [80], bookmarks: ["bm_morning_edition"])
            game.run.puzzle?.target = 100
            if censored {
                game.run.puzzle?.boss = .censor
                game.run.puzzle?.censoredDigit = .eight
            } else {
                game.run.puzzle?.clueReveals.insert(Square(80))
            }
            var saved = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
            var oldPuzzle = try XCTUnwrap(saved["puzzle"] as? [String: Any])
            oldPuzzle.removeValue(forKey: "bookmarkState")
            saved["puzzle"] = oldPuzzle
            game = try Game(decoding: JSONSerialization.data(withJSONObject: saved))
            XCTAssertTrue(game.puzzle!.bookmarkState.legacyTurn)
            let action = try play(80, in: &game)
            XCTAssertEqual(action.points, 0)
            XCTAssertEqual(action.lineClearPoints, [0, 0, 0])
            XCTAssertEqual(action.fullClearPoints, 0)
            XCTAssertEqual(action.automaticTurn?.pointsGained, 100)
            XCTAssertEqual(game.puzzle?.score, 100)
            XCTAssertEqual(game.puzzle?.phase, .won)
            XCTAssertNil(game.run.outcome)
            XCTAssertEqual(game.puzzle?.lastScoringLedger?.operations.filter { $0.kind == .directScore }.map(\.amount), [100])
        }
    }

    func testLocalPointsBuffsAndOrderedBookmarksNeverMultiplyCoins() throws {
        var game = try fixture(bookmarks: ["bm_local_gossip", "bm_op_ed", "bm_stop_the_presses"])
        try keepSpare(in: &game)
        game.give(marker: "mk_crimson", on: [Square(4)])
        game.give(buff: Buffs.paperCrane)
        game.give(buff: "bf_double_down")
        let craneID = game.run.buffs[0].id.uuidString
        let doubleID = game.run.buffs[1].id.uuidString
        XCTAssertTrue(try game.useBuff(at: 0, digit: .five))
        XCTAssertTrue(try game.useBuff(at: 0))
        let coins = game.run.coins
        let action = try play(4, in: &game)
        // (50 digit + 30 Gossip + 50 Crane) × 4 Crimson × 2 Double Down.
        XCTAssertEqual(action.points, 1_040)
        XCTAssertEqual(game.puzzle?.pendingBase, 1_040)
        let operations = action.scoreReceipts.flatMap(\.operations)
        XCTAssertEqual(operations.filter { $0.kind == .multiplyPoints }.map(\.amount), [4, 2])
        XCTAssertEqual(operations.first { $0.sourceID == Buffs.paperCrane }?.sourceInstanceID, craneID)
        XCTAssertEqual(operations.first { $0.sourceID == "bf_double_down" }?.sourceInstanceID, doubleID)
        XCTAssertEqual(game.puzzle?.pendingScore, 6_240) // (1+1)×3 = 6.
        XCTAssertEqual(try game.endTurn().pointsGained, 6_240)
        XCTAssertEqual(game.run.coins, coins)
    }

    func testThreeUnitAndFullClearHaveIndependentDoublingAndOrderedLedger() throws {
        var game = try fixture(blanks: [80], bookmarks: ["bm_sports_section", "bm_society_pages",
            "bm_extra_extra", "bm_finance_pages", "bm_op_ed"])
        game.give(marker: "mk_emerald", on: [Square(80)])
        game.give(buff: "bf_second_print")
        XCTAssertTrue(try game.useBuff(at: 0))
        let coins = game.run.coins
        let action = try play(80, in: &game)
        XCTAssertEqual(action.lineClears, [.row, .col, .box])
        // Digit 8; (45+25)×2 Emerald×3 Extra; first clear doubles once;
        // full board (500+500)×3; Mult 1+1. No clear hook is repeated.
        XCTAssertEqual(action.scoreReceipts.map(\.points), [80, 840, 420, 420, 3_000])
        XCTAssertEqual(action.automaticTurn?.pointsGained, 9_520)
        XCTAssertEqual(game.puzzle?.score, 9_520)
        XCTAssertEqual(game.run.coins, coins + 3)
        let ledger = try XCTUnwrap(game.puzzle?.lastScoringLedger)
        XCTAssertEqual(ledger.points, 4_760)
        XCTAssertEqual(ledger.multiplier, 2)
        XCTAssertEqual(ledger.total, 9_520)
        XCTAssertEqual(ledger.operations.filter { $0.kind == .coins }.map(\.after.coins), [coins + 1, coins + 2, coins + 3])
        XCTAssertEqual(Set(ledger.operations.map(\.id)).count, ledger.operations.count)
        XCTAssertEqual(try Game(decoding: game.encoded()).puzzle?.lastScoringLedger, ledger)
    }

    func testSleepingDuplicateAndSoldCopyStayLockedByIdentityThroughResume() throws {
        var game = try fixture(bookmarks: ["bm_op_ed", "bm_stop_the_presses", "bm_op_ed"])
        try keepSpare(in: &game)
        game.run.puzzle?.boss = .unluckyLucky
        game.run.puzzle?.bossTurn = BossTurnState()
        game.run.puzzle?.bossTurn?.disabledBookmark = 0
        let sleeping = game.run.bookmarks[0].id
        let activeAdd = game.run.bookmarks[2].id
        _ = try play(4, in: &game)
        XCTAssertEqual(game.puzzle?.pendingScore, 200) // sleeping +1, then ×3, then +1.
        XCTAssertTrue(game.reorderBookmark(id: sleeping, to: 2))
        _ = try game.sell(kind: .bookmark, index: 0) // Sell the ×3 copy after locking.
        game = try Game(decoding: game.encoded())
        let ledger = try XCTUnwrap(game.puzzle).pendingScoringLedger
        XCTAssertEqual(ledger.total, 200)
        XCTAssertEqual(ledger.operations.last?.sourceInstanceID, activeAdd.uuidString)
        XCTAssertFalse(ledger.operations.contains { $0.sourceInstanceID == sleeping.uuidString })
        XCTAssertEqual(try game.endTurn().pointsGained, 200)
    }

    func testMirrorSuppressesOnlyClearPointsAndPreservesUnusedDoubler() throws {
        var game = try fixture(blanks: [80], bookmarks: ["bm_finance_pages"])
        game.run.puzzle?.boss = .mirror
        game.run.puzzle?.target = 500
        game.give(buff: "bf_double_down")
        game.give(buff: "bf_second_print")
        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertTrue(try game.useBuff(at: 0))
        let coins = game.run.coins
        let action = try play(80, in: &game)
        XCTAssertEqual(action.points, 160)
        XCTAssertEqual(action.lineClearPoints, [0, 0, 0])
        XCTAssertEqual(action.fullClearPoints, 500)
        XCTAssertEqual(action.automaticTurn?.pointsGained, 660)
        XCTAssertEqual(game.run.coins, coins + 3)
        XCTAssertTrue(try XCTUnwrap(game.puzzle).armedFlags.contains(.secondPrint))
        XCTAssertFalse(try XCTUnwrap(game.puzzle).armedFlags.contains(.doubleDown))
        XCTAssertEqual(game.puzzle?.phase, .won)
    }

    func testRollingGrowthAppliesAtItsClearAndPreviewCannotGrowIt() throws {
        var game = try fixture(blanks: [4, 13, 80], bookmarks: [Bookmarks.rollingPresses])
        _ = try XCTUnwrap(game.stackHand(with: .eight)) // Keeps first turn open.
        let first = try play(4, in: &game)
        XCTAssertEqual(first.lineClears, [.row])
        XCTAssertEqual(game.puzzle?.pendingBase, 95)
        XCTAssertEqual(game.puzzle?.pendingScore, 142)
        XCTAssertEqual(game.puzzle?.itemState[Bookmarks.rollingPresses], 1)
        let bytes = try game.encoded()
        for _ in 0..<10 { XCTAssertEqual(game.puzzle?.pendingScore, 142) }
        XCTAssertEqual(try game.encoded(), bytes)
        _ = try game.endTurn()
        // New Turn can use growth from the preceding clear before any new event.
        let second = try play(13, in: &game)
        XCTAssertEqual(second.lineClears, [.row, .col, .box])
        // 80+3×45=215; all four completed clears now supply held ×3.
        XCTAssertEqual(game.puzzle?.pendingBase, 215)
        XCTAssertEqual(game.puzzle?.pendingScore, 645) // 215×3.
        XCTAssertEqual(game.puzzle?.itemState[Bookmarks.rollingPresses], 4)
    }

    func testLegacyContinuationKeepsOldUnorderedMathAndPersistentRewards() throws {
        var game = try fixture(bookmarks: ["bm_stop_the_presses", "bm_op_ed"])
        try keepSpare(in: &game)
        game.run.coins = 37
        game.run.runItemState["clipping.circulation"] = 5
        game.run.runItemState["clipping.taken.1.0"] = 1
        game.run.puzzle?.score = 444
        game.run.puzzle?.pendingBase = 40
        game.run.puzzle?.pendingMult = 6
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: game.encoded()) as? [String: Any])
        var puzzle = try XCTUnwrap(json["puzzle"] as? [String: Any])
        for key in ["scoringVersion", "turnScoringState", "turnScoringOperations", "lastScoringLedger", "scoringBuffSources", "bookmarkState"] { puzzle.removeValue(forKey: key) }
        json["puzzle"] = puzzle
        game = try Game(decoding: JSONSerialization.data(withJSONObject: json))
        _ = try play(4, in: &game)
        XCTAssertEqual(game.puzzle?.pendingBase, 90)
        XCTAssertEqual(game.puzzle?.pendingScore, 540) // v1 keeps (1+1)×3 despite reversed inventory.
        XCTAssertEqual(try game.endTurn().pointsGained, 540)
        XCTAssertEqual(game.puzzle?.score, 984)
        XCTAssertEqual(game.run.coins, 37)
        XCTAssertEqual(game.run.runItemState["clipping.circulation"], 5)
        XCTAssertEqual(game.run.runItemState["clipping.taken.1.0"], 1)
        game = try Game(decoding: game.encoded())
        _ = try play(3, in: &game)
        XCTAssertEqual(game.puzzle?.pendingScore, 160) // v2: 40×(1×3+1).
        XCTAssertEqual(game.puzzle?.score, 984)
    }

    func testSaturationRecordsActualBankDeltaWithoutOverflowOrDuplicatePayment() throws {
        var game = try fixture(bookmarks: ["bm_stop_the_presses", "bm_morning_edition"])
        game.run.puzzle?.target = Int.max
        game.run.puzzle?.score = 8_999_999_999_999_990
        game.run.puzzle?.pendingBase = 50
        game.run.puzzle?.bookmarkState.turn.eligiblePlacements = 1
        let turn = try game.endTurn()
        XCTAssertEqual(turn.pointsGained, 10)
        XCTAssertEqual(game.puzzle?.score, 9_000_000_000_000_000)
        let ledger = try XCTUnwrap(turn.scoringLedger)
        XCTAssertEqual(ledger.total, 10)
        XCTAssertEqual(ledger.operations.first { $0.kind == .bank }?.amount, 10)
        let direct = try XCTUnwrap(ledger.operations.first { $0.kind == .directScore })
        XCTAssertEqual(direct.after.score, direct.before.score)
        game = try Game(decoding: game.encoded())
        XCTAssertEqual(game.puzzle?.lastScoringLedger, ledger)
        XCTAssertEqual(try game.endTurn().pointsGained, 0)
        XCTAssertEqual(game.puzzle?.score, 9_000_000_000_000_000)
    }

    func testLargeFiniteSavedPaperCraneModifierIsBoundedBeforeIntegerConversion() throws {
        var game = try fixture()
        try keepSpare(in: &game)
        game.run.puzzle?.target = Int.max
        game.run.puzzle?.itemState[Buffs.paperCraneKey(.five)] = 1e20
        // This is a finite, JSON-representable historical modifier, not NaN.
        game = try Game(decoding: game.encoded())
        let action = try play(4, in: &game)
        XCTAssertEqual(action.points, 9_000_000_000_000_000)
        XCTAssertEqual(game.puzzle?.pendingScore, 9_000_000_000_000_000)
        _ = try game.encoded()
        XCTAssertEqual(try game.endTurn().pointsGained, 9_000_000_000_000_000)
        XCTAssertEqual(try Game(decoding: game.encoded()).puzzle?.score, 9_000_000_000_000_000)
    }

    func testBirdSeedLedgerRetainsConsumedCopyIdentityAcrossPuzzlesAndResume() throws {
        var game = try fixture(blanks: [80])
        let board = try XCTUnwrap(game.puzzle).board
        game.run.puzzle?.target = 500
        game.give(buff: Buffs.birdSeed)
        let source = game.run.buffs[0].id.uuidString
        XCTAssertTrue(try game.useBuff(at: 0))
        let first = try play(80, in: &game)
        XCTAssertEqual(first.scoreReceipts.flatMap(\.operations).filter { $0.sourceID == Buffs.birdSeed }.map(\.sourceInstanceID), [source, source, source])
        _ = try game.cashOut()
        game.openShop()
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        // Arrange the same one-card board in the new production Puzzle.
        game.run.puzzle?.board = board
        game.run.puzzle?.pool = Pool(blanksOf: board)
        game.run.puzzle?.hand = []
        game.run.puzzle?.target = 500
        game = try Game(decoding: game.encoded())
        let coins = game.run.coins
        let next = try play(80, in: &game)
        XCTAssertEqual(game.run.coins, coins + 3)
        XCTAssertEqual(next.scoreReceipts.flatMap(\.operations).filter { $0.sourceID == Buffs.birdSeed }.map(\.sourceInstanceID), [source, source, source])
        XCTAssertEqual(game.run.buffs.count, 0)
    }
}
