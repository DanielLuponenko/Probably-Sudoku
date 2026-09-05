import XCTest
@testable import ProbablySudokuEngine

final class ShopAndItemRegressionTests: XCTestCase {
    func testInitialAndRerolledStockNeverRepeatsAMarkerDefinition() throws {
        for level in 1...9 {
            for seed in 0..<30 {
                var run = RunState(seed: "unique-markers-\(seed)")
                run.level = level
                run.coins = 100
                Shop.open(&run)
                for roll in 0..<4 {
                    let markers = try XCTUnwrap(run.shop).offers.filter { $0.def.kind == .marker }
                    guard Set(markers.map(\.defID)).count == markers.count else {
                        return XCTFail("Level \(level), seed \(seed), roll \(roll): \(markers.map { "\($0.defID)=\($0.price)" })")
                    }
                    XCTAssertEqual(markers.count, 2)
                    try Shop.reroll(&run)
                }
            }
        }
    }

    func testOwnedMarkersRemainEligibleInLaterStock() throws {
        var run = RunState(seed: "owned-markers-still-available")
        run.markers = Markers.all.map { OwnedMarker(defID: $0.id, boughtAtLevel: 1, pricePaid: 5) }
        Shop.open(&run)
        let markers = try XCTUnwrap(run.shop).offers.filter { $0.def.kind == .marker }
        XCTAssertEqual(markers.count, 2)
        XCTAssertEqual(Set(markers.map(\.defID)).count, 2)
    }

    func testAccountantDebitsCorrectAndWrongPlacementsImmediatelyAndOnlyOnce() throws {
        for correct in [true, false] {
            var game = Game(seed: "accountant-live")
            try game.startPuzzle()
            game.run.puzzle?.boss = .accountant
            game.run.coins = 0
            let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
            let solution = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let digit = correct ? solution : (solution == .one ? .two : .one)
            let turn = game.puzzle?.turnNumber
            let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            XCTAssertEqual(outcome.correct, correct)
            XCTAssertEqual(game.run.coins, -1, "The placement cost is live even below zero")
            XCTAssertEqual(game.puzzle?.turnNumber, turn, "No bank was needed to debit the coin")
            game = try Game(decoding: game.encoded())
            XCTAssertEqual(game.run.coins, -1, "The immediate debit survives saving before bank")
            _ = try game.endTurn()
            XCTAssertEqual(game.run.coins, -1, "Banking must not debit the placement again")
        }
    }

    func testAccountantNetsLiveMarkerCoinsAndDoesNotChargeRejectedAttempts() throws {
        var game = Game(seed: "accountant-marker")
        try game.startPuzzle()
        game.run.puzzle?.boss = .accountant
        game.run.coins = 0
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        game.give(marker: "mk_azure", on: [square])
        _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertEqual(game.run.coins, 0, "The immediate marker coin offsets the immediate cost")
        XCTAssertThrowsError(try game.place(handIndex: 0, at: square))
        XCTAssertEqual(game.run.coins, 0)
        XCTAssertThrowsError(try game.place(handIndex: -1, at: square))
        XCTAssertEqual(game.run.coins, 0)
    }

    func testConsumedBirdSeedPaysThroughTheLevelAndSurvivesSaving() throws {
        var game = Game(seed: "bird-seed-lifetime")
        try game.startPuzzle()
        game.give(buff: Buffs.birdSeed)
        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertTrue(game.run.buffs.isEmpty)
        game = try Game(decoding: game.encoded())

        for slot in PuzzleSlot.allCases {
            game.run.slot = slot
            try game.startPuzzle()
            game.run.puzzle?.boss = nil
            let square = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let before = game.run.coins
            let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            XCTAssertGreaterThan(outcome.lineClears.count, 0)
            XCTAssertEqual(game.run.coins - before, outcome.lineClears.count, "Consumed Bird Seed remains active in \(slot)")
        }
    }

