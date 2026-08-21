import Foundation

/// §3 — chosen once, at the start of a Book.
public enum StartingBoard: String, Codable, CaseIterable, Sendable {
    case scholar, merchant, oracle

    public var name: String {
        switch self {
        case .scholar: return "Scholar's Board"
        case .merchant: return "Merchant's Board"
        case .oracle: return "Oracle's Board"
        }
    }
    public var text: String {
        switch self {
        case .scholar: return "Hand size 7 for the whole Book"
        case .merchant: return "Start with 15 coins"
        case .oracle: return "1 Clue every Puzzle"
        }
    }
}

public enum Baseline {
    public static let handSize = 6
    public static let coins = 5
    public static let turns = 10
    public static let clues = 0
    /// §5.1, revised: the allowance is **per Puzzle**, not per Turn. Per Turn
    /// it was effectively unlimited over ten Turns, so it cost tempo but never
    /// forced a decision. Four for a whole Puzzle makes each one a choice.
    public static let tossAllowance = 4
    public static let interestCap = 10
}

public enum RunOutcome: String, Codable, Sendable {
    case bookCompleted, failed
}

/// A whole attempt at a Sudoku Book: 9 Levels of 3 Puzzles.
public struct RunState: Codable, Sendable {
    public let seed: String
    public var streams: SeedStreams
    public let startingBoard: StartingBoard
    /// Chosen with the Book, and fixed for the whole run.
    public let obstacle: Obstacle

    public var level: Int
    public var slot: PuzzleSlot
    public var coins: Int

    public var bookmarks: [OwnedBookmark] = []
    public var markers: [OwnedMarker] = []
    public var buffs: [OwnedBuff] = []
    /// Expensive Book-wide upgrades. Deliberately separate from held slots.
    public var subscriptions: [OwnedSubscription] = []

    /// Run-scoped scaling state, e.g. Syndication's accumulated wins. Reset
    /// only at a new Book.
    public var runItemState: [String: Double] = [:]

    public var puzzle: PuzzleState?
    public var shop: ShopState?
    public var outcome: RunOutcome?

    public init(seed: String, startingBoard: StartingBoard, obstacle: Obstacle = .none) {
        self.seed = seed
        self.streams = SeedStreams(seed: seed)
        self.startingBoard = startingBoard
        self.obstacle = obstacle
        self.level = 1
        self.slot = .easy
        self.coins = startingBoard == .merchant ? 15 : Baseline.coins
    }

    private enum CodingKeys: String, CodingKey {
        case seed, streams, startingBoard, obstacle, level, slot, coins
        case bookmarks, markers, buffs, subscriptions, runItemState, puzzle, shop, outcome
    }

