import Foundation

/// §13 — one is rolled for every Boss Puzzle. Six active final encounters
/// belong to Level 9; legacy raw IDs and their powers remain save-compatible.
public enum BossModifier: String, Codable, CaseIterable, Sendable {
    case censor, editor, deadline, fog, critic, mirror, paywall, erratum, collector
    case heavyLifter, unluckyLucky, buffborger, sashimi, overPusher
    case accountant, tikTak, handyDandy, grayTheGarry, garryTheGray
    case galleyQueue, bookends, reprintBan, rebinder, lateCourier, collator, pageCutter
    case chainStitcher, returnSlip, orphanLine, serialPublisher, bindery, embargo, dryPress
    case reviewBoard, rivalColumn, royaltyContract, publicist, wordCount, backPage

    case collateral, splitEdition, lastEdition

    // Keep the original raw IDs so existing active encounters still decode
    // with the same mechanics. Only future selection and display names change.
    /// Frozen pools for Books saved before the redesigned roster.
    public static let legacyFinalBosses: [BossModifier] = [
        .heavyLifter, .unluckyLucky, .buffborger, .sashimi, .overPusher,
        .lateCourier, .pageCutter, .serialPublisher, .bindery, .reviewBoard
    ]
    public static let legacyRegularBosses = allCases.filter {
        !legacyFinalBosses.contains($0) && ![.collateral, .splitEdition, .lastEdition].contains($0)
    }
    public static let finalBosses: [BossModifier] = [
        .heavyLifter, .unluckyLucky, .bindery, .reviewBoard, .splitEdition, .lastEdition
    ]
    public static let regularBosses: [BossModifier] = [
        .fog, .mirror, .erratum, .accountant, .tikTak, .garryTheGray,
        .bookends, .rebinder, .chainStitcher, .returnSlip, .dryPress,
        .backPage, .royaltyContract, .rivalColumn, .publicist, .collateral
    ]
    public static let activeRoster = regularBosses + finalBosses
    public static let activeBosses = activeRoster
    /// Historical final encounters retain their classification and saved rules.
    public var isFinalBoss: Bool { Self.finalBosses.contains(self) || Self.legacyFinalBosses.contains(self) }
    public var isActiveEncounter: Bool { Self.activeRoster.contains(self) }

    public var name: String {
        switch self {
        case .censor: return "The Censor"
        case .editor: return "The Editor"
        case .deadline: return "The Deadline"
        case .fog: return "The Fog"
        case .critic: return "The Critic"
        case .mirror: return "The Mirror"
        case .paywall: return "The Paywall"
        case .erratum: return "The Erratum"
        case .collector: return "The Collector"
        case .heavyLifter: return "The Final Draft"
        case .unluckyLucky: return "The Executive Editor"
        case .buffborger: return "The Fine Print"
        case .sashimi: return "The Budget Cut"
        case .overPusher: return "The Shredder"
        case .accountant: return "Natural Born Accountant"
        case .tikTak: return "Tik Tak"
        case .handyDandy: return "Handy Dandy"
        case .grayTheGarry: return "Gray the Garry"
        case .garryTheGray: return "Garry the Gray"
        case .galleyQueue: return "The Galley Queue"
        case .bookends: return "The Bookends"
        case .reprintBan: return "The Reprint Ban"
        case .rebinder: return "The Rebinder"
        case .lateCourier: return "The Late Courier"
        case .collator: return "The Collator"
        case .pageCutter: return "The Page Cutter"
        case .chainStitcher: return "The Chain Stitcher"
        case .returnSlip: return "The Return Slip"
        case .orphanLine: return "The Orphan Line"
        case .serialPublisher: return "The Serial Publisher"
        case .bindery: return "The Bindery"
        case .embargo: return "The Embargo"
        case .dryPress: return "The Dry Press"
        case .reviewBoard: return "The Review Board"
        case .rivalColumn: return "The Rival Column"
        case .royaltyContract: return "The Royalty Contract"
        case .publicist: return "The Publicist"
        case .wordCount: return "The Word Count"
        case .backPage: return "The Back Page"
        case .collateral: return "The Collateral"
        case .splitEdition: return "The Split Edition"
        case .lastEdition: return "The Last Edition"
        }
    }

