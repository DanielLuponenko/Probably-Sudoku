import Foundation

/// The fifty Bookmarks in the approved 20 September 2026 catalogue.
/// IDs and existing owned-copy identities remain stable across the expansion.
/// Stateful and conditional rules live in BookmarkMechanics; the original
/// hooks remain available only where the integrator preserves a legacy Turn.
public enum Bookmarks {
    public static let morningEdition = "bm_morning_edition"
    public static let eveningEdition = "bm_evening_edition"
    public static let localGossip = "bm_local_gossip"
    public static let sportsSection = "bm_sports_section"
    public static let societyPages = "bm_society_pages"
    public static let opEd = "bm_op_ed"
    public static let editorialBoard = "bm_editorial_board"
    public static let frontPageSplash = "bm_front_page_splash"
    public static let lettersToTheEditor = "bm_letters_to_the_editor"
    public static let rollingPresses = "bm_rolling_presses"
    public static let syndication = "bm_syndication"
    public static let stopThePresses = "bm_stop_the_presses"
    public static let theSundaySupplement = "bm_the_sunday_supplement"
    public static let extraExtra = "bm_extra_extra"
    public static let financePages = "bm_finance_pages"
    public static let paperRoute = "bm_paper_route"
    public static let marketWrap = "bm_market_wrap"
    public static let auctionNotices = "bm_auction_notices"
    public static let helpWanted = "bm_help_wanted"
    public static let weatherForecast = "bm_weather_forecast"
    public static let puzzleCorner = "bm_puzzle_corner"
    public static let lateCityFinal = "bm_late_city_final"
    public static let crosswordDaily = "bm_crossword_daily"
    public static let marginNotes = "bm_margin_notes"
    public static let neighbourhoodNews = "bm_neighbourhood_news"
    public static let serialStory = "bm_serial_story"
    public static let doubleColumn = "bm_double_column"
    public static let carryover = "bm_carryover"
    public static let numberIndex = "bm_number_index"
    public static let earlyDeadline = "bm_early_deadline"
    public static let duplicateDispatch = "bm_duplicate_dispatch"
    public static let overflowColumn = "bm_overflow_column"
    public static let paperSalvage = "bm_paper_salvage"
    public static let forthcomingEdition = "bm_forthcoming_edition"
    public static let carbonPaper = "bm_carbon_paper"
    public static let pocketInsert = "bm_pocket_insert"
    public static let bulkNotice = "bm_bulk_notice"
    public static let buybackColumn = "bm_buyback_column"
    public static let windowShopping = "bm_window_shopping"
    public static let advancePayment = "bm_advance_payment"
    public static let typeCase = "bm_type_case"
    public static let crossReference = "bm_cross_reference"
    public static let issueTracker = "bm_issue_tracker"
    public static let correctionLedger = "bm_correction_ledger"
    public static let referenceDesk = "bm_reference_desk"
    public static let recycledInsert = "bm_recycled_insert"
    public static let readersCircle = "bm_readers_circle"
    public static let personalColumn = "bm_personal_column"
    public static let archiveRoom = "bm_archive_room"
    public static let rightToReply = "bm_right_to_reply"

