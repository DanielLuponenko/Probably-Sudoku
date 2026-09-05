import XCTest
@testable import ProbablySudokuEngine

/// Complements the hook matrix with the real consume/place/bank paths. A hook
/// can be correct while an action never calls it, drops it, or broadens its scope.
final class CatalogActionIntegrationTests: XCTestCase {
    private func startedGame() throws -> Game {
        var game = Game(seed: "catalog-real-actions", book: .noPressure)
        try game.startPuzzle()
        return game
    }

    func testEveryBuffIsConsumedAndItsEffectReachesSavedGameplayState() throws {
        let handled: Set<String> = [Buffs.peek, Buffs.redraw, "bf_overtime", "bf_double_down",
            "bf_insurance", "bf_second_print", "bf_lucky_dip", Buffs.birdSeed,
            Buffs.freshInk, Buffs.litmus, Buffs.paperCrane]
        XCTAssertEqual(Set(Buffs.all.map(\.id)), handled)
        let fixture = try startedGame()
        for id in handled.sorted() {
            var game = fixture
            game.give(buff: id)
            let before = try XCTUnwrap(game.puzzle)
            XCTAssertTrue(try game.useBuff(at: 0, digit: .five), id)
            XCTAssertTrue(game.run.buffs.isEmpty, id)
            game = try Game(decoding: game.encoded())
            let after = try XCTUnwrap(game.puzzle)
            switch id {
            case Buffs.peek: XCTAssertEqual(after.cluesRemaining, before.cluesRemaining + 1)
            case Buffs.redraw:
                XCTAssertEqual(after.hand.count, before.handSize)
                XCTAssertEqual(after.tossedThisPuzzle, before.tossedThisPuzzle)
                XCTAssertNotEqual(game.run.streams.pool.state, fixture.run.streams.pool.state)
            case "bf_overtime": XCTAssertEqual(after.turnsMax, before.turnsMax + 2)
            case "bf_double_down": XCTAssertTrue(after.armedFlags.contains(.doubleDown))
            case "bf_insurance": XCTAssertTrue(after.armedFlags.contains(.insurance))
            case "bf_second_print": XCTAssertTrue(after.armedFlags.contains(.secondPrint))
            case "bf_lucky_dip": XCTAssertEqual(after.hand.count, before.hand.count + 2)
            case Buffs.birdSeed: XCTAssertEqual(game.run.runItemState[id], Double(game.run.level))
            case Buffs.freshInk: XCTAssertEqual(after.pendingMultiplier, before.pendingMultiplier + 2)
            case Buffs.litmus: XCTAssertTrue(after.armedFlags.contains(.litmus))
            case Buffs.paperCrane:
                XCTAssertEqual(after.itemState[Buffs.paperCraneKey(.five)], 50)
                let square = try XCTUnwrap(game.blank(wanting: .five))
                let placed = try game.place(handIndex: XCTUnwrap(game.stackHand(with: .five)), at: square)
                XCTAssertEqual(placed.points, 100)
            default: XCTFail("Missing action expectation for \(id)")
            }
            game.puzzle?.assertConservation()
        }
    }

    private func markerAction(_ game: inout Game, id: String, square: Square) throws -> PlacementOutcome {
        if id == Markers.onyx { return try game.useClue(at: square) }
        let solution = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        let wrong = id == Markers.ivory || id == Markers.jade
        let digit = wrong ? (solution == .one ? Digit.two : .one) : solution
        return try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
    }

