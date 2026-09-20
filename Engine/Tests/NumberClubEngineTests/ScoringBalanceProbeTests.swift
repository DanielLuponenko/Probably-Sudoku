import XCTest
@testable import ProbablySudokuEngine

/// A reproducible upper-bound comparison, not a claimed player win rate.
/// Every remaining digit is held in one deliberately oversized QA hand; no Shop availability or
/// human deduction is simulated. Only production placement/bank arithmetic runs.
final class ScoringBalanceProbeTests: XCTestCase {
    func testSeededTargetScaleAndEconomyProbe() throws {
        var rows: [String] = []
        for level in [1, 5, 9] {
            for slot in [PuzzleSlot.easy, .boss] {
                var seedGame = Game(seed: "score-balance-\(level)-\(slot.rawValue)")
                seedGame.run.level = level
                seedGame.run.slot = slot
                seedGame.run.pendingBoss = .censor
                try seedGame.startPuzzle()
                seedGame.run.puzzle?.boss = nil // isolate score formula from restrictions
                seedGame.run.puzzle?.target = ScoreMath.ceiling
                // This is explicitly a single-batch ceiling: hold every
                // remaining digit, preserving conservation and preventing an
                // incidental mid-board automatic bank from lowering growth.
                for digit in Digit.allCases {
                    while seedGame.run.puzzle?.pool.take(digit) == true {
                        seedGame.run.puzzle?.hand.append(digit)
                    }
                }
                let puzzle = try XCTUnwrap(seedGame.puzzle)
                let clearedUnits = (Geometry.rows + Geometry.cols + Geometry.boxes).filter {
                    $0.contains { puzzle.board.isBlank($0) }
                }.count
                let digitPoints = puzzle.board.blanks.reduce(0) { $0 + puzzle.board.correctDigit(at: $1).rawValue * 10 }
                let base = digitPoints + clearedUnits * 45 + 500
                let target = Targets.target(level: level, slot: slot)
                for build in 0..<3 {
                    var game = seedGame
                    let ids: [String]
                    let factor: Double
                    switch build {
                    case 0: ids = []; factor = 1
                    case 1: ids = ["bm_op_ed", "bm_stop_the_presses"]; factor = 2 // Third placement removes Stop.
                    default:
                        ids = ["bm_front_page_splash", Bookmarks.rollingPresses, Bookmarks.syndication,
                               "bm_stop_the_presses", "bm_the_sunday_supplement"]
                        let priorWins = Double((level - 1) * 3)
                        game.run.runItemState[Bookmarks.syndication] = priorWins
                        factor = 6 * (1 + 0.5 * Double(clearedUnits)) * (1 + priorWins * 0.25) * (slot == .boss ? 3 : 2)
                    }
                    for id in ids { game.give(ad: id) }
                    let coins = game.run.coins
                    for square in puzzle.board.blanks {
                        let digit = puzzle.board.correctDigit(at: square)
                        _ = try game.place(handIndex: XCTUnwrap(game.stackHand(with: digit)), at: square)
                    }
                    let score = try XCTUnwrap(game.puzzle?.score)
                    XCTAssertEqual(score, Int((Double(base) * factor).rounded(.down)))
                    XCTAssertEqual(game.run.coins, coins, "Points/Mult must not mint coins")
                    XCTAssertTrue(try XCTUnwrap(game.puzzle).board.isFull)
                    rows.append("| \(level) | \(slot == .boss ? "Boss" : "Ordinary") | \(["None", "Op-Ed → Stop", "Five-slot scaling"][build]) | \(target) | \(score) | \(String(format: "%.2f", Double(score) / Double(target))) |")
                }
            }
        }
        if let path = ProcessInfo.processInfo.environment["SCORING_BALANCE_REPORT"] {
            let header = "# Ordered scoring target/economy probe\n\nDeterministic perfect-placement single-Turn ceiling, not a simulated human run. Every remaining digit is deliberately held in one oversized QA hand to isolate the scoring formula; card conservation is preserved. Seeds: score-balance-chapter-slot. Boss restrictions were disabled only to isolate the formula. Targets are the unchanged base Book ladder; Final Draft is another ×4 target. Five-slot scaling uses Front Page Splash → Rolling Presses → Syndication → Stop the Presses → Sunday Supplement, with three prior wins per completed chapter. Stop the Presses has expired after the third eligible placement in this full-board batch. Every scenario verified unchanged coins. Shops, acquisition likelihood, mistakes and forced End Turns are excluded.\n\n| Chapter | Puzzle | Build | Target | Full-board score | Score/target |\n|---|---|---|---:|---:|---:|\n"
            try (header + rows.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }
}
