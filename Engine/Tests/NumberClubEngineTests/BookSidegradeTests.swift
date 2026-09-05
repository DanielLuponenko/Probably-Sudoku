import XCTest
@testable import ProbablySudokuEngine

final class BookSidegradeTests: XCTestCase {
    func testTwelveBooksHaveDistinctStableIDsVolumesAndBenefits() throws {
        let ids = ["probably", "slightlyHarder", "noPressure", "bites", "genuinely",
                   "snackBreak", "trustMe", "overthinking", "smallVictories", "rainyDay",
                   "secondThoughts", "wellEarned"]
        XCTAssertEqual(Book.allCases.map(\.rawValue), ids)
        XCTAssertEqual(Book.allCases.map(\.volume), Array(1...12))
        XCTAssertEqual(Set(Book.allCases.map(\.benefit)).count, 12)
        XCTAssertEqual(Set(Book.allCases.map(\.benefit)), Set(BookBenefit.allCases))
        for book in Book.allCases {
            let game = Game(seed: "book-sidegrade-save", book: book)
            let restored = try Game(decoding: game.encoded())
            XCTAssertEqual(restored.run.book, book)
            XCTAssertEqual(restored.run.book.benefit, book.benefit)
            XCTAssertEqual(try restored.encoded(), try game.encoded())
            XCTAssertFalse(book.benefit.title.isEmpty)
            XCTAssertFalse(book.benefit.detail.isEmpty)
        }
    }

    func testNewBooksAreBaselineSidegradesAndOriginalRulesAreUnchanged() {
        for book in Book.allCases.dropFirst(4) {
            XCTAssertEqual(RunState(seed: "baseline", book: book).coins, Baseline.coins)
            for slot in PuzzleSlot.allCases {
                XCTAssertEqual(book.givens(for: slot.difficulty), slot.difficulty.givens)
                for level in 1...9 {
                    XCTAssertEqual(book.target(level: level, slot: slot), Targets.target(level: level, slot: slot))
                }
            }
        }
        XCTAssertEqual(RunState(seed: "original", book: .probably).effectiveHandSize(boss: nil), 7)
        XCTAssertEqual(RunState(seed: "original", book: .slightlyHarder).coins, 15)
        XCTAssertEqual(RunState(seed: "original", book: .noPressure).effectiveClues(boss: nil), 1)
        XCTAssertEqual(RunState(seed: "original", book: .bites).effectiveTurns(boss: .deadline), 9)
        XCTAssertEqual(RunState(seed: "original", book: .bites).coins, 3)
    }

    func testExtraTossStacksButCannotBypassBossOrObstacleRestrictions() throws {
        var game = try started(.genuinely)
        XCTAssertEqual(game.puzzle?.tossAllowance, 5)
        game.give(ad: Bookmarks.weatherForecast)
        game.run.subscriptions.append(OwnedSubscription(defID: Subscriptions.wireService, pricePaid: 0))
        XCTAssertEqual(game.run.effectiveTossAllowance(boss: nil), 9)
        XCTAssertEqual(game.run.effectiveTossAllowance(boss: .erratum), 0)
        for obstacle in Obstacle.allCases where obstacle.removesTosses {
            let run = RunState(seed: "no-toss", book: .genuinely, obstacle: obstacle)
            XCTAssertEqual(run.effectiveTossAllowance(boss: nil), 0)
        }
    }

    func testInterestCapStacksAndCollectorStillCancelsInterest() throws {
        var game = try started(.rainyDay)
        XCTAssertEqual(game.run.interestCap, 15)
        game.give(ad: Bookmarks.marketWrap)
        XCTAssertEqual(game.run.interestCap, 20)
        game.run.subscriptions.append(OwnedSubscription(defID: Subscriptions.annualRate, pricePaid: 0))
        game.run.runItemState["clipping.circulation"] = 5
        XCTAssertEqual(game.run.interestCap, 30)
        game.run.coins = 500
        XCTAssertEqual(game.run.payout(for: game.puzzle!).interest, 30)
        game.run.puzzle?.boss = .collector
        XCTAssertEqual(game.run.payout(for: game.puzzle!).interest, 0)
    }

