import Foundation

public enum ItemKind: String, Codable, CaseIterable, Sendable {
    case bookmark, marker, buff

    /// §9 — slot capacity per kind.
    public var capacity: Int {
        switch self {
        case .bookmark: return 5
        case .marker: return 3
        case .buff: return 2
        }
    }
}

/// The moments at which effects can fire (§14).
public enum GameEvent: String, Codable, Hashable, CaseIterable, Sendable {
    case place, lineClear, fullClear, turnEnd, puzzleEnd, wrongPlace, shopEnter
    /// Not dispatched on its own: hooks registered here also run for `.place`,
    /// `.lineClear` and `.fullClear`, which is how a plain "+1 mult" applies to
    /// every scoring event without being written out three times.
    case anyScore

    var isScoring: Bool { self == .place || self == .lineClear || self == .fullClear }
}

/// One-shot arms that a later qualifying event consumes (§6, §12).
public enum OneShotFlag: String, Codable, Hashable, Sendable {
    case doubleDown     // next correct placement scores x2
    case insurance      // next wrong placement takes no penalty
    case secondPrint    // next Line Clear this Puzzle scores twice
}

// MARK: - Context

/// Everything an effect is allowed to read. Deliberately a snapshot rather
/// than a reference to the live state, so an effect cannot reach sideways and
/// mutate the game out from under the resolver.
public struct EffectContext: Sendable {
    public let event: GameEvent
    public let digit: Digit?
    public let square: Square?
    public let unit: Unit?
    /// True when this placement came from a Clue — it scores 0 unless an Onyx
    /// Marker restores it (§6).
    public let isClue: Bool

    public let level: Int
    public let slot: PuzzleSlot
    public let difficulty: Difficulty
    /// How many Bookmarks are owned, for Front Page Splash.
    public let bookmarkCount: Int
    /// Copies of `digit` locked on the board *before* this placement, Givens
    /// included — what the Silver Marker counts.
    public let boardCountBefore: Int
    /// True when this placement also completed a row, column or box, for
    /// Copper. Only meaningful on `.place`.
    public let completesLine: Bool
    /// Number of row, column, and box units completed by this placement. A
    /// simultaneous row-and-box clear has a count of two, so effects such as
    /// Copper can pay once for each qualifying unit.
    public let completedUnitCount: Int

    public let puzzleState: [String: Double]
    public let runState: [String: Double]
}

// MARK: - Result

/// The three running totals of §6 plus every side effect an item can have.
/// Effects only ever add into this; the resolver applies it.
public struct EffectResult: Sendable {
    public var flat = 0
    public var multAdd = 0.0
    public var multX = 1.0
    /// Cancels this event outright — The Censor, The Mirror, Ivory, Insurance.
    public var zeroed = false
    /// Violet Marker: score the placement as if the number were a 9.
    public var baseOverride: Digit?
    /// Onyx Marker: a Clue on this square still earns its placement points.
    public var clueScoresPlacement = false
    /// Jade Marker: a wrong number returns to the Hand, not the Pool.
    public var wrongReturnsToHand = false

    public var coins = 0
    /// Points added straight to the score without passing through the formula,
    /// for the end-of-Turn and end-of-Puzzle flat payouts.
    public var directScore = 0
    public var extraTurns = 0
    public var extraClues = 0
    public var draws = 0
    public var redrawHand = false

    public var puzzleStateWrites: [String: Double] = [:]
    public var runStateWrites: [String: Double] = [:]
    public var armFlags: Set<OneShotFlag> = []

    public init() {}

    /// Bumps a counter, reading through to the context so several items in one
    /// dispatch accumulate rather than overwrite.
    public mutating func bumpPuzzleState(_ key: String, by amount: Double, in context: EffectContext) {
        let current = puzzleStateWrites[key] ?? context.puzzleState[key] ?? 0
        puzzleStateWrites[key] = current + amount
    }
    public mutating func bumpRunState(_ key: String, by amount: Double, in context: EffectContext) {
        let current = runStateWrites[key] ?? context.runState[key] ?? 0
        runStateWrites[key] = current + amount
    }
}

public typealias Effect = @Sendable (EffectContext, inout EffectResult) -> Void

// MARK: - Item definitions

public struct ItemDef: Sendable {
    public let id: String
    public let kind: ItemKind
    public let name: String
    public let rarity: Rarity
    /// The price printed in the design tables. The Shop rolls within the §9
    /// band for the kind and rarity rather than using this, but it is what the
    /// item is "worth" and what the tables document.
    public let listedPrice: Int
    public let text: String
    public let hooks: [GameEvent: Effect]
    /// Buffs only — what happens when the player spends it.
    public let onUse: Effect?

    public init(id: String, kind: ItemKind, name: String, rarity: Rarity,
                listedPrice: Int, text: String,
                hooks: [GameEvent: Effect] = [:], onUse: Effect? = nil) {
        self.id = id
        self.kind = kind
        self.name = name
        self.rarity = rarity
        self.listedPrice = listedPrice
        self.text = text
        self.hooks = hooks
        self.onUse = onUse
    }
}

public enum Catalog {
    public static let all: [ItemDef] = Bookmarks.all + Markers.all + Buffs.all
    private static let byID: [String: ItemDef] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    public static func item(_ id: String) -> ItemDef? { byID[id] }
    public static func items(of kind: ItemKind) -> [ItemDef] { all.filter { $0.kind == kind } }
    public static func items(of kind: ItemKind, rarity: Rarity) -> [ItemDef] {
        all.filter { $0.kind == kind && $0.rarity == rarity }
    }
}
