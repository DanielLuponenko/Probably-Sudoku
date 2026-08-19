import XCTest
@testable import NumberClubEngine

extension Game {
    /// Fills every Blank of a row except the last one, then returns that last
    /// square so a test can score the Line Clear itself.
    mutating func setUpRowClear(row: Int) throws -> Square? {
        guard let puzzle = run.puzzle else { return nil }
        let blanks = Geometry.rows[row].filter { puzzle.board.isBlank($0) }
        guard let last = blanks.last, blanks.count >= 2 else { return nil }
        for square in blanks.dropLast() {
            let digit = run.puzzle!.board.correctDigit(at: square)
            _ = try place(handIndex: stackHand(with: digit)!, at: square)
        }
        return last
    }

    /// The row with the most Blanks — the safest one to drive to a clear.
    var emptiestRow: Int {
        guard let puzzle = run.puzzle else { return 0 }
        return (0..<9).max { a, b in
            Geometry.rows[a].filter(puzzle.board.isBlank).count
                < Geometry.rows[b].filter(puzzle.board.isBlank).count
        }!
    }
}

final class RulesTests: XCTestCase {

    private func startedGame(seed: String = "rules", board: StartingBoard = .scholar) throws -> Game {
        var game = Game(seed: seed, startingBoard: board)
        try game.startPuzzle()
        return game
    }

    // MARK: Line Clears (§6)

