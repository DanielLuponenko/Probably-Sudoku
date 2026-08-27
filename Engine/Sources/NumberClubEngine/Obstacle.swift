import Foundation

/// How hard the Book is made to play, chosen alongside it when it is opened.
///
/// Separate from the Book's own difficulty ladder (§2, which is undecided):
/// this does not change the boards or the targets, it changes what you have to
/// work with. Both dials can move independently, which is the point of keeping
/// them apart.
public enum Obstacle: Int, Codable, CaseIterable, Sendable {
    case none = 1
    case shortHanded = 2
    case shortHandedAndBlocked = 3
    case smallerHand = 4
    case smallerHandAndBlocked = 5
    case doubleBlocked = 6
    case shortDeadline = 7
    case noTosses = 8
    case finalEdition = 9

    public var name: String {
        switch self {
        case .none: return "Obstacle I"
        case .shortHanded: return "Obstacle II"
        case .shortHandedAndBlocked: return "Obstacle III"
        case .smallerHand: return "Obstacle IV"
        case .smallerHandAndBlocked: return "Obstacle V"
        case .doubleBlocked: return "Obstacle VI"
        case .shortDeadline: return "Obstacle VII"
        case .noTosses: return "Obstacle VIII"
        case .finalEdition: return "Obstacle IX"
        }
    }

    public var text: String {
        switch self {
        case .none:
            return "No obstacles."
        case .shortHanded:
            return "One fewer number in hand."
        case .shortHandedAndBlocked:
            return "One fewer in hand, one blocked each Turn."
        case .smallerHand:
            return "Two fewer in hand, one blocked each Turn."
        case .smallerHandAndBlocked:
            return "Two fewer in hand, two blocked each Turn."
        case .doubleBlocked:
            return "Two fewer in hand, two blocked, one fewer Turn."
        case .shortDeadline:
            return "Two fewer in hand, two blocked, one fewer Turn, no Tosses."
        case .noTosses:
            return "Two fewer in hand, three blocked, one fewer Turn, no Tosses."
        case .finalEdition:
            return "Three fewer in hand, three blocked, one fewer Turn, no Tosses."
        }
    }

    /// Applied to the Hand for the whole Book.
    public var handSizeDelta: Int {
        switch self {
        case .none: return 0
        case .shortHanded, .shortHandedAndBlocked: return -1
        case .smallerHand, .smallerHandAndBlocked, .doubleBlocked,
             .shortDeadline, .noTosses: return -2
        case .finalEdition: return -3
        }
    }

    /// Numbers barred from placement each Turn. They stay in the Hand, so the
    /// player can still see them (and Toss them when Tosses are allowed).
    public var blockedNumbersEachTurn: Int {
        switch self {
        case .none, .shortHanded: return 0
        case .shortHandedAndBlocked, .smallerHand: return 1
        case .smallerHandAndBlocked, .doubleBlocked, .shortDeadline: return 2
        case .noTosses, .finalEdition: return 3
        }
    }

    /// Obstacles VI–IX shorten the Puzzle deadline by one Turn.
    public var turnsDelta: Int {
        switch self {
        case .doubleBlocked, .shortDeadline, .noTosses, .finalEdition: return -1
        default: return 0
        }
    }

    /// Obstacles VII–IX remove the safety valve completely, even if an
    /// item would otherwise grant extra Tosses.
    public var removesTosses: Bool {
        switch self {
        case .shortDeadline, .noTosses, .finalEdition: return true
        default: return false
        }
    }
}
