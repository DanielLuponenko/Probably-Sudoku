import Foundation

/// What a cosmetic changes. Each category is one slot: you own many and wear
/// one. The desk and pencil are now fixed parts of the Club room; the player
/// chooses only the three things printed on the live puzzle page.
enum CosmeticCategory: String, Codable, CaseIterable, Identifiable {
    case paper
    case board
    case numbers

    var id: String { rawValue }

    /// The counter it is sold from, printed on the drawer.
    var title: String {
        switch self {
        case .paper: return "Paper"
        case .board: return "Grid"
        case .numbers: return "Numbers"
        }
    }

    var note: String {
        switch self {
        case .paper: return "The actual stock under every page."
        case .board: return "The live rule drawn across every puzzle."
        case .numbers: return "Individual digits, set exactly as they play."
        }
    }
}

/// One thing on the shelf. A definition, not a possession — what the player
/// owns is a set of these ids, held in `PlayerProfile`.
struct CosmeticItem: Identifiable, Codable, Hashable {
    let id: String
    let category: CosmeticCategory
    let name: String
    /// What it costs in permanent currency. Zero means it is the one you start
    /// in, and it is never for sale.
    let price: Int
    let blurb: String

    var isDefault: Bool { price == 0 }
}

/// One id per active category. Never optional, so "nothing equipped" is not a
/// state the game has to draw.
///
/// Decoding is deliberately manual. Profiles written by the five-category
/// shop contain `deskID` and `markerID`; unknown keys are ignored, while a
/// profile from before any active slot existed receives that slot's default.
struct EquippedCosmetics: Codable, Equatable {
    var paperID: String
    var boardID: String
    var numberID: String

    static let starting = EquippedCosmetics(
        paperID: "pp_newsprint", boardID: "bd_printed", numberID: "nb_press")

    enum CodingKeys: String, CodingKey {
        case paperID, boardID, numberID
        // Kept in the wire envelope so a device still running the old build can
        // decode a profile written by this one. They no longer control a skin.
        case deskID, markerID
    }

    init(paperID: String, boardID: String, numberID: String) {
        self.paperID = paperID
        self.boardID = boardID
        self.numberID = numberID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        paperID = try container.decodeIfPresent(String.self, forKey: .paperID)
            ?? Self.starting.paperID
        boardID = try container.decodeIfPresent(String.self, forKey: .boardID)
            ?? Self.starting.boardID
        numberID = try container.decodeIfPresent(String.self, forKey: .numberID)
            ?? Self.starting.numberID
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(paperID, forKey: .paperID)
        try container.encode(boardID, forKey: .boardID)
        try container.encode(numberID, forKey: .numberID)
        try container.encode("dk_walnut", forKey: .deskID)
        try container.encode("pc_graphite", forKey: .markerID)
    }

    subscript(category: CosmeticCategory) -> String {
        get {
            switch category {
            case .paper: return paperID
            case .board: return boardID
            case .numbers: return numberID
            }
        }
        set {
            switch category {
            case .paper: paperID = newValue
            case .board: boardID = newValue
            case .numbers: numberID = newValue
            }
        }
    }
}