    public var text: String {
        switch self {
        case .censor: return "One random number scores no points this Puzzle"
        case .editor: return "Hand size -1"
        case .deadline: return "8 Turns instead of 10"
        case .fog: return "Marked squares are hidden this Puzzle"
        case .critic: return "Wrong-placement penalty doubled"
        case .mirror: return "No Line Clear bonuses this Puzzle"
        case .paywall: return "All Clues disabled, including Buff-granted"
        case .erratum: return "No Tosses this Puzzle"
        case .collector: return "This Puzzle's payout includes no interest"
        case .heavyLifter: return "The target is four times what it would be"
        case .unluckyLucky: return "One triggered Bookmark sleeps each Turn; passive upgrades stay active"
        case .buffborger: return "No Buff can be spent this Puzzle"
        case .sashimi: return "All score multipliers are cut in half"
        case .overPusher: return "Up to three squares are fouled each Turn for two Turns; one blank stays free"
        case .accountant: return "Every placement costs a coin, even if you have none"
        case .tikTak: return "Four minutes for the whole Puzzle"
        case .handyDandy: return "Up to two cards are barred each Turn; your whole Hand is never barred"
        case .grayTheGarry: return "A row is barred each Turn, unless it holds every remaining blank"
        case .garryTheGray: return "A box is barred each Turn, unless it holds every remaining blank"
        case .galleyQueue: return "Your two oldest available cards play first. Use one to open the next card."
        case .bookends: return "Only the lowest and highest available numbers can play."
        case .reprintBan: return "A number you filled this Turn waits while a new number can play. When only repeats remain, they open."
        case .rebinder: return "At End Turn, return leftovers to the Pool before drawing a fresh Hand"
        case .lateCourier: return "Automatic bonus draws arrive after banking and count toward refill"
        case .collator: return "Half your Hand waits for 2 correct fills or an empty first packet"
        case .pageCutter: return "Every 4 correct fills end the Turn; start with 4 extra Turns"
        case .chainStitcher: return "Follow your last placement: same row, column or box earns full placement Points; elsewhere earns half. Clues don't move the link."
        case .returnSlip: return "Wrong cards return sealed until next Turn; normal penalties still apply"
        case .orphanLine: return "Banking costs 20 queued Points per leftover card, up to 100"
        case .serialPublisher: return "Bank up to a third of target. Carry overflow; Full Clear pays all"
        case .bindery: return "Bookmarks pin on your first action; odd Turns read forwards, even Turns backwards"
        case .embargo: return "Use preparation Buffs before your first placement attempt each Turn"
        case .dryPress: return "After a marked fill, its placement bonuses sleep until an unmarked fill"
        case .reviewBoard: return "Reach the target and complete a row, a column and a box"
        case .rivalColumn: return "Beat your previous bank or lose 20% of this bank, up to 100 points"
        case .royaltyContract: return "Each Buff spent adds 5% of the starting target, up to 3 times"
        case .publicist: return "Each Bookmark’s flat placement or Line Clear bonus pays once per Turn"
        case .wordCount: return "Item bonuses to natural placements share 150 Points per Turn"
        case .backPage: return "Natural number values run backwards: 1 scores 90, 9 scores 10"
        case .collateral: return "Target +50%. Before acting, pledge one card for +2 Mult this Turn. Banking returns it."
        case .splitEdition: return "Fill both editions. Choose where this Turn’s score goes before acting; excess stays in that edition."
        case .lastEdition: return "One bank to win. Start with 4 extra cards and one quarter of the usual target. No extra Turns or rescue."
        }
    }

