import Foundation

/// §13 — one is rolled for every Boss Puzzle. Each attacks a different
/// resource, so no single build answers all of them.
public enum BossModifier: String, Codable, CaseIterable, Sendable {
    case censor, editor, deadline, fog, critic, mirror, paywall, erratum, collector
    case heavyLifter, unluckyLucky, buffborger, sashimi, overPusher
    case accountant, tikTak, handyDandy, grayTheGarry, garryTheGray

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
        case .heavyLifter: return "Heavy Lifter"
        case .unluckyLucky: return "Unlucky Lucky"
        case .buffborger: return "Big Buffborger Jr"
        case .sashimi: return "Sashimi"
        case .overPusher: return "Over Pusher"
        case .accountant: return "Natural Born Accountant"
        case .tikTak: return "Tik Tak"
        case .handyDandy: return "Handy Dandy"
        case .grayTheGarry: return "Gray the Garry"
        case .garryTheGray: return "Garry the Gray"
        }
    }

    public var text: String {
        switch self {
        case .censor: return "One random number scores 0 points this Puzzle"
        case .editor: return "Hand size -1"
        case .deadline: return "8 Turns instead of 10"
        case .fog: return "Marked squares are hidden this Puzzle"
        case .critic: return "Wrong-placement penalty doubled"
        case .mirror: return "Line Clear bonuses score 0"
        case .paywall: return "All Clues disabled, including Buff-granted"
        case .erratum: return "Toss allowance 0"
        case .collector: return "This Puzzle's payout includes no interest"
        case .heavyLifter: return "The target is four times what it would be"
        case .unluckyLucky: return "One Bookmark sleeps each Turn"
        case .buffborger: return "No Buff can be spent this Puzzle"
        case .sashimi: return "All score multipliers are cut in half"
        case .overPusher: return "Three squares are fouled each Turn, and clear two Turns later"
        case .accountant: return "Every placement costs a coin, even if you have none"
        case .tikTak: return "Three minutes for the whole Puzzle"
        case .handyDandy: return "Two numbers in your Hand are barred each Turn"
        case .grayTheGarry: return "A row is greyed out each Turn and cannot be written in"
        case .garryTheGray: return "A box is greyed out each Turn and cannot be written in"
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
        }
    }

    // MARK: Standing modifiers, applied when the Puzzle is created

    public var handSizeDelta: Int { self == .editor ? -1 : 0 }
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
    public var secondsAllowed: Double? { self == .tikTak ? 180 : nil }

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
    public static func roll(_ rng: inout RandomStream) -> BossModifier {
        allCases[rng.int(allCases.count)]
    }
    public static func rollCensoredDigit(_ rng: inout RandomStream) -> Digit {
        Digit.all[rng.int(9)]
    }
}
