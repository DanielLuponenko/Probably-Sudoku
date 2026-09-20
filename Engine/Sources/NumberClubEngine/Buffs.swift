import Foundation

/// Catalogue consumables. Runtime validation and transactions live in BuffRuntime.
public enum Buffs {
    public static let peek = "bf_peek"
    public static let redraw = "bf_redraw"
    public static let overtime = "bf_overtime"
    public static let doubleDown = "bf_double_down"
    public static let insurance = "bf_insurance"
    public static let secondPrint = "bf_second_print"
    public static let luckyDip = "bf_lucky_dip"
    public static let birdSeed = "bf_bird_seed"
    public static let freshInk = "bf_fresh_ink"
    public static let litmus = "bf_litmus"
    public static let paperCrane = "bf_paper_crane"
    public static let indexRequest = "bf_index_request"
    public static let carefulCut = "bf_careful_cut"
    public static let eraserShavings = "bf_eraser_shavings"
    public static let collation = "bf_collation"
    public static let fairExchange = "bf_fair_exchange"
    public static let inventoryCount = "bf_inventory_count"
    public static let proofSheet = "bf_proof_sheet"
    public static let foldTest = "bf_fold_test"
    public static let rebind = "bf_rebind"
    public static let transposition = "bf_transposition"
    public static let passage = "bf_passage"
    public static let releaseNote = "bf_release_note"
    public static let singleIssue = "bf_single_issue"
    public static let reservation = "bf_reservation"
    public static let counteroffer = "bf_counteroffer"
    public static let supplement = "bf_supplement"
    public static let freePress = "bf_free_press"
    public static let detour = "bf_detour"
    public static let bossDraft = "bf_boss_draft"
    public static let tightDeadline = "bf_tight_deadline"
    public static let collateral = "bf_collateral"
    public static let exchangeRate = "bf_exchange_rate"
    public static let returnReceipt = "bf_return_receipt"
    public static let cleanFinish = "bf_clean_finish"
    public static let crossCut = "bf_cross_cut"
    public static let openBracket = "bf_open_bracket"
    public static let newEdition = "bf_new_edition"
    public static let carbonReceipt = "bf_carbon_receipt"
    public static let rainCheck = "bf_rain_check"

    public static func paperCraneKey(_ digit: Digit) -> String { "\(paperCrane)_\(digit.rawValue)" }

