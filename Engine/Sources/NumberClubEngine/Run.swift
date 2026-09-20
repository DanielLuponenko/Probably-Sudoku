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
    /// Monotonic within this Book, without consuming any gameplay RNG.
    public internal(set) var shopVisitCount: Int = 0

    public var bookmarks: [OwnedBookmark] = []
    public var markers: [OwnedMarker] = []
    public var buffs: [OwnedBuff] = []
    /// Only new Buff rewards appear here. Earlier Clippings are never converted.
    public internal(set) var skipHistory: [SkipRecord] = []
    /// Expensive Book-wide upgrades. Deliberately separate from held slots.
    public var subscriptions: [OwnedSubscription] = []

    /// Run-scoped scaling state, e.g. Syndication's accumulated wins. Reset
    /// only at a new Book.
    public var runItemState: [String: Double] = [:]
    /// Exact consumed source for effects that outlive their Puzzle (Bird Seed).
    public var activeBuffSources: [String: UUID] = [:]
    public var markerState = MarkerRunState()
    public var bookmarkState = BookmarkRunState()
    public var buffState = BuffRunState()
    public var pendingItemDecisions: [ItemDecision] = []
    public var itemSerial: Int = 0
    public var itemRandom: RandomStream?
    /// Historical skip offers retain their frozen catalogue; new Books use v2.
    public var catalogueVersion: Int = 2
    /// Missing in older saves: preserve their frozen encounter pools.
    public var bossRosterVersion: Int = 2
    /// Announced encounters, persisted so navigation cannot reroll variety.
    public var bossEncounterHistory: [BossModifier] = []

    public var puzzle: PuzzleState?
    public var shop: ShopState?
    /// Chosen when the run enters a Level, then consumed by its Boss Puzzle.
    /// The announced encounter and played encounter are one persisted decision.
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
        self.ensurePendingBoss()
    }

    private enum CodingKeys: String, CodingKey {
        // Older save keys not listed here are ignored automatically. The
        // selected Book now owns its benefit.
        case seed, streams, book, obstacle, level, slot, coins
        case bookmarks, markers, buffs, subscriptions, runItemState, puzzle, shop, pendingBoss, outcome
        case bestPuzzleScore, shopVisitCount, skipHistory, activeBuffSources
        case markerState, bookmarkState, buffState, pendingItemDecisions, itemSerial, itemRandom, catalogueVersion, bossRosterVersion, bossEncounterHistory
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
        let decodedBookmarks = try c.decodeIfPresent([OwnedBookmark].self, forKey: .bookmarks) ?? []
        bookmarks = decodedBookmarks.enumerated().map { index, bookmark in
            guard bookmark.needsIdentityMigration else { return bookmark }
            return OwnedBookmark(defID: bookmark.defID, boughtAtLevel: bookmark.boughtAtLevel,
                                 pricePaid: bookmark.pricePaid, boughtInShopVisitID: bookmark.boughtInShopVisitID,
                                 id: SkipOffer.stableIdentity(seed: seed,
                                    domain: "bookmark.legacy.v1.\(index).\(bookmark.defID).\(bookmark.boughtAtLevel).\(bookmark.pricePaid).\(bookmark.boughtInShopVisitID ?? -1)"))
        }
        markers = try c.decodeIfPresent([OwnedMarker].self, forKey: .markers) ?? []
        let decodedBuffs = try c.decodeIfPresent([OwnedBuff].self, forKey: .buffs) ?? []
        buffs = decodedBuffs.enumerated().map { index, buff in
            guard buff.needsIdentityMigration else { return buff }
            return OwnedBuff(defID: buff.defID, pricePaid: buff.pricePaid,
                             boughtInShopVisitID: buff.boughtInShopVisitID,
                             id: SkipOffer.stableIdentity(seed: seed,
                                domain: "buff.legacy.v1.\(index).\(buff.defID).\(buff.pricePaid).\(buff.boughtInShopVisitID ?? -1)"))
        }
        skipHistory = try c.decodeIfPresent([SkipRecord].self, forKey: .skipHistory) ?? []
        subscriptions = try c.decodeIfPresent([OwnedSubscription].self, forKey: .subscriptions) ?? []
        runItemState = try c.decodeIfPresent([String: Double].self, forKey: .runItemState) ?? [:]
        activeBuffSources = try c.decodeIfPresent([String: UUID].self, forKey: .activeBuffSources) ?? [:]
        markerState = try c.decodeIfPresent(MarkerRunState.self, forKey: .markerState) ?? .init()
        bookmarkState = try c.decodeIfPresent(BookmarkRunState.self, forKey: .bookmarkState) ?? .init()
        buffState = try c.decodeIfPresent(BuffRunState.self, forKey: .buffState) ?? .init()
        pendingItemDecisions = try c.decodeIfPresent([ItemDecision].self, forKey: .pendingItemDecisions) ?? []
        itemSerial = try c.decodeIfPresent(Int.self, forKey: .itemSerial) ?? 0
        itemRandom = try c.decodeIfPresent(RandomStream.self, forKey: .itemRandom)
        catalogueVersion = try c.decodeIfPresent(Int.self, forKey: .catalogueVersion) ?? 1
        bossRosterVersion = try c.decodeIfPresent(Int.self, forKey: .bossRosterVersion) ?? 1
        bossEncounterHistory = try c.decodeIfPresent([BossModifier].self, forKey: .bossEncounterHistory) ?? []
        puzzle = try c.decodeIfPresent(PuzzleState.self, forKey: .puzzle)
        shop = try c.decodeIfPresent(ShopState.self, forKey: .shop)
        // Missing provenance remains unknown. Recover the high-water mark
        // from known identities too, so a partial migration cannot reuse one.
        let knownVisits = bookmarks.compactMap(\.boughtInShopVisitID)
            + buffs.compactMap(\.boughtInShopVisitID)
            + [shop?.visitID ?? 0, try c.decodeIfPresent(Int.self, forKey: .shopVisitCount) ?? 0]
        shopVisitCount = max(0, knownVisits.max() ?? 0)
        pendingBoss = try c.decodeIfPresent(BossModifier.self, forKey: .pendingBoss)
        outcome = try c.decodeIfPresent(RunOutcome.self, forKey: .outcome)
        if outcome == nil { puzzle?.repairUntouchedOpeningBars() }
        finishBookIfCashedOut()
        // Fill a missing announcement only at an undealt briefing. A stored
        // announcement/active Puzzle keeps its Boss and a Shop consumes no roll.
        if puzzle == nil, shop == nil, outcome == nil {
            ensurePendingBoss()
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
        try c.encode(shopVisitCount, forKey: .shopVisitCount)
        try c.encode(bookmarks, forKey: .bookmarks)
        try c.encode(markers, forKey: .markers)
        try c.encode(buffs, forKey: .buffs)
        try c.encode(skipHistory, forKey: .skipHistory)
        try c.encode(subscriptions, forKey: .subscriptions)
        try c.encode(runItemState, forKey: .runItemState)
        try c.encode(activeBuffSources, forKey: .activeBuffSources)
        try c.encode(markerState, forKey: .markerState)
        try c.encode(bookmarkState, forKey: .bookmarkState)
        try c.encode(buffState, forKey: .buffState)
        try c.encode(pendingItemDecisions, forKey: .pendingItemDecisions)
        try c.encode(itemSerial, forKey: .itemSerial)
        try c.encodeIfPresent(itemRandom, forKey: .itemRandom)
        try c.encode(catalogueVersion, forKey: .catalogueVersion)
        try c.encode(bossRosterVersion, forKey: .bossRosterVersion)
        try c.encode(bossEncounterHistory, forKey: .bossEncounterHistory)
        try c.encodeIfPresent(puzzle, forKey: .puzzle)
        try c.encodeIfPresent(shop, forKey: .shop)
        try c.encodeIfPresent(pendingBoss, forKey: .pendingBoss)
        try c.encodeIfPresent(outcome, forKey: .outcome)
    }

    // MARK: - Ownership queries

    mutating func nextShopVisitID() -> Int {
        shopVisitCount += 1
        return shopVisitCount
    }

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
        if BookmarkMechanics.owns( Bookmarks.helpWanted, run: self) { size += 1 }
        if owns(subscription: Subscriptions.homeDelivery) { size += 1 }
        size += boss?.handSizeDelta ?? 0
        size += obstacle.handSizeDelta
        size += puzzle?.buffState.handSizeBonus ?? 0
        return max(1, size)
    }

    /// The Deadline replaces the base 10 with 8; Late City Final still adds its
    /// Turn on top of whichever base applies.
    public func effectiveTurns(boss: BossModifier?) -> Int {
        if boss == .lastEdition { return 1 }
        var turns = boss?.turnsOverride ?? Baseline.turns
        turns += book.benefit.turnsDelta
        if BookmarkMechanics.owns( Bookmarks.lateCityFinal, run: self) { turns += 1 }
        if owns(subscription: Subscriptions.weekendEdition) { turns += 1 }
        turns += obstacle.turnsDelta
        if boss == .pageCutter { turns += 4 }
        return max(1, turns)
    }

    public func effectiveClues(boss: BossModifier?) -> Int {
        if boss?.disablesClues == true { return 0 }
        var clues = Baseline.clues
        clues += book.benefit.clueDelta
        if BookmarkMechanics.owns( Bookmarks.puzzleCorner, run: self) { clues += 1 }
        return clues
    }

    /// Per Puzzle. The Erratum removes it entirely; Weather Forecast adds two.
    public func effectiveTossAllowance(boss: BossModifier?) -> Int {
        if boss?.forcesTossAllowanceToZero == true || obstacle.removesTosses { return 0 }
        return Baseline.tossAllowance
            + book.benefit.tossDelta
            + (BookmarkMechanics.owns(Bookmarks.weatherForecast, run: self) ? 2 : 0)
            + (owns(subscription: Subscriptions.wireService) ? 2 : 0)
    }

    public var interestCap: Int {
        let bookmarkCap = BookmarkMechanics.owns(Bookmarks.marketWrap, run: self) ? 15 : Baseline.interestCap
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
    public var currentSkipOffer: SkipOffer? {
        guard (1...9).contains(level), slot != .boss, puzzle == nil, shop == nil, outcome == nil,
              runItemState["clipping.taken.\(level).\(slot.rawValue)"] == nil,
              !skipHistory.contains(where: { $0.level == level && $0.slot == slot }) else {
            return nil
        }
        return SkipOffer.offer(seed: seed, level: level, slot: slot, version: catalogueVersion)
    }

    public var skipsUsed: Int {
        Set(runItemState.keys.filter { $0.hasPrefix("clipping.taken.") }
            + skipHistory.map { "clipping.taken.\($0.level).\($0.slot.rawValue)" }).count
    }

    public var takenClippings: [Clipping] {
        (1...9).flatMap { level in
            [PuzzleSlot.easy, .medium].compactMap { slot in
                runItemState["clipping.taken.\(level).\(slot.rawValue)"] == nil
                    ? nil : Clipping.offer(seed: seed, level: level, slot: slot)
            }
        }
    }

    // MARK: - Economy (§8)

    public struct Payout: Codable, Sendable, Equatable {
        public var base = 0
        /// One coin for each Turn left when the Puzzle is banked.
        public var unusedTurns = 0
        public var keepFillingBank = 0
        public var interest = 0
        /// The Collector's exact withheld amount, retained with the receipt.
        /// This is descriptive only and never contributes to the payout.
        public var suppressedInterest = 0
        public var paperRoute = 0
        public var earlyDeadline = 0
        public var stipend = 0
        public var total: Int { base + unusedTurns + keepFillingBank + interest + paperRoute + earlyDeadline + stipend }
        public init() {}
        private enum CodingKeys: String, CodingKey { case base, unusedTurns, keepFillingBank, interest, suppressedInterest, paperRoute, earlyDeadline, stipend }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            base = try c.decodeIfPresent(Int.self, forKey: .base) ?? 0
            unusedTurns = try c.decodeIfPresent(Int.self, forKey: .unusedTurns) ?? 0
            keepFillingBank = try c.decodeIfPresent(Int.self, forKey: .keepFillingBank) ?? 0
            interest = try c.decodeIfPresent(Int.self, forKey: .interest) ?? 0
            suppressedInterest = try c.decodeIfPresent(Int.self, forKey: .suppressedInterest) ?? 0
            paperRoute = try c.decodeIfPresent(Int.self, forKey: .paperRoute) ?? 0
            earlyDeadline = try c.decodeIfPresent(Int.self, forKey: .earlyDeadline) ?? 0
            stipend = try c.decodeIfPresent(Int.self, forKey: .stipend) ?? 0
        }
    }

    public func payout(for puzzle: PuzzleState) -> Payout {
        var p = Payout()
        p.base = 5 + book.benefit.winCoinsDelta
        p.unusedTurns = puzzle.turnsRemaining
        p.keepFillingBank = puzzle.keepFillingCoins
        // Accountant debt cannot create negative interest, including in the
        // Collector's crossed-out receipt. Save the exact withheld amount.
        let ordinaryInterest = max(0, min(interestCap + puzzle.markerState.interestCapIncrease, coins / 10))
        if puzzle.boss?.cancelsInterest == true { p.suppressedInterest = ordinaryInterest }
        else { p.interest = ordinaryInterest }
        if BookmarkMechanics.owns( Bookmarks.paperRoute, run: self, puzzle: puzzle) { p.paperRoute = 2 }
        p.earlyDeadline = BookmarkMechanics.earlyDeadlineCoins(run: self, puzzle: puzzle)
        p.stipend = MarkerRuntime.stipendPayout(puzzle: puzzle)
        return p
    }

    /// §8 — selling refunds half of what you paid, rounded down, minimum 1.
    public static func sellValue(pricePaid: Int) -> Int { max(1, pricePaid / 2) }

    /// §8 — moving an already-placed Marker square.
    public static let moveSquareCost = 2

    // MARK: - Progression

    public var isBossPuzzle: Bool { slot == .boss }
    public var isFinalPuzzle: Bool { level == 9 && slot == .boss }
    public var target: Int { book.target(level: level, slot: slot) }

    /// The final board is kept for the closing page. Old versions discarded it
    /// when opening the final Shop; that saved Shop is already paid, never an
    /// invitation to pay again. No score, coins, or RNG state are changed here.
    mutating func finishBookIfCashedOut() {
        guard isFinalPuzzle, outcome != .failed else { return }
        guard outcome == .bookCompleted || puzzle?.phase == .cashedOut
                || (puzzle == nil && shop != nil) else { return }
        outcome = .bookCompleted
        shop = nil
        pendingBoss = nil
    }

    /// A saved announcement is never reselected after roster changes. Only
    /// an absent announcement rolls from this Book’s persisted roster version.
    mutating func ensurePendingBoss() {
        // Announcements are promises. Even a retired or out-of-tier saved
        // encounter remains playable; only a genuinely missing choice rolls.
        guard pendingBoss == nil else { return }
        pendingBoss = BossEligibility.roll(run: &self)
    }

    /// Advances to the next Puzzle, rolling over into the next Level. Returns
    /// false when the Book is finished (beating the Level 9 Boss).
    public mutating func advance() -> Bool {
        guard outcome == nil else { return false }
        switch slot {
        case .easy:
            slot = .medium
            ensurePendingBoss()
        case .medium:
            slot = .boss
            ensurePendingBoss()
        case .boss:
            if level >= 9 {
                outcome = .bookCompleted
                return false
            }
            level += 1
            slot = .easy
            // Reveal the following level's real Boss on its new run plan.
            pendingBoss = BossEligibility.roll(run: &self)
            grantPendingMarkerSquares()
        }
        return true
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
