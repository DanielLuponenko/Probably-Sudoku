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

    public static let crimson = "mk_crimson"
    public static let golden = "mk_golden"
    public static let azure = "mk_azure"
    public static let ivory = "mk_ivory"
    public static let emerald = "mk_emerald"
    public static let onyx = "mk_onyx"
    public static let silver = "mk_silver"
    public static let sapphire = "mk_sapphire"
    public static let rose = "mk_rose"
    public static let copper = "mk_copper"
    public static let violet = "mk_violet"
    public static let jade = "mk_jade"
    public static let eraser = "mk_eraser"
    public static let exchange = "mk_exchange"
    public static let echo = "mk_echo"
    public static let prism = "mk_prism"
    public static let fork = "mk_fork"
    public static let forecast = "mk_forecast"
    public static let escapement = "mk_escapement"
    public static let lamp = "mk_lamp"
    public static let ledger = "mk_ledger"
    public static let umbrella = "mk_umbrella"
    public static let hearth = "mk_hearth"
    public static let constellation = "mk_constellation"
    public static let rhythm = "mk_rhythm"
    public static let bridge = "mk_bridge"
    public static let crossroads = "mk_crossroads"
    public static let voucher = "mk_voucher"
    public static let interest = "mk_interest"
    public static let pledge = "mk_pledge"
    public static let collection = "mk_collection"
    public static let debt = "mk_debt"
    public static let stipend = "mk_stipend"
    public static let route = "mk_route"
    public static let ladder = "mk_ladder"
    public static let counterweight = "mk_counterweight"
    public static let keystone = "mk_keystone"
    public static let finale = "mk_finale"
    public static let crosscheck = "mk_crosscheck"
    public static let carbon = "mk_carbon"
    public static let pressmark = "mk_pressmark"
    public static let tiebreaker = "mk_tiebreaker"
    public static let blotter = "mk_blotter"
    public static let patina = "mk_patina"
    public static let windlass = "mk_windlass"
    public static let beacon = "mk_beacon"
    public static let sweep = "mk_sweep"
    public static let census = "mk_census"
    public static let bounty = "mk_bounty"
    public static let harvest = "mk_harvest"

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

    /// Existing hooks retain their original lifecycle. New catalogue rules
    /// run through MarkerRuntime, which also owns their saved limits/choices.
    public static let all: [ItemDef] = [

        marker(crimson, "Crimson Marker", .rare, 14,
               "Multiply this square’s placement Points by 4. Does not multiply adjacent placements or the Turn bank.",
               [.place: { _, r in r.multX *= 4 }]),

        marker(golden, "Golden Marker", .common, 6,
               "Add +100 placement Points here before placement multipliers and Bookmarks score.",
               [.place: { _, r in r.flat += 100 }]),

        marker(azure, "Azure Marker", .common, 6,
               "Gain 1 coin for a correct fill here, including Clue placements and fills during Keep Filling.",
               [.place: { _, r in r.coins += 1 }]),

        marker(ivory, "Ivory Marker", .uncommon, 9,
               "Wrong placements on this square take no score penalty. The wrong card still follows its normal return-to-Pool behavior.",
               [.wrongPlace: { _, r in r.zeroed = true }]),

        marker(emerald, "Emerald Marker", .uncommon, 10,
               "Double the Points for each row, column, or box completed by a correct placement here. Clears made with Clues, or prevented from scoring by a Boss, still score zero.",
               [.lineClear: { _, r in r.multX *= 2 }]),

        marker(onyx, "Onyx Marker", .uncommon, 9,
               "A Clue placement here earns its normal placement Points. Its row, column, and box clears still score zero. Bosses can still prevent it from scoring.",
               [.place: { _, r in r.clueScoresPlacement = true }]),

        marker(silver, "Silver Marker", .uncommon, 9,
               "Add +20 placement Points for each copy of this digit already on the board before this fill, including Givens.",
               [.place: { c, r in r.flat += 20 * c.boardCountBefore }]),

        marker(sapphire, "Sapphire Marker", .common, 7,
               "Draw 1 random number from the Pool after a correct fill here, if one remains. Clue placements and fills during Keep Filling also count.",
               [.place: { _, r in r.draws += 1 }]),

        marker(rose, "Rose Marker", .rare, 14,
               "Each correct fill here adds +1 Puzzle Mult before Bookmarks for the rest of this Puzzle, including the current Turn.",
               [.place: { c, r in r.bumpPuzzleState(rose, by: 1, in: c) }]),

        marker(copper, "Copper Marker", .common, 7,
               "Gain 3 coins for each row, column, or box completed by a fill here. Clue placements and Keep Filling also count; completing several units pays for each one.",
               [.place: { c, r in r.coins += 3 * c.completedUnitCount }]),

        marker(violet, "Violet Marker", .rare, 12,
               "The number placed here is worth 90 base Points, as though it were a 9. The number itself and any added bonuses stay unchanged.",
               [.place: { _, r in r.baseOverride = .nine }]),

        marker(jade, "Jade Marker", .common, 5,
               "A wrong card played here returns to the Hand instead of the Pool. This Marker does not cancel the wrong-placement score or boss coin penalty.",
               [.wrongPlace: { _, r in r.wrongReturnsToHand = true }]),

        marker(eraser, "Eraser Marker", .common, 6,
               "Restore 1 already-spent Toss after a qualifying placement here. Cannot raise Toss allowance above its starting value or bypass a no-Toss rule. At most 2 restored Tosses this Puzzle."),

        marker(exchange, "Exchange Marker", .uncommon, 8,
               "After a qualifying placement here, you may return one unblocked Hand card to the Pool and draw a random card of a different digit. A different digit must remain in the Pool. Up to 3 exchanges per Puzzle."),

        marker(echo, "Echo Marker", .common, 7,
               "After a qualifying placement here, draw one more copy of the digit just placed, if that digit remains in the Pool. At most 3 matching draws this Puzzle."),

        marker(prism, "Prism Marker", .uncommon, 9,
               "After a qualifying placement here, draw a random Pool number whose digit is absent from your remaining Hand. If no such digit remains in the Pool, draw nothing. Up to 3 draws per Puzzle."),

        marker(fork, "Fork Marker", .uncommon, 10,
               "After a qualifying placement here, reveal two random Pool numbers and choose one for your Hand. Return the other to the Pool. If only one remains, draw it. Up to 2 offers per Puzzle."),

        marker(forecast, "Forecast Marker", .common, 5,
               "After a qualifying placement here, reveal the digit of the next random Pool draw. The preview lasts until that draw occurs or the Turn ends. It does not draw, reserve, or change the card. At most 3 previews this Puzzle."),

        marker(escapement, "Escapement Marker", .rare, 13,
               "Count qualifying fills of Escapement squares across Puzzles in this Book. Every 3 fills grant 1 extra Turn in the current Puzzle, then reset the count. After that reward, further fills this Puzzle do not add progress. Unfinished progress carries to the next Puzzle."),

        marker(lamp, "Lamp Marker", .common, 7,
               "After a qualifying placement here, if no Clues remain, gain 1 Clue. At most once this Puzzle. Disabled whenever the Boss disables Clues."),

        marker(ledger, "Ledger Marker", .uncommon, 9,
               "A correct placement here without a Clue that would earn Points instead earns 2 coins. Clear Points are unchanged. This trade happens automatically for the first 3 qualifying fills each Puzzle; later fills score normally."),

        marker(umbrella, "Umbrella Marker", .uncommon, 8,
               "After a qualifying placement here, protect up to 100 Points from the next wrong-placement penalty anywhere this Turn. One protection may be armed at a time; unused protection expires at Turn end. At most 2 protections can be consumed this Puzzle."),

        marker(hearth, "Hearth Marker", .common, 5,
               "A qualifying placement here gains +20 Points for each blank square directly above, below, left, or right, counted before the placement. Spaces beyond the board do not count."),

        marker(constellation, "Constellation Marker", .uncommon, 9,
               "A qualifying placement here gains +50 placement Points for each other distinct Marker type that has already triggered from an eligible correct placement this Turn, up to 4 types."),

        marker(rhythm, "Rhythm Marker", .common, 7,
               "A qualifying placement here gains +25 placement Points for each uninterrupted eligible correct placement immediately before it this Turn, capped at 6. Any wrong placement, Clue use, Toss, or Turn end resets the streak."),

        marker(bridge, "Bridge Marker", .common, 6,
               "A qualifying placement here gains +60 placement Points for each opposite pair of adjacent squares already filled by the player: left-and-right, or above-and-below. Givens and Clue-filled neighbors do not count."),

        marker(crossroads, "Crossroads Marker", .uncommon, 10,
               "The first qualifying placement on Crossroads that simultaneously completes at least 2 of its row, column, and box adds +300 placement Points. This bonus can occur once per Puzzle."),

        marker(voucher, "Voucher Marker", .common, 6,
               "Each qualifying placement here reduces the price of the first paid Reroll in the next Shop by 1 coin, up to 2 coins. The discount cannot make a price negative and expires when that Shop closes."),

        marker(interest, "Interest Marker", .uncommon, 8,
               "Each qualifying placement here raises this Puzzle’s cash-out interest cap by 1 coin, up to +2. Normal interest calculation still determines how much you earn. The Collector still prevents all interest."),

        marker(pledge, "Pledge Marker", .uncommon, 8,
               "After a qualifying placement here, you may pay 2 coins to add +100 placement Points to that placement. Pay only if your current balance can cover the full cost. At most 3 payments this Puzzle."),

        marker(collection, "Collection Marker", .common, 6,
               "Collect the digits used in qualifying fills of Collection squares across Puzzles in this Book. When 3 different digits have been collected, gain 4 coins and clear the collection. Further Collection fills this Puzzle do not add progress; an unfinished collection carries into the next Puzzle."),

        marker(debt, "Debt Marker", .common, 5,
               "After a qualifying placement here, if your coin balance is below zero, cancel up to 2 coins of that debt. The balance can rise no higher than zero. At most 6 debt coins can be cancelled this Puzzle."),

        marker(stipend, "Stipend Marker", .uncommon, 8,
               "The first qualifying placement here opens a contract: win this Puzzle without using another Clue to receive 4 extra cash-out coins. Any later Clue use breaks the contract. It cannot be restarted in this Puzzle."),

        marker(route, "Route Marker", .uncommon, 9,
               "After a qualifying placement here, make your next 2 eligible correct placements in 2 different boxes, both different from this square’s box, before this Turn ends. Add +120 placement Points to the second follow-up. A placement in a repeated box, wrong placement, Clue, or Toss breaks the route."),

        marker(ladder, "Ladder Marker", .common, 7,
               "After a qualifying placement here, your next 2 eligible correct placements this Turn must use successively larger digits. Add +90 placement Points to the second follow-up. A non-increasing placement, wrong placement, Clue, or Toss breaks the ladder."),

        marker(counterweight, "Counterweight Marker", .common, 6,
               "After a qualifying placement here, if your very next eligible correct placement this Turn has a digit that sums to 10 with this digit, add +70 Points to that next placement. Any other placement, wrong attempt, Clue, Toss, or Turn end breaks the pair."),

        marker(keystone, "Keystone Marker", .uncommon, 10,
               "After a qualifying placement here that leaves its box unfinished, the next natural scoring clear of that same box gains +120 clear Points. The promise lasts for this Puzzle. Only one box promise may be active at a time."),

        marker(finale, "Finale Marker", .rare, 12,
               "If a qualifying placement here locks the ninth and final copy of its digit onto the board, add +800 placement Points. Givens count toward the nine. This can pay for at most 2 digits per Puzzle."),

        marker(crosscheck, "Crosscheck Marker", .common, 5,
               "After a qualifying placement here, choose one blank square in this box to inspect its candidates from visible row, column, and box rules. The reading updates as the board changes and closes at Turn end. It does not identify the true solution. At most 2 readings this Puzzle."),

        marker(carbon, "Carbon Marker", .uncommon, 8,
               "A qualifying placement here gains extra placement Points equal to the combined ordinary digit base Points of your previous 2 eligible correct placements this Turn. With only one earlier placement, copy that one; with none, add nothing. Never copy bonuses or multipliers."),

        marker(pressmark, "Pressmark Marker", .uncommon, 9,
               "After a qualifying placement here, the next 3 eligible correct placements elsewhere this Turn each gain +20 placement Points. The source placement does not receive this bonus. Only one Pressmark run may be active; at most 2 runs can be armed this Puzzle."),

        marker(tiebreaker, "Tiebreaker Marker", .rare, 12,
               "After a qualifying placement here, if 1–3 unblocked cards remain in Hand, offer a challenge: correctly place all of those exact cards before this Turn ends to add +250 Points to the last one. A wrong play, Clue, Toss, exchange, or manual Turn end fails the challenge; later draws do not add cards to it."),

        marker(blotter, "Blotter Marker", .uncommon, 8,
               "The first wrong placement on a Blotter square each Puzzle returns that card to the Hand and cancels its score penalty, but locks that square against further attempts until the next Turn. Later wrong placements use normal rules."),

        marker(patina, "Patina Marker", .uncommon, 9,
               "A qualifying placement here gains +25 Points for each earlier Puzzle where you made a qualifying fill on this Patina square, up to +200. This fill adds one success for future Puzzles; it cannot count twice in the same Puzzle."),

        marker(windlass, "Windlass Marker", .uncommon, 9,
               "After a qualifying placement here, you may spend 1 remaining Toss allowance to draw 2 random Pool cards. Do not return any Hand card. At most 2 activations this Puzzle. Cannot be used when a rule disables Tosses."),

        marker(beacon, "Beacon Marker", .uncommon, 10,
               "After a qualifying placement here, remember its digit. The next 2 eligible correct placements of that digit elsewhere this Puzzle each gain +40 placement Points. One digit may be watched at a time, and at most 2 Beacon watches can be started per Puzzle."),

        marker(sweep, "Sweep Marker", .common, 6,
               "After a qualifying placement here, you may choose a digit and return up to 2 unblocked copies of it from your Hand to the Pool without drawing replacements or spending Toss allowance. At most 2 sweeps this Puzzle. No-Toss rules also forbid Sweep."),

        marker(census, "Census Marker", .common, 5,
               "After a qualifying placement here, inspect the exact current Pool count of that placed digit until this Turn ends. The count updates as cards move. At most 2 count inspections this Puzzle; a later one replaces the earlier digit."),

        marker(bounty, "Bounty Marker", .uncommon, 9,
               "After a qualifying placement here, a random unmarked, unbarred blank square elsewhere in this box becomes a target. A qualifying correct placement there before Turn end gains +120 Points. No available target means no bounty."),

        marker(harvest, "Harvest Marker", .uncommon, 10,
               "After a qualifying placement here, you may return every remaining unblocked Hand copy of that same digit, up to 3 cards, and draw the same number of random Pool cards of other digits. Offer only when enough other-digit cards exist. At most once per Puzzle."),
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