    public static let all: [ItemDef] = [
        ItemDef(id: peek, kind: .buff, name: "Peek", rarity: .common,
                listedPrice: 3, text: "Gain 1 Clue for this Puzzle. Use it with a number in your Hand to reveal a correct square. That placement and its clears score zero; Onyx can restore the placement Points only.",
                onUse: { _, r in r.extraClues += 1 }),
        ItemDef(id: redraw, kind: .buff, name: "Redraw", rarity: .common,
                listedPrice: 3, text: "Return every number in your Hand to the Pool, then refill your Hand to its normal size from the Pool. This spends no Tosses. You may draw numbers you just returned; drawing stops if the Pool is empty.",
                onUse: { _, r in r.redrawHand = true }),
        ItemDef(id: overtime, kind: .buff, name: "Overtime", rarity: .uncommon,
                listedPrice: 7, text: "Gain 2 more Turns in this Puzzle. Your current Hand and unbanked Points stay as they are.",
                onUse: { _, r in r.extraTurns += 2 }),
        ItemDef(id: doubleDown, kind: .buff, name: "Double Down", rarity: .uncommon,
                listedPrice: 5, text: "Double the Points from your next correct scoring placement made without a Clue. Only that placement is doubled. Wrong placements, Clues, and placements worth zero leave the effect ready.",
                onUse: { _, r in r.armFlags.insert(.doubleDown) }),
        ItemDef(id: insurance, kind: .buff, name: "Insurance", rarity: .common,
                listedPrice: 3, text: "Cancel the next wrong-placement score penalty you would pay. The number returns to the Pool, or to your Hand if it was played on Jade.",
                onUse: { _, r in r.armFlags.insert(.insurance) }),
        ItemDef(id: secondPrint, kind: .buff, name: "Second Print", rarity: .uncommon,
                listedPrice: 5, text: "Double the next scoring row, column, or box clear made without a Clue. If one placement completes several, only one is doubled, checking row, then column, then box. Clears worth zero leave the effect ready.",
                onUse: { _, r in r.armFlags.insert(.secondPrint) }),
        ItemDef(id: luckyDip, kind: .buff, name: "Lucky Dip", rarity: .common,
                listedPrice: 3, text: "Immediately draw up to 2 random numbers from the Pool into your Hand. Draw fewer if the Pool has only one number left; do not consume the Buff if the Pool is empty.",
                onUse: { _, r in r.draws += 2 }),
        ItemDef(id: birdSeed, kind: .buff, name: "Bird Seed", rarity: .uncommon,
                listedPrice: 6, text: "Gain 1 extra coin for each row, column, or box clear for the rest of this Chapter. Clue clears and Keep Filling also count; completing several units pays for each one.",
                hooks: [.lineClear: { c, r in if c.runState[birdSeed] == Double(c.level) { r.coins += 1 } }],
                onUse: { c, r in r.runStateWrites[birdSeed] = Double(c.level) }),
        ItemDef(id: freshInk, kind: .buff, name: "Fresh Ink", rarity: .rare,
                listedPrice: 9, text: "Add 2 to Puzzle Mult before Bookmark multipliers for the remainder of the current Puzzle, including the current Turn. It changes multiplier calculation and does not create placement or clear points by itself.",
                onUse: { c, r in r.bumpPuzzleState(freshInk, by: 2, in: c) }),
        ItemDef(id: litmus, kind: .buff, name: "Litmus", rarity: .rare,
                listedPrice: 8, text: "Choose one digit when using Litmus and reveal all still-blank solution-correct squares for that digit. The chosen digit cannot change, and the reveal ends after the next accepted correct or wrong placement, or at Puzzle end.",
                onUse: { _, r in r.armFlags.insert(.litmus) }),
        ItemDef(id: paperCrane, kind: .buff, name: "Paper Crane", rarity: .uncommon,
                listedPrice: 6, text: "Choose a digit. Its scoring placements gain +50 Points before multipliers for the rest of this Puzzle. Clue placements gain nothing unless Onyx allows them to score.",
                onUse: { c, r in guard let digit = c.digit else { return }; r.bumpPuzzleState(paperCraneKey(digit), by: 50, in: c) }),
        ItemDef(id: indexRequest, kind: .buff, name: "Index Request", rarity: .uncommon,
                listedPrice: 5, text: "Choose a digit with at least one copy remaining in the Pool and take exactly one copy into your Hand. This neither identifies a correct square nor bypasses any boss restriction on using the drawn card."),
        ItemDef(id: carefulCut, kind: .buff, name: "Careful Cut", rarity: .common,
                listedPrice: 3, text: "Return 1–3 tossable cards from your Hand to the Pool without spending a Toss. You draw no replacements. If your Hand becomes empty, the Turn ends."),
        ItemDef(id: eraserShavings, kind: .buff, name: "Eraser Shavings", rarity: .common,
                listedPrice: 4, text: "Restore up to two Tosses already spent in this Puzzle. Remaining Tosses cannot rise above this Puzzle's originally granted allowance, and no card moves until you later choose to Toss it normally."),
        ItemDef(id: collation, kind: .buff, name: "Collation", rarity: .uncommon,
                listedPrice: 5, text: "Reveal up to 3 random numbers from the Pool and arrange their next draw order. They stay in the Pool until drawn. Taking one separately removes it from this order."),
        ItemDef(id: fairExchange, kind: .buff, name: "Fair Exchange", rarity: .common,
                listedPrice: 4, text: "Return one chosen tossable Hand card and take one different chosen digit that was already in the Pool before the return. Hand count stays unchanged, and no Toss allowance is spent."),
        ItemDef(id: inventoryCount, kind: .buff, name: "Inventory Count", rarity: .common,
                listedPrice: 3, text: "See how many of each digit remain in the Pool until this Turn ends. The counts update as cards move. This does not show where the numbers belong."),
        ItemDef(id: proofSheet, kind: .buff, name: "Proof Sheet", rarity: .common,
                listedPrice: 3, text: "Choose a row, column, or box. Until Turn end, see which digits fit the visible Sudoku rules in each blank square. These possibilities update as you place numbers; they are not guaranteed answers."),
        ItemDef(id: foldTest, kind: .buff, name: "Fold Test", rarity: .common,
                listedPrice: 3, text: "Choose one blank square and learn whether its solution digit is odd or even. Keep that parity note until the square is filled or the Puzzle ends; it gives partial solution information without naming a digit or automatically placing one."),
        ItemDef(id: rebind, kind: .buff, name: "Rebind", rarity: .uncommon,
                listedPrice: 7, text: "Move one Marker from a blank square where it has not triggered this Puzzle to a different blank, unmarked square. Both squares must be unbarred. The move lasts for this Book. Its progress and used effects are preserved; its other squares stay in place."),
        ItemDef(id: transposition, kind: .buff, name: "Transposition", rarity: .uncommon,
                listedPrice: 5, text: "Swap two Markers of different types on blank, unbarred squares. Neither may have triggered this Puzzle. The swap lasts for this Book and preserves their progress and used effects. Their other squares stay in place."),
        ItemDef(id: passage, kind: .buff, name: "Passage", rarity: .uncommon,
                listedPrice: 6, text: "Choose one blank square currently barred by a boss and permit one accepted placement there during this Turn. The exception ends after a correct or wrong accepted placement, or at Turn end, and all number restrictions, coin fees, penalties, and scoring rules still apply."),
        ItemDef(id: releaseNote, kind: .buff, name: "Release Note", rarity: .uncommon,
                listedPrice: 5, text: "Let one blocked card in your Hand be placed or tossed once this Turn. This applies only to that card. Barred squares, Toss allowance, coin fees, and placement rules still apply."),
        ItemDef(id: singleIssue, kind: .buff, name: "Single Issue", rarity: .common,
                listedPrice: 3, text: "In the Shop, replace one unsold offer with a random different item of the same category and rarity, at its normal price. Other offers and your Reroll count stay unchanged."),
        ItemDef(id: reservation, kind: .buff, name: "Reservation", rarity: .uncommon,
                listedPrice: 5, text: "As you leave an open Shop, reserve one unsold offer at its current price for the next Shop you reach. It replaces one normal slot of the same category there and remains through that visit's Rerolls until purchased or until you leave that next Shop."),
        ItemDef(id: counteroffer, kind: .buff, name: "Counteroffer", rarity: .common,
                listedPrice: 3, text: "Reduce one chosen unsold Marker's price in the current Shop by 4 coins, to a minimum price of 1. The reduction belongs to that offer until it is bought or rerolled; it does not grant coins or apply to Buff purchases."),
        ItemDef(id: supplement, kind: .buff, name: "Supplement", rarity: .common,
                listedPrice: 4, text: "Choose Bookmarks, Markers, or Buffs; add one extra offer of that category to the initial stock of the next Shop you reach. It must still be purchased at its normal price and disappears on that visit's first Reroll or when you leave."),
        ItemDef(id: freePress, kind: .buff, name: "Free Press", rarity: .common,
                listedPrice: 3, text: "Apply up to 6 coins of credit to the next paid regular Reroll in the current Shop. Charge any cost above 6 normally, then advance the Reroll counter exactly as if its full price had been paid."),
        ItemDef(id: detour, kind: .buff, name: "Detour", rarity: .rare,
                listedPrice: 8, text: "Before an ordinary Puzzle, choose between its given layout and one random alternative with the same difficulty, target, and resources. Your Markers stay in their positions. You preview the givens, not the solutions."),
        ItemDef(id: bossDraft, kind: .buff, name: "Boss Draft", rarity: .rare,
                listedPrice: 10, text: "Before this Chapter's Boss Puzzle, choose between the announced Boss and one random alternative. You keep the same Boss encounter and rewards; the chosen Boss's own target and resource rules apply."),
        ItemDef(id: tightDeadline, kind: .buff, name: "Tight Deadline", rarity: .uncommon,
                listedPrice: 6, text: "Give up one future Turn in this Puzzle for +3 Mult on the Points earned without Clues this Turn, before Bookmarks score. Clue Points get no bonus, even with Onyx; Points worth zero stay zero. Lasts for this bank only."),
        ItemDef(id: collateral, kind: .buff, name: "Collateral", rarity: .rare,
                listedPrice: 8, text: "Before any scoring this Turn, set aside one active Bookmark for the rest of this Puzzle to add 2 to your Hand size at each refill. It stays in its slot and returns at Puzzle end. Points already earned and its saved growth are kept."),
        ItemDef(id: exchangeRate, kind: .buff, name: "Exchange Rate", rarity: .common,
                listedPrice: 3, text: "Pay 1–3 coins for that much extra Mult on the Points earned without Clues this Turn, before Bookmarks score. Clue Points get no bonus, even with Onyx; Points worth zero stay zero. Lasts for this bank only."),
        ItemDef(id: returnReceipt, kind: .buff, name: "Return Receipt", rarity: .uncommon,
                listedPrice: 5, text: "Recover one Insurance, Double Down, or Second Print you used this Puzzle whose effect is still waiting. Cancel that effect and return the same Buff to your inventory. An effect that already happened cannot be recovered."),
        ItemDef(id: cleanFinish, kind: .buff, name: "Clean Finish", rarity: .uncommon,
                listedPrice: 5, text: "With at least 3 cards in Hand, start a challenge: score every card currently in your Hand without Clues before this Turn ends to gain +150 Points on the last one. A wrong placement, Toss, exchange, return, or Clue use on one of those cards fails the challenge."),
        ItemDef(id: crossCut, kind: .buff, name: "Cross-Cut", rarity: .uncommon,
                listedPrice: 6, text: "Gain +120 Points when one scoring placement without a Clue completes two scoring rows, columns, or boxes at once, or +180 for all three. Every counted clear must earn Points. One reward; single clears leave it ready."),
        ItemDef(id: openBracket, kind: .buff, name: "Open Bracket", rarity: .uncommon,
                listedPrice: 5, text: "Choose two blank, unbarred squares in different boxes. Score a placement without a Clue on both before this Puzzle ends to add +200 Points to the second one. A Clue or zero-score fill on either square ends the challenge without a reward."),
        ItemDef(id: newEdition, kind: .buff, name: "New Edition", rarity: .uncommon,
                listedPrice: 6, text: "In the Shop, replace one owned Bookmark with a random different unowned Bookmark of the same rarity. It takes the same slot and starts without earned progress. You receive no refund or buy/sell rewards."),
        ItemDef(id: carbonReceipt, kind: .buff, name: "Carbon Receipt", rarity: .uncommon,
                listedPrice: 6, text: "Repeat the last eligible Buff you used this Puzzle: Peek, Redraw, Double Down, Insurance, Second Print, or Lucky Dip. You see the chosen effect before confirming. It must still be usable; any cards it draws come from the current Pool."),
        ItemDef(id: rainCheck, kind: .buff, name: "Rain Check", rarity: .uncommon,
                listedPrice: 5, text: "Set aside 20–100 Points from this Turn's scoring placements made without Clues. They will not count in this bank. Your first scoring placement without a Clue next Turn gains twice that amount before multipliers. The bonus is lost if no such placement happens next Turn or the Puzzle ends first."),
    ]
}

