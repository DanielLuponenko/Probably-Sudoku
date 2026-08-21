import Foundation

public enum ClippingError: Error, Equatable, Sendable {
    case cannotSkip
}

/// A small, run-scoped reward for declining a non-Boss Puzzle. Clippings are
/// derived from the Book seed and position, so inspecting an offer never
/// perturbs board, Shop, or Boss randomness.
public enum Clipping: String, Codable, CaseIterable, Sendable, Identifiable, Equatable {
    case coupon
    case overprint
    case circulation

    public var id: String { rawValue }

    public var name: String {
        switch self {
        case .coupon: "Coupon"
        case .overprint: "Overprint"
        case .circulation: "Circulation"
        }
    }

    public var detail: String {
        switch self {
        case .coupon: "+8 coins now"
        case .overprint: "+1 multiplier on the next Puzzle"
        case .circulation: "+5 interest cap for this Book"
        }
    }

    static func offer(seed: String, level: Int, slot: PuzzleSlot) -> Clipping {
        var stream = RandomStream(seed: seed, stream: "clipping.\(level).\(slot.rawValue)")
        return Self.allCases[stream.int(Self.allCases.count)]
    }
}
