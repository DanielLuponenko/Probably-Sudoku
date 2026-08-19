import Foundation

/// §11 — a Marker is a coloured mark on a **square of the grid**, not on a
/// number. Whatever number ends up in that square triggers the effect.
///
/// Squares are owned by position and persist for the rest of the Book even
/// though boards are regenerated every Puzzle. That has two consequences the
/// rest of the engine has to respect: a marked square that arrives as a Given
/// is dead for that Puzzle, and each Marker gains one more square per Level
/// completed while owned (§11, Stacking).
public enum Markers {

    public static let ivory = "mk_ivory"
    public static let onyx = "mk_onyx"
    public static let jade = "mk_jade"
    public static let rose = "mk_rose"

    private static func marker(_ id: String, _ name: String, _ rarity: Rarity, _ price: Int,
                               _ text: String, _ hooks: [GameEvent: Effect] = [:]) -> ItemDef {
        ItemDef(id: id, kind: .marker, name: name, rarity: rarity,
                listedPrice: price, text: text, hooks: hooks)
    }

    /// How many squares a Marker owns, given how many Levels have completed
    /// since it was bought. Starts at 1, caps at 9 (§11, Stacking).
    public static func squareCount(levelsOwned: Int) -> Int {
        min(9, max(1, levelsOwned + 1))
    }

    public static let all: [ItemDef] = [

        marker("mk_crimson", "Crimson Marker", .rare, 9,
               "x4 mult",
               [.place: { _, r in r.multX *= 4 }]),

        marker("mk_golden", "Golden Marker", .common, 5,
               "+100 points",
               [.place: { _, r in r.flat += 100 }]),

        marker("mk_azure", "Azure Marker", .common, 5,
               "+1 coin",
               [.place: { _, r in r.coins += 1 }]),

        marker(ivory, "Ivory Marker", .uncommon, 7,
               "A wrong placement here takes no penalty",
               [.wrongPlace: { _, r in r.zeroed = true }]),

        marker("mk_emerald", "Emerald Marker", .uncommon, 7,
               "A Line Clear completed here scores x2",
               [.lineClear: { _, r in r.multX *= 2 }]),

        marker(onyx, "Onyx Marker", .uncommon, 7,
               "A Clue used here still scores full placement points",
               [.place: { _, r in r.clueScoresPlacement = true }]),

        marker("mk_silver", "Silver Marker", .uncommon, 7,
               "+20 points for each copy of the placed number already locked on the board, Givens included",
               [.place: { c, r in r.flat += 20 * c.boardCountBefore }]),

        marker("mk_sapphire", "Sapphire Marker", .common, 6,
               "Draw 1 number from the Pool",
               [.place: { _, r in r.draws += 1 }]),

        marker(rose, "Rose Marker", .rare, 8,
               "+1 mult for the rest of the Puzzle, each time one triggers",
               [.place: { c, r in r.bumpPuzzleState(rose, by: 1, in: c) }]),

        marker("mk_copper", "Copper Marker", .common, 6,
               "+3 coins if the placement completes a Line Clear",
               [.place: { c, r in if c.completesLine { r.coins += 3 } }]),

        marker("mk_violet", "Violet Marker", .rare, 8,
               "The number scores base points as if it were a 9",
               [.place: { _, r in r.baseOverride = .nine }]),

        marker(jade, "Jade Marker", .common, 5,
               "A wrong placement here returns to your Hand instead of the Pool",
               [.wrongPlace: { _, r in r.wrongReturnsToHand = true }]),
    ]
}

/// A Marker the player owns, together with the squares it has claimed.
public struct OwnedMarker: Codable, Sendable, Identifiable {
    public let defID: String
    public let boughtAtLevel: Int
    public let pricePaid: Int
    /// Positions, kept for the rest of the Book. Two Markers may never share a
    /// square (§11).
    public var squares: [Square]

    public var id: String { defID }
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, boughtAtLevel: Int, pricePaid: Int, squares: [Square] = []) {
        self.defID = defID
        self.boughtAtLevel = boughtAtLevel
        self.pricePaid = pricePaid
        self.squares = squares
    }

    /// How many squares this Marker is entitled to at `level`.
    public func entitledSquares(atLevel level: Int) -> Int {
        Markers.squareCount(levelsOwned: max(0, level - boughtAtLevel))
    }
    public func pendingSquares(atLevel level: Int) -> Int {
        max(0, entitledSquares(atLevel: level) - squares.count)
    }
    public func covers(_ square: Square) -> Bool { squares.contains(square) }
}