/// A Buff the player is holding.
public struct OwnedBuff: Codable, Sendable, Identifiable {
    /// Catalogue IDs describe effects; UUIDs identify separately held copies.
    public let id: UUID
    public let defID: String
    public let pricePaid: Int
    /// Nil for older saves and granted items: their purchase Shop is unknown.
    public let boughtInShopVisitID: Int?
    var needsIdentityMigration = false
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, pricePaid: Int, boughtInShopVisitID: Int? = nil,
                id: UUID = UUID()) {
        self.id = id
        self.defID = defID
        self.pricePaid = pricePaid
        self.boughtInShopVisitID = boughtInShopVisitID
    }

    private enum CodingKeys: String, CodingKey {
        case id, defID, pricePaid, boughtInShopVisitID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defID = try c.decode(String.self, forKey: .defID)
        pricePaid = try c.decode(Int.self, forKey: .pricePaid)
        boughtInShopVisitID = try c.decodeIfPresent(Int.self, forKey: .boughtInShopVisitID)
        let savedID = try c.decodeIfPresent(UUID.self, forKey: .id)
        needsIdentityMigration = savedID == nil
        // RunState adds the Book seed to this migration. Standalone decoding
        // is stable too, including duplicate entries in an old array.
        id = savedID ?? SkipOffer.stableIdentity(seed: defID,
            domain: "buff.legacy.v1.\(decoder.codingPath.map(\.stringValue).joined(separator: ".")).\(pricePaid).\(boughtInShopVisitID ?? -1)")
    }
}

