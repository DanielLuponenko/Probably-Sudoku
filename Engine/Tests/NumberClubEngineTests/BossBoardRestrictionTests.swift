import XCTest
@testable import ProbablySudokuEngine

final class BossBoardRestrictionTests: XCTestCase {
    func testTemporarySquareBossesLeaveTheLastBlankAvailableAcrossTurns() throws {
        for boss in [BossModifier.overPusher, .grayTheGarry, .garryTheGray] {
            var game = encounter(boss: boss, blankIndices: [40])
            for turn in 1...8 {
                startTurn(&game, number: turn)
                let puzzle = try XCTUnwrap(game.puzzle)
                XCTAssertFalse(puzzle.isBarred(Square(40)), "\(boss.rawValue), Turn \(turn)")
            }
            let outcome = try game.place(handIndex: 0, at: Square(40))
            XCTAssertTrue(outcome.correct)
            XCTAssertTrue(game.puzzle!.board.isFull)
            XCTAssertEqual(game.puzzle?.phase, .won)
        }
    }

    func testShredderLeavesABlankAsFoulsCarryAndExpireOnNearlyFullBoards() throws {
        for remaining in 1...8 {
            var game = encounter(boss: .overPusher, blankIndices: Array(0..<remaining))
            for turn in 1...12 {
                startTurn(&game, number: turn)
                let puzzle = try XCTUnwrap(game.puzzle)
                XCTAssertTrue(puzzle.board.blanks.contains { !puzzle.isBarred($0) },
                              "\(remaining) blanks, Turn \(turn)")
                XCTAssertTrue(puzzle.bossTurn!.fouled.values.allSatisfy { $0 > turn && $0 <= turn + 2 })
                XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
            }
        }
    }

    func testShredderReleasesOneBlankFromAnExistingFullyFouledSaveAtNextTurn() throws {
        var game = encounter(boss: .overPusher, blankIndices: [0, 1, 2])
        var state = BossTurnState()
        state.fouled = [Square(0): 3, Square(1): 3, Square(2): 3]
        game.run.puzzle?.bossTurn = state
        game = try Game(decoding: game.encoded())
        let before = game.run.streams.boss.state
        startTurn(&game, number: 2)
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertFalse(puzzle.isBarred(Square(0)))
        XCTAssertEqual(puzzle.bossTurn?.fouled, [Square(1): 3, Square(2): 3])
        XCTAssertEqual(game.run.streams.boss.state, before, "Making room does not reroll the remaining fouls.")
    }

    func testGrayBossSkipsAUnitThatContainsEveryRemainingBlank() throws {
        for (boss, indices) in [(BossModifier.grayTheGarry, [0, 1, 2, 3]),
                                (.garryTheGray, [0, 1, 9, 10, 18])] {
            var game = encounter(boss: boss, blankIndices: indices)
            for turn in 1...8 {
                startTurn(&game, number: turn)
                XCTAssertTrue(try XCTUnwrap(game.puzzle?.bossTurn).greyed.isEmpty, boss.rawValue)
            }
        }
    }

    func testGrayBossStillBarsARealUnitWhenAnotherBlankRemainsOutsideIt() throws {
        for boss in [BossModifier.grayTheGarry, .garryTheGray] {
            var game = encounter(boss: boss, blankIndices: [0, 1, 40, 80])
            for turn in 1...8 {
                startTurn(&game, number: turn)
                let puzzle = try XCTUnwrap(game.puzzle)
                let greyed = try XCTUnwrap(puzzle.bossTurn).greyed
                XCTAssertFalse(greyed.isEmpty)
                XCTAssertTrue(puzzle.board.blanks.contains { !greyed.contains($0) })
                if boss == .grayTheGarry { XCTAssertEqual(Set(greyed.map(\.row)).count, 1) }
                else { XCTAssertEqual(Set(greyed.map(\.box)).count, 1) }
            }
        }
    }

    func testExecutiveEditorOnlySleepsTriggeredBookmarksInMixedInventory() throws {
        var game = encounter(boss: .unluckyLucky, blankIndices: [0, 1, 40])
        let standing = [Bookmarks.helpWanted, Bookmarks.weatherForecast, Bookmarks.puzzleCorner,
                        Bookmarks.lateCityFinal, Bookmarks.marketWrap, Bookmarks.auctionNotices,
                        Bookmarks.paperRoute]
        let ids = standing + ["bm_local_gossip", "bm_morning_edition"]
        game.run.bookmarks = ids.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
        let hand = game.puzzle!.hand
        for turn in 1...32 {
            startTurn(&game, number: turn)
            let puzzle = try XCTUnwrap(game.puzzle)
            let sleeping = try XCTUnwrap(puzzle.disabledBookmark)
            XCTAssertTrue((standing.count..<ids.count).contains(sleeping))
            let place = Resolver.context(.place, run: game.run, puzzle: puzzle, digit: .five)
            let end = Resolver.context(.turnEnd, run: game.run, puzzle: puzzle)
            XCTAssertEqual(Resolver.holdings(place, run: game.run, puzzle: puzzle).flat,
                           ids[sleeping] == "bm_local_gossip" ? 0 : 30)
            XCTAssertEqual(Resolver.holdings(end, run: game.run, puzzle: puzzle).directScore,
                           ids[sleeping] == "bm_morning_edition" ? 0 : 100)
            XCTAssertEqual(puzzle.hand, hand)
        }
    }