/// Everything that outlives a Book.
///
/// Its own file on disk rather than more fields on `RunStore.Progress`: that
/// struct is decoded from a file written by older builds, and a new
/// non-optional field there would throw the player's unlocks away.
struct PlayerProfile: Codable, Equatable {
    var ownedCosmeticIDs: Set<String> = CosmeticCatalog.startingOwnedIDs
    var equipped: EquippedCosmetics = .starting
    /// Every reward already paid, by event id. Kept even though
    /// `earnedRewardAmounts` now carries the amount: this set is what a
    /// pre-ledger build still round-trips correctly, so it stays both the
    /// idempotence check for `earn` and the only signal that survives an
    /// old-build re-encode.
    var rewardedCompletionIDs: Set<String> = []
    /// The amount paid for each reward event, keyed the same as
    /// `rewardedCompletionIDs`. This — never the catalog price of an owned
    /// item — is what "currency earned" sums to, so a reward's value is
    /// fixed forever at the moment it is paid.
    var earnedRewardAmounts: [String: Int] = [:]
    /// The price actually paid for each owned cosmetic, keyed by item id.
    /// Deliberately independent of `CosmeticCatalog.item(_:).price`: a later
    /// price change must never retroactively change what a past purchase
    /// cost, and an id owned through a grant or debug unlock never appears
    /// here at all.
    var purchaseAmounts: [String: Int] = [:]
    /// A gross earned figure folded in once, from a profile decoded before
    /// this ledger existed: the legacy scalar balance plus whatever paid
    /// ownership that same decode could reconstruct spend for. Untouched by
    /// ordinary play — only `init(from:)` and `merge` ever set it.
    var legacyEarnedAnchor: Int = 0
    /// The reward ids `legacyEarnedAnchor` already accounts for. An id in
    /// this set must never also be added from `earnedRewardAmounts` — that
    /// would pay the same reward twice, once as a lump sum and once as a
    /// ledger entry.
    var legacyEarnedAnchorCoverage: Set<String> = []
    /// Set as soon as the opening lesson starts, so Continue never repeats it.
    var hasStartedFirstRunTutorial = false
    /// Local-first achievement truth. Game Center is only a mirror of this
    /// set, never a prerequisite for earning an achievement.
    var earnedAchievementIDs: Set<String> = []
    var achievementProgress = AchievementProgress()
    /// General profile modification time. This is not the cosmetic decision
    /// clock because currency, inventory and achievements also advance it.
    var lastModifiedAt: Date = .distantPast
    /// Advanced only by an explicit equip choice or an accepted remote choice.
    /// Old profiles decode this as distant past and remain migration fallbacks.
    var equippedDecisionAt: Date = .distantPast

    /// The balance a player can see and spend. Computed, never stored:
    /// earning and spending only ever append ledger entries, so this number
    /// can always be recomputed the same way after any merge. Floored at
    /// zero — concurrent offline overspend is a debt the ledger itself may
    /// carry (see `ledgerBalance`), but nothing on screen, and nothing
    /// written to the old-build wire key, may show negative.
    var cosmeticCurrency: Int { max(0, ledgerBalance) }

    /// The signed total: everything earned minus everything spent, before
    /// the zero floor. Kept distinct from `cosmeticCurrency` so two devices
    /// that each spent currency the other also spent concurrently still
    /// carry that as visible debt internally, rather than being silently
    /// clamped away and then wrongly topped back up by the next earn.
    var ledgerBalance: Int { totalEarned - totalSpent }

    private var totalEarned: Int {
        let uncovered = earnedRewardAmounts.reduce(into: 0) { total, entry in
            guard !legacyEarnedAnchorCoverage.contains(entry.key) else { return }
            total += entry.value
        }
        return legacyEarnedAnchor + uncovered
    }

    private var totalSpent: Int { purchaseAmounts.values.reduce(0, +) }

    // Decoded leniently, so a profile written by an earlier build still opens.
    enum CodingKeys: String, CodingKey {
        case cosmeticCurrency, ownedCosmeticIDs, equipped, rewardedCompletionIDs,
             earnedRewardAmounts, purchaseAmounts, legacyEarnedAnchor, legacyEarnedAnchorCoverage,
             hasStartedFirstRunTutorial, earnedAchievementIDs, achievementProgress,
             lastModifiedAt, equippedDecisionAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        ownedCosmeticIDs = try container.decodeIfPresent(Set<String>.self, forKey: .ownedCosmeticIDs)
            ?? CosmeticCatalog.startingOwnedIDs
        equipped = try container.decodeIfPresent(EquippedCosmetics.self, forKey: .equipped) ?? .starting
        rewardedCompletionIDs = try container
            .decodeIfPresent(Set<String>.self, forKey: .rewardedCompletionIDs) ?? []
        hasStartedFirstRunTutorial = try container
            .decodeIfPresent(Bool.self, forKey: .hasStartedFirstRunTutorial) ?? false
        earnedAchievementIDs = try container
            .decodeIfPresent(Set<String>.self, forKey: .earnedAchievementIDs) ?? []
        achievementProgress = try container
            .decodeIfPresent(AchievementProgress.self, forKey: .achievementProgress) ?? AchievementProgress()
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? .distantPast
        equippedDecisionAt = try container
            .decodeIfPresent(Date.self, forKey: .equippedDecisionAt) ?? .distantPast

