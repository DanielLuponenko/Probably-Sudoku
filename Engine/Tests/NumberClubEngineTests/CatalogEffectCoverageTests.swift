import XCTest
@testable import ProbablySudokuEngine

/// A catalog-wide, deterministic contract for every purchasable item. The
/// focused scenario tests elsewhere cover scoring order; these tests make sure
/// adding or editing a catalogue entry cannot silently leave its advertised
/// effect unexercised.
final class CatalogEffectCoverageTests: XCTestCase {

    private func puzzle(slot: PuzzleSlot = .easy) throws -> (RunState, PuzzleState) {
        var run = RunState(seed: "catalog-coverage", startingBoard: .scholar)
        run.slot = slot
        return (run, try PuzzleState.create(run: &run))
    }

    private func markerResult(_ id: String, event: GameEvent,
                              completedUnits: Int = 0,
                              boardCount: Int = 0) throws -> EffectResult {
        var (run, puzzle) = try self.puzzle()
        let square = try XCTUnwrap(puzzle.board.blanks.first)
        run.markers = [OwnedMarker(defID: id, boughtAtLevel: 1, pricePaid: 0, squares: [square])]
        let context = Resolver.context(event, run: run, puzzle: puzzle, digit: .five,
                                       square: square, boardCountBefore: boardCount,
                                       completedUnitCount: completedUnits)
        return Resolver.dispatch(context, run: run, puzzle: puzzle)
    }

    private func bookmarkResult(_ id: String, event: GameEvent,
                                slot: PuzzleSlot = .easy,
                                puzzleState: [String: Double] = [:],
                                runState: [String: Double] = [:]) throws -> EffectResult {
        var (run, puzzle) = try self.puzzle(slot: slot)
        run.bookmarks = [OwnedBookmark(defID: id, boughtAtLevel: 1, pricePaid: 0)]
        run.runItemState = runState
        puzzle.itemState = puzzleState
        let context = Resolver.context(event, run: run, puzzle: puzzle, digit: .five)
        return Resolver.dispatch(context, run: run, puzzle: puzzle)
    }

    private func buffUseResult(_ id: String, digit: Digit? = nil) throws -> EffectResult {
        let (run, puzzle) = try self.puzzle()
        let context = Resolver.context(.shopEnter, run: run, puzzle: puzzle, digit: digit)
        var result = EffectResult()
        try XCTUnwrap(Catalog.item(id)?.onUse)(context, &result)
        return result
    }

    func testEveryMarkerEffectDispatchesItsAdvertisedResult() throws {
        let placeExpectations: [(String, (EffectResult) -> Void)] = [
            ("mk_crimson", { XCTAssertEqual($0.multX, 4, "mk_crimson") }),
            ("mk_golden", { XCTAssertEqual($0.flat, 100, "mk_golden") }),
            ("mk_azure", { XCTAssertEqual($0.coins, 1, "mk_azure") }),
            (Markers.onyx, { XCTAssertTrue($0.clueScoresPlacement, "\(Markers.onyx)") }),
            ("mk_sapphire", { XCTAssertEqual($0.draws, 1, "mk_sapphire") }),
            (Markers.rose, { XCTAssertEqual($0.puzzleStateWrites[Markers.rose], 1, "\(Markers.rose)") }),
            ("mk_violet", { XCTAssertEqual($0.baseOverride, .nine, "mk_violet") }),
        ]
        for (id, check) in placeExpectations { check(try markerResult(id, event: .place)) }

        XCTAssertTrue(try markerResult(Markers.ivory, event: .wrongPlace).zeroed, "\(Markers.ivory)")
        XCTAssertTrue(try markerResult(Markers.jade, event: .wrongPlace).wrongReturnsToHand, "\(Markers.jade)")
        XCTAssertEqual(try markerResult("mk_emerald", event: .lineClear).multX, 2, "mk_emerald")
        XCTAssertEqual(try markerResult("mk_silver", event: .place, boardCount: 4).flat, 80, "mk_silver")
        XCTAssertEqual(try markerResult("mk_copper", event: .place, completedUnits: 2).coins, 6, "mk_copper")
        XCTAssertEqual(Catalog.items(of: .marker).count, 12)
    }

