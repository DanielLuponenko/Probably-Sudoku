import Foundation

/// §13 — one is rolled for every Boss Puzzle. Each attacks a different
/// resource, so no single build answers all of them.
public enum BossModifier: String, Codable, CaseIterable, Sendable {
    case censor, editor, deadline, fog, critic, mirror, paywall, erratum, collector

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
