import XCTest
@testable import NumberClubEngine

/// Helpers for driving a Puzzle deterministically without going through the
/// random Hand, so a test can assert on one placement in isolation.
extension Game {
    /// Forces `digit` into the Hand, taking it from the Pool so conservation
    /// still holds, and returns its index.
    mutating func stackHand(with digit: Digit) -> Int? {
        guard var puzzle = run.puzzle else { return nil }
        guard puzzle.pool.take(digit) else {
            return puzzle.hand.firstIndex(of: digit)
        }
        puzzle.hand.append(digit)
        run.puzzle = puzzle
        return puzzle.hand.count - 1
    }

    /// The first Blank whose solution is `digit`.
    func blank(wanting digit: Digit) -> Square? {
        guard let puzzle = run.puzzle else { return nil }
        return puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) == digit }
    }

    mutating func give(ad id: String) {
        run.bookmarks.append(OwnedBookmark(defID: id, boughtAtLevel: run.level, pricePaid: 0))
    }
    mutating func give(marker id: String, on squares: [Square]) {
        run.markers.append(OwnedMarker(defID: id, boughtAtLevel: run.level,
                                       pricePaid: 0, squares: squares))
    }
    mutating func give(buff id: String) {
        run.buffs.append(OwnedBuff(defID: id, pricePaid: 0))
    }
}

final class ScoringTests: XCTestCase {

    private func startedGame(seed: String = "scoring", board: StartingBoard = .scholar) throws -> Game {
        var game = Game(seed: seed, startingBoard: board)
        try game.startPuzzle()
        return game
    }

    /// Fill all the currently blank cells in `cells` except `last`, retaining
    /// a playable Puzzle even if setup reaches the target score.
    private func setUpClear(_ game: inout Game, cells: [Square], leaving last: Square) throws {
        for square in cells where square != last && game.puzzle!.board.isBlank(square) {
            if game.puzzle!.phase == .won { try game.keepFilling() }
            let digit = game.puzzle!.board.correctDigit(at: square)
            _ = try game.place(handIndex: game.stackHand(with: digit)!, at: square)
        }
    }

    // MARK: Base scoring

