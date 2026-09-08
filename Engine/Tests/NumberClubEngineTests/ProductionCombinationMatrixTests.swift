import XCTest
@testable import ProbablySudokuEngine

/// Exhausts the standing/dynamic Book × Boss × Obstacle axes on a cached legal
/// board. This is a rules/persistence matrix, not 2,052 newly graded boards or
/// an exhaustive test of every possible inventory permutation.
final class ProductionCombinationMatrixTests: XCTestCase {
    /// Actual production starts, not the cached Boss fixtures below. The
    /// solution is a test oracle for legal inputs, not human-play evidence.
    func testAll108BookObstacleStartsKeepTurnRulesAndPreserveSaves() throws {
        var starts = 0
        for book in Book.allCases {
            for obstacle in Obstacle.allCases {
                let label = "\(book.rawValue) / \(obstacle.rawValue)"
                var game = Game(seed: "fresh-opening-\(label)", book: book, obstacle: obstacle)
                try game.startPuzzle()
                starts += 1
                let opening = try XCTUnwrap(game.puzzle)
                XCTAssertEqual(opening.board.isGiven.filter { $0 }.count, book.givens(for: .easy), label)
                XCTAssertEqual(opening.target, book.target(level: 1, slot: .easy), label)
                XCTAssertEqual(opening.handSize, game.run.effectiveHandSize(boss: nil), label)
                XCTAssertEqual(opening.turnsMax, game.run.effectiveTurns(boss: nil), label)
                XCTAssertEqual(opening.tossAllowance, game.run.effectiveTossAllowance(boss: nil), label)
                let grid = Square.all.map { opening.board.isGiven[$0.index]
                    ? UInt8(opening.board.correctDigit(at: $0).rawValue) : 0 }
                XCTAssertEqual(Solver.countSolutions(grid, limit: 2), 1, label)

                for _ in 0..<3 {
                    let puzzle = try XCTUnwrap(game.puzzle)
                    XCTAssertEqual(puzzle.phase, .playing, label)
                    let unique = Set(puzzle.hand)
                    XCTAssertEqual(puzzle.obstacleBlockedDigits.count,
                                   min(obstacle.blockedNumbersEachTurn, max(0, unique.count - 1)), label)
                    XCTAssertTrue(puzzle.obstacleBlockedDigits.isSubset(of: unique), label)
                    try assertState(game, label: label)
                    if obstacle.removesTosses {
                        let before = try canonicalSnapshot(game)
                        XCTAssertThrowsError(try game.toss(handIndex: 0), label)
                        XCTAssertEqual(try canonicalSnapshot(game), before, label)
                    }
                    if let move = legalMove(in: puzzle) {
                        _ = try game.place(handIndex: move.0, at: move.1)
                    }
                    var restored = try Game(decoding: game.encoded())
                    XCTAssertEqual(try canonicalSnapshot(game), try canonicalSnapshot(restored), label)
                    XCTAssertEqual(try game.endTurn(), try restored.endTurn(), label)
                    XCTAssertEqual(try canonicalSnapshot(game), try canonicalSnapshot(restored), label)
                }
                XCTAssertEqual(game.run.book, book)
                XCTAssertEqual(game.run.obstacle, obstacle)
                try assertState(game, label: label)
            }
        }
        XCTAssertEqual(starts, 12 * 9)
    }