    func testEveryMarkerChangesOnlyItsOwnedSquareThroughRealActions() throws {
        let handled: Set<String> = ["mk_crimson", "mk_golden", "mk_azure", Markers.ivory,
            "mk_emerald", Markers.onyx, "mk_silver", "mk_sapphire", Markers.rose,
            "mk_copper", "mk_violet", Markers.jade]
        XCTAssertEqual(Set(Markers.all.map(\.id)), handled)
        let fixture = try startedGame()
        for id in handled.sorted() {
            var baseline = fixture
            let square: Square
            if id == "mk_emerald" || id == "mk_copper" {
                square = try XCTUnwrap(baseline.setUpRowClear(row: baseline.emptiestRow))
            } else {
                square = try XCTUnwrap(baseline.puzzle?.board.blanks.first)
            }
            let digit = try XCTUnwrap(baseline.puzzle?.board.correctDigit(at: square))
            let copies = try XCTUnwrap(baseline.puzzle?.board.count(of: digit))
            var marked = baseline
            var elsewhere = baseline
            marked.give(marker: id, on: [square])
            let otherSquare = try XCTUnwrap(baseline.puzzle?.board.blanks.first { $0 != square })
            elsewhere.give(marker: id, on: [otherSquare])
            let ordinary = try markerAction(&baseline, id: id, square: square)
            let unrelated = try markerAction(&elsewhere, id: id, square: square)
            XCTAssertEqual(unrelated, ordinary, "\(id) must not fire off its square")
            XCTAssertEqual(elsewhere.run.coins, baseline.run.coins, id)
            XCTAssertEqual(elsewhere.puzzle?.hand, baseline.puzzle?.hand, id)
            XCTAssertEqual(elsewhere.puzzle?.itemState, baseline.puzzle?.itemState, id)
            let outcome = try markerAction(&marked, id: id, square: square)
            switch id {
            case "mk_crimson": XCTAssertEqual(outcome.points, ordinary.points * 4)
            case "mk_golden": XCTAssertEqual(outcome.points, ordinary.points + 100)
            case "mk_azure": XCTAssertEqual(marked.run.coins, baseline.run.coins + 1)
            case Markers.ivory: XCTAssertEqual(outcome.penalty, 0)
            case "mk_emerald": XCTAssertEqual(outcome.lineClearPoints, ordinary.lineClearPoints.map { $0 * 2 })
            case Markers.onyx: XCTAssertEqual(outcome.points, digit.rawValue * 10)
            case "mk_silver": XCTAssertEqual(outcome.points, ordinary.points + 20 * copies)
            case "mk_sapphire": XCTAssertEqual(marked.puzzle?.hand.count, baseline.puzzle!.hand.count + 1)
            case Markers.rose: XCTAssertEqual(marked.puzzle?.itemState[Markers.rose], 1)
            case "mk_copper": XCTAssertEqual(marked.run.coins, baseline.run.coins + outcome.lineClears.count * 3)
            case "mk_violet": XCTAssertEqual(outcome.points, 90)
            case Markers.jade:
                XCTAssertTrue(outcome.returnedToHand)
                XCTAssertEqual(marked.puzzle?.hand.count, baseline.puzzle!.hand.count + 1)
            default: XCTFail("Missing action expectation for \(id)")
            }
            marked.puzzle?.assertConservation()
        }
    }

    func testPlacementAndTurnBookmarkMatrix() throws {
        let cases: [(String, Int, Double, Int)] = [
            ("bm_morning_edition", 0, 1, 100), ("bm_evening_edition", 0, 1, 300),
            ("bm_local_gossip", 30, 1, 0), ("bm_op_ed", 0, 2, 0),
            ("bm_editorial_board", 0, 3, 0), ("bm_front_page_splash", 0, 2, 0),
            ("bm_letters_to_the_editor", 0, 1, 0), (Bookmarks.rollingPresses, 0, 2, 0),
            (Bookmarks.syndication, 0, 2, 0), ("bm_stop_the_presses", 0, 3, 0),
            ("bm_the_sunday_supplement", 0, 2, 0),
        ]
        let fixture = try startedGame()
        for (id, flat, multiplier, direct) in cases {
            var game = fixture
            game.give(ad: id)
            if id == Bookmarks.rollingPresses { game.run.puzzle?.itemState[id] = 2 }
            if id == Bookmarks.syndication { game.run.runItemState[id] = 4 }
            if id == "bm_evening_edition" { game.run.puzzle?.turnNumber = 10 }
            let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            XCTAssertTrue(outcome.lineClears.isEmpty, id)
            XCTAssertEqual(outcome.points, digit.rawValue * 10 + flat, id)
            XCTAssertEqual(game.puzzle?.pendingMultiplier, multiplier, id)
            game = try Game(decoding: game.encoded())
            _ = try game.endTurn()
            XCTAssertEqual(game.puzzle?.score, Int(Double(outcome.points) * multiplier) + direct, id)
        }
    }

