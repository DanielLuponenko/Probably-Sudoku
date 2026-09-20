import Foundation

/// Saved encounter decisions, separate from presentation and animation state.
public struct BossEncounterState: Codable, Equatable, Sendable {
    public var pledgedCard: CatalogueHandCard?
    public var turnCommitted = false
    public var selectedEdition = 0
    public var editionScores = [0, 0]
    public var editionTargets: [Int] = []
    public var banksUsed = 0
    public init() {}

    private enum CodingKeys: String, CodingKey {
        case pledgedCard, turnCommitted, selectedEdition, editionScores, editionTargets, banksUsed
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pledgedCard = try c.decodeIfPresent(CatalogueHandCard.self, forKey: .pledgedCard)
        turnCommitted = try c.decodeIfPresent(Bool.self, forKey: .turnCommitted) ?? false
        selectedEdition = min(1, max(0, try c.decodeIfPresent(Int.self, forKey: .selectedEdition) ?? 0))
        let scores = try c.decodeIfPresent([Int].self, forKey: .editionScores) ?? [0, 0]
        editionScores = (0..<2).map { scores.indices.contains($0) ? max(0, scores[$0]) : 0 }
        let targets = try c.decodeIfPresent([Int].self, forKey: .editionTargets) ?? []
        editionTargets = targets.count == 2 ? targets.map { max(0, $0) } : []
        banksUsed = max(0, try c.decodeIfPresent(Int.self, forKey: .banksUsed) ?? 0)
    }
}

public enum BossEncounterRules {
    /// Applied after puzzle-wide Marker/Buff additions and BEFORE held
    /// Bookmarks. The exact card UUID is included in its scoring operation.
    public static let collateralMult = 2.0
    public static let collateralMultBonus = collateralMult

    public static func startingTarget(base: Int, boss: BossModifier?) -> Int {
        switch boss {
        case .collateral: return ScoreMath.add(base, base / 2 + base % 2)
        case .lastEdition: return max(1, base / 4 + (base % 4 == 0 ? 0 : 1))
        default: return ScoreMath.integer(Double(base) * Double(boss?.targetMultiplier ?? 1))
        }
    }

    public static func bankLimit(boss: BossModifier?) -> Int? { boss == .lastEdition ? 1 : nil }

    public static func canChooseEdition(run: RunState) -> Bool {
        guard canPrepare(run: run), let puzzle = run.puzzle else { return false }
        return puzzle.boss == .splitEdition
    }

    public static func canPledge(cardID: UUID, run: RunState) -> Bool {
        guard canPrepare(run: run), let puzzle = run.puzzle,
              puzzle.boss == .collateral, puzzle.bossState.encounter.pledgedCard == nil,
              let index = puzzle.handCards.firstIndex(where: { $0.id == cardID }),
              !puzzle.isBlocked(handIndex: index) || BuffRuntime.releaseAllows(handIndex: index, puzzle: puzzle)
        else { return false }
        // Pledging must leave another playable card. It never reads a hidden
        // solution to promise whether that number has a correct destination.
        return puzzle.hand.indices.contains { other in
            other != index && (!puzzle.isBlocked(handIndex: other)
                || BuffRuntime.releaseAllows(handIndex: other, puzzle: puzzle))
        }
    }

    private static func canPrepare(run: RunState) -> Bool {
        guard run.outcome == nil, run.shop == nil, run.pendingItemDecisions.isEmpty,
              let puzzle = run.puzzle, puzzle.phase == .playing,
              !puzzle.bossState.encounter.turnCommitted,
              !puzzle.bookmarkState.turn.actionTaken, puzzle.pendingBase == 0,
              !puzzle.bossState.placementStarted else { return false }
        return true
    }

    public static func editionTargets(puzzle: PuzzleState) -> [Int] {
        let saved = puzzle.bossState.encounter.editionTargets
        return saved.count == 2 ? saved : [puzzle.target / 2 + puzzle.target % 2, puzzle.target / 2]
    }

    public static func targetSatisfied(puzzle: PuzzleState) -> Bool {
        guard BossRuntime.reviewQualified(puzzle: puzzle) else { return false }
        if puzzle.boss == .splitEdition {
            let targets = editionTargets(puzzle: puzzle)
            return (0..<2).allSatisfy { puzzle.bossState.encounter.editionScores[$0] >= targets[$0] }
        }
        if puzzle.boss == .lastEdition && puzzle.bossState.encounter.banksUsed == 0 { return false }
        return puzzle.score >= puzzle.target
    }

    /// A saved won/Keep Filling phase was already qualified by its original
    /// engine. Preserve that historical entitlement; the new objectives also
    /// verify their saved ledgers/bank count before a result can be claimed.
    static func completionQualified(puzzle: PuzzleState) -> Bool {
        if [.collateral, .splitEdition, .lastEdition].contains(puzzle.boss) {
            return targetSatisfied(puzzle: puzzle)
        }
        return BossRuntime.reviewQualified(puzzle: puzzle)
    }

