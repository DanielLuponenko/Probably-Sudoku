import XCTest
@testable import ProbablySudokuEngine

final class ProductionRuleRegressionTests: XCTestCase {
    func testFinalObstacleDoesNotMechanicallyBarAnEntireOpeningHand() throws {
        var game = Game(seed: "obstacle-nine-opening", book: .slightlyHarder, obstacle: .finalEdition)
        try game.startPuzzle()
        for _ in 0..<3 {
            let puzzle = try XCTUnwrap(game.puzzle)
            XCTAssertEqual(puzzle.handSize, 3)
            XCTAssertTrue(puzzle.hand.indices.contains { !puzzle.isBlocked(handIndex: $0) },
                          "No Tosses plus a fully barred carried Hand makes this Book impossible to start")
            _ = try game.endTurn()
        }
    }

    func testDuplicateDigitsAndHandyDandyStillLeaveOneMechanicallyUnblockedCard() throws {
        var run = RunState(seed: "stacked-bars", obstacle: .finalEdition)
        let base = try PuzzleState.create(run: &run)
        for hand: [Digit] in [[.six], [.six, .six], [.six, .six, .two], [.one, .two, .three],
                              [.one, .two, .three, .four], [.one, .two, .three, .four, .five]] {
            for boss: BossModifier? in [nil, .handyDandy] {
                var puzzle = base
                puzzle.hand = hand
                puzzle.boss = boss
                for _ in 0..<12 {
                    puzzle.startObstacleTurn(&run)
                    puzzle.startBossTurn(&run)
                    XCTAssertTrue(hand.indices.contains { !puzzle.isBlocked(handIndex: $0) },
                                  "Stacked digit/card bars locked \(hand) for \(String(describing: boss))")
                }
            }
        }
    }

    func testLegacyUntouchedOpeningDeadlockRepairsWithoutChangingBoardHandCoinsOrStreams() throws {
        var game = Game(seed: "legacy-opening-deadlock", book: .genuinely, obstacle: .finalEdition)
        try game.startPuzzle()
        let held = try XCTUnwrap(game.puzzle).hand
        game.run.puzzle?.obstacleBlockedDigits = Set(held)
        let before = try XCTUnwrap(game.puzzle)
        let restored = try Game(decoding: game.encoded())
        let after = try XCTUnwrap(restored.puzzle)
        XCTAssertTrue(after.hand.indices.contains { !after.isBlocked(handIndex: $0) })
        XCTAssertEqual(after.hand, before.hand)
        XCTAssertEqual(after.board.placed, before.board.placed)
        XCTAssertEqual(after.turnNumber, before.turnNumber)
        XCTAssertEqual(restored.run.coins, game.run.coins)
        XCTAssertEqual(restored.run.streams.pool.state, game.run.streams.pool.state)
        XCTAssertEqual(restored.run.streams.boss.state, game.run.streams.boss.state)
    }

    func testSavingPartiallySpentHandCannotUnbarAnExtraCard() throws {
        var game = Game(seed: "partially-spent-bars", obstacle: .finalEdition)
        try game.startPuzzle()
        XCTAssertTrue(game.puzzle!.hand.indices.contains(where: game.puzzle!.isBlocked(handIndex:)))
        while let puzzle = game.puzzle,
              let index = puzzle.hand.indices.first(where: { !puzzle.isBlocked(handIndex: $0) }) {
            let square = try XCTUnwrap(puzzle.board.blanks.first { puzzle.board.correctDigit(at: $0) == puzzle.hand[index] })
            _ = try game.place(handIndex: index, at: square)
        }
        let held = try XCTUnwrap(game.puzzle).hand
        XCTAssertFalse(held.isEmpty, "The legitimately barred cards are still held")
        XCTAssertGreaterThan(game.puzzle!.pendingBase, 0)
        let restored = try Game(decoding: game.encoded())
        XCTAssertTrue(restored.puzzle!.hand.indices.allSatisfy(restored.puzzle!.isBlocked(handIndex:)))
        XCTAssertEqual(restored.puzzle?.obstacleBlockedDigits, game.puzzle?.obstacleBlockedDigits)
        XCTAssertEqual(restored.puzzle?.hand, held)
        XCTAssertEqual(restored.puzzle?.pendingBase, game.puzzle?.pendingBase)
    }

    func testSellingABookmarkDoesNotMoveExecutiveEditorsSleepingTarget() throws {
        for soldIndex in 0..<3 {
            var game = Game(seed: "sleeping-bookmark-sale")
            try game.startPuzzle()
            for id in [Bookmarks.helpWanted, "bm_local_gossip", "bm_morning_edition"] {
                game.give(ad: id)
            }
            game.run.puzzle?.boss = .unluckyLucky
            var state = BossTurnState()
            state.disabledBookmark = 1
            game.run.puzzle?.bossTurn = state
            _ = try game.sell(kind: .bookmark, index: soldIndex)
            let restored = try Game(decoding: game.encoded())
            let expected: Int? = soldIndex == 1 ? nil : (soldIndex == 0 ? 0 : 1)
            XCTAssertEqual(restored.puzzle?.disabledBookmark, expected)
            if let expected {
                XCTAssertEqual(restored.run.bookmarks[expected].defID, "bm_local_gossip")
                let puzzle = try XCTUnwrap(restored.puzzle)
                let context = Resolver.context(.place, run: restored.run, puzzle: puzzle, digit: .five)
                XCTAssertEqual(Resolver.dispatch(context, run: restored.run, puzzle: puzzle).flat, 0)
            }
        }
    }

    func testAccountantDebtDoesNotTurnInterestIntoAnUnadvertisedPenalty() throws {
        var game = Game(seed: "accountant-interest")
        try game.startPuzzle()
        game.run.puzzle?.boss = .accountant
        for coins in [-101, -20, -10, -1, 0, 9, 10, 100] {
            game.run.coins = coins
            let puzzle = try XCTUnwrap(game.puzzle)
            let payout = game.run.payout(for: puzzle)
            XCTAssertEqual(payout.interest, max(0, min(game.run.interestCap, coins / 10)))
            XCTAssertGreaterThanOrEqual(payout.total, 0)
            XCTAssertEqual(game.run.coins, coins, "Debt is real and must not itself be erased")
        }
    }
}
