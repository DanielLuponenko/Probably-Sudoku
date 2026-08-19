import Foundation

// MARK: - Digit

/// One of the nine playing numbers.
public enum Digit: Int, CaseIterable, Codable, Hashable, Comparable, Sendable {
    case one = 1, two, three, four, five, six, seven, eight, nine

    public init?(_ raw: Int) { self.init(rawValue: raw) }
    public static func < (a: Digit, b: Digit) -> Bool { a.rawValue < b.rawValue }
}

public extension Digit {
    static let all = Digit.allCases
}

// MARK: - Square

/// A cell of the grid, 0..<81, row-major: `index = row * 9 + col`.
public struct Square: Hashable, Codable, Comparable, Sendable, CustomStringConvertible {
    public let index: Int

    public init(_ index: Int) {
        precondition((0..<81).contains(index), "Square index out of range: \(index)")
        self.index = index
    }
    public init(row: Int, col: Int) { self.init(row * 9 + col) }

    public var row: Int { index / 9 }
    public var col: Int { index % 9 }
    public var box: Int { (row / 3) * 3 + (col / 3) }

    /// "R4C7" — the notation the design doc uses for Marker squares.
    public var description: String { "R\(row + 1)C\(col + 1)" }

    public static func < (a: Square, b: Square) -> Bool { a.index < b.index }
    public static let all: [Square] = (0..<81).map(Square.init)
}

// MARK: - Units

public enum Unit: String, Codable, Sendable {
    case row, col, box
}

public enum Geometry {
    public static let rows: [[Square]] = (0..<9).map { r in (0..<9).map { Square(row: r, col: $0) } }
    public static let cols: [[Square]] = (0..<9).map { c in (0..<9).map { Square(row: $0, col: c) } }
    public static let boxes: [[Square]] = (0..<9).map { b in
        let br = (b / 3) * 3, bc = (b % 3) * 3
        return (0..<3).flatMap { dr in (0..<3).map { dc in Square(row: br + dr, col: bc + dc) } }
    }
    /// All 27 units, in the order rows, cols, boxes — matching the solver's indexing.
    public static let allUnits: [[Square]] = rows + cols + boxes

    public static func cells(of unit: Unit, through square: Square) -> [Square] {
        switch unit {
        case .row: return rows[square.row]
        case .col: return cols[square.col]
        case .box: return boxes[square.box]
        }
    }

    /// The 20 squares that share a row, column or box with `square`.
    public static let peers: [[Int]] = Square.all.map { sq in
        var set = Set<Int>()
        for s in rows[sq.row] { set.insert(s.index) }
        for s in cols[sq.col] { set.insert(s.index) }
        for s in boxes[sq.box] { set.insert(s.index) }
        set.remove(sq.index)
        return set.sorted()
    }
}

// MARK: - Difficulty

public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, medium, boss

    /// §2 — Givens per difficulty.
    public var givens: Int {
        switch self {
        case .easy: return 41
        case .medium: return 35
        case .boss: return 29
        }
    }
    public var blanks: Int { 81 - givens }

    /// §2 — target multiplier against the Level's `base`.
    public var targetMultiplier: Double {
        switch self {
        case .easy: return 1.0
        case .medium: return 1.5
        case .boss: return 2.0
        }
    }
}

/// Which of a Level's three Puzzles this is.
public enum PuzzleSlot: Int, Codable, CaseIterable, Sendable {
    case easy = 0, medium = 1, boss = 2

    public var difficulty: Difficulty {
        switch self {
        case .easy: return .easy
        case .medium: return .medium
        case .boss: return .boss
        }
    }
}

// MARK: - Targets

public enum Targets {
    /// §2 — `base = 1000 × 2^(Level − 1)`, then × the slot multiplier.
    public static func base(level: Int) -> Int {
        1000 * (1 << (level - 1))
    }
    public static func target(level: Int, slot: PuzzleSlot) -> Int {
        Int((Double(base(level: level)) * slot.difficulty.targetMultiplier).rounded(.down))
    }
}

// MARK: - Rarity

public enum Rarity: String, Codable, CaseIterable, Sendable {
    case common, uncommon, rare
}