    func testClearAndStandingBookmarkMatrixCoversTheRestOfTheCatalog() throws {
        let placementIDs: Set<String> = ["bm_morning_edition", "bm_evening_edition", "bm_local_gossip",
            "bm_op_ed", "bm_editorial_board", "bm_front_page_splash", "bm_letters_to_the_editor",
            Bookmarks.rollingPresses, Bookmarks.syndication, "bm_stop_the_presses", "bm_the_sunday_supplement"]
        let clearIDs: Set<String> = ["bm_sports_section", "bm_society_pages", "bm_extra_extra",
            "bm_finance_pages", "bm_crossword_daily"]
        let standingIDs: Set<String> = [Bookmarks.paperRoute, Bookmarks.marketWrap, Bookmarks.auctionNotices,
            Bookmarks.helpWanted, Bookmarks.weatherForecast, Bookmarks.puzzleCorner, Bookmarks.lateCityFinal]
        XCTAssertEqual(Set(Bookmarks.all.map(\.id)), placementIDs.union(clearIDs).union(standingIDs))
        let fixture = try startedGame()
        for id in clearIDs.sorted() {
            var game = fixture
            let last: Square
            if id == "bm_society_pages" {
                last = try XCTUnwrap(game.puzzle?.board.blanks.last)
                for square in try XCTUnwrap(game.puzzle).board.blanks where square != last {
                    if game.puzzle?.phase == .won { try game.keepFilling() }
                    let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
                    _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
                }
            } else {
                last = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
            }
            if game.puzzle?.phase == .won { try game.keepFilling() }
            game.give(ad: id)
            let beforeCoins = game.run.coins
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: last))
            let handIndex = try XCTUnwrap(game.stackHand(with: digit))
            let beforeHand = try XCTUnwrap(game.puzzle?.hand.count)
            let outcome = try game.place(handIndex: handIndex, at: last)
            XCTAssertFalse(outcome.lineClears.isEmpty, id)
            switch id {
            case "bm_sports_section": XCTAssertEqual(outcome.lineClearPoints, Array(repeating: 70, count: outcome.lineClears.count))
            case "bm_society_pages": XCTAssertEqual(outcome.fullClearPoints, 1_000)
            case "bm_extra_extra": XCTAssertEqual(outcome.lineClearPoints, Array(repeating: 135, count: outcome.lineClears.count))
            case "bm_finance_pages": XCTAssertEqual(game.run.coins, beforeCoins + outcome.lineClears.count)
            case "bm_crossword_daily": XCTAssertEqual(game.puzzle?.hand.count, beforeHand - 1 + outcome.lineClears.count)
            default: XCTFail(id)
            }
        }
        for id in standingIDs.sorted() {
            var game = fixture
            game.give(ad: id)
            game.run.coins = 200
            try game.startPuzzle()
            let puzzle = try XCTUnwrap(game.puzzle)
            switch id {
            case Bookmarks.helpWanted: XCTAssertEqual(puzzle.hand.count, fixture.puzzle!.hand.count + 1)
            case Bookmarks.weatherForecast: XCTAssertEqual(puzzle.tossAllowance, fixture.puzzle!.tossAllowance + 2)
            case Bookmarks.puzzleCorner: XCTAssertEqual(puzzle.cluesRemaining, fixture.puzzle!.cluesRemaining + 1)
            case Bookmarks.lateCityFinal: XCTAssertEqual(puzzle.turnsMax, fixture.puzzle!.turnsMax + 1)
            case Bookmarks.paperRoute, Bookmarks.marketWrap:
                game.run.puzzle?.phase = .won
                let payout = try game.cashOut()
                XCTAssertEqual(payout.paperRoute, id == Bookmarks.paperRoute ? 2 : 0)
                XCTAssertEqual(payout.interest, id == Bookmarks.marketWrap ? 15 : 10)
            case Bookmarks.auctionNotices:
                game.openShop()
                try game.reroll()
                XCTAssertEqual(game.run.coins, 200)
                XCTAssertEqual(game.shop?.rerollCost, 2)
            default: XCTFail(id)
            }
        }
    }

    func testBossConditionalBookmarksReachTheActualTurnBank() throws {
        for slot in [PuzzleSlot.easy, .boss] {
            var fixture = Game(seed: "catalog-boss-bank")
            fixture.run.slot = slot
            try fixture.startPuzzle()
            fixture.run.puzzle?.boss = nil
            fixture.run.puzzle?.bossTurn = nil
            for (id, multiplier) in [
                ("bm_letters_to_the_editor", slot == .boss ? 4 : 1),
                ("bm_the_sunday_supplement", slot == .boss ? 3 : 2),
            ] {
                var game = fixture
                game.give(ad: id)
                let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
                let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
                let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
                XCTAssertTrue(outcome.lineClears.isEmpty)
                XCTAssertEqual(outcome.points, 10 * digit.rawValue, id)
                XCTAssertEqual(game.puzzle?.pendingMultiplier, Double(multiplier), "\(id), \(slot)")
                _ = try game.endTurn()
                XCTAssertEqual(game.puzzle?.score, 10 * digit.rawValue * multiplier, "\(id), \(slot)")
            }
        }
    }

    func testRollingPressesGrowsFromRealClearsAndResetsForANewPuzzle() throws {
        var game = try startedGame()
        game.run.puzzle?.target = 1_000_000
        game.give(ad: Bookmarks.rollingPresses)
        for _ in 0..<2 {
            let square = try XCTUnwrap(game.setUpRowClear(row: game.emptiestRow))
            let beforeState = game.puzzle?.itemState[Bookmarks.rollingPresses] ?? 0
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            let outcome = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            let clearCount = Double(outcome.lineClears.count)
            XCTAssertGreaterThan(clearCount, 0)
            XCTAssertEqual(game.puzzle?.itemState[Bookmarks.rollingPresses], beforeState + clearCount)
            XCTAssertEqual(game.puzzle?.pendingMultiplier, 1 + 0.5 * (beforeState + clearCount - 1),
                           "The last Clear sees only previously completed units")
            let expectedScore = try XCTUnwrap(game.puzzle?.score) + XCTUnwrap(game.puzzle?.pendingScore)
            _ = try game.endTurn()
            XCTAssertEqual(game.puzzle?.score, expectedScore)
        }
        XCTAssertGreaterThanOrEqual(game.puzzle?.itemState[Bookmarks.rollingPresses] ?? 0, 2)
        game = try Game(decoding: game.encoded())
        try game.startPuzzle()
        XCTAssertNil(game.puzzle?.itemState[Bookmarks.rollingPresses])
        let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
        let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
        _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
        XCTAssertEqual(game.puzzle?.pendingMultiplier, 1)
    }

    func testSyndicationGrowsFromActualWinsAndResetsOnlyForANewBook() throws {
        var game = try startedGame()
        game.give(ad: Bookmarks.syndication)
        for winsBefore in 0..<2 {
            while let puzzle = game.puzzle, puzzle.phase == .playing,
                  puzzle.score + puzzle.pendingScore < puzzle.target {
                let square = try XCTUnwrap(puzzle.board.blanks.first)
                let digit = puzzle.board.correctDigit(at: square)
                _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            }
            if game.puzzle?.phase == .playing { _ = try game.endTurn() }
            XCTAssertEqual(game.puzzle?.phase, .won)
            XCTAssertEqual(game.run.runItemState[Bookmarks.syndication] ?? 0, Double(winsBefore))
            _ = try game.cashOut()
            XCTAssertEqual(game.run.runItemState[Bookmarks.syndication], Double(winsBefore + 1))
            game = try Game(decoding: game.encoded())
            game.openShop()
            XCTAssertTrue(game.advance())
            try game.startPuzzle()
            // Remove the announced Boss only to isolate the advertised Bookmark multiplier.
            game.run.puzzle?.boss = nil
            game.run.puzzle?.bossTurn = nil
            let square = try XCTUnwrap(game.puzzle?.board.blanks.first)
            let digit = try XCTUnwrap(game.puzzle?.board.correctDigit(at: square))
            _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
            XCTAssertEqual(game.puzzle?.pendingMultiplier, 1 + 0.25 * Double(winsBefore + 1))
        }
        var newBook = try startedGame()
        newBook.give(ad: Bookmarks.syndication)
        XCTAssertNil(newBook.run.runItemState[Bookmarks.syndication])
        let square = try XCTUnwrap(newBook.puzzle?.board.blanks.first)
        let digit = try XCTUnwrap(newBook.puzzle?.board.correctDigit(at: square))
        _ = try newBook.place(handIndex: XCTUnwrap(newBook.stackHand(with: digit)), at: square)
        XCTAssertEqual(newBook.puzzle?.pendingMultiplier, 1)
    }
}
