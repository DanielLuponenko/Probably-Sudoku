import Foundation

/// §12 — one-shot consumables. Consumed on use. 2 slots.
public enum Buffs {

    public static let peek = "bf_peek"
    public static let redraw = "bf_redraw"
    public static let paperCrane = "bf_paper_crane"
    public static let birdSeed = "bf_bird_seed"
    public static let freshInk = "bf_fresh_ink"

    /// Round-scoped keys the scoring resolver reads.
    public static func paperCraneKey(_ digit: Digit) -> String { "\(paperCrane)_\(digit.rawValue)" }

    private static func buff(_ id: String, _ name: String, _ rarity: Rarity, _ price: Int,
                             _ text: String, hooks: [GameEvent: Effect] = [:],
                             onUse: Effect? = nil) -> ItemDef {
        ItemDef(id: id, kind: .buff, name: name, rarity: rarity,
                listedPrice: price, text: text, hooks: hooks, onUse: onUse)
    }

    public static let all: [ItemDef] = [

        buff(peek, "Peek", .common, 3,
             "Grants a free Clue",
             onUse: { _, r in r.extraClues += 1 }),

        buff(redraw, "Redraw", .common, 3,
             "Return your whole Hand to the Pool and immediately draw a fresh one. Does not spend Toss allowance",
             onUse: { _, r in r.redrawHand = true }),

        buff("bf_overtime", "Overtime", .uncommon, 4,
             "+2 Turns this Puzzle",
             onUse: { _, r in r.extraTurns += 2 }),

        buff("bf_double_down", "Double Down", .uncommon, 4,
             "Your next correct placement scores x2",
             onUse: { _, r in r.armFlags.insert(.doubleDown) }),

        buff("bf_insurance", "Insurance", .common, 3,
             "Your next wrong placement takes no penalty",
             onUse: { _, r in r.armFlags.insert(.insurance) }),

        buff("bf_second_print", "Second Print", .uncommon, 4,
             "The next Line Clear this Puzzle scores twice",
             onUse: { _, r in r.armFlags.insert(.secondPrint) }),

        buff("bf_lucky_dip", "Lucky Dip", .common, 3,
             "Draw 2 numbers from the Pool",
             onUse: { _, r in r.draws += 2 }),

        buff(birdSeed, "Bird Seed", .uncommon, 4,
             "+1 coin per Line Clear for the rest of the Level",
             hooks: [.lineClear: { c, r in
                 if (c.runState[birdSeed] ?? 0) > 0 { r.coins += 1 }
             }],
             onUse: { c, r in r.runStateWrites[birdSeed] = Double(c.level) }),

        buff(freshInk, "Fresh Ink", .rare, 4,
             "+2 mult for the rest of the Puzzle",
             onUse: { c, r in r.bumpPuzzleState(freshInk, by: 2, in: c) }),

        buff(paperCrane, "Paper Crane", .common, 3,
             "Choose a number: it scores +50 flat for the rest of the Puzzle",
             onUse: { c, r in
                 guard let digit = c.digit else { return }
                 r.bumpPuzzleState(paperCraneKey(digit), by: 50, in: c)
             }),
    ]
}

/// A Buff the player is holding.
public struct OwnedBuff: Codable, Sendable, Identifiable {
    public let defID: String
    public let pricePaid: Int
    public var id: String { defID }
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, pricePaid: Int) {
        self.defID = defID
        self.pricePaid = pricePaid
    }
}

/// An Ad the player owns. Purchase order matters: Ads resolve in the order
/// they were bought (§14).
public struct OwnedAd: Codable, Sendable, Identifiable {
    public let defID: String
    public let boughtAtLevel: Int
    public let pricePaid: Int
    public var id: String { defID }
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, boughtAtLevel: Int, pricePaid: Int) {
        self.defID = defID
        self.boughtAtLevel = boughtAtLevel
        self.pricePaid = pricePaid
    }
}
