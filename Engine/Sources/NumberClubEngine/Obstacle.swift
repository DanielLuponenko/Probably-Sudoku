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

    public var name: String {
        switch self {
        case .none: return "Obstacle I"
        case .shortHanded: return "Obstacle II"
        case .shortHandedAndBlocked: return "Obstacle III"
        }
    }

    public var text: String {
        switch self {
        case .none:
            return "No obstacles."
        case .shortHanded:
            return "One fewer number in hand."
        case .shortHandedAndBlocked:
            return "One fewer number in hand, and one number blocked each Turn."
        }
    }

    /// Applied to the Hand for the whole Book.
    public var handSizeDelta: Int {
        switch self {
        case .none: return 0
        case .shortHanded, .shortHandedAndBlocked: return -1
        }
    }

    /// One number is barred from being played each Turn. It stays in the Hand
    /// — you can see it, and you can still Toss it — you simply cannot put it
    /// on the board until the Turn is over.
    public var blocksANumberEachTurn: Bool {
        self == .shortHandedAndBlocked
    }
}
