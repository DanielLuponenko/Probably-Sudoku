import Foundation

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
    /// The published Book selected on the shelf, fixed for the whole run.
    public let book: Book
    /// Chosen with the Book, and fixed for the whole run.
    public let obstacle: Obstacle

    public var level: Int
    public var slot: PuzzleSlot
    public var coins: Int
    /// Kept for the completed-Book record. It is updated only when a Puzzle
    /// is banked, so an unfinished score is never presented as an achievement.
    public var bestPuzzleScore: Int

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
    /// Chosen when the run enters a Boss briefing, then consumed by the
    /// Puzzle. This makes the announced encounter and played encounter one
    /// persisted decision.
    public var pendingBoss: BossModifier?
    public var outcome: RunOutcome?

    public init(seed: String, book: Book = .probably, obstacle: Obstacle = .none) {
        self.seed = seed
        self.streams = SeedStreams(seed: seed)
        self.book = book
        self.obstacle = obstacle
        self.level = 1
        self.slot = .easy
        self.coins = book.startingCoins + book.benefit.coinsDelta
        self.bestPuzzleScore = 0
        // A Book's Boss is part of its route, not a surprise generated after
        // the second Puzzle. Rolling it here lets the briefing name the real
        // encounter and its exact power from the very first page, while the
        // stored value still guarantees that the announced Boss is the one
        // eventually played.
        self.pendingBoss = BossModifier.roll(&self.streams.boss)
    }

    private enum CodingKeys: String, CodingKey {
        // Older save keys not listed here are ignored automatically. The
        // selected Book now owns its benefit.
        case seed, streams, book, obstacle, level, slot, coins
        case bookmarks, markers, buffs, subscriptions, runItemState, puzzle, shop, pendingBoss, outcome
        case bestPuzzleScore
    }

    /// Subscriptions arrived after saved Books existed. Decode their absence as
    /// an empty collection so a new app never discards an otherwise valid run.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seed = try c.decode(String.self, forKey: .seed)
        streams = try c.decode(SeedStreams.self, forKey: .streams)
        book = try c.decodeIfPresent(Book.self, forKey: .book) ?? .probably
        obstacle = try c.decodeIfPresent(Obstacle.self, forKey: .obstacle) ?? .none
        level = try c.decode(Int.self, forKey: .level)
        slot = try c.decode(PuzzleSlot.self, forKey: .slot)
        coins = try c.decode(Int.self, forKey: .coins)
        bestPuzzleScore = try c.decodeIfPresent(Int.self, forKey: .bestPuzzleScore) ?? 0
        bookmarks = try c.decodeIfPresent([OwnedBookmark].self, forKey: .bookmarks) ?? []
        markers = try c.decodeIfPresent([OwnedMarker].self, forKey: .markers) ?? []
        buffs = try c.decodeIfPresent([OwnedBuff].self, forKey: .buffs) ?? []
        subscriptions = try c.decodeIfPresent([OwnedSubscription].self, forKey: .subscriptions) ?? []
        runItemState = try c.decodeIfPresent([String: Double].self, forKey: .runItemState) ?? [:]
        puzzle = try c.decodeIfPresent(PuzzleState.self, forKey: .puzzle)
        shop = try c.decodeIfPresent(ShopState.self, forKey: .shop)
        pendingBoss = try c.decodeIfPresent(BossModifier.self, forKey: .pendingBoss)
        outcome = try c.decodeIfPresent(RunOutcome.self, forKey: .outcome)
        // Older saves did not select a Boss until after Puzzle 2. Give an
        // idle in-progress Book a single, persisted encounter now. A running
        // Puzzle or a post-Boss Shop must not consume another boss-stream
        // value.
        if puzzle == nil, shop == nil, outcome == nil, pendingBoss == nil {
            pendingBoss = BossModifier.roll(&streams.boss)
        }
    }

    /// New saves deliberately omit the retired selection key. The custom
    /// encoder is paired with the tolerant decoder above so existing saves
    /// remain readable while every new run is represented solely by its Book.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(seed, forKey: .seed)
        try c.encode(streams, forKey: .streams)
        try c.encode(book, forKey: .book)
        try c.encode(obstacle, forKey: .obstacle)
        try c.encode(level, forKey: .level)
        try c.encode(slot, forKey: .slot)
        try c.encode(coins, forKey: .coins)
        try c.encode(bestPuzzleScore, forKey: .bestPuzzleScore)
        try c.encode(bookmarks, forKey: .bookmarks)
        try c.encode(markers, forKey: .markers)
        try c.encode(buffs, forKey: .buffs)
        try c.encode(subscriptions, forKey: .subscriptions)
        try c.encode(runItemState, forKey: .runItemState)
        try c.encodeIfPresent(puzzle, forKey: .puzzle)
        try c.encodeIfPresent(shop, forKey: .shop)
        try c.encodeIfPresent(pendingBoss, forKey: .pendingBoss)
        try c.encodeIfPresent(outcome, forKey: .outcome)
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
        size += book.benefit.handSizeDelta
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
        turns += book.benefit.turnsDelta
        if owns(bookmark: Bookmarks.lateCityFinal) { turns += 1 }
        if owns(subscription: Subscriptions.weekendEdition) { turns += 1 }
        turns += obstacle.turnsDelta
        return max(1, turns)
    }

    public func effectiveClues(boss: BossModifier?) -> Int {
        if boss?.disablesClues == true { return 0 }
        var clues = Baseline.clues
        clues += book.benefit.clueDelta
        if owns(bookmark: Bookmarks.puzzleCorner) { clues += 1 }
        return clues
    }

    /// Per Puzzle. The Erratum removes it entirely; Weather Forecast adds two.
    public func effectiveTossAllowance(boss: BossModifier?) -> Int {
        if boss?.forcesTossAllowanceToZero == true || obstacle.removesTosses { return 0 }
        return Baseline.tossAllowance
            + book.benefit.tossDelta
            + (owns(bookmark: Bookmarks.weatherForecast) ? 2 : 0)
            + (owns(subscription: Subscriptions.wireService) ? 2 : 0)
    }

    public var interestCap: Int {
        let bookmarkCap = owns(bookmark: Bookmarks.marketWrap) ? 15 : Baseline.interestCap
        let subscriptionCap = owns(subscription: Subscriptions.annualRate) ? 20 : bookmarkCap
        return subscriptionCap + book.benefit.interestCapDelta
            + Int(runItemState["clipping.circulation"] ?? 0)
    }

    public var markerCapacity: Int {
        .max
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
        /// One coin for each Turn left when the Puzzle is banked.
        public var unusedTurns = 0
        public var keepFillingBank = 0
        public var interest = 0
        public var paperRoute = 0
        public var total: Int { base + unusedTurns + keepFillingBank + interest + paperRoute }
    }

    public func payout(for puzzle: PuzzleState) -> Payout {
        var p = Payout()
        p.base = 5 + book.benefit.winCoinsDelta
        p.unusedTurns = puzzle.turnsRemaining
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
    public var target: Int { book.target(level: level, slot: slot) }

    /// Advances to the next Puzzle, rolling over into the next Level. Returns
    /// false when the Book is finished (beating the Level 9 Boss).
    public mutating func advance() -> Bool {
        switch slot {
        case .easy: slot = .medium
        case .medium:
            slot = .boss
            // New Books already carry their announced Boss. The fallback is
            // solely for legacy saves decoded before this invariant existed.
            if pendingBoss == nil {
                pendingBoss = BossModifier.roll(&streams.boss)
            }
        case .boss:
            if level >= 9 {
                outcome = .bookCompleted
                return false
            }
            level += 1
            slot = .easy
            // Reveal the following level's real Boss on its new run plan.
            pendingBoss = BossModifier.roll(&streams.boss)
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