    func testFreeFirstRerollHasTheNormalPaidLadderAndDoesNotDoubleStack() throws {
        for ownsAuction in [false, true] {
            var game = Game(seed: "book-reroll", book: .secondThoughts)
            game.run.coins = 100
            if ownsAuction { game.give(ad: Bookmarks.auctionNotices) }
            game.openShop()
            XCTAssertEqual(game.shop?.rerollCost, 0)
            try game.reroll()
            XCTAssertEqual(game.run.coins, 100)
            XCTAssertEqual(game.shop?.rerollCost, 2)
            try game.reroll()
            XCTAssertEqual(game.run.coins, 98)
            XCTAssertEqual(game.shop?.rerollCost, 3)
            game = try Game(decoding: game.encoded())
            try game.reroll()
            XCTAssertEqual(game.run.coins, 95)
            XCTAssertEqual(game.shop?.rerollCost, 4)
            game.openShop()
            XCTAssertEqual(game.shop?.rerollCost, 0)
        }
    }

    func testPlacementBonusAddsFlatPointsButCluesAndCensorStillScoreZero() throws {
        var game = try started(.overthinking)
        game.give(ad: "bm_local_gossip")
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let digit = game.puzzle!.board.correctDigit(at: square)
        let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertEqual(outcome.points, digit.rawValue * 10 + 10 + 30)

        for isClue in [false, true] {
            var suppressed = try started(.overthinking)
            let target = try XCTUnwrap(suppressed.puzzle?.board.blanks.first)
            let wanted = suppressed.puzzle!.board.correctDigit(at: target)
            let result: PlacementOutcome
            if isClue {
                suppressed.run.puzzle?.cluesRemaining = 1
                result = try suppressed.useClue(at: target)
            } else {
                suppressed.run.puzzle?.boss = .censor
                suppressed.run.puzzle?.censoredDigit = wanted
                result = try suppressed.place(handIndex: XCTUnwrap(suppressed.stackHand(with: wanted)), at: target)
            }
            XCTAssertEqual(result.points, 0)
        }
    }