    func testExecutiveEditorLeavesStandingOnlyInventoryAwakeAndDoesNotReroll() throws {
        var game = encounter(boss: .unluckyLucky, blankIndices: [0, 1, 40])
        let ids = [Bookmarks.helpWanted, Bookmarks.weatherForecast, Bookmarks.puzzleCorner,
                   Bookmarks.lateCityFinal, Bookmarks.marketWrap, Bookmarks.auctionNotices,
                   Bookmarks.paperRoute]
        game.run.bookmarks = ids.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
        let before = game.run.streams.boss.state
        let handSize = game.run.effectiveHandSize(boss: .unluckyLucky)
        let turns = game.run.effectiveTurns(boss: .unluckyLucky)
        let clues = game.run.effectiveClues(boss: .unluckyLucky)
        let tosses = game.run.effectiveTossAllowance(boss: .unluckyLucky)
        for turn in 1...8 {
            startTurn(&game, number: turn)
            XCTAssertNil(game.puzzle?.disabledBookmark)
            XCTAssertEqual(game.run.streams.boss.state, before)
            XCTAssertEqual(game.run.effectiveHandSize(boss: .unluckyLucky), handSize)
            XCTAssertEqual(game.run.effectiveTurns(boss: .unluckyLucky), turns)
            XCTAssertEqual(game.run.effectiveClues(boss: .unluckyLucky), clues)
            XCTAssertEqual(game.run.effectiveTossAllowance(boss: .unluckyLucky), tosses)
        }
    }

    func testMirrorPreservesFullClearAndItsItemsWhileZeroingAllThreeFinalLines() throws {
        var game = encounter(boss: .mirror, blankIndices: [40])
        game.run.puzzle?.phase = .playing
        game.run.puzzle?.score = 0
        game.run.bookmarks = ["bm_society_pages", "bm_extra_extra", "bm_sports_section"].map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5)
        }
        let digit = try XCTUnwrap(game.puzzle?.hand.first)
        let outcome = try game.place(handIndex: 0, at: Square(40))
        XCTAssertTrue(game.puzzle!.board.isFull)
        XCTAssertTrue(outcome.fullClear)
        XCTAssertEqual(outcome.lineClears.count, 3)
        XCTAssertEqual(outcome.lineClearPoints, [0, 0, 0])
        XCTAssertEqual(outcome.points, 10 * digit.rawValue)
        XCTAssertEqual(outcome.fullClearPoints, 3_000, "Full Clear (500 + Society Pages 500) × Extra! Extra! 3.")
        XCTAssertTrue(outcome.scoreReceipts.contains { $0.event == .fullClear && $0.points == 3_000 })
    }

    private func startTurn(_ game: inout Game, number: Int) {
        var puzzle = game.puzzle!
        puzzle.turnNumber = number
        puzzle.startBossTurn(&game.run)
        game.run.puzzle = puzzle
    }

    private func encounter(boss: BossModifier, blankIndices: [Int]) -> Game {
        let blanks = Set(blankIndices)
        let solution = Square.all.map { square in
            Digit((square.row * 3 + square.row / 3 + square.col) % 9 + 1)!
        }
        let board = Board(GeneratedPuzzle(solution: solution, isGiven: (0..<81).map { !blanks.contains($0) }))
        let hand = blankIndices.map { solution[$0] }
        var run = RunState(seed: "near-full-\(boss.rawValue)-\(blankIndices.count)")
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = nil
        run.puzzle = PuzzleState(level: run.level, slot: .boss, difficulty: .boss,
                                 board: board, pool: Pool(), hand: hand, handSize: hand.count,
                                 turnNumber: 1, turnsMax: 20, tossedThisPuzzle: 0,
                                 tossAllowance: 0, score: 1, target: 1, cluesRemaining: 0,
                                 boss: boss, censoredDigit: nil, blockedDigit: nil,
                                 bossTurn: nil, phase: .keepFilling, keepFillingCoins: 0)
        return Game(run: run)
    }
}
