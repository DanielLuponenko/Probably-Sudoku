import Foundation

/// A partially filled grid: 81 entries, `0` meaning Blank, `1...9` a number.
/// Kept as a flat `[UInt8]` because the solver is the hot path in generation.
public typealias Grid = [UInt8]

// Candidate sets are 9-bit masks, bit `d - 1` meaning "d is possible here".
@inline(__always) private func bit(_ d: Int) -> UInt16 { UInt16(1) << UInt16(d - 1) }
private let allCandidates: UInt16 = 0b1_1111_1111

public enum Solver {

    @inline(__always)
    static func isValid(_ g: Grid, _ cell: Int, _ v: UInt8) -> Bool {
        for p in Geometry.peers[cell] where g[p] == v { return false }
        return true
    }

    /// Backtracking count that stops as soon as it reaches `limit`.
    /// Used by the digger to guarantee a unique solution.
    public static func countSolutions(_ grid: Grid, limit: Int = 2) -> Int {
        var g = grid
        var count = 0

        func findEmptyMRV() -> Int {
            var best = -1
            var bestCount = 10
            for i in 0..<81 {
                guard g[i] == 0 else { continue }
                var candidates = 0
                for v in 1...9 where isValid(g, i, UInt8(v)) { candidates += 1 }
                if candidates < bestCount {
                    bestCount = candidates
                    best = i
                    if candidates == 0 { return best }   // dead end, bail fast
                    if candidates == 1 { break }
                }
            }
            return best
        }

        func backtrack() -> Bool {
            let cell = findEmptyMRV()
            if cell == -1 {
                count += 1
                return count >= limit
            }
            for v in 1...9 {
                guard isValid(g, cell, UInt8(v)) else { continue }
                g[cell] = UInt8(v)
                if backtrack() { return true }
                g[cell] = 0
            }
            return false
        }

        _ = backtrack()
        return count
    }

    /// Solves a grid, returning the first solution found (which is *the*
    /// solution when the grid is known to be unique).
    public static func solve(_ grid: Grid) -> [Digit]? {
        var g = grid

        func findEmptyMRV() -> Int {
            var best = -1
            var bestCount = 10
            for i in 0..<81 {
                guard g[i] == 0 else { continue }
                var candidates = 0
                for v in 1...9 where isValid(g, i, UInt8(v)) { candidates += 1 }
                if candidates < bestCount {
                    bestCount = candidates
                    best = i
                    if candidates == 0 { return best }
                }
            }
            return best
        }

        func backtrack() -> Bool {
            let cell = findEmptyMRV()
            if cell == -1 { return true }
            for v in 1...9 {
                guard isValid(g, cell, UInt8(v)) else { continue }
                g[cell] = UInt8(v)
                if backtrack() { return true }
                g[cell] = 0
            }
            return false
        }

        guard backtrack() else { return nil }
        return g.map { Digit(rawValue: Int($0))! }
    }

    // MARK: - Technique ladder

    /// The hardest human technique a puzzle needs, or `.unsolved` when the
    /// ladder below cannot finish it — which is what qualifies a Boss board.
    public enum Technique: Int, Comparable, Sendable {
        case nakedSingle = 0, hiddenSingle, lockedCandidates, nakedPair, hiddenPair, unsolved
        public static func < (a: Technique, b: Technique) -> Bool { a.rawValue < b.rawValue }
    }