        if let earned = try container.decodeIfPresent([String: Int].self, forKey: .earnedRewardAmounts) {
            // A build that already writes the ledger wrote this payload:
            // every figure below is exact, nothing to reconstruct.
            earnedRewardAmounts = earned
            purchaseAmounts = try container.decodeIfPresent([String: Int].self, forKey: .purchaseAmounts) ?? [:]
            legacyEarnedAnchor = try container.decodeIfPresent(Int.self, forKey: .legacyEarnedAnchor) ?? 0
            legacyEarnedAnchorCoverage = try container
                .decodeIfPresent(Set<String>.self, forKey: .legacyEarnedAnchorCoverage) ?? []
        } else {
            // A scalar-only payload: no per-item price and no per-reward
            // amount survives in it, so this is a one-time reconstruction,
            // never an ongoing source of truth.
            let legacyScalarBalance = try container.decodeIfPresent(Int.self, forKey: .cosmeticCurrency) ?? 0
            let bootstrappedPurchases = ownedCosmeticIDs.reduce(into: [String: Int]()) { result, id in
                guard let item = CosmeticCatalog.item(id), item.price > 0 else { return }
                result[id] = item.price
            }
            earnedRewardAmounts = [:]
            purchaseAmounts = bootstrappedPurchases
            legacyEarnedAnchor = legacyScalarBalance + bootstrappedPurchases.values.reduce(0, +)
            // Every id this build had ever paid for is already folded into
            // the scalar above. None may also be added from a ledger entry.
            legacyEarnedAnchorCoverage = rewardedCompletionIDs
        }
        // A ledger key missing here would otherwise still pass the pre-ledger
        // `rewardedCompletionIDs` idempotence check and be earned again.
        rewardedCompletionIDs.formUnion(earnedRewardAmounts.keys)
        // A profile written before a category existed still has to wear
        // something in it.
        normalize()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Preserve the scalar and bare reward ids for builds that predate the
        // ledger, while this build reads the exact event records below.
        try container.encode(cosmeticCurrency, forKey: .cosmeticCurrency)
        try container.encode(ownedCosmeticIDs, forKey: .ownedCosmeticIDs)
        try container.encode(equipped, forKey: .equipped)
        try container.encode(rewardedCompletionIDs, forKey: .rewardedCompletionIDs)
        try container.encode(earnedRewardAmounts, forKey: .earnedRewardAmounts)
        try container.encode(purchaseAmounts, forKey: .purchaseAmounts)
        try container.encode(legacyEarnedAnchor, forKey: .legacyEarnedAnchor)
        try container.encode(legacyEarnedAnchorCoverage, forKey: .legacyEarnedAnchorCoverage)
        try container.encode(hasStartedFirstRunTutorial, forKey: .hasStartedFirstRunTutorial)
        try container.encode(earnedAchievementIDs, forKey: .earnedAchievementIDs)
        try container.encode(achievementProgress, forKey: .achievementProgress)
        try container.encode(lastModifiedAt, forKey: .lastModifiedAt)
        try container.encode(equippedDecisionAt, forKey: .equippedDecisionAt)
    }

