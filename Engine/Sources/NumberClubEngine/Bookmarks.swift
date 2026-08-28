import Foundation

/// §10 — Advertisements printed through the Sudoku Book. Passive, and they run
/// for the whole Book once bought. 5 slots.
///
/// Several Bookmarks are not event hooks at all but standing modifiers (hand size,
/// Turns, Clues, interest cap, reroll cost). Those are resolved by the
/// `effective…` queries on `RunState`, keyed by the ids below.
public enum Bookmarks {

    // Ids referenced by the passive queries in Run.swift.
    public static let helpWanted = "bm_help_wanted"
    public static let weatherForecast = "bm_weather_forecast"
    public static let puzzleCorner = "bm_puzzle_corner"
    public static let lateCityFinal = "bm_late_city_final"
    public static let marketWrap = "bm_market_wrap"
    public static let auctionNotices = "bm_auction_notices"
    public static let paperRoute = "bm_paper_route"
    public static let syndication = "bm_syndication"
    public static let rollingPresses = "bm_rolling_presses"

    private static func ad(_ id: String, _ name: String, _ rarity: Rarity, _ price: Int,
                           _ text: String, _ hooks: [GameEvent: Effect] = [:]) -> ItemDef {
        ItemDef(id: id, kind: .bookmark, name: name, rarity: rarity,
                listedPrice: price, text: text, hooks: hooks)
    }

    public static let all: [ItemDef] = flatPoints + additiveMult + multiplicativeMult + coins + utility

    // MARK: Flat points

    static let flatPoints: [ItemDef] = [
        ad("bm_morning_edition", "Morning Edition", .common, 4,
           "+100 points at the end of each Turn",
           [.turnEnd: { _, r in r.directScore += 100 }]),

        ad("bm_evening_edition", "Evening Edition", .common, 4,
           "+300 points at the end of Turn 10",
           [.puzzleEnd: { _, r in r.directScore += 300 }]),

        ad("bm_local_gossip", "Local Gossip", .common, 4,
           "Every correct placement scores +30 flat",
           [.place: { _, r in r.flat += 30 }]),

        ad("bm_sports_section", "Sports Section", .common, 5,
           "Line Clears gain +25",
           [.lineClear: { _, r in r.flat += 25 }]),

        ad("bm_society_pages", "Society Pages", .uncommon, 6,
           "Full Clear gains +500",
           [.fullClear: { _, r in r.flat += 500 }]),
    ]

    // MARK: Additive mult
    // These enter the formula as `1 + (sum of every additive contribution)`,
    // so two "+1 mult" Bookmarks give x3, not x4 (§6).

    static let additiveMult: [ItemDef] = [
        ad("bm_op_ed", "Op-Ed Column", .common, 5,
           "+1 mult",
           [.anyScore: { _, r in r.multAdd += 1 }]),

        ad("bm_editorial_board", "Editorial Board", .uncommon, 6,
           "+2 mult",
           [.anyScore: { _, r in r.multAdd += 2 }]),

        ad("bm_front_page_splash", "Front Page Splash", .uncommon, 7,
           "+1 mult per Bookmark owned, including itself",
           [.anyScore: { c, r in r.multAdd += Double(c.bookmarkCount) }]),

        ad("bm_letters_to_the_editor", "Letters to the Editor", .uncommon, 6,
           "+3 mult, Boss Puzzles only",
           [.anyScore: { c, r in if c.difficulty == .boss { r.multAdd += 3 } }]),
    ]

    // MARK: Multiplicative mult
    // These multiply with each other and with the additive total, so they do
    // not suffer the additive pool's diminishing returns (§14).

    static let multiplicativeMult: [ItemDef] = [
        ad("bm_rolling_presses", "Rolling Presses", .uncommon, 7,
           "Starts at x1, gains +x0.5 per Line Clear this Puzzle. Resets each Puzzle",
           [
            .anyScore: { c, r in
                r.multX *= 1 + 0.5 * (c.puzzleState[rollingPresses] ?? 0)
            },
            .lineClear: { c, r in
                r.bumpPuzzleState(rollingPresses, by: 1, in: c)
            },
           ]),

        ad("bm_syndication", "Syndication", .rare, 8,
           "Starts at x1, permanently gains +x0.25 every Puzzle you win. Resets only at a new Book",
           [.anyScore: { c, r in
               r.multX *= 1 + 0.25 * (c.runState[syndication] ?? 0)
           }]),

        ad("bm_stop_the_presses", "Stop the Presses", .rare, 8,
           "x3 mult, always",
           [.anyScore: { _, r in r.multX *= 3 }]),

        ad("bm_the_sunday_supplement", "The Sunday Supplement", .rare, 7,
           "x2 mult; x3 on Boss Puzzles",
           [.anyScore: { c, r in r.multX *= c.difficulty == .boss ? 3 : 2 }]),

        ad("bm_extra_extra", "Extra! Extra!", .rare, 8,
           "Line Clears and Full Clears score x3",
           [
            .lineClear: { _, r in r.multX *= 3 },
            .fullClear: { _, r in r.multX *= 3 },
           ]),
    ]

    // MARK: Coins

    static let coins: [ItemDef] = [
        ad("bm_finance_pages", "Finance Pages", .common, 5,
           "+1 coin per Line Clear",
           [.lineClear: { _, r in r.coins += 1 }]),

        ad(paperRoute, "Paper Route", .common, 4,
           "+2 coins on every Puzzle win payout"),

        ad(marketWrap, "Market Wrap", .uncommon, 6,
           "Interest cap raised from 10 to 15"),

        ad(auctionNotices, "Auction Notices", .uncommon, 6,
           "First reroll in each Shop is free"),
    ]

    // MARK: Utility

    static let utility: [ItemDef] = [
        ad(helpWanted, "Help Wanted", .common, 5, "Hand size +1"),
        ad(weatherForecast, "Weather Forecast", .common, 4, "Toss allowance +2"),
        ad(puzzleCorner, "Puzzle Corner", .uncommon, 6, "+1 Clue every Puzzle"),
        ad(lateCityFinal, "Late City Final", .uncommon, 7, "+1 Turn every Puzzle"),

        ad("bm_crossword_daily", "Crossword Daily", .rare, 8,
           "After each Line Clear, draw 1 number from the Pool",
           [.lineClear: { _, r in r.draws += 1 }]),
    ]
}