    /// Repeatedly applies techniques in escalating strength until solved or
    /// stuck, reporting the hardest one that was ever needed.
    public static func grade(_ grid: Grid) -> Technique {
        var g = grid
        var cands = [UInt16](repeating: 0, count: 81)
        for i in 0..<81 where g[i] == 0 {
            var m: UInt16 = 0
            for v in 1...9 where isValid(g, i, UInt8(v)) { m |= bit(v) }
            cands[i] = m
        }

        var hardest: Technique = .nakedSingle
        var remaining = g.reduce(0) { $1 == 0 ? $0 + 1 : $0 }

        func place(_ cell: Int, _ v: Int) {
            g[cell] = UInt8(v)
            cands[cell] = 0
            let mask = ~bit(v)
            for p in Geometry.peers[cell] { cands[p] &= mask }
            remaining -= 1
        }

        func nakedSingle() -> Bool {
            for i in 0..<81 where g[i] == 0 {
                if cands[i].nonzeroBitCount == 1 {
                    place(i, cands[i].trailingZeroBitCount + 1)
                    return true
                }
            }
            return false
        }

        func hiddenSingle() -> Bool {
            for unit in Geometry.allUnits {
                for v in 1...9 {
                    let b = bit(v)
                    var spot = -1
                    var count = 0
                    for s in unit where g[s.index] == 0 && (cands[s.index] & b) != 0 {
                        spot = s.index; count += 1
                        if count > 1 { break }
                    }
                    if count == 1 {
                        place(spot, v)
                        return true
                    }
                }
            }
            return false
        }

        /// Pointing and claiming: candidates for `v` confined to one row or
        /// column within a box eliminate `v` from the rest of that line.
        func lockedCandidates() -> Bool {
            var changed = false
            for b in 0..<9 {
                let box = Geometry.boxes[b]
                let boxSet = Set(box.map(\.index))
                for v in 1...9 {
                    let bt = bit(v)
                    let spots = box.filter { g[$0.index] == 0 && (cands[$0.index] & bt) != 0 }
                    guard spots.count >= 2 else { continue }
                    let rows = Set(spots.map(\.row))
                    let cols = Set(spots.map(\.col))
                    if rows.count == 1 {
                        for s in Geometry.rows[rows.first!]
                        where !boxSet.contains(s.index) && (cands[s.index] & bt) != 0 {
                            cands[s.index] &= ~bt; changed = true
                        }
                    }
                    if cols.count == 1 {
                        for s in Geometry.cols[cols.first!]
                        where !boxSet.contains(s.index) && (cands[s.index] & bt) != 0 {
                            cands[s.index] &= ~bt; changed = true
                        }
                    }
                }
            }
            return changed
        }

        /// Two cells in a unit sharing the same two candidates lock those two
        /// numbers out of every other cell in the unit.
        func nakedPair() -> Bool {
            var changed = false
            for unit in Geometry.allUnits {
                let twos = unit.filter { g[$0.index] == 0 && cands[$0.index].nonzeroBitCount == 2 }
                guard twos.count >= 2 else { continue }
                for i in 0..<twos.count {
                    for j in (i + 1)..<twos.count {
                        let a = cands[twos[i].index]
                        guard a == cands[twos[j].index] else { continue }
                        for s in unit {
                            if s == twos[i] || s == twos[j] || g[s.index] != 0 { continue }
                            if cands[s.index] & a != 0 {
                                cands[s.index] &= ~a; changed = true
                            }
                        }
                    }
                }
            }
            return changed
        }

        /// Two numbers that can only go in the same two cells of a unit own
        /// those cells, so every other candidate there is eliminated.
        func hiddenPair() -> Bool {
            var changed = false
            for unit in Geometry.allUnits {
                for v1 in 1...8 {
                    let b1 = bit(v1)
                    let s1 = unit.filter { g[$0.index] == 0 && (cands[$0.index] & b1) != 0 }
                    guard s1.count == 2 else { continue }
                    for v2 in (v1 + 1)...9 {
                        let b2 = bit(v2)
                        let s2 = unit.filter { g[$0.index] == 0 && (cands[$0.index] & b2) != 0 }
                        guard s2.count == 2, s1[0] == s2[0], s1[1] == s2[1] else { continue }
                        let pair = b1 | b2
                        for s in s1 where cands[s.index] != pair {
                            cands[s.index] = pair; changed = true
                        }
                    }
                }
            }
            return changed
        }

        let passes: [(Technique, () -> Bool)] = [
            (.nakedSingle, nakedSingle),
            (.hiddenSingle, hiddenSingle),
            (.lockedCandidates, lockedCandidates),
            (.nakedPair, nakedPair),
            (.hiddenPair, hiddenPair),
        ]

        while remaining > 0 {
            var progressed = false
            for (technique, run) in passes where run() {
                if technique > hardest { hardest = technique }
                progressed = true
                break
            }
            if !progressed { return .unsolved }
        }
        return hardest
    }
}