    /// What the modifier attacks, for the UI to explain itself.
    public var attacks: String {
        switch self {
        case .censor: return "Any build leaning on one number"
        case .editor: return "Options per Turn"
        case .deadline: return "Time"
        case .fog: return "Marker builds"
        case .critic: return "Risk-taking"
        case .mirror: return "Line-clear builds"
        case .paywall: return "Clue builds"
        case .erratum: return "Hand filtering"
        case .collector: return "Hoarding"
        case .heavyLifter: return "Everything at once"
        case .unluckyLucky: return "Builds that lean on one Bookmark"
        case .buffborger: return "Anything held in reserve"
        case .sashimi: return "Mult stacking"
        case .overPusher: return "Room to play"
        case .accountant: return "The Shop after this"
        case .tikTak: return "Thinking it through"
        case .handyDandy: return "The Hand you were counting on"
        case .grayTheGarry: return "Rows you were about to finish"
        case .garryTheGray: return "Boxes you were about to finish"
        case .galleyQueue: return "Keeping old cards in reserve"
        case .bookends: return "The middle of your Hand"
        case .reprintBan: return "Repeating one number"
        case .rebinder: return "Saving cards between Turns"
        case .lateCourier: return "Immediate bonus draws"
        case .collator: return "Opening Hand options"
        case .pageCutter: return "Long placement chains"
        case .chainStitcher: return "Disconnected placements"
        case .returnSlip: return "Speculative placements"
        case .orphanLine: return "Banking with a full Hand"
        case .serialPublisher: return "One enormous bank"
        case .bindery: return "A fixed multiplier order"
        case .embargo: return "Late preparation"
        case .dryPress: return "Consecutive Marker bonuses"
        case .reviewBoard: return "Scoring without completing units"
        case .rivalColumn: return "Shrinking banks"
        case .royaltyContract: return "Marginal Buff uses"
        case .publicist: return "Repeated flat Bookmark bonuses"
        case .wordCount: return "Many boosted placements"
        case .backPage: return "High-number base Points"
        case .collateral: return "A useful number or a stronger bank"
        case .splitEdition: return "One-sided scoring"
        case .lastEdition: return "Saving your build for a later Turn"
        }
    }

    // MARK: Standing modifiers, applied when the Puzzle is created

    public var handSizeDelta: Int { self == .editor ? -1 : (self == .lastEdition ? 4 : 0) }
    public var turnsOverride: Int? { self == .deadline ? 8 : nil }
    public var forcesTossAllowanceToZero: Bool { self == .erratum }
    public var disablesClues: Bool { self == .paywall }
    public var hidesMarkedSquares: Bool { self == .fog }
    public var cancelsInterest: Bool { self == .collector }
    public var doublesWrongPenalty: Bool { self == .critic }
    public var targetMultiplier: Int { self == .heavyLifter ? 4 : 1 }
    public var disablesBuffs: Bool { self == .buffborger }
    public var halvesScoreMultiplier: Bool { self == .sashimi }
    /// Natural Born Accountant. Coins can go negative: the point is pressure,
    /// not an affordability check that turns a placement into a dead end.
    public var coinsPerPlacement: Int { self == .accountant ? 1 : 0 }
    public var barsNumbersEachTurn: Int { self == .handyDandy ? 2 : 0 }
    public var foulsSquaresEachTurn: Bool { self == .overPusher }
    public var greysARowEachTurn: Bool { self == .grayTheGarry }
    public var greysABoxEachTurn: Bool { self == .garryTheGray }
    public var disablesABookmarkEachTurn: Bool { self == .unluckyLucky }
    public var secondsAllowed: Double? { self == .tikTak ? 240 : nil }

    /// Needs a digit rolled alongside it.
    public var censorsARandomDigit: Bool { self == .censor }

    /// Effects that fire during scoring. The Censor and The Mirror zero their
    /// event outright, which §14 says wins regardless of what else contributed.
    public func apply(to result: inout EffectResult, context: EffectContext, censoredDigit: Digit?) {
        switch self {
        case .censor:
            if let censored = censoredDigit, context.digit == censored { result.zeroed = true }
        case .mirror:
            // Line Clear bonuses score 0; the Full Clear is unaffected.
            if context.event == .lineClear { result.zeroed = true }
        case .sashimi:
            // KAN-47 applies this after the Turn's held multipliers are known.
            break
        default:
            break
        }
    }

    /// Rolled off the boss stream, so drawing numbers or rerolling the Shop can
    /// never change which modifier appears (§15).
    public static func roll(_ rng: inout RandomStream, level: Int = 1) -> BossModifier {
        let pool = level == 9 ? finalBosses : regularBosses
        return pool[rng.int(pool.count)]
    }
    public static func rollCensoredDigit(_ rng: inout RandomStream) -> Digit {
        Digit.all[rng.int(9)]
    }
}
