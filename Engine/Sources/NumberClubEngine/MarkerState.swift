import Foundation

/// A claimed position has its own identity. Rebind/Transposition move this
/// record, including earned history, rather than creating a fresh trigger.
public struct MarkerClaim: Codable, Sendable, Equatable, Identifiable {
    public var id: String
    public var markerID: String
    public var square: Square
    public var patinaSuccesses: Int = 0
    public var lastTriggeredPuzzle: String?
    public var lastGrowthPuzzle: String?

    public init(id: String, markerID: String, square: Square) {
        self.id = id; self.markerID = markerID; self.square = square
    }
}

/// Source provenance survives a contract's later payout on another square.
public struct MarkerSource: Codable, Sendable, Equatable {
    public var markerID: String
    public var claimID: String
    public var square: Square

    public init(markerID: String, claimID: String, square: Square) {
        self.markerID = markerID; self.claimID = claimID; self.square = square
    }
}

public struct MarkerRunState: Codable, Sendable, Equatable {
    public var claims: [MarkerClaim] = []
    public var nextClaimSerial: Int = 0
    public var escapementProgress: Int = 0
    /// Sorted raw digits, never a Set whose encoding order could change CAS.
    public var collectionDigits: [Digit] = []
    public var pendingVoucherCoins: Int = 0
    public var shopVoucherCoins: Int = 0
    public var voucherShopVisit: Int?

    public init() {}
}

public struct MarkerRoute: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var nextBox: Int?
    public init(source: MarkerSource) { self.source = source }
}

public struct MarkerLadder: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var lastDigit: Digit
    public var steps: Int = 0
    public init(source: MarkerSource, digit: Digit) { self.source = source; lastDigit = digit }
}

public struct MarkerDigitPromise: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var digit: Digit
    public var uses: Int
    public init(source: MarkerSource, digit: Digit, uses: Int) {
        self.source = source; self.digit = digit; self.uses = uses
    }
}

public struct MarkerUses: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var remaining: Int
    public init(source: MarkerSource, remaining: Int) { self.source = source; self.remaining = remaining }
}

public struct MarkerCardChallenge: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var remainingCardIDs: [UUID]
    public init(source: MarkerSource, cardIDs: [UUID]) { self.source = source; remainingCardIDs = cardIDs }
}

public struct MarkerTarget: Codable, Sendable, Equatable {
    public var source: MarkerSource
    public var square: Square
    public init(source: MarkerSource, square: Square) { self.source = source; self.square = square }
}

public struct MarkerTurnState: Codable, Sendable, Equatable {
    public var eligibleMarkerTypes: [String] = []
    public var previousDigits: [Digit] = []
    public var streak: Int = 0
    public var umbrella: MarkerSource?
    public var route: MarkerRoute?
    public var ladder: MarkerLadder?
    public var counterweight: MarkerDigitPromise?
    public var pressmark: MarkerUses?
    public var tiebreaker: MarkerCardChallenge?
    public var bounty: MarkerTarget?
    public var forecast: MarkerSource?
    public var crosscheck: MarkerTarget?
    public var censusDigit: Digit?
    public var blotterSquare: Square?

    public init() {}
}

public enum MarkerStipend: String, Codable, Sendable, Equatable {
    case inactive, active, broken
}

public struct MarkerPuzzleState: Codable, Sendable, Equatable {
    /// Successful uses only, unless a rule explicitly limits offers/arms.
    public var counts: [String: Int] = [:]
    public var turn = MarkerTurnState()
    public var stipend: MarkerStipend = .inactive
    public var stipendSource: MarkerSource?
    public var keystone: MarkerSource?
    public var beacon: MarkerDigitPromise?
    public var finaleDigits: [Digit] = []
    public var interestCapIncrease: Int = 0
    /// Actual Pool cards held outside the Hand during a mandatory Fork choice.
    public var reservedForkCards: [Digit] = []
    /// Pledge acceptance is committed by the original deferred placement only.
    public var acceptedPledgeSquare: Square?
    public var declinedPledgeSquare: Square?
    /// Captured before a qualifying event; an active Pressmark cannot be
    /// refreshed by a source square that also spends its final prior use.
    public var pressmarkWasActiveForPlacement: Bool = false

    public init() {}
    public func count(_ markerID: String) -> Int { counts[markerID] ?? 0 }
    public mutating func increment(_ markerID: String, by amount: Int = 1) {
        counts[markerID, default: 0] += amount
    }
}