    /// Subscriptions arrived after saved Books existed. Decode their absence as
    /// an empty collection so a new app never discards an otherwise valid run.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seed = try c.decode(String.self, forKey: .seed)
        streams = try c.decode(SeedStreams.self, forKey: .streams)
        startingBoard = try c.decode(StartingBoard.self, forKey: .startingBoard)
        obstacle = try c.decodeIfPresent(Obstacle.self, forKey: .obstacle) ?? .none
        level = try c.decode(Int.self, forKey: .level)
        slot = try c.decode(PuzzleSlot.self, forKey: .slot)
        coins = try c.decode(Int.self, forKey: .coins)
        bookmarks = try c.decodeIfPresent([OwnedBookmark].self, forKey: .bookmarks) ?? []
        markers = try c.decodeIfPresent([OwnedMarker].self, forKey: .markers) ?? []
        buffs = try c.decodeIfPresent([OwnedBuff].self, forKey: .buffs) ?? []
        subscriptions = try c.decodeIfPresent([OwnedSubscription].self, forKey: .subscriptions) ?? []
        runItemState = try c.decodeIfPresent([String: Double].self, forKey: .runItemState) ?? [:]
        puzzle = try c.decodeIfPresent(PuzzleState.self, forKey: .puzzle)
        shop = try c.decodeIfPresent(ShopState.self, forKey: .shop)
        outcome = try c.decodeIfPresent(RunOutcome.self, forKey: .outcome)
    }

    // MARK: - Ownership queries

    public func owns(bookmark id: String) -> Bool { bookmarks.contains { $0.defID == id } }
    public func owns(marker id: String) -> Bool { markers.contains { $0.defID == id } }
    public func owns(subscription id: String) -> Bool { subscriptions.contains { $0.defID == id } }

    /// Markers whose squares include `square` — what a placement there triggers.
    public func markers(covering square: Square) -> [OwnedMarker] {
        markers.filter { $0.covers(square) }
    }
    /// Every square any Marker owns, for the grid to colour.
    public var markedSquares: [Square: OwnedMarker] {
        var out: [Square: OwnedMarker] = [:]
        for marker in markers {
            for square in marker.squares { out[square] = marker }
        }
        return out
    }
    /// Two Markers may never share a square (§11).
    public func squareIsFree(_ square: Square) -> Bool {
        !markers.contains { $0.covers(square) }
    }

    // MARK: - Standing modifiers
    // Bookmarks that are not event hooks but change the Puzzle's starting shape.

    public func effectiveHandSize(boss: BossModifier?) -> Int {
        var size = Baseline.handSize
        if startingBoard == .scholar { size += 1 }
        if owns(bookmark: Bookmarks.helpWanted) { size += 1 }
        if owns(subscription: Subscriptions.homeDelivery) { size += 1 }
        size += boss?.handSizeDelta ?? 0
        size += obstacle.handSizeDelta
        return max(1, size)
    }

    /// The Deadline replaces the base 10 with 8; Late City Final still adds its
    /// Turn on top of whichever base applies.
    public func effectiveTurns(boss: BossModifier?) -> Int {
        var turns = boss?.turnsOverride ?? Baseline.turns
        if owns(bookmark: Bookmarks.lateCityFinal) { turns += 1 }
        if owns(subscription: Subscriptions.weekendEdition) { turns += 1 }
        return max(1, turns)
    }

    public func effectiveClues(boss: BossModifier?) -> Int {
        if boss?.disablesClues == true { return 0 }
        var clues = Baseline.clues
        if startingBoard == .oracle { clues += 1 }
        if owns(bookmark: Bookmarks.puzzleCorner) { clues += 1 }
        return clues
    }

    /// Per Puzzle. The Erratum removes it entirely; Weather Forecast adds two.
    public func effectiveTossAllowance(boss: BossModifier?) -> Int {
        if boss?.forcesTossAllowanceToZero == true { return 0 }
        return Baseline.tossAllowance
            + (owns(bookmark: Bookmarks.weatherForecast) ? 2 : 0)
            + (owns(subscription: Subscriptions.wireService) ? 2 : 0)
    }

    public var interestCap: Int {
        let bookmarkCap = owns(bookmark: Bookmarks.marketWrap) ? 15 : Baseline.interestCap
        let subscriptionCap = owns(subscription: Subscriptions.annualRate) ? 20 : bookmarkCap
        return subscriptionCap + Int(runItemState["clipping.circulation"] ?? 0)
    }

    public var markerCapacity: Int {
        ItemKind.marker.capacity + (owns(subscription: Subscriptions.overseasEdition) ? 1 : 0)
    }

    /// The offer is pure from the Book seed and position. It can therefore be
    /// read by the pre-Puzzle page as often as needed without shifting any
    /// gameplay RNG stream.
    public var currentClipping: Clipping? {
        guard slot != .boss, skipsRemaining > 0, puzzle == nil, shop == nil, outcome == nil else {
            return nil
        }
        return Clipping.offer(seed: seed, level: level, slot: slot)
    }

    public var skipsUsed: Int {
        runItemState.keys.filter { $0.hasPrefix("clipping.taken.") }.count
    }

    public var skipsRemaining: Int { max(0, 2 - skipsUsed) }

    public var takenClippings: [Clipping] {
        (1...9).flatMap { level in
            [PuzzleSlot.easy, .medium].compactMap { slot in
                runItemState["clipping.taken.\(level).\(slot.rawValue)"] == nil
                    ? nil : Clipping.offer(seed: seed, level: level, slot: slot)
            }
        }
    }

    // MARK: - Economy (§8)

    public struct Payout: Sendable, Equatable {
        public var base = 0
        public var unusedTurns = 0
        public var keepFillingBank = 0
        public var interest = 0
        public var paperRoute = 0
        public var total: Int { base + unusedTurns + keepFillingBank + interest + paperRoute }
    }

    public func payout(for puzzle: PuzzleState) -> Payout {
        var p = Payout()
        p.base = 5
        p.unusedTurns = min(3, max(0, puzzle.turnsMax - puzzle.turnNumber + 1))
        p.keepFillingBank = puzzle.keepFillingCoins
        if puzzle.boss?.cancelsInterest != true {
            p.interest = min(interestCap, coins / 10)
        }
        if owns(bookmark: Bookmarks.paperRoute) { p.paperRoute = 2 }
        return p
    }

    /// §8 — selling refunds half of what you paid, rounded down, minimum 1.
    public static func sellValue(pricePaid: Int) -> Int { max(1, pricePaid / 2) }

    /// §8 — moving an already-placed Marker square.
    public static let moveSquareCost = 2

    // MARK: - Progression

    public var isBossPuzzle: Bool { slot == .boss }
    public var target: Int { Targets.target(level: level, slot: slot) }

    /// Advances to the next Puzzle, rolling over into the next Level. Returns
    /// false when the Book is finished (beating the Level 9 Boss).
    public mutating func advance() -> Bool {
        switch slot {
        case .easy: slot = .medium
        case .medium: slot = .boss
        case .boss:
            if level >= 9 {
                outcome = .bookCompleted
                return false
            }
            level += 1
            slot = .easy
            grantPendingMarkerSquares()
        }
        return true
    }

    mutating func takeCurrentClipping() throws -> Clipping {
        guard let clipping = currentClipping else { throw ClippingError.cannotSkip }
        runItemState["clipping.taken.\(level).\(slot.rawValue)"] = 1
        switch clipping {
        case .coupon:
            coins += 8
        case .overprint:
            runItemState["clipping.overprint"] = (runItemState["clipping.overprint"] ?? 0) + 1
        case .circulation:
            runItemState["clipping.circulation"] = (runItemState["clipping.circulation"] ?? 0) + 5
        }
        return clipping
    }

    /// §11 — each Marker gains one more square per Level completed while owned.
    /// The square itself is chosen by the player in the Shop; this only records
    /// the entitlement.
    private mutating func grantPendingMarkerSquares() {
        // Entitlement is derived from `level` and `boughtAtLevel`, so there is
        // nothing to store — `pendingSquares(atLevel:)` reports the new debt.
    }

    /// Total squares the player still has to choose before play can continue.
    public func pendingMarkerSquares() -> Int {
        markers.reduce(0) { $0 + $1.pendingSquares(atLevel: level) }
    }
}
