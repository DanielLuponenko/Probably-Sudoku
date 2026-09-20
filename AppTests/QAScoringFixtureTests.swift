#if DEBUG && targetEnvironment(simulator)
import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

final class QAScoringFixtureTests: XCTestCase {
    func testEveryFixtureArrangesAConservedUnscoredPlayableState() throws {
        for fixture in QAScoringFixture.allCases {
            let game = try fixture.makeGame()
            let puzzle = try XCTUnwrap(game.puzzle)
            XCTAssertEqual(puzzle.phase, .playing, fixture.rawValue)
            XCTAssertEqual(puzzle.score, 0, fixture.rawValue)
            XCTAssertEqual(puzzle.pendingBase, 0, fixture.rawValue)
            XCTAssertNil(puzzle.lastScoringLedger, fixture.rawValue)
            XCTAssertNil(puzzle.turnScoringState, fixture.rawValue)
            XCTAssertTrue(puzzle.turnScoringOperations.isEmpty, fixture.rawValue)
            XCTAssertTrue(puzzle.armedFlags.isEmpty, fixture.rawValue)
            XCTAssertEqual(game.run.coins, 5, fixture.rawValue)
            XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand), fixture.rawValue)
            XCTAssertLessThanOrEqual(game.run.bookmarks.count, 5)
            XCTAssertLessThanOrEqual(game.run.buffs.count, 2)
            XCTAssertEqual(puzzle.board.correctDigit(at: Square(4)), .five)
            XCTAssertEqual(puzzle.board.correctDigit(at: Square(80)), .eight)
            XCTAssertFalse(fixture.instructions.isEmpty)
        }
    }

    func testClearFixtureProvidesTwoUnitsAndCardsForRealDrawHooks() throws {
        let game = try QAScoringFixture.simultaneousClears.makeGame()
        var board = try XCTUnwrap(game.puzzle).board
        board.fill(Square(4), with: .five, by: .player)
        XCTAssertEqual(board.unitsCompleted(at: Square(4)), [.row, .box])
        XCTAssertGreaterThan(try XCTUnwrap(game.puzzle).pool.total, 2)
        XCTAssertEqual(game.run.buffs.map(\.defID), ["bf_second_print"])
    }

    func testModifierPreviewUsesRealPlacementBuffAndBankingActions() throws {
        var game = try QAScoringFixture.modifierPreview.makeGame()
        let square = Square(3) // R1C4, a correct 4 on Crimson.
        XCTAssertEqual(game.puzzle?.board.blanks.count, 81)
        XCTAssertEqual(game.puzzle?.board.correctDigit(at: square), .four)
        XCTAssertEqual(game.puzzle?.hand, [.four, .nine, .two])
        XCTAssertEqual(game.run.markers.map(\.defID), ["mk_crimson"])
        XCTAssertEqual(game.run.markers.first?.squares, [square])
        XCTAssertEqual(game.run.bookmarks.map(\.defID), ["bm_op_ed", "bm_stop_the_presses"])
        XCTAssertEqual(game.run.buffs.map(\.defID), [Buffs.freshInk])
        XCTAssertGreaterThan(try XCTUnwrap(game.puzzle?.target), 1_920)

        let placement = try game.place(handIndex: 0, at: square)
        XCTAssertTrue(placement.correct)
        XCTAssertEqual(game.puzzle?.board[square], .four)
        let beforeBuff = try XCTUnwrap(game.puzzle?.pendingScoringLedger)
        XCTAssertEqual(beforeBuff.points, 160, "40 placement Points ×4 from Crimson")
        XCTAssertEqual(beforeBuff.multiplier, 6, "Base 1, Op-Ed +1, then Stop ×3")
        XCTAssertEqual(beforeBuff.total, 960)
        XCTAssertEqual(game.puzzle?.score, 0, "Pending points have not banked")
        XCTAssertEqual(game.run.buffs.map(\.defID), [Buffs.freshInk], "Loading and placement do not use the held Buff")
        XCTAssertEqual(game.puzzle?.turnNumber, 1, "Other held numbers prevent an automatic End Turn")

        XCTAssertTrue(try game.useBuff(at: 0))
        XCTAssertTrue(game.run.buffs.isEmpty)
        let afterBuff = try XCTUnwrap(game.puzzle?.pendingScoringLedger)
        XCTAssertEqual(afterBuff.points, 160)
        XCTAssertEqual(afterBuff.multiplier, 12, "Fresh Ink adds 2 before the ordered Bookmarks")
        XCTAssertEqual(afterBuff.total, 1_920)
        XCTAssertEqual(game.puzzle?.score, 0)

        let turn = try game.endTurn()
        XCTAssertEqual(turn.scoringLedger?.total, 1_920)
        XCTAssertEqual(game.puzzle?.score, 1_920)
        XCTAssertEqual(game.puzzle?.pendingBase, 0)
        XCTAssertEqual(game.puzzle?.phase, .playing)
        XCTAssertEqual(game.puzzle?.turnNumber, 2)
        XCTAssertNil(Conservation.check(board: try XCTUnwrap(game.puzzle).board,
                                        pool: try XCTUnwrap(game.puzzle).pool,
                                        hand: try XCTUnwrap(game.puzzle).hand))
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.puzzle?.score, 1_920)
        XCTAssertTrue(restored.run.buffs.isEmpty)
        XCTAssertEqual(restored.puzzle?.board[square], .four)
    }

    func testDuplicateInventoryFixtureKeepsExactCopiesSeparateAcrossSaveAndDoesNotSpendThem() throws {
        let game = try QAScoringFixture.duplicateInventory.makeGame()
        XCTAssertEqual(game.run.buffs.map(\.defID), [Buffs.peek, Buffs.peek])
        XCTAssertEqual(Set(game.run.buffs.map(\.id)).count, 2)
        XCTAssertEqual(game.run.bookmarks.map(\.defID), ["bm_op_ed", "bm_stop_the_presses"])
        XCTAssertEqual(Set(game.run.bookmarks.map(\.id)).count, 2)
        XCTAssertEqual(game.puzzle?.cluesRemaining, 0)
        XCTAssertEqual(game.puzzle?.hand, [.five, .five, .nine])
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.run.buffs.map(\.id), game.run.buffs.map(\.id))
        XCTAssertEqual(restored.run.bookmarks.map(\.id), game.run.bookmarks.map(\.id))
        XCTAssertEqual(restored.puzzle?.hand, game.puzzle?.hand)
        XCTAssertEqual(restored.run.coins, 5)
        XCTAssertEqual(restored.run.skipHistory.count, 0)
    }
}
#endif