    func testBirdSeedExpiresNextLevelEvenIfAnotherCopyIsHeld() throws {
        var game = Game(seed: "bird-seed-expiry")
        try game.startPuzzle()
        game.give(buff: Buffs.birdSeed)
        XCTAssertTrue(try game.useBuff(at: 0))
        game.give(buff: Buffs.birdSeed)
        game.run.level = 2
        try game.startPuzzle()
        let square = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let before = game.run.coins
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertGreaterThan(outcome.lineClears.count, 0)
        XCTAssertEqual(game.run.coins, before, "An old Level's activation must not pay from a held copy")
        XCTAssertEqual(game.run.buffs.count, 1)
    }

    func testBuffsCannotBeSpentAfterThePuzzleStopsBeingPlayable() throws {
        for phase in [PuzzlePhase.outOfTurns, .won, .cashedOut, .failed] {
            var game = Game(seed: "terminal-buffs")
            try game.startPuzzle()
            game.give(buff: Buffs.freshInk)
            game.run.puzzle?.phase = phase
            let before = try game.encoded()
            XCTAssertThrowsError(try game.useBuff(at: 0), "Phase: \(phase)")
            XCTAssertEqual(try game.encoded(), before, "Rejected use preserves inventory and saved state")
        }
    }

    func testPaperCraneWithoutANumberDoesNotSpendTheBuff() throws {
        var game = Game(seed: "paper-crane-needs-number")
        try game.startPuzzle()
        game.give(buff: Buffs.paperCrane)
        let before = try game.encoded()
        XCTAssertFalse(try game.useBuff(at: 0))
        XCTAssertEqual(try game.encoded(), before)
    }

    func testPeekUnderPaywallDoesNotSpendTheBuff() throws {
        var game = Game(seed: "paywall-peek")
        try game.startPuzzle()
        game.run.puzzle?.boss = .paywall
        game.give(buff: Buffs.peek)
        let before = try game.encoded()
        XCTAssertThrowsError(try game.useBuff(at: 0)) {
            XCTAssertEqual($0 as? PlacementError, .cluesDisabled)
        }
        XCTAssertEqual(try game.encoded(), before)
    }

