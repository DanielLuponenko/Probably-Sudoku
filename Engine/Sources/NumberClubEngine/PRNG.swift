import Foundation

// Seeded determinism (§15). Every function here is pure.
// Never use Double.random / Int.random / Date() anywhere in the engine.
//
// This is a bit-exact port of the TypeScript prototype's cyrb128 + mulberry32
// so a seed produces the same Book in both implementations. All arithmetic is
// UInt32 with wrapping operators, which reproduces JavaScript's `Math.imul`
// and `>>> 0` semantics exactly.

/// Hashes a seed string into four 32-bit words.
public func cyrb128(_ str: String) -> (UInt32, UInt32, UInt32, UInt32) {
    var h1: UInt32 = 1779033703
    var h2: UInt32 = 3144134277
    var h3: UInt32 = 1013904242
    var h4: UInt32 = 2773480762

    // JS iterates UTF-16 code units; String.utf16 matches that exactly.
    for unit in str.utf16 {
        let k = UInt32(unit)
        // JS assigns these one after another, so the last line reads the h1
        // written by the first. Keep that order or every seed changes.
        let oldH1 = h1, oldH2 = h2, oldH3 = h3, oldH4 = h4
        h1 = oldH2 ^ ((oldH1 ^ k) &* 597399067)
        h2 = oldH3 ^ ((oldH2 ^ k) &* 2869860233)
        h3 = oldH4 ^ ((oldH3 ^ k) &* 951274213)
        h4 = h1     ^ ((oldH4 ^ k) &* 2716044179)
    }

    let f1 = (h3 ^ (h1 >> 18)) &* 597399067
    let f2 = (h4 ^ (h2 >> 22)) &* 2869860233
    let f3 = (f1 ^ (h3 >> 17)) &* 951274213
    let f4 = (f2 ^ (h4 >> 19)) &* 2716044179

    return (f1 ^ f2 ^ f3 ^ f4, f2 ^ f1, f3 ^ f1, f4 ^ f1)
}

/// A mulberry32 stream. Its whole state is one `UInt32`, so it serialises into
/// a save file trivially and a run can be resumed mid-Puzzle.
public struct RandomStream: Codable, Sendable {
    public private(set) var state: UInt32

    public init(state: UInt32) { self.state = state }
    public init(seed: String, stream name: String) {
        self.state = cyrb128(seed + ":" + name).0
    }

    /// Next value in [0, 1).
    public mutating func next() -> Double {
        state = state &+ 0x6D2B79F5
        var t = (state ^ (state >> 15)) &* (1 | state)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4294967296.0
    }

    /// Uniform integer in `0..<n`.
    public mutating func int(_ n: Int) -> Int {
        precondition(n > 0, "int(_:) needs a positive bound")
        return Int(next() * Double(n))
    }

    /// Fisher–Yates, walking downwards — same order as the TS `shuffle`.
    public mutating func shuffled<T>(_ array: [T]) -> [T] {
        var a = array
        var i = a.count - 1
        while i > 0 {
            let j = int(i + 1)
            a.swapAt(i, j)
            i -= 1
        }
        return a
    }

    /// Picks one element uniformly. Returns nil for an empty array.
    public mutating func pick<T>(_ array: [T]) -> T? {
        guard !array.isEmpty else { return nil }
        return array[int(array.count)]
    }

    /// Inclusive integer range, for price bands like "4–5".
    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(range.count)
    }
}

/// §15 — four independent streams, so drawing a number can never shift which
/// Boss Modifier appears, and rerolling a Shop can never shift the next board.
public struct SeedStreams: Codable, Sendable {
    public var board: RandomStream
    public var pool: RandomStream
    public var shop: RandomStream
    public var boss: RandomStream

    public init(seed: String) {
        board = RandomStream(seed: seed, stream: "board")
        pool  = RandomStream(seed: seed, stream: "pool")
        shop  = RandomStream(seed: seed, stream: "shop")
        boss  = RandomStream(seed: seed, stream: "boss")
    }
}
