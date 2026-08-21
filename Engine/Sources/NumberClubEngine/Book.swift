import Foundation

/// The fixed rules of a published Sudoku Book. Obstacles are intentionally
/// separate: a Book changes the puzzle itself; an Obstacle changes the tools
/// available while solving it.
public enum Book: String, Codable, CaseIterable, Sendable {
    case probably
    case slightlyHarder

    public var volume: Int {
        switch self {
        case .probably: return 1
        case .slightlyHarder: return 2
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
        }
        return max(17, difficulty.givens - reduction)
    }

    public func target(level: Int, slot: PuzzleSlot) -> Int {
        Targets.target(level: level, slot: slot)
    }

    public var startingCoins: Int { Baseline.coins }
}
