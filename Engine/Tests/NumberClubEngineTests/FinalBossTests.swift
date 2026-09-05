import Foundation
import XCTest
@testable import ProbablySudokuEngine

final class FinalBossTests: XCTestCase {
    private let finalBosses: Set<BossModifier> = [
        .heavyLifter, .unluckyLucky, .buffborger, .sashimi, .overPusher
    ]

    func testFiveNamedFinalBossesKeepTheirDistinctExistingPowersAndSaveIDs() throws {
        let expected: [(BossModifier, String, String)] = [
            (.heavyLifter, "heavyLifter", "The Final Draft"),
            (.unluckyLucky, "unluckyLucky", "The Executive Editor"),
            (.buffborger, "buffborger", "The Fine Print"),
            (.sashimi, "sashimi", "The Budget Cut"),
            (.overPusher, "overPusher", "The Shredder")
        ]
        XCTAssertEqual(expected.count, 5)
        XCTAssertEqual(Set(expected.map { $0.2 }).count, 5)
        for (boss, rawID, name) in expected {
            XCTAssertEqual(boss.rawValue, rawID)
            XCTAssertEqual(boss.name, name)
            XCTAssertEqual(try JSONDecoder().decode(BossModifier.self,
                                                    from: Data("\"\(rawID)\"".utf8)), boss)
        }
        XCTAssertEqual(BossModifier.heavyLifter.targetMultiplier, 4)
        XCTAssertTrue(BossModifier.unluckyLucky.disablesABookmarkEachTurn)
        XCTAssertTrue(BossModifier.buffborger.disablesBuffs)
        XCTAssertTrue(BossModifier.sashimi.halvesScoreMultiplier)
        XCTAssertTrue(BossModifier.overPusher.foulsSquaresEachTurn)
        XCTAssertFalse(finalBosses.contains(.collector))
    }

    func testEntireBookRouteReservesExactlyFiveBossesForLevelNine() throws {
        var seenFinals: Set<BossModifier> = []
        var seenNormal: Set<BossModifier> = []
        for seed in 0..<128 {
            var run = RunState(seed: "final-route-\(seed)")
            repeat {
                let announced = try XCTUnwrap(run.pendingBoss)
                XCTAssertEqual(finalBosses.contains(announced), run.level == 9,
                               "Level \(run.level), slot \(run.slot), seed \(seed)")
                if run.level == 9 { seenFinals.insert(announced) }
                else { seenNormal.insert(announced) }
            } while run.advance()
        }
        XCTAssertEqual(seenFinals, finalBosses)
        XCTAssertEqual(seenNormal, Set(BossModifier.allCases).subtracting(finalBosses))
    }

    func testFinalBossOnlyAppearsInLastPuzzleAndMatchesItsAnnouncement() throws {
        for slot in [PuzzleSlot.easy, .medium] {
            var run = RunState(seed: "final-normal-\(slot)")
            run.level = 9
            run.slot = slot
            run.pendingBoss = .heavyLifter
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertNil(puzzle.boss)
            XCTAssertEqual(run.pendingBoss, .heavyLifter)
        }
        for boss in finalBosses {
            var run = RunState(seed: "final-announced-\(boss.rawValue)")
            run.level = 9
            run.slot = .boss
            run.pendingBoss = boss
            let bossStream = run.streams.boss.state
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertEqual(puzzle.boss, boss)
            XCTAssertEqual(puzzle.target, run.target * boss.targetMultiplier)
            XCTAssertNil(run.pendingBoss)
            if !boss.foulsSquaresEachTurn {
                XCTAssertEqual(run.streams.boss.state, bossStream)
            } // The Shredder legitimately rolls its first three fouled squares.
        }
    }

    func testLegacyUndealtBriefingRepairsWrongPoolOnceAndPersistsAnnouncement() throws {
        for (level, oldBoss) in [(1, BossModifier.heavyLifter), (9, .collector)] {
            var legacy = RunState(seed: "legacy-final-pool-\(level)")
            legacy.level = level
            legacy.slot = .boss
            legacy.pendingBoss = oldBoss
            let oldStream = legacy.streams.boss.state
            let restored = try JSONDecoder().decode(RunState.self,
                                                    from: JSONEncoder().encode(legacy))
            let announced = try XCTUnwrap(restored.pendingBoss)
            XCTAssertEqual(finalBosses.contains(announced), level == 9)
            XCTAssertNotEqual(restored.streams.boss.state, oldStream)
            let roundTrip = try JSONDecoder().decode(RunState.self,
                                                     from: JSONEncoder().encode(restored))
            XCTAssertEqual(roundTrip.pendingBoss, announced)
            XCTAssertEqual(roundTrip.streams.boss.state, restored.streams.boss.state)
            var game = Game(run: roundTrip)
            try game.startPuzzle()
            XCTAssertEqual(game.puzzle?.boss, announced)
        }
    }

    func testLegacyActiveBossIsNotRewrittenOrRerolled() throws {
        for (level, oldBoss) in [(1, BossModifier.heavyLifter), (9, .collector)] {
            var game = Game(seed: "active-legacy-final-\(level)")
            game.run.level = level
            game.run.slot = .boss
            try game.startPuzzle()
            game.run.puzzle?.boss = oldBoss
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let originalPuzzle = try encoder.encode(XCTUnwrap(game.puzzle))
            let originalStream = game.run.streams.boss.state
            let restored = try Game(decoding: game.encoded())
            XCTAssertEqual(try encoder.encode(XCTUnwrap(restored.puzzle)), originalPuzzle)
            XCTAssertEqual(restored.run.streams.boss.state, originalStream)
            XCTAssertNil(restored.run.pendingBoss)
        }
    }

    func testLegacyPendingBossRepairsWhenLeavingShopForBossBriefing() throws {
        var game = Game(seed: "legacy-pending-final")
        game.run.level = 9
        game.run.slot = .medium
        game.run.pendingBoss = .collector
        try game.startPuzzle()
        game.qaMeetTarget()
        _ = try game.cashOut()
        game.openShop()
        let stream = game.run.streams.boss.state
        var restored = try Game(decoding: game.encoded())
        XCTAssertEqual(restored.run.streams.boss.state, stream,
                       "A post-Puzzle Shop must not silently consume a boss roll")
        XCTAssertTrue(restored.advance())
        let announced = try XCTUnwrap(restored.run.pendingBoss)
        XCTAssertTrue(finalBosses.contains(announced))
        try restored.startPuzzle()
        XCTAssertEqual(restored.puzzle?.boss, announced)
    }

    func testDirectDealCannotUseWrongPendingPool() throws {
        for (level, oldBoss) in [(1, BossModifier.heavyLifter), (9, .collector)] {
            var run = RunState(seed: "direct-final-pool-\(level)")
            run.level = level
            run.slot = .boss
            run.pendingBoss = oldBoss
            let puzzle = try PuzzleState.create(run: &run)
            XCTAssertEqual(finalBosses.contains(try XCTUnwrap(puzzle.boss)), level == 9)
        }
    }
}