    func testEveryBookmarkEffectDispatchesOrChangesItsStandingRule() throws {
        let directScore: [(String, GameEvent, Int)] = [
            ("bm_morning_edition", .turnEnd, 100),
            ("bm_evening_edition", .puzzleEnd, 300),
        ]
        for (id, event, expected) in directScore {
            XCTAssertEqual(try bookmarkResult(id, event: event).directScore, expected, id)
        }

        let flats: [(String, GameEvent, Int)] = [
            ("bm_local_gossip", .place, 30),
            ("bm_sports_section", .lineClear, 25),
            ("bm_society_pages", .fullClear, 500),
        ]
        for (id, event, expected) in flats {
            XCTAssertEqual(try bookmarkResult(id, event: event).flat, expected, id)
        }

        let additive: [(String, Double)] = [
            ("bm_op_ed", 1), ("bm_editorial_board", 2), ("bm_front_page_splash", 1),
        ]
        for (id, expected) in additive {
            XCTAssertEqual(try bookmarkResult(id, event: .place).multAdd, expected, id)
        }
        XCTAssertEqual(try bookmarkResult("bm_letters_to_the_editor", event: .place).multAdd, 0,
                       "Letters is inactive outside Boss Puzzles")
        XCTAssertEqual(try bookmarkResult("bm_letters_to_the_editor", event: .place, slot: .boss).multAdd, 3,
                       "Letters is active in Boss Puzzles")

        XCTAssertEqual(try bookmarkResult(Bookmarks.rollingPresses, event: .place,
                                          puzzleState: [Bookmarks.rollingPresses: 2]).multX, 2,
                       "Rolling Presses reads its accumulated Puzzle state")
        XCTAssertEqual(try bookmarkResult(Bookmarks.rollingPresses, event: .lineClear)
            .puzzleStateWrites[Bookmarks.rollingPresses], 1, "Rolling Presses gains after a Line Clear")
        XCTAssertEqual(try bookmarkResult(Bookmarks.syndication, event: .place,
                                          runState: [Bookmarks.syndication: 4]).multX, 2,
                       "Syndication reads its accumulated Book state")
        XCTAssertEqual(try bookmarkResult("bm_stop_the_presses", event: .place).multX, 3, "bm_stop_the_presses")
        XCTAssertEqual(try bookmarkResult("bm_the_sunday_supplement", event: .place).multX, 2,
                       "Sunday Supplement normal Puzzle")
        XCTAssertEqual(try bookmarkResult("bm_the_sunday_supplement", event: .place, slot: .boss).multX, 3,
                       "Sunday Supplement Boss Puzzle")
        XCTAssertEqual(try bookmarkResult("bm_extra_extra", event: .lineClear).multX, 3, "bm_extra_extra Line Clear")
        XCTAssertEqual(try bookmarkResult("bm_extra_extra", event: .fullClear).multX, 3, "bm_extra_extra Full Clear")
        XCTAssertEqual(try bookmarkResult("bm_finance_pages", event: .lineClear).coins, 1, "bm_finance_pages")
        XCTAssertEqual(try bookmarkResult("bm_crossword_daily", event: .lineClear).draws, 1, "bm_crossword_daily")

        var run = RunState(seed: "bookmark-standing", startingBoard: .scholar)
        run.bookmarks = [
            OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.weatherForecast, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.puzzleCorner, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.lateCityFinal, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.marketWrap, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.paperRoute, boughtAtLevel: 1, pricePaid: 0),
            OwnedBookmark(defID: Bookmarks.auctionNotices, boughtAtLevel: 1, pricePaid: 0),
        ]
        run.coins = 500
        XCTAssertEqual(run.effectiveHandSize(boss: nil), 8, "\(Bookmarks.helpWanted)")
        XCTAssertEqual(run.effectiveTossAllowance(boss: nil), 6, "\(Bookmarks.weatherForecast)")
        XCTAssertEqual(run.effectiveClues(boss: nil), 1, "\(Bookmarks.puzzleCorner)")
        XCTAssertEqual(run.effectiveTurns(boss: nil), 11, "\(Bookmarks.lateCityFinal)")
        XCTAssertEqual(run.interestCap, 15, "\(Bookmarks.marketWrap)")
        var payoutPuzzle = try PuzzleState.create(run: &run)
        payoutPuzzle.hand = []
        XCTAssertEqual(run.payout(for: payoutPuzzle).paperRoute, 2, "\(Bookmarks.paperRoute)")
        Shop.open(&run)
        XCTAssertEqual(run.shop?.rerollCost, 0, "\(Bookmarks.auctionNotices)")
        XCTAssertEqual(Catalog.items(of: .bookmark).count, 23)
    }

    func testEveryBuffUseOrStandingEffectDispatchesItsAdvertisedResult() throws {
        XCTAssertEqual(try buffUseResult(Buffs.peek).extraClues, 1, "\(Buffs.peek)")
        XCTAssertTrue(try buffUseResult(Buffs.redraw).redrawHand, "\(Buffs.redraw)")
        XCTAssertEqual(try buffUseResult("bf_overtime").extraTurns, 2, "bf_overtime")
        XCTAssertTrue(try buffUseResult("bf_double_down").armFlags.contains(.doubleDown), "bf_double_down")
        XCTAssertTrue(try buffUseResult("bf_insurance").armFlags.contains(.insurance), "bf_insurance")
        XCTAssertTrue(try buffUseResult("bf_second_print").armFlags.contains(.secondPrint), "bf_second_print")
        XCTAssertEqual(try buffUseResult("bf_lucky_dip").draws, 2, "bf_lucky_dip")
        XCTAssertEqual(try buffUseResult(Buffs.birdSeed).runStateWrites[Buffs.birdSeed], 1, "\(Buffs.birdSeed)")
        XCTAssertEqual(try buffUseResult(Buffs.freshInk).puzzleStateWrites[Buffs.freshInk], 2, "\(Buffs.freshInk)")
        XCTAssertTrue(try buffUseResult(Buffs.litmus).armFlags.contains(.litmus), "\(Buffs.litmus)")
        XCTAssertEqual(try buffUseResult(Buffs.paperCrane, digit: .seven)
            .puzzleStateWrites[Buffs.paperCraneKey(.seven)], 50, "\(Buffs.paperCrane)")

        var (run, puzzle) = try self.puzzle()
        run.buffs = [OwnedBuff(defID: Buffs.birdSeed, pricePaid: 0)]
        run.runItemState[Buffs.birdSeed] = 1
        let context = Resolver.context(.lineClear, run: run, puzzle: puzzle, digit: .five)
        XCTAssertEqual(Resolver.dispatch(context, run: run, puzzle: puzzle).coins, 1,
                       "Bird Seed stays active for the Level")
        XCTAssertEqual(Catalog.items(of: .buff).count, 11)
    }
}