    func testExtraExtraOnlyTriplesClearPointsNotUnrelatedPlacements() throws {
        var game = Game(seed: "extra-extra-scope")
        try game.startPuzzle()
        let square = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
        game.run.puzzle?.pendingBase = 0
        game.run.puzzle?.pendingMult = 1
        game.give(ad: "bm_extra_extra")
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertEqual(outcome.points, 10 * digit.rawValue)
        XCTAssertEqual(outcome.lineClearPoints, Array(repeating: 135, count: outcome.lineClears.count))
        let expected = 10 * digit.rawValue + 135 * outcome.lineClears.count
        XCTAssertEqual(game.puzzle?.pendingBase, expected)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 1)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, expected)
    }

    func testExtraExtraScopesAcrossOtherPlacementsHeldMultipliersAndSave() throws {
        var game = Game(seed: "extra-extra-composition")
        try game.startPuzzle()
        let closingSquare = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
        game.run.puzzle?.pendingBase = 0
        game.run.puzzle?.pendingMult = 1
        game.give(ad: "bm_extra_extra")
        game.give(ad: "bm_op_ed")
        game.give(ad: "bm_stop_the_presses")

        func placeWithoutClear(_ game: inout Game) throws -> Int {
            for square in try XCTUnwrap(game.puzzle).board.blanks where square != closingSquare {
                var candidate = game
                let digit = try XCTUnwrap(candidate.puzzle?.board.correctDigit(at: square))
                let outcome = try candidate.place(handIndex: XCTUnwrap(candidate.stackHand(with: digit)), at: square)
                guard outcome.lineClears.isEmpty else { continue }
                game = candidate
                XCTAssertEqual(outcome.points, digit.rawValue * 10)
                return outcome.points
            }
            throw XCTSkip("Fixture needs a non-clearing placement")
        }

        let before = try placeWithoutClear(&game)
        let closingDigit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: closingSquare))
        let clear = try game.place(handIndex: XCTUnwrap(game.stackHand(with: closingDigit)), at: closingSquare)
        XCTAssertEqual(clear.lineClearPoints, Array(repeating: 135, count: clear.lineClears.count))
        game = try Game(decoding: game.encoded())
        let after = try placeWithoutClear(&game)
        let expectedBase = before + closingDigit.rawValue * 10 + clear.lineClears.count * 135 + after
        XCTAssertEqual(game.puzzle?.pendingBase, expectedBase)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 6)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, expectedBase * 6)
    }

    func testBirdSeedDoesNotMultiplyWithUnspentCopiesOrRepeatActivation() throws {
        var game = Game(seed: "bird-seed-copies")
        try game.startPuzzle()
        game.give(buff: Buffs.birdSeed)
        game.give(buff: Buffs.birdSeed)
        XCTAssertTrue(try game.useBuff(at: 0))
        let square = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let before = game.run.coins
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertEqual(game.run.coins - before, outcome.lineClears.count)
        XCTAssertEqual(game.run.buffs.count, 1)
        let beforeRepeat = try game.encoded()
        XCTAssertFalse(try game.useBuff(at: 0), "The Level effect cannot stack, so keep the spare")
        XCTAssertEqual(try game.encoded(), beforeRepeat)
    }

    func testAlreadyArmedOneShotBuffsKeepTheDuplicateCopy() throws {
        for id in ["bf_double_down", "bf_insurance", "bf_second_print", Buffs.litmus] {
            var game = Game(seed: "armed-duplicates")
            try game.startPuzzle()
            game.give(buff: id)
            game.give(buff: id)
            XCTAssertTrue(try game.useBuff(at: 0), id)
            let before = try game.encoded()
            XCTAssertFalse(try game.useBuff(at: 0), id)
            XCTAssertEqual(try game.encoded(), before, id)
        }
    }

    func testLuckyDipKeepsTheBuffWhenThePoolIsEmpty() throws {
        var game = Game(seed: "empty-pool-lucky-dip")
        try game.startPuzzle()
        for digit in Digit.allCases {
            while game.run.puzzle?.pool[digit] ?? 0 > 0 { _ = game.stackHand(with: digit) }
        }
        game.give(buff: "bf_lucky_dip")
        let before = try game.encoded()
        XCTAssertFalse(try game.useBuff(at: 0))
        XCTAssertEqual(try game.encoded(), before)
    }

    func testExtraExtraFullClearComposesWithFlatHeldAndSquareBonuses() throws {
        var game = Game(seed: "extra-extra-full-clear")
        try game.startPuzzle()
        game.run.puzzle?.target = 1_000_000
        let last = try XCTUnwrap(game.puzzle?.board.blanks.last)
        for square in try XCTUnwrap(game.puzzle).board.blanks where square != last {
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        }
        game.run.puzzle?.score = 0
        game.run.puzzle?.pendingBase = 0
        game.run.puzzle?.pendingMult = 1
        game.give(ad: "bm_extra_extra")
        game.give(ad: "bm_society_pages")
        game.give(ad: "bm_op_ed")
        game.give(marker: "mk_emerald", on: [last])
        game.give(buff: "bf_second_print")
        XCTAssertTrue(try game.useBuff(at: 0))
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: last))
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: last)
        XCTAssertEqual(outcome.points, digit.rawValue * 10)
        XCTAssertEqual(outcome.lineClearPoints, [540, 270, 270])
        XCTAssertEqual(outcome.fullClearPoints, 3_000)
        XCTAssertEqual(game.puzzle?.score, outcome.totalPoints * 2)
    }

    func testKeepFillingWrongPlacementPreservesFrozenScoreProtectionAndCoinRules() throws {
        let cases: [(Book, String?)] = [(.probably, nil), (.trustMe, nil),
            (.probably, Markers.jade), (.trustMe, Markers.jade), (.probably, Markers.ivory)]
        for (book, marker) in cases {
            var game = Game(seed: "keep-filling-wrong", book: book)
            try game.startPuzzle()
            let wonScore = try XCTUnwrap(game.puzzle?.target) + 1_000
            game.run.puzzle?.score = wonScore
            game.run.puzzle?.phase = .won
            game.run.puzzle?.armedFlags.insert(.insurance)
            game.run.puzzle?.boss = .accountant
            try game.keepFilling()
            let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
            if let marker { game.give(marker: marker, on: [square]) }
            let solution = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let wrong: Digit = solution == .one ? .two : .one
            let index = try XCTUnwrap(game.stackHand(with: wrong))
            let before = try XCTUnwrap(game.puzzle)
            let beforeCoins = game.run.coins
            let outcome = try game.place(handIndex: index, at: square)
            XCTAssertFalse(outcome.correct)
            XCTAssertEqual(outcome.penalty, 0)
            XCTAssertEqual(outcome.points, 0)
            XCTAssertEqual(game.puzzle?.score, before.score)
            XCTAssertEqual(game.puzzle?.itemState, before.itemState, "No first-mistake waiver is needed")
            XCTAssertEqual(game.puzzle?.armedFlags, before.armedFlags, "No Insurance charge is needed")
            XCTAssertEqual(game.puzzle?.phase, .keepFilling)
            XCTAssertEqual(game.run.coins, beforeCoins - 1, "Accountant still charges for placing")
            XCTAssertEqual(game.puzzle?.hand.count, before.hand.count - (marker == Markers.jade ? 0 : 1))
            XCTAssertEqual(game.puzzle?.pool[wrong], before.pool[wrong] + (marker == Markers.jade ? 0 : 1))
            game.puzzle?.assertConservation()
            game = try Game(decoding: game.encoded())
            _ = try game.cashOut()
            XCTAssertEqual(game.run.bestPuzzleScore, before.score)
        }
    }

    func testKeepFillingWrongPlacementCannotLowerScoreWithoutAnyProtectionItem() throws {
        var game = Game(seed: "keep-filling-unprotected")
        try game.startPuzzle()
        let wonScore = try XCTUnwrap(game.puzzle?.target) + 100
        game.run.puzzle?.score = wonScore
        game.run.puzzle?.phase = .won
        try game.keepFilling()
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let solution = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let wrong: Digit = solution == .one ? .two : .one
        let before = game.puzzle?.score
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: wrong)), at: square)
        XCTAssertEqual(outcome.penalty, 0)
        XCTAssertEqual(game.puzzle?.score, before)
    }

    func testKeepFillingKeepsScoreOnlyBuffsButAllowsUsefulResources() throws {
        let scoreOnly: Set<String> = ["bf_double_down", "bf_insurance", "bf_second_print",
                                      Buffs.freshInk, Buffs.paperCrane]
        for def in Buffs.all {
            var game = Game(seed: "keep-filling-buff-effect")
            try game.startPuzzle()
            let target = try XCTUnwrap(game.puzzle?.target)
            game.run.puzzle?.score = target
            game.run.puzzle?.phase = .won
            try game.keepFilling()
            game.give(buff: def.id)
            let before = try game.encoded()
            let used = try game.useBuff(at: 0, digit: .five)
            XCTAssertEqual(used, !scoreOnly.contains(def.id), def.id)
            if scoreOnly.contains(def.id) {
                XCTAssertEqual(try game.encoded(), before, "\(def.id) cannot change the frozen score")
            } else {
                XCTAssertTrue(game.run.buffs.isEmpty, "\(def.id) can still help earn coins from clears")
            }
        }
    }
}