    func testAllBooksBossesAndObstaclesKeepRulesConservationAndRescueIdentity() throws {
        var combinations = 0
        for book in Book.allCases {
            var source = Game(seed: "production-matrix-\(book.rawValue)", book: book)
            try source.startPuzzle()
            let board = try XCTUnwrap(source.puzzle).board
            for obstacle in Obstacle.allCases {
                for boss in BossModifier.allCases {
                    var game = makeEncounter(book: book, obstacle: obstacle, boss: boss,
                                             board: board, variation: combinations)
                    let label = "\(book.rawValue) / \(boss.rawValue) / \(obstacle.rawValue)"
                    combinations += 1
                    let puzzle = try XCTUnwrap(game.puzzle)
                    XCTAssertEqual(puzzle.handSize, game.run.effectiveHandSize(boss: boss), label)
                    XCTAssertEqual(puzzle.turnsMax, game.run.effectiveTurns(boss: boss), label)
                    XCTAssertEqual(puzzle.tossAllowance, game.run.effectiveTossAllowance(boss: boss), label)
                    XCTAssertEqual(puzzle.cluesRemaining, game.run.effectiveClues(boss: boss), label)
                    XCTAssertEqual(puzzle.target, book.target(level: puzzle.level, slot: .boss) * boss.targetMultiplier, label)
                    XCTAssertEqual(puzzle.clockSecondsRemaining, boss.secondsAllowed, label)
                    try assertState(game, label: label)

                    // Attempt a real placement, never bypassing either card or
                    // square bars. Some combinations legitimately need to end
                    // a Turn when the playable digit's squares are fouled.
                    if let move = legalMove(in: puzzle) {
                        _ = try game.place(handIndex: move.0, at: move.1)
                    }
                    let beforeBuff = try game.encoded()
                    let consumed = try? game.useBuff(at: 0, digit: .five)
                    if consumed == false || consumed == nil {
                        XCTAssertEqual(try game.encoded(), beforeBuff, label)
                    }
                    XCTAssertNil(Conservation.check(board: game.puzzle!.board,
                                                     pool: game.puzzle!.pool, hand: game.puzzle!.hand), label)

                    // Refilling and Boss/Obstacle bars must be deterministic
                    // across a save, including with consumed/armed Buffs.
                    var restored = try Game(decoding: game.encoded())
                    XCTAssertEqual(try game.endTurn(), try restored.endTurn(), label)
                    XCTAssertEqual(try canonicalSnapshot(game), try canonicalSnapshot(restored), label)
                    try assertState(game, label: label)

                    // Pause a real exhausted Turn; ad rescue restores this same
                    // prepared Hand/board/restrictions and never rolls twice.
                    game.run.puzzle?.phase = .playing
                    game.run.puzzle?.score = 0
                    game.run.puzzle?.pendingBase = 0
                    game.run.puzzle?.target = 1_000_000
                    let lastTurn = try XCTUnwrap(game.puzzle).turnsMax
                    game.run.puzzle?.turnNumber = lastTurn
                    _ = try game.endTurn()
                    XCTAssertEqual(game.puzzle?.phase, .outOfTurns, label)
                    let saved = try game.encoded()
                    restored = try Game(decoding: saved)
                    XCTAssertTrue(restored.claimRewardedRescue(), label)
                    let claimed = try restored.encoded()
                    XCTAssertFalse(restored.claimRewardedRescue(), label)
                    XCTAssertEqual(try restored.encoded(), claimed, label)
                    XCTAssertEqual(restored.puzzle?.hand, game.puzzle?.hand, label)
                    XCTAssertEqual(restored.puzzle?.board.placed, game.puzzle?.board.placed, label)
                    XCTAssertEqual(restored.puzzle?.blockedDigits, game.puzzle?.blockedDigits, label)
                    XCTAssertEqual(restored.puzzle?.bossTurn?.blockedHandIndices,
                                   game.puzzle?.bossTurn?.blockedHandIndices, label)
                    XCTAssertEqual(restored.run.streams.boss.state, game.run.streams.boss.state, label)
                    XCTAssertEqual(restored.run.streams.pool.state, game.run.streams.pool.state, label)
                    XCTAssertEqual(restored.run.book, book)
                    XCTAssertEqual(restored.run.obstacle, obstacle)
                    try assertState(restored, label: label)
                }
            }
        }
        XCTAssertEqual(combinations, 12 * 19 * 9)
    }

    func testEveryBossIsActuallyDealtFromItsCorrectPoolWithItsRealStandingRules() throws {
        for boss in BossModifier.allCases {
            var run = RunState(seed: "production-boss-deal-\(boss.rawValue)")
            run.level = boss.isFinalBoss ? 9 : 1
            run.slot = .boss
            run.pendingBoss = boss
            var game = Game(run: run)
            try game.startPuzzle()
            XCTAssertEqual(game.puzzle?.boss, boss)
            XCTAssertEqual(game.puzzle?.difficulty, .boss)
            XCTAssertNil(game.run.pendingBoss)
            XCTAssertEqual(game.puzzle?.target, game.run.book.target(level: run.level, slot: .boss) * boss.targetMultiplier)
            try assertState(game, label: boss.rawValue)
        }
    }

