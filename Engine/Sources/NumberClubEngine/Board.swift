import Foundation

/// How a number came to be in a square. Clues score nothing (§6), so the
/// board has to remember which numbers the player actually earned.
public enum Provenance: String, Codable, Sendable {
    case given, player, clue
}

public struct Board: Codable, Sendable {
    public let solution: [Digit]
    public let isGiven: [Bool]
    public private(set) var placed: [Digit?]
    public private(set) var filledBy: [Provenance?]

    public init(_ generated: GeneratedPuzzle) {
        solution = generated.solution
        isGiven = generated.isGiven
        placed = (0..<81).map { generated.isGiven[$0] ? generated.solution[$0] : nil }
        filledBy = (0..<81).map { generated.isGiven[$0] ? .given : nil }
    }

    public subscript(square: Square) -> Digit? { placed[square.index] }

    public func isBlank(_ square: Square) -> Bool { placed[square.index] == nil }
    public func correctDigit(at square: Square) -> Digit { solution[square.index] }

    /// The squares still waiting for a number.
    public var blanks: [Square] { Square.all.filter { placed[$0.index] == nil } }
    public var isFull: Bool { !placed.contains(where: { $0 == nil }) }

    public mutating func fill(_ square: Square, with digit: Digit, by provenance: Provenance) {
        placed[square.index] = digit
        filledBy[square.index] = provenance
    }

    /// Which of the three units through `square` this placement just finished (§6).
    public func unitsCompleted(at square: Square) -> [Unit] {
        var completed: [Unit] = []
        for unit in [Unit.row, .col, .box] where Geometry.cells(of: unit, through: square)
            .allSatisfy({ placed[$0.index] != nil }) {
            completed.append(unit)
        }
        return completed
    }

    /// How many copies of `digit` are locked on the board, Givens included.
    /// This is what the Silver Marker counts, and what makes the Pool knowable.
    public func count(of digit: Digit) -> Int {
        placed.reduce(0) { $1 == digit ? $0 + 1 : $0 }
    }

    /// Squares holding a number that contradicts the solution. Nothing wrong
    /// ever stays on the board, so this is only a safety net for the UI.
    public func conflicts() -> [Square] {
        Square.all.filter { placed[$0.index] != nil && placed[$0.index] != solution[$0.index] }
    }
}