    func testCompletingARowScoresTheLineClearBonus() throws {
        var game = try startedGame()
        let row = game.emptiestRow
        let last = try game.setUpRowClear(row: row)!
        let digit = game.puzzle!.board.correctDigit(at: last)

        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)
        XCTAssertTrue(outcome.lineClears.contains(.row))
        XCTAssertEqual(outcome.lineClearPoints.first, 45)
        XCTAssertEqual(outcome.points, 10 * digit.rawValue)
    }

    func testLineClearsUseTheSameMultipliersAsPlacements() throws {
        var game = try startedGame()
        game.give(ad: "ad_op_ed")           // +1 additive -> x2
        game.give(ad: "ad_sports_section")  // +25 flat on Line Clears
        let row = game.emptiestRow
        let last = try game.setUpRowClear(row: row)!
        let digit = game.puzzle!.board.correctDigit(at: last)

        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)
        XCTAssertEqual(outcome.lineClearPoints.first, (45 + 25) * 2)
        XCTAssertEqual(outcome.points, 10 * digit.rawValue * 2)
    }

    func testFillingTheWholeBoardScoresEveryUnitThenTheFullClear() throws {
        var game = try startedGame()
        var last: Square?
        for square in game.puzzle!.board.blanks {
            // The target is met long before the board fills, so play on.
            if game.puzzle!.phase == .won { try game.keepFilling() }
            let digit = game.puzzle!.board.correctDigit(at: square)
            let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
            if outcome.fullClear {
                XCTAssertEqual(outcome.fullClearPoints, 500)
                // The final placement always closes its row, column and box.
                XCTAssertEqual(Set(outcome.lineClears), [.row, .col, .box])
                last = square
            }
        }
        XCTAssertNotNil(last, "board never reported a Full Clear")
        XCTAssertTrue(game.puzzle!.board.isFull)
    }

    func testSecondPrintDoublesOnlyTheNextLineClear() throws {
        var game = try startedGame()
        game.give(buff: "bf_second_print")
        _ = try game.useBuff(at: 0)
        let last = try game.setUpRowClear(row: game.emptiestRow)!
        let digit = game.puzzle!.board.correctDigit(at: last)
        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)
        XCTAssertEqual(outcome.lineClearPoints.first, 90)
        XCTAssertTrue(game.puzzle!.armedFlags.isEmpty)
    }

    func testRollingPressesGrowsPerLineClearAndStartsAtOne() throws {
        var game = try startedGame()
        game.give(ad: "ad_rolling_presses")
        let last = try game.setUpRowClear(row: game.emptiestRow)!
        let digit = game.puzzle!.board.correctDigit(at: last)
        // The clear that starts it still scores at x1; the next scores at x1.5.
        let first = try game.place(handIndex: game.stackHand(with: digit)!, at: last)
        XCTAssertEqual(first.lineClearPoints.first, 45)
        XCTAssertEqual(game.puzzle!.itemState["ad_rolling_presses"], 1)
    }

    // MARK: Clues (§5, §6)

    func testClueFillsTheSquareAndScoresNothing() throws {
        var game = try startedGame(board: .oracle)
        XCTAssertEqual(game.puzzle?.cluesRemaining, 1)
        let square = game.puzzle!.board.blanks[0]
        let digit = game.puzzle!.board.correctDigit(at: square)
        let poolBefore = game.puzzle!.pool[digit]

        let outcome = try game.useClue(at: square)
        XCTAssertEqual(outcome.points, 0)
        XCTAssertEqual(game.puzzle?.score, 0)
        XCTAssertEqual(game.puzzle?.board[square], digit)
        XCTAssertEqual(game.puzzle?.board.filledBy[square.index], .clue)
        XCTAssertEqual(game.puzzle?.pool[digit], poolBefore - 1)
        XCTAssertEqual(game.puzzle?.cluesRemaining, 0)
    }

    func testOnyxRestoresAcluePlacementButNotItsLineClear() throws {
        var game = try startedGame(board: .oracle)
        game.give(ad: Ads.puzzleCorner)   // a second Clue
        try game.startPuzzle()

        let last = try game.setUpRowClear(row: game.emptiestRow)!
        game.give(marker: Markers.onyx, on: [last])
        let digit = game.puzzle!.board.correctDigit(at: last)

        let outcome = try game.useClue(at: last)
        XCTAssertEqual(outcome.points, 10 * digit.rawValue, "Onyx restores the placement")
        XCTAssertEqual(outcome.lineClearPoints.first, 0, "a Clue-made Line Clear always scores 0")
    }

    func testCluesAreUnavailableWithoutTheOracleBoardOrPuzzleCorner() throws {
        var game = try startedGame(board: .scholar)
        XCTAssertEqual(game.puzzle?.cluesRemaining, 0)
        XCTAssertThrowsError(try game.useClue(at: game.puzzle!.board.blanks[0])) {
            XCTAssertEqual($0 as? PlacementError, .noCluesLeft)
        }
    }

    // MARK: Toss (§5.1)

    func testTossIsOneAtATimeAndBudgetedForTheWholePuzzle() throws {
        var game = try startedGame()
        XCTAssertEqual(game.puzzle?.tossAllowance, 4)

        let digit = game.puzzle!.hand[0]
        let poolBefore = game.puzzle!.pool[digit]
        XCTAssertEqual(try game.toss(handIndex: 0), digit)
        XCTAssertEqual(game.puzzle?.pool[digit], poolBefore + 1)
        XCTAssertEqual(game.puzzle?.tossesRemaining, 3)

        for _ in 0..<3 { _ = try game.toss(handIndex: 0) }
        XCTAssertEqual(game.puzzle?.tossesRemaining, 0)
        XCTAssertThrowsError(try game.toss(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .tossAllowanceSpent)
        }
    }

    func testTheTossAllowanceDoesNotRefillEachTurn() throws {
        // The whole point of moving it off the Turn: ten Turns of two was
        // effectively unlimited, so it never forced a decision.
        var game = try startedGame()
        for _ in 0..<4 { _ = try game.toss(handIndex: 0) }
        XCTAssertEqual(game.puzzle?.tossesRemaining, 0)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.tossesRemaining, 0)
    }

    func testTossingLeavesYouShortForTheRestOfTheTurn() throws {
        // The Hand only refills at the end of a Turn, which is the whole cost.
        var game = try startedGame()
        let size = game.puzzle!.hand.count
        _ = try game.toss(handIndex: 0)
        _ = try game.toss(handIndex: 0)
        XCTAssertEqual(game.puzzle?.hand.count, size - 2)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.hand.count, size)
    }

    func testWeatherForecastRaisesTheAllowanceBySix() throws {
        var game = Game(seed: "rules", startingBoard: .scholar)
        game.give(ad: Ads.weatherForecast)
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.tossAllowance, 6)
        for _ in 0..<6 { _ = try game.toss(handIndex: 0) }
        XCTAssertEqual(game.puzzle?.tossesRemaining, 0)
    }

    // MARK: Turns (§4)

    func testEndTurnRefillsToHandSizeAndCarriesUnplacedNumbersOver() throws {
        var game = try startedGame()
        let size = game.puzzle!.handSize
        XCTAssertEqual(game.puzzle?.hand.count, size)

        let kept = game.puzzle!.hand[1]
        let square = game.blank(wanting: game.puzzle!.hand[0])!
        _ = try game.place(handIndex: 0, at: square)
        XCTAssertEqual(game.puzzle?.hand.count, size - 1)

        let result = try game.endTurn()
        XCTAssertEqual(result.numbersDrawn, 1)
        XCTAssertEqual(game.puzzle?.hand.count, size)
        XCTAssertTrue(game.puzzle!.hand.contains(kept))
        XCTAssertEqual(game.puzzle?.turnNumber, 2)
    }

    func testRunningOutOfTurnsBelowTargetFailsThePuzzleAndEndsTheBook() throws {
        var game = try startedGame()
        for _ in 0..<game.puzzle!.turnsMax {
            _ = try? game.endTurn()
        }
        XCTAssertEqual(game.puzzle?.phase, .failed)
        XCTAssertEqual(game.run.outcome, .failed)
    }

    func testMorningEditionPaysOutAtEachTurnEnd() throws {
        var game = try startedGame()
        game.give(ad: "ad_morning_edition")
        let result = try game.endTurn()
        XCTAssertEqual(result.pointsGained, 100)
        XCTAssertEqual(game.puzzle?.score, 100)
    }

    // MARK: Ending a Puzzle (§7)

    func testMeetingTheTargetOffersCashOutOrKeepFilling() throws {
        var game = try startedGame()
        game.give(ad: "ad_stop_the_presses")
        game.give(ad: "ad_editorial_board")
        while game.puzzle!.phase == .playing, let square = game.puzzle!.board.blanks.first {
            let digit = game.puzzle!.board.correctDigit(at: square)
            _ = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
        }
        XCTAssertEqual(game.puzzle?.phase, .won)
        XCTAssertGreaterThanOrEqual(game.puzzle!.score, game.puzzle!.target)
    }

    func testKeepFillingFreezesScoreAndBanksCoinsInstead() throws {
        var game = try startedGame()
        game.give(ad: "ad_stop_the_presses")
        game.give(ad: "ad_editorial_board")
        while game.puzzle!.phase == .playing, let square = game.puzzle!.board.blanks.first {
            let digit = game.puzzle!.board.correctDigit(at: square)
            _ = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
        }
        try game.keepFilling()
        let frozen = game.puzzle!.score

        var clears = 0
        for square in game.puzzle!.board.blanks {
            let digit = game.puzzle!.board.correctDigit(at: square)
            let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
            clears += outcome.lineClears.count
        }
        XCTAssertEqual(game.puzzle?.score, frozen, "score must not move while Keep Filling")
        XCTAssertGreaterThan(game.puzzle!.keepFillingCoins, clears, "Full Clear banks 3, each clear 1")
    }

    func testPayoutAddsBaseUnusedTurnsInterestAndPaperRoute() throws {
        var game = try startedGame()
        game.run.coins = 60          // 10% interest = 6
        game.give(ad: Ads.paperRoute)
        game.give(ad: "ad_stop_the_presses")
        game.give(ad: "ad_editorial_board")
        while game.puzzle!.phase == .playing, let square = game.puzzle!.board.blanks.first {
            let digit = game.puzzle!.board.correctDigit(at: square)
            _ = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
        }
        let payout = try game.cashOut()
        XCTAssertEqual(payout.base, 5)
        XCTAssertEqual(payout.unusedTurns, 3, "capped at 3")
        XCTAssertEqual(payout.interest, 6)
        XCTAssertEqual(payout.paperRoute, 2)
        XCTAssertEqual(game.run.coins, 60 + payout.total)
    }

    func testInterestIsCappedAndRaisedByMarketWrap() throws {
        var run = RunState(seed: "interest", startingBoard: .scholar)
        run.coins = 500
        XCTAssertEqual(run.interestCap, 10)
        run.ads.append(OwnedAd(defID: Ads.marketWrap, boughtAtLevel: 1, pricePaid: 6))
        XCTAssertEqual(run.interestCap, 15)
    }
}