    private func makeEncounter(book: Book, obstacle: Obstacle, boss: BossModifier,
                               board: Board, variation: Int) -> Game {
        var run = RunState(seed: "matrix-\(book.rawValue)-\(obstacle.rawValue)-\(boss.rawValue)",
                           book: book, obstacle: obstacle)
        run.level = boss.isFinalBoss ? 9 : 1
        run.slot = .boss
        run.pendingBoss = nil
        let holdings = [Bookmarks.helpWanted, "bm_op_ed", "bm_local_gossip", "bm_morning_edition", Bookmarks.rollingPresses]
        run.bookmarks = holdings.map { OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: 5) }
        let marker = Markers.all[variation % Markers.all.count]
        run.markers = [OwnedMarker(defID: marker.id, boughtAtLevel: 1, pricePaid: 5,
                                  squares: Array(board.blanks.prefix(2)))]
        let buff = Buffs.all[variation % Buffs.all.count]
        run.buffs = [OwnedBuff(defID: buff.id, pricePaid: 4), OwnedBuff(defID: buff.id, pricePaid: 4)]
        run.coins = variation.isMultiple(of: 3) ? -20 : 20
        var pool = Pool(blanksOf: board)
        let handSize = run.effectiveHandSize(boss: boss)
        let hand = pool.draw(&run.streams.pool, count: handSize)
        var puzzle = PuzzleState(level: run.level, slot: .boss, difficulty: .boss,
                                 board: board, pool: pool, hand: hand, handSize: handSize,
                                 turnNumber: 1, turnsMax: run.effectiveTurns(boss: boss),
                                 tossedThisPuzzle: 0, tossAllowance: run.effectiveTossAllowance(boss: boss),
                                 score: 0, target: book.target(level: run.level, slot: .boss) * boss.targetMultiplier,
                                 cluesRemaining: run.effectiveClues(boss: boss), boss: boss,
                                 censoredDigit: boss.censorsARandomDigit ? .five : nil,
                                 blockedDigit: nil, bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.startObstacleTurn(&run)
        puzzle.startBossTurn(&run)
        run.puzzle = puzzle
        return Game(run: run)
    }

    private func assertState(_ game: Game, label: String) throws {
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand), label)
        XCTAssertGreaterThanOrEqual(puzzle.score, 0, label)
        XCTAssertGreaterThanOrEqual(puzzle.pendingBase, 0, label)
        XCTAssertTrue(puzzle.pendingMultiplier.isFinite, label)
        XCTAssertTrue(puzzle.hand.isEmpty || puzzle.hand.indices.contains { !puzzle.isBlocked(handIndex: $0) }, label)
        XCTAssertTrue(puzzle.bossTurn?.blockedHandIndices.allSatisfy { puzzle.hand.indices.contains($0) } ?? true, label)
        XCTAssertTrue(puzzle.barredSquares.allSatisfy(puzzle.board.isBlank), label)
        if let sleeping = puzzle.disabledBookmark { XCTAssertTrue(game.run.bookmarks.indices.contains(sleeping), label) }
        XCTAssertGreaterThanOrEqual(game.run.payout(for: puzzle).interest, 0, label)
        let saved = try game.encoded()
        XCTAssertEqual(try canonicalSnapshot(Game(decoding: saved)), try canonicalSnapshot(game), label)
    }

    /// JSON's Set and non-string Dictionary arrays have no defined encoding
    /// order. Canonicalize those fields only; Hand/board/inventory order stays
    /// significant and is never sorted away by the persistence assertion.
    private func canonicalSnapshot(_ game: Game) throws -> Data {
        let setKeys: Set<String> = ["blockedDigits", "obstacleBlockedDigits", "blockedHandIndices",
                                    "greyed", "clueReveals", "armedFlags"]
        func encoded(_ value: Any) throws -> String {
            String(decoding: try JSONSerialization.data(withJSONObject: value,
                                                        options: [.sortedKeys, .fragmentsAllowed]), as: UTF8.self)
        }
        func normalize(_ value: Any, key: String = "") throws -> Any {
            if let object = value as? [String: Any] {
                var output: [String: Any] = [:]
                for (childKey, childValue) in object { output[childKey] = try normalize(childValue, key: childKey) }
                return output
            }
            if let array = value as? [Any] {
                let normalized = try array.map { try normalize($0) }
                if setKeys.contains(key) { return try normalized.sorted { try encoded($0) < encoded($1) } }
                if key == "fouled" {
                    let pairs = stride(from: 0, to: normalized.count, by: 2).map { [normalized[$0], normalized[$0 + 1]] }
                    return try pairs.sorted { try encoded($0[0]) < encoded($1[0]) }
                }
                return normalized
            }
            return value
        }
        let object = try JSONSerialization.jsonObject(with: game.encoded())
        return try JSONSerialization.data(withJSONObject: normalize(object), options: [.sortedKeys])
    }

    private func legalMove(in puzzle: PuzzleState) -> (Int, Square)? {
        for index in puzzle.hand.indices where !puzzle.isBlocked(handIndex: index) {
            if let square = puzzle.board.blanks.first(where: {
                !puzzle.isBarred($0) && puzzle.board.correctDigit(at: $0) == puzzle.hand[index]
            }) { return (index, square) }
        }
        return nil
    }
}
