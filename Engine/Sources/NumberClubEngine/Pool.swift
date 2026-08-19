import Foundation

/// §4 — the undrawn numbers. Never shown to the player and never counted for
/// them, but always knowable: a finished sudoku holds each digit nine times,
/// so `pool(d) = 9 − board(d) − hand(d)`.
public struct Pool: Codable, Sendable {
    private var counts: [Int]   // index 0 = digit 1

    public init() { counts = [Int](repeating: 0, count: 9) }

    /// Every Blank puts its solution digit into the Pool.
    public init(blanksOf board: Board) {
        counts = [Int](repeating: 0, count: 9)
        for i in 0..<81 where !board.isGiven[i] {
            counts[board.solution[i].rawValue - 1] += 1
        }
    }

    public subscript(digit: Digit) -> Int { counts[digit.rawValue - 1] }
    public var total: Int { counts.reduce(0, +) }
    public var isEmpty: Bool { total == 0 }

    public mutating func put(_ digit: Digit) { counts[digit.rawValue - 1] += 1 }

    /// Removes one specific number. A Clue chooses the square, and therefore
    /// the number, so it cannot go through the random draw.
    @discardableResult
    public mutating func take(_ digit: Digit) -> Bool {
        guard counts[digit.rawValue - 1] > 0 else { return false }
        counts[digit.rawValue - 1] -= 1
        return true
    }

    /// Draws one number uniformly at random, without replacement.
    public mutating func draw(_ rng: inout RandomStream) -> Digit? {
        let t = total
        guard t > 0 else { return nil }
        var idx = rng.int(t)
        for d in Digit.all {
            let n = counts[d.rawValue - 1]
            if idx < n {
                counts[d.rawValue - 1] -= 1
                return d
            }
            idx -= n
        }
        return nil   // unreachable while total > 0
    }

    /// Draws up to `n`, stopping early if the Pool runs dry.
    public mutating func draw(_ rng: inout RandomStream, count n: Int) -> [Digit] {
        var out: [Digit] = []
        for _ in 0..<max(0, n) {
            guard let d = draw(&rng) else { break }
            out.append(d)
        }
        return out
    }
}

/// §4, the conservation rule — Pool + Hand is exactly the multiset the
/// remaining Blanks still need. Nothing is created or destroyed, so any bug in
/// Place / Toss / Clue shows up here immediately rather than as a board that
/// quietly becomes unfinishable.
public enum Conservation {
    public static func check(board: Board, pool: Pool, hand: [Digit]) -> String? {
        var needed = [Int](repeating: 0, count: 9)
        for square in board.blanks {
            needed[board.solution[square.index].rawValue - 1] += 1
        }
        var have = [Int](repeating: 0, count: 9)
        for d in Digit.all { have[d.rawValue - 1] = pool[d] }
        for d in hand { have[d.rawValue - 1] += 1 }

        for d in Digit.all {
            let i = d.rawValue - 1
            if needed[i] != have[i] {
                return "Conservation broken for \(d.rawValue): blanks need \(needed[i]), "
                     + "pool+hand hold \(have[i])"
            }
        }
        return nil
    }
}