    func testCorrectPlacementScoresTenTimesTheNumber() throws {
        var game = try startedGame()
        let square = game.blank(wanting: .seven)!
        let index = game.stackHand(with: .seven)!
        let outcome = try game.place(handIndex: index, at: square)

        XCTAssertTrue(outcome.correct)
        XCTAssertEqual(outcome.points, 70)
        XCTAssertEqual(game.puzzle?.pendingBase, 70)
        XCTAssertEqual(game.puzzle?.score, 0)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 70)
    }

    func testWrongPlacementSubtractsFiftyTimesTheNumberAndReturnsItToThePool() throws {
        var game = try startedGame()
        // Bank enough first that the floor at 0 cannot hide the penalty.
        game.give(ad: "bm_stop_the_presses")            // x3
        let good = game.blank(wanting: .nine)!
        _ = try game.place(handIndex: game.stackHand(with: .nine)!, at: good)
        _ = try game.endTurn()
        let before = game.puzzle!.score
        XCTAssertEqual(before, 270)

        let target = game.blank(wanting: .one)!
        let wrongDigit: Digit = game.puzzle!.board.correctDigit(at: target) == .four ? .five : .four
        let poolBefore = game.puzzle!.pool[wrongDigit]
        let outcome = try game.place(handIndex: game.stackHand(with: wrongDigit)!, at: target)

        XCTAssertFalse(outcome.correct)
        XCTAssertEqual(outcome.penalty, 50 * wrongDigit.rawValue)
        XCTAssertEqual(game.puzzle?.score, before - 50 * wrongDigit.rawValue)
        XCTAssertEqual(game.puzzle?.pool[wrongDigit], poolBefore)   // taken out, put back
        XCTAssertTrue(game.puzzle!.board.isBlank(target))
    }

    func testScoreNeverDropsBelowZero() throws {
        var game = try startedGame()
        let target = game.blank(wanting: .one)!
        let wrong: Digit = game.puzzle!.board.correctDigit(at: target) == .nine ? .eight : .nine
        _ = try game.place(handIndex: game.stackHand(with: wrong)!, at: target)
        XCTAssertEqual(game.puzzle?.score, 0)
    }

    // MARK: The formula (§6)

    func testAdditiveMultAccumulatesIntoOnePool() throws {
        // Two "+1 mult" Bookmarks give x3, not x4.
        var game = try startedGame()
        game.give(ad: "bm_op_ed")
        game.give(ad: "bm_op_ed")
        let square = game.blank(wanting: .five)!
        let outcome = try game.place(handIndex: game.stackHand(with: .five)!, at: square)
        XCTAssertEqual(outcome.points, 50)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 3)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 50 * 3)
    }

    func testMultiplicativeMultMultipliesWithTheAdditiveTotal() throws {
        var game = try startedGame()
        game.give(ad: "bm_op_ed")             // +1 additive  -> x2
        game.give(ad: "bm_stop_the_presses")  // x3 multiplicative
        let square = game.blank(wanting: .five)!
        let outcome = try game.place(handIndex: game.stackHand(with: .five)!, at: square)
        XCTAssertEqual(outcome.points, 50)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 6)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 50 * 2 * 3)
    }

    func testFlatBonusesAddBeforeMultiplication() throws {
        var game = try startedGame()
        game.give(ad: "bm_local_gossip")   // +30 flat
        game.give(ad: "bm_op_ed")          // x2
        let square = game.blank(wanting: .four)!
        let outcome = try game.place(handIndex: game.stackHand(with: .four)!, at: square)
        XCTAssertEqual(outcome.points, 40 + 30)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, (40 + 30) * 2)
    }

    func testFrontPageSplashCountsItself() throws {
        var game = try startedGame()
        game.give(ad: "bm_local_gossip")
        game.give(ad: "bm_front_page_splash")   // +1 mult per Bookmark owned = +2
        let square = game.blank(wanting: .one)!
        let outcome = try game.place(handIndex: game.stackHand(with: .one)!, at: square)
        XCTAssertEqual(outcome.points, 10 + 30)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, (10 + 30) * 3)
    }

    func testTurnBankComposesFreshInkHeldMultAndSashimi() throws {
        var game = try startedGame()
        game.give(ad: "bm_op_ed")             // +1 additive
        game.give(ad: "bm_stop_the_presses")  // x3 multiplicative
        game.give(buff: Buffs.freshInk)         // +2 additive for this Puzzle
        _ = try game.useBuff(at: 0)
        game.run.puzzle?.boss = .sashimi

        let square = game.blank(wanting: .five)!
        _ = try game.place(handIndex: game.stackHand(with: .five)!, at: square)
        // Held items collect as x6; Fresh Ink adds +2 and Sashimi halves the
        // completed Turn, making the displayed and banked multiplier x4.
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 4)
        _ = try game.endTurn()
        XCTAssertEqual(game.puzzle?.score, 50 * 4)
    }

    func testWrongPlacementDrainsQueuedWorkBeforeBankedScore() throws {
        var game = try startedGame()
        _ = try game.place(handIndex: game.stackHand(with: .five)!,
                           at: game.blank(wanting: .five)!)
        XCTAssertEqual(game.puzzle?.pendingBase, 50)

        let square = game.blank(wanting: .one)!
        let wrong: Digit = game.puzzle!.board.correctDigit(at: square) == .four ? .five : .four
        _ = try game.place(handIndex: game.stackHand(with: wrong)!, at: square)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        XCTAssertEqual(game.puzzle?.score, 0)
    }

    // MARK: Markers are positional (§11)

    func testMarkerFiresOnItsOwnSquareOnly() throws {
        var game = try startedGame()
        let marked = game.blank(wanting: .three)!
        let unmarked = game.puzzle!.board.blanks.first {
            $0 != marked && game.puzzle!.board.correctDigit(at: $0) == .three
        }!
        game.give(marker: "mk_golden", on: [marked])   // +100 points

        let onMarked = try game.place(handIndex: game.stackHand(with: .three)!, at: marked)
        XCTAssertEqual(onMarked.points, 10 * 3 + 100)

        let offMarked = try game.place(handIndex: game.stackHand(with: .three)!, at: unmarked)
        XCTAssertEqual(offMarked.points, 10 * 3)
    }

    func testCrimsonMarkerMultipliesWhateverLandsOnIt() throws {
        var game = try startedGame()
        let square = game.blank(wanting: .two)!
        game.give(marker: "mk_crimson", on: [square])
        let outcome = try game.place(handIndex: game.stackHand(with: .two)!, at: square)
        XCTAssertEqual(outcome.points, 20 * 4)
    }

    func testVioletMarkerScoresTheNumberAsANine() throws {
        var game = try startedGame()
        let square = game.blank(wanting: .one)!
        game.give(marker: "mk_violet", on: [square])
        let outcome = try game.place(handIndex: game.stackHand(with: .one)!, at: square)
        XCTAssertEqual(outcome.points, 90)
    }

    func testIvoryMarkerCancelsTheWrongPlacementPenalty() throws {
        var game = try startedGame()
        _ = try game.place(handIndex: game.stackHand(with: .nine)!, at: game.blank(wanting: .nine)!)
        let before = game.puzzle!.score

        let square = game.blank(wanting: .one)!
        let wrong: Digit = game.puzzle!.board.correctDigit(at: square) == .six ? .seven : .six
        game.give(marker: "mk_ivory", on: [square])
        let outcome = try game.place(handIndex: game.stackHand(with: wrong)!, at: square)

        XCTAssertEqual(outcome.penalty, 0)
        XCTAssertEqual(game.puzzle?.score, before)
    }

    func testJadeMarkerReturnsAWrongNumberToTheHand() throws {
        var game = try startedGame()
        let square = game.blank(wanting: .one)!
        let wrong: Digit = game.puzzle!.board.correctDigit(at: square) == .six ? .seven : .six
        game.give(marker: "mk_jade", on: [square])

        let index = game.stackHand(with: wrong)!
        let poolBefore = game.puzzle!.pool[wrong]
        let outcome = try game.place(handIndex: index, at: square)

        XCTAssertTrue(outcome.returnedToHand)
        XCTAssertTrue(game.puzzle!.hand.contains(wrong))
        XCTAssertEqual(game.puzzle?.pool[wrong], poolBefore)
    }

    func testSilverMarkerCountsCopiesAlreadyLockedIncludingGivens() throws {
        var game = try startedGame()
        let square = game.blank(wanting: .eight)!
        let alreadyOnBoard = game.puzzle!.board.count(of: .eight)
        game.give(marker: "mk_silver", on: [square])
        let outcome = try game.place(handIndex: game.stackHand(with: .eight)!, at: square)
        XCTAssertEqual(outcome.points, 80 + 20 * alreadyOnBoard)
    }

    func testCopperPaysThreeCoinsForOneCompletedRow() throws {
        var game = try startedGame()
        let row = game.emptiestRow
        let blanks = Geometry.rows[row].filter(game.puzzle!.board.isBlank)
        let last = try XCTUnwrap(blanks.last)
        try setUpClear(&game, cells: Geometry.rows[row], leaving: last)
        game.give(marker: "mk_copper", on: [last])
        let coinsBefore = game.run.coins

        let digit = game.puzzle!.board.correctDigit(at: last)
        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)

        XCTAssertEqual(outcome.lineClears, [.row])
        XCTAssertEqual(outcome.coinsEarned, 3)
        XCTAssertEqual(game.run.coins, coinsBefore + 3)
    }

    func testCopperPaysThreeCoinsForOneCompletedBox() throws {
        var game = try startedGame()
        let box = (0..<9).max { a, b in
            Geometry.boxes[a].filter(game.puzzle!.board.isBlank).count
                < Geometry.boxes[b].filter(game.puzzle!.board.isBlank).count
        }!
        let blanks = Geometry.boxes[box].filter(game.puzzle!.board.isBlank)
        let last = try XCTUnwrap(blanks.last)
        try setUpClear(&game, cells: Geometry.boxes[box], leaving: last)
        game.give(marker: "mk_copper", on: [last])
        let coinsBefore = game.run.coins

        let digit = game.puzzle!.board.correctDigit(at: last)
        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)

        XCTAssertEqual(outcome.lineClears, [.box])
        XCTAssertEqual(outcome.coinsEarned, 3)
        XCTAssertEqual(game.run.coins, coinsBefore + 3)
    }

    func testCopperPaysForEveryUnitInASimultaneousRowAndBoxClear() throws {
        var game = try startedGame()
        let puzzle = try XCTUnwrap(game.puzzle)
        let last = try XCTUnwrap(puzzle.board.blanks.first { square in
            let rowAndBox = Set(Geometry.rows[square.row] + Geometry.boxes[square.box])
            return Geometry.rows[square.row].filter(puzzle.board.isBlank).count >= 2
                && Geometry.boxes[square.box].filter(puzzle.board.isBlank).count >= 2
                && Geometry.cols[square.col].filter(puzzle.board.isBlank).contains {
                    !rowAndBox.contains($0)
                }
        })
        let rowAndBox = Array(Set(Geometry.rows[last.row] + Geometry.boxes[last.box]))
        try setUpClear(&game, cells: rowAndBox, leaving: last)
        game.give(marker: "mk_copper", on: [last])
        let coinsBefore = game.run.coins

        let digit = game.puzzle!.board.correctDigit(at: last)
        let outcome = try game.place(handIndex: game.stackHand(with: digit)!, at: last)

        XCTAssertEqual(Set(outcome.lineClears), [.row, .box])
        XCTAssertEqual(outcome.coinsEarned, 6)
        XCTAssertEqual(game.run.coins, coinsBefore + 6)
    }

    func testMarkerStacksOneSquarePerLevelOwned() {
        let marker = OwnedMarker(defID: "mk_golden", boughtAtLevel: 1, pricePaid: 5)
        XCTAssertEqual(marker.entitledSquares(atLevel: 1), 1)
        XCTAssertEqual(marker.entitledSquares(atLevel: 2), 2)
        XCTAssertEqual(marker.entitledSquares(atLevel: 9), 9)
        // Buying at Level 8 is worth far less than buying the same Marker early.
        let late = OwnedMarker(defID: "mk_golden", boughtAtLevel: 8, pricePaid: 5)
        XCTAssertEqual(late.entitledSquares(atLevel: 9), 2)
    }

    func testTwoMarkersMayNotShareASquare() throws {
        var run = RunState(seed: "squares", startingBoard: .scholar)
        run.markers = [OwnedMarker(defID: "mk_golden", boughtAtLevel: 1, pricePaid: 5),
                       OwnedMarker(defID: "mk_azure", boughtAtLevel: 1, pricePaid: 5)]
        try Shop.claimSquare(&run, markerIndex: 0, square: Square(40))
        XCTAssertThrowsError(try Shop.claimSquare(&run, markerIndex: 1, square: Square(40))) {
            XCTAssertEqual($0 as? Shop.MarkerError, .squareTaken)
        }
    }

    func testMovingAPlacedSquareCostsTwoCoins() throws {
        var run = RunState(seed: "squares", startingBoard: .scholar)
        run.markers = [OwnedMarker(defID: "mk_golden", boughtAtLevel: 1, pricePaid: 5,
                                   squares: [Square(40)])]
        run.coins = 3
        try Shop.moveSquare(&run, markerIndex: 0, from: Square(40), to: Square(41))
        XCTAssertEqual(run.coins, 1)
        XCTAssertEqual(run.markers[0].squares, [Square(41)])
        XCTAssertThrowsError(try Shop.moveSquare(&run, markerIndex: 0, from: Square(41), to: Square(42)))
    }
}