    static func puzzleStarted(puzzle: inout PuzzleState) {
        if puzzle.boss == .splitEdition {
            puzzle.bossState.encounter.editionTargets = [puzzle.target / 2 + puzzle.target % 2, puzzle.target / 2]
        }
    }

    static func actionAccepted(puzzle: inout PuzzleState) {
        if [.collateral, .splitEdition, .lastEdition].contains(puzzle.boss) {
            puzzle.bossState.encounter.turnCommitted = true
        }
    }

    /// Award or penalize score exactly once at its existing engine commit.
    /// Previewing does not call this. An edition never transfers excess to its
    /// neighbour; negative penalties debit the selected edition first.
    static func addScore(_ delta: Int, puzzle: inout PuzzleState) {
        let before = puzzle.score
        // Historical scores above today's positive-award ceiling still take
        // the same wrong-placement penalty; ScoreMath.add preserves them only
        // when adding a new award.
        puzzle.score = delta < 0 ? max(0, before + delta) : ScoreMath.add(before, delta)
        guard puzzle.boss == .splitEdition else { return }
        let index = puzzle.bossState.encounter.selectedEdition
        let actual = puzzle.score - before
        if actual >= 0 {
            puzzle.bossState.encounter.editionScores[index] = ScoreMath.add(
                puzzle.bossState.encounter.editionScores[index], actual)
        } else {
            let paid = min(-actual, puzzle.bossState.encounter.editionScores[index])
            puzzle.bossState.encounter.editionScores[index] -= paid
            puzzle.bossState.encounter.editionScores[1 - index] = max(0,
                puzzle.bossState.encounter.editionScores[1 - index] - (-actual - paid))
        }
    }

    static func didBank(puzzle: inout PuzzleState) {
        if [.collateral, .splitEdition, .lastEdition].contains(puzzle.boss) {
            puzzle.bossState.encounter.banksUsed += 1
        }
        // Return before refill, so this is an existing token, never a bonus
        // draw or new identity. Held reservation also counts through Redraw.
        if let card = puzzle.bossState.encounter.pledgedCard {
            puzzle.bossState.encounter.pledgedCard = nil
            if !puzzle.handCardIDs.contains(card.id) { puzzle.appendHandCard(card) }
        }
    }

    static func turnStarted(puzzle: inout PuzzleState) {
        puzzle.bossState.encounter.turnCommitted = false
    }
}

public extension Actions {
    @discardableResult
    static func pledgeBossCard(_ run: inout RunState, cardID: UUID) -> Bool {
        guard BossEncounterRules.canPledge(cardID: cardID, run: run), var puzzle = run.puzzle else { return false }
        puzzle.ensureHandIdentities(seed: run.seed)
        guard let index = puzzle.handCardIDs.firstIndex(of: cardID) else { return false }
        let card = puzzle.removeHandCard(at: index)
        puzzle.bossState.encounter.pledgedCard = card
        puzzle.assertConservation()
        run.puzzle = puzzle
        return true
    }

    @discardableResult
    static func chooseBossEdition(_ run: inout RunState, edition: Int) -> Bool {
        guard (0..<2).contains(edition), BossEncounterRules.canChooseEdition(run: run),
              run.puzzle?.bossState.encounter.selectedEdition != edition else { return false }
        run.puzzle?.bossState.encounter.selectedEdition = edition
        return true
    }
}

public extension Game {
    @discardableResult
    mutating func pledgeBossCard(cardID: UUID) -> Bool { Actions.pledgeBossCard(&run, cardID: cardID) }
    @discardableResult
    mutating func chooseBossEdition(edition: Int) -> Bool { Actions.chooseBossEdition(&run, edition: edition) }
    @discardableResult
    mutating func chooseBossEdition(_ edition: Int) -> Bool { Actions.chooseBossEdition(&run, edition: edition) }
}

public extension PuzzleState {
    var reservedBossCards: [CatalogueHandCard] { bossState.encounter.pledgedCard.map { [$0] } ?? [] }
    /// Target for a replacement Hand while a card sits in Collateral's sleeve.
    var drawableHandSize: Int { max(0, handSize - reservedBossCards.count) }
}

public enum BossFamily: String, Codable, Sendable {
    case information, scoring, resources, time, board, hand, sequencing, economy, preparation, final
}
public extension BossModifier {
    var encounterFamily: BossFamily {
        switch self {
        case .fog: return .information
        case .mirror, .backPage, .publicist, .rivalColumn: return .scoring
        case .erratum, .rebinder, .returnSlip: return .resources
        case .accountant, .royaltyContract: return .economy
        case .tikTak: return .time
        case .garryTheGray: return .board
        case .bookends: return .hand
        case .chainStitcher, .dryPress: return .sequencing
        case .collateral: return .preparation
        default: return .final
        }
    }
}
