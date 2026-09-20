import Foundation
import XCTest
@testable import ProbablySudokuEngine

/// A reproducible mechanical probe, not a player win-rate estimate. The policy
/// knows the solution, but can only place an actually held, currently playable
/// card. It keeps normal Hands, draws, targets, Turn limits and boss rules.
/// No acquisition model, mistakes, rescue or adaptive Shop build is simulated.
final class ExpandedBossBalanceTests: XCTestCase {
    private struct Build {
        let name: String
        let bookmarks: [String]
    }

    private struct Row: Codable, Equatable {
        let seed: String
        let boss: String
        let build: String
        let chapter: Int
        let initialTarget: Int
        let finalTarget: Int
        let score: Int
        let phase: String
        let turnLimit: Int
        let banks: Int
        let placements: Int
        let manualEnds: Int
        let blanksRemaining: Int
        let heldAtFinish: Int
        let poolAtFinish: Int
        let carryAtFinish: Int
        let scoreToTarget: Double
        let observations: [String]
    }

    private struct Simulation {
        let row: Row
        let saved: Data
    }

    private let builds = [
        Build(name: "Three-slot core", bookmarks: [Bookmarks.localGossip, Bookmarks.opEd,
                                                   Bookmarks.theSundaySupplement]),
        Build(name: "Five-slot draw and growth", bookmarks: [Bookmarks.localGossip, Bookmarks.opEd,
            Bookmarks.theSundaySupplement, Bookmarks.crosswordDaily, Bookmarks.rollingPresses])
    ]

    private func startingGame(boss: BossModifier, build: Build) throws -> Game {
        // Every boss at the same chapter receives the same board and opening
        // Pool seed. The engine still applies that boss's own starting rules.
        let chapter = boss.isFinalBoss ? 9 : 3
        let seed = "expanded-boss-balance-chapter-\(chapter)"
        var game = Game(seed: seed, book: .probably)
        game.run.level = chapter
        game.run.slot = .boss
        game.run.pendingBoss = boss
        game.run.bookmarks = build.bookmarks.enumerated().map { index, definition in
            OwnedBookmark(defID: definition, boughtAtLevel: 1, pricePaid: 0,
                id: SkipOffer.stableIdentity(seed: seed, domain: "balance.bookmark.\(index)"))
        }
        game.run.buffs = [Buffs.freshInk, Buffs.luckyDip].enumerated().map { index, definition in
            OwnedBuff(defID: definition, pricePaid: 0,
                id: SkipOffer.stableIdentity(seed: seed, domain: "balance.buff.\(index)"))
        }
        try game.startPuzzle()
        let opening = try XCTUnwrap(game.puzzle)
        XCTAssertEqual(opening.boss, boss)
        XCTAssertEqual(opening.target, game.run.book.target(level: chapter, slot: .boss))
        // Fixed fixture resources, not simulated purchases: choose the first
        // four visible blanks so both builds can actually trigger their marks.
        // Their positions are independent of the hidden digits.
        let blanks = Array(opening.board.blanks.prefix(4))
        XCTAssertEqual(blanks.count, 4)
        game.run.markers = zip([Markers.golden, Markers.crimson, Markers.violet, Markers.sapphire], blanks)
            .map { entry in
                OwnedMarker(defID: entry.0, boughtAtLevel: 1, pricePaid: 0, squares: [entry.1])
            }
        MarkerRuntime.synchronizeOwnership(run: &game.run)
        XCTAssertTrue(BossEligibility.isEligible(boss, run: game.run, board: opening.board),
                      "Probe must supply a meaningful initial build for \(boss.name)")
        return game
    }

    private func conservation(_ game: Game) throws {
        let puzzle = try XCTUnwrap(game.puzzle)
        XCTAssertNil(Conservation.check(board: puzzle.board, pool: puzzle.pool,
                                       hand: puzzle.hand + puzzle.markerState.reservedForkCards))
        XCTAssertEqual(puzzle.hand.count, puzzle.handCardIDs.count)
        XCTAssertEqual(Set(puzzle.handCardIDs).count, puzzle.hand.count)
    }

    private func nextPlacement(_ game: Game) -> (hand: Int, square: Square)? {
        guard let puzzle = game.puzzle else { return nil }
        var choices: [(hand: Int, square: Square, priority: Int)] = []
        for index in puzzle.hand.indices where !puzzle.isBlocked(handIndex: index) {
            for square in puzzle.board.blanks where !puzzle.isBarred(square)
                && puzzle.board.correctDigit(at: square) == puzzle.hand[index] {
                // Prefer visible nearly-complete units. This fixed heuristic
                // does not search future draws or preview alternative scores.
                let fewestBlanks = [ProbablySudokuEngine.Unit.row, .col, .box].map { unit in
                    Geometry.cells(of: unit, through: square).filter { puzzle.board.isBlank($0) }.count
                }.min() ?? 9
                var priority = 20 - fewestBlanks
                if puzzle.boss == .chainStitcher, let anchor = puzzle.bossState.scoring.chainAnchor,
                   anchor.row == square.row || anchor.col == square.col || anchor.box == square.box {
                    priority += 100
                }
                if puzzle.boss == .dryPress {
                    let marked = !game.run.markers(covering: square).isEmpty
                    if marked == puzzle.bossState.scoring.dryPressReady { priority += 100 }
                }
                choices.append((index, square, priority))
            }
        }
        return choices.sorted {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.square.index != $1.square.index { return $0.square.index < $1.square.index }
            return $0.hand < $1.hand
        }.first.map { ($0.hand, $0.square) }
    }

