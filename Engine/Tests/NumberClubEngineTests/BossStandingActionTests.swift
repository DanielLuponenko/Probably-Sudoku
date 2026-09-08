import XCTest
@testable import ProbablySudokuEngine

final class BossStandingActionTests: XCTestCase {
    func testEditorActuallyDealsTheComposedReducedHandWithoutLosingNumbers() throws {
        var run = RunState(seed: "editor-standing-action", book: .genuinely, obstacle: .shortHanded)
        run.slot = .boss
        run.pendingBoss = .editor
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.helpWanted, boughtAtLevel: 1, pricePaid: 5)]
        var game = Game(run: run)
        try game.startPuzzle()
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(puzzle.boss, .editor)
        XCTAssertEqual(puzzle.handSize, 5, "Base 6 + Help Wanted 1 − Editor 1 − Obstacle 1.")
        XCTAssertEqual(puzzle.hand.count, 5, "The actual factory must deal the reduced capacity.")
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand))
        let restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.puzzle?.hand, puzzle.hand)
        XCTAssertEqual(restored.puzzle?.handSize, 5)
        XCTAssertNil(Conservation.check(board: restored.puzzle!.board,
                                        pool: restored.puzzle!.pool, hand: restored.puzzle!.hand))
    }

    func testDeadlineActuallyExhaustsAtEightTurnsAndPreservesFailureDecisionsAcrossSave() throws {
        var run = RunState(seed: "deadline-standing-action", book: .genuinely)
        run.slot = .boss
        run.pendingBoss = .deadline
        var game = Game(run: run)
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.boss, .deadline)
        XCTAssertEqual(game.puzzle?.turnsMax, 8)
        for turn in 1..<8 {
            XCTAssertEqual(game.puzzle?.turnNumber, turn)
            let result = try game.endTurn()
            XCTAssertFalse(result.turnsExhausted)
            XCTAssertFalse(result.puzzleFailed)
            XCTAssertEqual(game.puzzle?.phase, .playing)
        }
        let final = try game.endTurn()
        XCTAssertTrue(final.turnsExhausted)
        XCTAssertTrue(final.puzzleFailed)
        XCTAssertEqual(game.puzzle?.phase, .outOfTurns, "Failure first offers the existing one-time rescue.")
        XCTAssertNil(game.run.outcome)
        let paused = try game.encoded()
        var restored = try Game(decoding: paused)
        XCTAssertEqual(try restored.encoded(), paused)
        XCTAssertTrue(restored.canClaimRewardedRescue)
        XCTAssertTrue(restored.declineRewardedRescue())
        XCTAssertEqual(restored.puzzle?.phase, .failed)
        XCTAssertEqual(restored.run.outcome, .failed)
        let failed = try restored.encoded()
        let terminal = try Game(decoding: failed)
        XCTAssertEqual(try terminal.encoded(), failed)
        XCTAssertFalse(terminal.canClaimRewardedRescue)
    }

    func testErratumRejectsARealTossWithoutChangingSavedStateDespiteBonusAllowances() throws {
        var run = RunState(seed: "erratum-standing-action", book: .genuinely)
        run.slot = .boss
        run.pendingBoss = .erratum
        run.bookmarks = [OwnedBookmark(defID: Bookmarks.weatherForecast, boughtAtLevel: 1, pricePaid: 4)]
        XCTAssertEqual(run.effectiveTossAllowance(boss: nil), 7, "Base 4 + Book 1 + Weather Forecast 2.")
        var game = Game(run: run)
        try game.startPuzzle()
        XCTAssertEqual(game.puzzle?.boss, .erratum)
        XCTAssertFalse(game.puzzle!.hand.isEmpty)
        XCTAssertEqual(game.puzzle?.tossAllowance, 0)
        let before = try game.encoded()
        XCTAssertThrowsError(try game.toss(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .tossAllowanceSpent)
        }
        XCTAssertEqual(try game.encoded(), before)
        var restored = try Game(decoding: before)
        XCTAssertThrowsError(try restored.toss(handIndex: 0)) {
            XCTAssertEqual($0 as? PlacementError, .tossAllowanceSpent)
        }
        XCTAssertEqual(try restored.encoded(), before)
    }
}