    mutating func merge(remote: PlayerProfile) {
        ownedCosmeticIDs.formUnion(remote.ownedCosmeticIDs)
        rewardedCompletionIDs.formUnion(remote.rewardedCompletionIDs)
        earnedRewardAmounts.merge(remote.earnedRewardAmounts, uniquingKeysWith: max)
        rewardedCompletionIDs.formUnion(earnedRewardAmounts.keys)
        purchaseAmounts.merge(remote.purchaseAmounts, uniquingKeysWith: max)
        if remote.legacyEarnedAnchor > legacyEarnedAnchor {
            legacyEarnedAnchor = remote.legacyEarnedAnchor
            legacyEarnedAnchorCoverage = remote.legacyEarnedAnchorCoverage
        } else if remote.legacyEarnedAnchor == legacyEarnedAnchor {
            legacyEarnedAnchorCoverage.formUnion(remote.legacyEarnedAnchorCoverage)
        }
        hasStartedFirstRunTutorial = hasStartedFirstRunTutorial || remote.hasStartedFirstRunTutorial
        earnedAchievementIDs.formUnion(remote.earnedAchievementIDs)
        achievementProgress.merge(remote: remote.achievementProgress)
        if remote.equippedDecisionAt > equippedDecisionAt {
            equipped = remote.equipped
            equippedDecisionAt = remote.equippedDecisionAt
        } else if equippedDecisionAt == .distantPast
                    && remote.equippedDecisionAt == .distantPast
                    && remote.lastModifiedAt > lastModifiedAt {
            // Until either side has a v2 decision, retain the legacy v1
            // last-write-wins behavior so an existing cloud loadout migrates.
            equipped = remote.equipped
        }
        lastModifiedAt = max(lastModifiedAt, remote.lastModifiedAt)
        normalize()
    }

    mutating func normalize() {
        ownedCosmeticIDs.formUnion(CosmeticCatalog.startingOwnedIDs)
        for category in CosmeticCategory.allCases {
            let id = equipped[category]
            guard let item = CosmeticCatalog.item(id),
                  item.category == category,
                  ownedCosmeticIDs.contains(id) else {
                equipped[category] = CosmeticCatalog.defaultID(for: category)
                continue
            }
        }
    }
}

// MARK: - Earning

/// Why currency was paid. Held so the reason can be shown, and so two
/// different reasons never collapse into one event id.
enum CosmeticRewardReason: String, Codable {
    case bookCompleted
    case bookFailed
    case obstacleMilestone
    case firstBookCompletion
}

struct CosmeticRewardEvent {
    let id: String
    let amount: Int
    let reason: CosmeticRewardReason
}

/// One place to argue about the economy in.
enum CosmeticRewardPolicy {
    static let bookCompleted = 60
    static let firstBookCompletion = 40

    /// A finished Book, identified by its seed. A Book is the run — there is
    /// no second "run completed" event, because that would pay twice for the
    /// same afternoon.
    static func bookCompleted(seed: String, isFirstEver: Bool) -> [CosmeticRewardEvent] {
        var events = [CosmeticRewardEvent(id: "book:\(seed)", amount: bookCompleted,
                                          reason: .bookCompleted)]
        if isFirstEver {
            events.append(CosmeticRewardEvent(id: "first-book", amount: firstBookCompletion,
                                              reason: .firstBookCompletion))
        }
        return events
    }

    /// A failed Book pays for the progress the player actually made, but never
    /// approaches the completion reward. Reaching level `n` means the first
    /// `n - 1` levels and their Bosses were beaten.
    static func bookFailed(seed: String, currentLevel: Int) -> CosmeticRewardEvent {
        let levelsCleared = max(0, currentLevel - 1)
        let bossesBeaten = levelsCleared
        return CosmeticRewardEvent(
            id: "book-failed:\(seed)",
            amount: levelsCleared * 2 + bossesBeaten,
            reason: .bookFailed
        )
    }
}

/// What the currency is called on the page. Kept in one place so the name can
/// be settled later without touching a single stored byte.
enum ClubCurrency {
    static let name = "Stamps"
    static let symbol = "seal"
}