    private func simulate(_ starting: Game, build: Build, restoring: Bool) throws -> Simulation {
        var game = starting
        let initial = try XCTUnwrap(game.puzzle)
        let boss = try XCTUnwrap(initial.boss)
        let initialTarget = initial.target
        var placements = 0, manualEnds = 0
        var paidByTurn: [Int: Int] = [:]
        // Both builds deliberately spend their two genuinely held Buffs at the
        // opening. Embargo and Royalty remain active; these are real commits.
        for source in game.run.buffs {
            XCTAssertTrue(BuffRuntime.canUse(buffID: source.id, run: game.run))
            _ = try game.beginBuff(id: source.id)
            XCTAssertFalse(game.run.buffs.contains { $0.id == source.id })
            try conservation(game)
        }
        for _ in 0..<200 {
            guard let puzzle = game.puzzle, puzzle.phase == .playing else { break }
            XCTAssertTrue(game.run.pendingItemDecisions.isEmpty, "This probe has no optional-choice sources")
            if let next = nextPlacement(game) {
                let result = try game.place(handIndex: next.hand, at: next.square)
                XCTAssertTrue(result.correct)
                XCTAssertEqual(result.penalty, 0)
                placements += 1
            } else {
                _ = try game.endTurn()
                manualEnds += 1
            }
            try conservation(game)
            if let ledger = game.puzzle?.lastScoringLedger {
                if let prior = paidByTurn[ledger.turnNumber] { XCTAssertEqual(prior, ledger.total) }
                paidByTurn[ledger.turnNumber] = ledger.total
            }
            if restoring, (placements + manualEnds).isMultiple(of: 3) {
                let saved = try game.encoded()
                game = try Game(decoding: saved)
                XCTAssertEqual(try game.encoded(), saved)
            }
        }
        let final = try XCTUnwrap(game.puzzle)
        XCTAssertNotEqual(final.phase, .playing, "Policy must reach a result within its bounded action budget")
        XCTAssertEqual(final.score, paidByTurn.values.reduce(0, +), "Every awarded Point must be explained by an actual bank receipt")
        XCTAssertLessThanOrEqual(paidByTurn.count, final.turnsMax)
        XCTAssertLessThanOrEqual(final.score, ScoreMath.ceiling)
        if final.phase == .won {
            XCTAssertGreaterThanOrEqual(final.score, final.target)
            XCTAssertTrue(BossRuntime.reviewQualified(puzzle: final))
        }
        let ratio = Double(final.score) / Double(max(1, final.target))
        var observations: [String] = []
        if final.phase == .won && paidByTurn.count <= 1 { observations.append("Target met in one bank with this fixed loadout") }
        if final.phase != .won && ratio < 0.25 { observations.append("Below quarter-target despite this perfect-placement policy") }
        if final.board.isFull && final.score < final.target { observations.append("Whole board filled below target") }
        if final.bossState.scoring.serialCarry > 0 { observations.append("Earned Serial carry remains unclaimed at stopping point") }
        let row = Row(seed: game.run.seed, boss: boss.rawValue, build: build.name,
            chapter: game.run.level, initialTarget: initialTarget, finalTarget: final.target,
            score: final.score, phase: final.phase.rawValue, turnLimit: final.turnsMax,
            banks: paidByTurn.count, placements: placements, manualEnds: manualEnds,
            blanksRemaining: final.board.blanks.count, heldAtFinish: final.hand.count,
            poolAtFinish: final.pool.total, carryAtFinish: final.bossState.scoring.serialCarry,
            scoreToTarget: ratio, observations: observations)
        return Simulation(row: row, saved: try game.encoded())
    }

    func testSeededExpandedBossBuildProbeAndMidPuzzleRestoreAgree() throws {
        var rows: [Row] = []
        for boss in BossModifier.legacyRegularBosses + BossModifier.legacyFinalBosses where boss.isExpanded {
            for build in builds {
                let starting = try startingGame(boss: boss, build: build)
                let uninterrupted = try simulate(starting, build: build, restoring: false)
                let resumed = try simulate(try Game(decoding: starting.encoded()), build: build, restoring: true)
                XCTAssertEqual(uninterrupted.row, resumed.row, "\(boss.name) / \(build.name)")
                XCTAssertEqual(uninterrupted.saved, resumed.saved, "Saving cannot reroll draws, replay sources or alter a boss")
                rows.append(uninterrupted.row)
                let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
                print("EXPANDED_BOSS_BALANCE \(String(decoding: try encoder.encode(uninterrupted.row), as: UTF8.self))")
            }
        }
        XCTAssertEqual(rows.count, 40)
        if let path = ProcessInfo.processInfo.environment["EXPANDED_BOSS_BALANCE_REPORT"] {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(rows).write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
}