    public static let all: [ItemDef] = [
        ItemDef(id: "bm_morning_edition", kind: .bookmark, name: "Morning Edition", rarity: .common,
            listedPrice: 4, text: "At the end of each eligible Turn, add 100 direct points after banking. This bonus is not multiplied.", hooks: [.turnEnd: { _, r in r.directScore += 100 }]),
        ItemDef(id: "bm_evening_edition", kind: .bookmark, name: "Evening Edition", rarity: .common,
            listedPrice: 4, text: "When you bank Turn 10 with at least one eligible placement, add 300 direct points after banking. Extra Turns do not repeat the award.", hooks: [.puzzleEnd: { _, r in r.directScore += 300 }]),
        ItemDef(id: "bm_local_gossip", kind: .bookmark, name: "Local Gossip", rarity: .common,
            listedPrice: 5, text: "Each correct placement gains +30 Points before multipliers. Clue placements score zero unless Onyx restores them; Bosses may still prevent scoring.", hooks: [.place: { _, r in r.flat += 30 }]),
        ItemDef(id: "bm_sports_section", kind: .bookmark, name: "Sports Section", rarity: .common,
            listedPrice: 5, text: "Each completed row, column, or box gains +25 clear Points before multipliers. Clue clears still score zero.", hooks: [.lineClear: { _, r in r.flat += 25 }]),
        ItemDef(id: "bm_society_pages", kind: .bookmark, name: "Society Pages", rarity: .uncommon,
            listedPrice: 7, text: "Completing the whole board adds +500 Full Clear Points before multipliers. A Full Clear made with a Clue still scores zero.", hooks: [.fullClear: { _, r in r.flat += 500 }]),
        ItemDef(id: "bm_op_ed", kind: .bookmark, name: "Op-Ed Column", rarity: .common,
            listedPrice: 5, text: "Add +1 Turn Mult when this Bookmark scores.", hooks: [.anyScore: { _, r in r.multAdd += 1 }]),
        ItemDef(id: "bm_editorial_board", kind: .bookmark, name: "Editorial Board", rarity: .uncommon,
            listedPrice: 8, text: "Score placements without Clues in at least three different boxes this Turn to add +3 Turn Mult when this Bookmark scores.", hooks: [.anyScore: { _, r in r.multAdd += 2 }]),
        ItemDef(id: "bm_front_page_splash", kind: .bookmark, name: "Front Page Splash", rarity: .uncommon,
            listedPrice: 9, text: "Add +1 Turn Mult for each Bookmark in this Turn's scoring order, including this one, when this Bookmark scores.", hooks: [.anyScore: { c, r in r.multAdd += Double(c.bookmarkCount) }]),
        ItemDef(id: "bm_letters_to_the_editor", kind: .bookmark, name: "Letters to the Editor", rarity: .uncommon,
            listedPrice: 8, text: "In a Boss Puzzle, losing points to a wrong placement earns +3 Turn Mult on the next Turn when this Bookmark scores. You must score at least one placement without a Clue on that next Turn.", hooks: [.anyScore: { c, r in if c.difficulty == .boss { r.multAdd += 3 } }]),
        ItemDef(id: "bm_rolling_presses", kind: .bookmark, name: "Rolling Presses", rarity: .uncommon,
            listedPrice: 10, text: "Starts each Puzzle at ×1. Every row, column, or box clear adds ×0.5 to this Bookmark's multiplier. Multiply Turn Mult by its current value when this Bookmark scores.", hooks: [.anyScore: { c, r in r.multX *= 1 + 0.5 * (c.puzzleState[rollingPresses] ?? 0) }, .lineClear: { c, r in r.bumpPuzzleState(rollingPresses, by: 1, in: c) }]),
        ItemDef(id: "bm_syndication", kind: .bookmark, name: "Syndication", rarity: .rare,
            listedPrice: 13, text: "Starts the Book at ×1. Each Puzzle win adds ×0.25 for later Puzzles. Multiply Turn Mult by this Bookmark's current value when it scores.", hooks: [.anyScore: { c, r in r.multX *= 1 + 0.25 * (c.runState[syndication] ?? 0) }]),
        ItemDef(id: "bm_stop_the_presses", kind: .bookmark, name: "Stop the Presses", rarity: .rare,
            listedPrice: 12, text: "Multiply Turn Mult by 3 when this Bookmark scores if you made only one or two scoring placements without Clues this Turn. A third removes the bonus.", hooks: [.anyScore: { _, r in r.multX *= 3 }]),
        ItemDef(id: "bm_the_sunday_supplement", kind: .bookmark, name: "The Sunday Supplement", rarity: .rare,
            listedPrice: 13, text: "Multiply Turn Mult by 2 when this Bookmark scores, or by 3 in a Boss Puzzle.", hooks: [.anyScore: { c, r in r.multX *= c.difficulty == .boss ? 3 : 2 }]),
        ItemDef(id: "bm_extra_extra", kind: .bookmark, name: "Extra! Extra!", rarity: .rare,
            listedPrice: 12, text: "Triple the Points from each row, column, box, and Full Clear before they are banked. Clears made with Clues, or prevented from scoring by a Boss, still score zero.", hooks: [.lineClear: { _, r in r.eventMultX *= 3 }, .fullClear: { _, r in r.eventMultX *= 3 }]),
        ItemDef(id: "bm_finance_pages", kind: .bookmark, name: "Finance Pages", rarity: .common,
            listedPrice: 5, text: "Gain 1 coin for each row, column, or box clear, including clears made by Clues or during Keep Filling.", hooks: [.lineClear: { _, r in r.coins += 1 }]),
        ItemDef(id: "bm_paper_route", kind: .bookmark, name: "Paper Route", rarity: .common,
            listedPrice: 5, text: "Gain 2 extra coins in each Puzzle-win payout.", hooks: [:]),
        ItemDef(id: "bm_market_wrap", kind: .bookmark, name: "Market Wrap", rarity: .uncommon,
            listedPrice: 8, text: "Raise the base cap on each Puzzle-win interest payout from 10 to 15 coins while owned. Other Book, Clipping, or subscription cap modifiers still apply.", hooks: [:]),
        ItemDef(id: "bm_auction_notices", kind: .bookmark, name: "Auction Notices", rarity: .uncommon,
            listedPrice: 8, text: "The first paid reroll you request in each Shop costs 0 coins.", hooks: [:]),
        ItemDef(id: "bm_help_wanted", kind: .bookmark, name: "Help Wanted", rarity: .common,
            listedPrice: 6, text: "Refill your Hand with one more card while you own this Bookmark. Boss and other item adjustments still apply.", hooks: [:]),
        ItemDef(id: "bm_weather_forecast", kind: .bookmark, name: "Weather Forecast", rarity: .common,
            listedPrice: 4, text: "Add 2 to each Puzzle's Toss allowance while this Bookmark is owned.", hooks: [:]),
        ItemDef(id: "bm_puzzle_corner", kind: .bookmark, name: "Puzzle Corner", rarity: .uncommon,
            listedPrice: 7, text: "Add 1 Clue at the start of each Puzzle while this Bookmark is owned. Boss rules that disable Clues still apply.", hooks: [:]),
        ItemDef(id: "bm_late_city_final", kind: .bookmark, name: "Late City Final", rarity: .uncommon,
            listedPrice: 9, text: "Add 1 scheduled Turn to each Puzzle while this Bookmark is owned.", hooks: [:]),
        ItemDef(id: "bm_crossword_daily", kind: .bookmark, name: "Crossword Daily", rarity: .rare,
            listedPrice: 11, text: "After each row, column, or box clear, draw 1 number from the Pool into the Hand, including Clue and Keep Filling clears.", hooks: [.lineClear: { _, r in r.draws += 1 }]),
        ItemDef(id: "bm_margin_notes", kind: .bookmark, name: "Margin Notes", rarity: .common,
            listedPrice: 4, text: "Scoring placements without Clues on the board's outermost row or column gain +50 Points before multipliers.", hooks: [:]),
        ItemDef(id: "bm_neighbourhood_news", kind: .bookmark, name: "Neighbourhood News", rarity: .common,
            listedPrice: 5, text: "A scoring placement without a Clue gains +45 Points before multipliers if at least two squares directly above, below, left, or right were already filled by you. Givens and Clue placements do not count as neighbours.", hooks: [:]),
        ItemDef(id: "bm_serial_story", kind: .bookmark, name: "Serial Story", rarity: .uncommon,
            listedPrice: 8, text: "Score three digits without Clues in consecutive ascending order, such as 2→3→4, to add +120 Points to the third placement before multipliers. A wrong placement, Clue, zero-score placement, or break in the sequence ends the run.", hooks: [:]),
        ItemDef(id: "bm_double_column", kind: .bookmark, name: "Double Column", rarity: .common,
            listedPrice: 6, text: "Score the same digit without Clues in two different boxes this Turn to add +2 Turn Mult when this Bookmark scores.", hooks: [:]),
        ItemDef(id: "bm_carryover", kind: .bookmark, name: "Carryover", rarity: .uncommon,
            listedPrice: 8, text: "After a Turn with a scoring placement made without a Clue, gain 10% of the previous Turn's banked score, rounded down, up to 300 Points. Bonuses added after banking are not copied, and this reward is not multiplied.", hooks: [:]),
        ItemDef(id: "bm_number_index", kind: .bookmark, name: "Number Index", rarity: .rare,
            listedPrice: 12, text: "The first time you score all nine different digits in a Puzzle, this Bookmark gains +2 Turn Mult for the rest of the Book, including this Turn.", hooks: [:]),
        ItemDef(id: "bm_early_deadline", kind: .bookmark, name: "Early Deadline", rarity: .uncommon,
            listedPrice: 7, text: "Win a Puzzle by the end of Turn 5 to gain 4 extra coins in its payout.", hooks: [:]),
        ItemDef(id: "bm_duplicate_dispatch", kind: .bookmark, name: "Duplicate Dispatch", rarity: .common,
            listedPrice: 6, text: "Once per Puzzle, at a Turn's start with at least three copies of one digit in your Hand, you may return all but one of those copies to the Pool and draw the same number of replacements.", hooks: [:]),
        ItemDef(id: "bm_overflow_column", kind: .bookmark, name: "Overflow Column", rarity: .uncommon,
            listedPrice: 8, text: "Each scoring placement without a Clue gains +25 Points per extra card above your normal Hand size, up to +100, before multipliers. Count the cards before the placed card leaves your Hand.", hooks: [:]),
        ItemDef(id: "bm_paper_salvage", kind: .bookmark, name: "Paper Salvage", rarity: .common,
            listedPrice: 4, text: "The first Toss you make in a Puzzle immediately draws 1 replacement number from the Pool. The Toss still spends its normal allowance.", hooks: [:]),
        ItemDef(id: "bm_forthcoming_edition", kind: .bookmark, name: "Forthcoming Edition", rarity: .common,
            listedPrice: 6, text: "Show the next two numbers that the current Pool would draw. Refresh the preview whenever the Pool or its draw state changes.", hooks: [:]),
        ItemDef(id: "bm_carbon_paper", kind: .bookmark, name: "Carbon Paper", rarity: .uncommon,
            listedPrice: 8, text: "Once per Turn, an eligible marked placement that adds marker-only extra placement points stores that extra amount, capped at 180. Add it as flat points to your next eligible unmarked placement that Turn, then clear it.", hooks: [:]),
        ItemDef(id: "bm_pocket_insert", kind: .bookmark, name: "Pocket Insert", rarity: .rare,
            listedPrice: 11, text: "Increase your Buff inventory capacity from 2 to 3 while this Bookmark is owned.", hooks: [:]),
        ItemDef(id: "bm_bulk_notice", kind: .bookmark, name: "Bulk Notice", rarity: .common,
            listedPrice: 4, text: "Reduce the first Buff you buy in each Shop by 1 coin, to a minimum price of 1.", hooks: [:]),
        ItemDef(id: "bm_buyback_column", kind: .bookmark, name: "Buyback Column", rarity: .common,
            listedPrice: 6, text: "Once per Shop, sell one other Bookmark you already owned on entry for its actual purchase price instead of the normal resale value.", hooks: [:]),
        ItemDef(id: "bm_window_shopping", kind: .bookmark, name: "Window Shopping", rarity: .common,
            listedPrice: 5, text: "Leave a Shop without buying any item or requesting any reroll to gain 3 coins. Selling owned items does not disqualify you.", hooks: [:]),
        ItemDef(id: "bm_advance_payment", kind: .bookmark, name: "Advance Payment", rarity: .uncommon,
            listedPrice: 9, text: "Before your first action in a Puzzle, you may pay 3 coins. For that Puzzle, multiply Turn Mult by 2.5 when this Bookmark scores.", hooks: [:]),
        ItemDef(id: "bm_type_case", kind: .bookmark, name: "Type Case", rarity: .common,
            listedPrice: 6, text: "At each Turn's start, choose one digit currently in your Hand to hold in reserve. Your first three eligible placements of other digits gain 50 flat points each; placing the chosen digit ends the bonus for that Turn.", hooks: [:]),
        ItemDef(id: "bm_cross_reference", kind: .bookmark, name: "Cross Reference", rarity: .uncommon,
            listedPrice: 8, text: "When one eligible placement completes at least two of row, column, and box, schedule 2 extra Pool draws after the next ordinary Turn refill.", hooks: [:]),
        ItemDef(id: "bm_issue_tracker", kind: .bookmark, name: "Issue Tracker", rarity: .common,
            listedPrice: 5, text: "On an eligible box clear, gain 1 coin for each different Turn in which you scored a placement inside that box, capped at 3 coins.", hooks: [:]),
        ItemDef(id: "bm_correction_ledger", kind: .bookmark, name: "Correction Ledger", rarity: .common,
            listedPrice: 4, text: "Record half of the first wrong-placement penalty you actually pay each Puzzle, rounded down and capped at 150. After three later eligible placements, refund that amount as direct score.", hooks: [:]),
        ItemDef(id: "bm_reference_desk", kind: .bookmark, name: "Reference Desk", rarity: .uncommon,
            listedPrice: 8, text: "The first eligible row clear, first eligible column clear, and first eligible box clear in a Puzzle each restore 1 Clue you have already spent. A category completed before you spend a Clue gives no charge.", hooks: [:]),
        ItemDef(id: "bm_recycled_insert", kind: .bookmark, name: "Recycled Insert", rarity: .common,
            listedPrice: 6, text: "After you consume three purchased Buffs, claim one free Common Buff from a choice of two at the next Shop. Claiming spends three receipts; free reward Buffs do not create receipts.", hooks: [:]),
        ItemDef(id: "bm_readers_circle", kind: .bookmark, name: "Readers' Circle", rarity: .rare,
            listedPrice: 12, text: "After a Turn with a scoring placement made without a Clue, copy the +Mult from the Bookmark immediately to this one's left, up to +3. Apply it when this Bookmark scores. It cannot copy ×Mult, other effects, or another Readers' Circle.", hooks: [:]),
        ItemDef(id: "bm_personal_column", kind: .bookmark, name: "Personal Column", rarity: .uncommon,
            listedPrice: 8, text: "Choose one digit at Puzzle start. After each of your first two eligible placements of that digit, draw another copy of it from the Pool if one remains.", hooks: [:]),
        ItemDef(id: "bm_archive_room", kind: .bookmark, name: "Archive Room", rarity: .uncommon,
            listedPrice: 8, text: "On a Puzzle win, store 50 points per unused Clue, capped at 150. Add those points as flat placement points to your first eligible placement in the next played Puzzle, then empty the archive.", hooks: [:]),
        ItemDef(id: "bm_right_to_reply", kind: .bookmark, name: "Right to Reply", rarity: .uncommon,
            listedPrice: 7, text: "The first time in a Puzzle a Boss would silence another Bookmark, silence this one for that same duration instead.", hooks: [:]),
    ]
}
