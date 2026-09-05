import Foundation

/// A published Book's standing advantage. Benefits belong to the Book itself;
/// there is no separate board archetype to choose or name.
public enum BookBenefit: Sendable {
    case extraNumber
    case openingFloat
    case marginClue
    case oneMoreTurn

    public var title: String {
        switch self {
        case .extraNumber: return "+1 Hand Size"
        case .openingFloat: return "+10 Coins"
        case .marginClue: return "+1 Clue"
        case .oneMoreTurn: return "+1 Turn"
        }
    }

    public var detail: String {
        switch self {
        case .extraNumber: return "Begin with 7 numbers instead of 6."
        case .openingFloat: return "Begin with 15 coins instead of 5."
        case .marginClue: return "Begin every puzzle with one clue."
        case .oneMoreTurn: return "Begin every puzzle with 11 turns instead of 10."
        }
    }

    public var before: Int {
        switch self {
        case .extraNumber: return Baseline.handSize
        case .openingFloat: return Baseline.coins
        case .marginClue: return Baseline.clues
        case .oneMoreTurn: return Baseline.turns
        }
    }

    public var after: Int {
        switch self {
        case .extraNumber: return Baseline.handSize + handSizeDelta
        case .openingFloat: return Baseline.coins + coinsDelta
        case .marginClue: return Baseline.clues + clueDelta
        case .oneMoreTurn: return Baseline.turns + turnsDelta
        }
    }

    public var handSizeDelta: Int { self == .extraNumber ? 1 : 0 }
    public var coinsDelta: Int { self == .openingFloat ? 10 : 0 }
    public var clueDelta: Int { self == .marginClue ? 1 : 0 }
    public var turnsDelta: Int { self == .oneMoreTurn ? 1 : 0 }
}

/// The fixed rules of a published Sudoku Book. Obstacles are intentionally
/// separate: a Book changes the puzzle itself; an Obstacle changes the tools
/// available while solving it.
public enum Book: String, Codable, CaseIterable, Sendable {
    case probably
    case slightlyHarder
    case noPressure
    case bites

    public var benefit: BookBenefit {
        switch self {
        case .probably: return .extraNumber
        case .slightlyHarder: return .openingFloat
        case .noPressure: return .marginClue
        case .bites: return .oneMoreTurn
        }
    }

    public var volume: Int {
        switch self {
        case .probably: return 1
        case .slightlyHarder: return 2
        case .noPressure: return 3
        case .bites: return 4
        }
    }

    /// Book 2 removes three givens at every normal slot. The generator still
    /// applies each slot's technique gate, so an easier gate is never used to
    /// compensate for the smaller clue count.
    public func givens(for difficulty: Difficulty) -> Int {
        let reduction: Int
        switch self {
        case .probably: reduction = 0
        case .slightlyHarder: reduction = 3
        case .noPressure: reduction = 3
        case .bites: reduction = 6
        }
        return max(17, difficulty.givens - reduction)
    }

    public func target(level: Int, slot: PuzzleSlot) -> Int {
        let multiplier: Double
        switch self {
        case .probably, .slightlyHarder: multiplier = 1
        case .noPressure: multiplier = 1.25
        case .bites: multiplier = 1.5
        }
        return Int((Double(Targets.target(level: level, slot: slot)) * multiplier).rounded(.down))
    }

    public var startingCoins: Int {
        switch self {
        case .bites: return 3
        case .probably, .slightlyHarder, .noPressure: return Baseline.coins
        }
    }
}
