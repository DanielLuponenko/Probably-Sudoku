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
    case shortHandedAndSnatched = 3

    public var name: String {
        switch self {
        case .none: return "Obstacle I"
        case .shortHanded: return "Obstacle II"
        case .shortHandedAndSnatched: return "Obstacle III"
        }
    }

    public var text: String {
        switch self {
        case .none:
            return "No obstacles."
        case .shortHanded:
            return "One fewer number in hand."
        case .shortHandedAndSnatched:
            return "One fewer number in hand, and one taken back every Turn."
        }
    }

    /// Applied to the Hand for the whole Book.
    public var handSizeDelta: Int {
        switch self {
        case .none: return 0
        case .shortHanded, .shortHandedAndSnatched: return -1
        }
    }

    /// At the end of every Turn one number is taken out of the Hand and put
    /// back in the Pool — after the refill, or topping up would undo it.
    public var snatchesANumberEachTurn: Bool {
        self == .shortHandedAndSnatched
    }
}