/// A Bookmark the player owns. Visible slot order is the scoring order; identity
/// belongs to the owned copy and survives reordering or a new copy of an old item.
public struct OwnedBookmark: Codable, Sendable, Identifiable {
    public let id: UUID
    public let defID: String
    public let boughtAtLevel: Int
    public let pricePaid: Int
    /// Run-local Shop identity, independent of Level and stock rerolls.
    public let boughtInShopVisitID: Int?
    var needsIdentityMigration = false
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, boughtAtLevel: Int, pricePaid: Int,
                boughtInShopVisitID: Int? = nil, id: UUID = UUID()) {
        self.id = id
        self.defID = defID
        self.boughtAtLevel = boughtAtLevel
        self.pricePaid = pricePaid
        self.boughtInShopVisitID = boughtInShopVisitID
    }

    private enum CodingKeys: String, CodingKey {
        case id, defID, boughtAtLevel, pricePaid, boughtInShopVisitID
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defID = try c.decode(String.self, forKey: .defID)
        boughtAtLevel = try c.decode(Int.self, forKey: .boughtAtLevel)
        pricePaid = try c.decode(Int.self, forKey: .pricePaid)
        boughtInShopVisitID = try c.decodeIfPresent(Int.self, forKey: .boughtInShopVisitID)
        let savedID = try c.decodeIfPresent(UUID.self, forKey: .id)
        needsIdentityMigration = savedID == nil
        id = savedID ?? SkipOffer.stableIdentity(seed: defID,
            domain: "bookmark.legacy.v1.\(decoder.codingPath.map(\.stringValue).joined(separator: ".")).\(boughtAtLevel).\(pricePaid).\(boughtInShopVisitID ?? -1)")
    }
}