    func testBoxCoinPaysOnlyPlayerBoxClearsAndRespectsClueAndBossSuppression() throws {
        for boss: BossModifier? in [nil, .mirror, .censor] {
            for isClue in [false, true] {
                var game = try started(.snackBreak)
                let target = try prepareBoxClear(&game)
                let digit = game.puzzle!.board.correctDigit(at: target)
                game.run.puzzle?.boss = boss
                game.run.puzzle?.censoredDigit = digit
                let before = game.run.coins
                let outcome: PlacementOutcome
                if isClue {
                    game.run.puzzle?.cluesRemaining = 1
                    outcome = try game.useClue(at: target)
                } else {
                    outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: target)
                }
                XCTAssertTrue(outcome.lineClears.contains(.box))
                let bonus = !isClue && boss == nil ? 1 : 0
                XCTAssertEqual(outcome.coinsEarned, bonus)
                XCTAssertEqual(game.run.coins - before, bonus)
            }
        }
        let game = try started(.snackBreak)
        for unit in [Unit.row, .col] {
            let context = Resolver.context(.lineClear, run: game.run, puzzle: game.puzzle!, unit: unit)
            XCTAssertEqual(Resolver.dispatch(context, run: game.run, puzzle: game.puzzle!).coins, 0)
        }
    }

    func testUnitBonusScoresEachUnitAndStacksWithoutBypassingTheMirror() throws {
        var game = try started(.smallVictories)
        game.give(ad: "bm_sports_section")
        for unit in [Unit.row, .col, .box] {
            let context = Resolver.context(.lineClear, run: game.run, puzzle: game.puzzle!, unit: unit)
            let result = Resolver.dispatch(context, run: game.run, puzzle: game.puzzle!)
            XCTAssertEqual(result.flat, 15 + 25)
            XCTAssertEqual(Resolver.points(base: 45, result: result, globalAdditive: 0, oneShotDoubler: false), 85)
        }
        for boss: BossModifier? in [nil, .mirror] {
            for isClue in [false, true] {
                var actual = try started(.smallVictories)
                let target = try prepareBoxClear(&actual)
                actual.run.puzzle?.boss = boss
                let digit = actual.puzzle!.board.correctDigit(at: target)
                let outcome: PlacementOutcome
                if isClue {
                    actual.run.puzzle?.cluesRemaining = 1
                    outcome = try actual.useClue(at: target)
                } else {
                    outcome = try actual.place(handIndex: XCTUnwrap(actual.stackHand(with: digit)), at: target)
                }
                XCTAssertFalse(outcome.lineClearPoints.isEmpty)
                XCTAssertTrue(outcome.lineClearPoints.allSatisfy { $0 == (!isClue && boss == nil ? 60 : 0) })
            }
        }
    }

    func testFirstMistakeWaiverSurvivesSaveAndResetsOnlyForTheNextPuzzle() throws {
        var game = try started(.trustMe)
        game.run.puzzle?.boss = .critic
        XCTAssertEqual(try makeWrongPlacement(&game).penalty, 0)
        game = try Game(decoding: game.encoded())
        let second = try makeWrongPlacement(&game)
        XCTAssertGreaterThan(second.penalty, 0)
        XCTAssertEqual(second.penalty % 100, 0, "The Critic still doubles an unprotected penalty")
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        XCTAssertTrue(game.advance())
        try game.startPuzzle()
        XCTAssertEqual(try makeWrongPlacement(&game).penalty, 0)
    }

    func testIvoryDoesNotWasteBookProtectionAndInsuranceRemainsASeparateCharge() throws {
        var game = try started(.trustMe)
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        game.give(marker: Markers.ivory, on: [square])
        XCTAssertEqual(try makeWrongPlacement(&game, at: square).penalty, 0)
        game.run.markers = []
        game.give(buff: "bf_insurance")
        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertEqual(try makeWrongPlacement(&game, at: square).penalty, 0)
        XCTAssertTrue(game.puzzle!.armedFlags.contains(.insurance))
        XCTAssertEqual(try makeWrongPlacement(&game, at: square).penalty, 0)
        XCTAssertFalse(game.puzzle!.armedFlags.contains(.insurance))
        XCTAssertGreaterThan(try makeWrongPlacement(&game, at: square).penalty, 0)
    }

    func testWinCoinIsIncludedInActualPayoutOnlyOnceAndStacksWithPaperRoute() throws {
        var game = try started(.wellEarned)
        game.give(ad: Bookmarks.paperRoute)
        game.qaMeetTarget()
        let before = game.run.coins
        let payout = try game.cashOut()
        XCTAssertEqual(payout.base, 6)
        XCTAssertEqual(payout.paperRoute, 2)
        XCTAssertEqual(game.run.coins, before + payout.total)
        let banked = game.run.coins
        XCTAssertThrowsError(try game.cashOut())
        XCTAssertEqual(game.run.coins, banked)
    }

    private func started(_ book: Book) throws -> Game {
        var game = Game(seed: "book-sidegrade-mechanics", book: book)
        try game.startPuzzle()
        return game
    }

    private func prepareBoxClear(_ game: inout Game) throws -> Square {
        let blanks = Geometry.boxes[0].filter { game.puzzle!.board.isBlank($0) }
        let target = try XCTUnwrap(blanks.last)
        for square in blanks.dropLast() {
            XCTAssertTrue(game.qaPlace(digit: game.puzzle!.board.correctDigit(at: square), at: square))
        }
        return target
    }

    private func makeWrongPlacement(_ game: inout Game, at square: Square? = nil) throws -> PlacementOutcome {
        let target = try XCTUnwrap(square ?? game.puzzle?.board.blanks.first)
        let correct = game.puzzle!.board.correctDigit(at: target)
        let digit = try XCTUnwrap(Digit.all.first { $0 != correct && game.puzzle!.pool[$0] > 0 })
        return try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: target)
    }
}
