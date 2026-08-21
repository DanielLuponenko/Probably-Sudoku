import Foundation

/// What a cosmetic changes. Each category is one slot: you own many and wear
/// one, the way you own many pencils and write with one.
enum CosmeticCategory: String, Codable, CaseIterable, Identifiable {
    case desk
    case paper
    case board
    case numbers
    case marker

    var id: String { rawValue }

    /// The counter it is sold from, printed on the drawer.
    var title: String {
        switch self {
        case .desk: return "Desk"
        case .paper: return "Paper"
        case .board: return "Grid"
        case .numbers: return "Numbers"
        case .marker: return "Pencil"
        }
    }

    var note: String {
        switch self {
        case .desk: return "The wood the Book lies on."
        case .paper: return "What it is printed on."
        case .board: return "How the grid is ruled."
        case .numbers: return "The face the digits are set in."
        case .marker: return "What you write with."
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

/// One id per category. Never optional: there is always something on the desk,
/// so "nothing equipped" is not a state the game has to draw.
struct EquippedCosmetics: Codable, Equatable {
    var deskID: String
    var paperID: String
    var boardID: String
    var numberID: String
    var markerID: String

    static let starting = EquippedCosmetics(
        deskID: "dk_walnut", paperID: "pp_newsprint", boardID: "bd_printed",
        numberID: "nb_press", markerID: "pc_graphite")

    subscript(category: CosmeticCategory) -> String {
        get {
            switch category {
            case .desk: return deskID
            case .paper: return paperID
            case .board: return boardID
            case .numbers: return numberID
            case .marker: return markerID
            }
        }
        set {
            switch category {
            case .desk: deskID = newValue
            case .paper: paperID = newValue
            case .board: boardID = newValue
            case .numbers: numberID = newValue
            case .marker: markerID = newValue
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
    var cosmeticCurrency: Int = 0
    var ownedCosmeticIDs: Set<String> = CosmeticCatalog.startingOwnedIDs
    var equipped: EquippedCosmetics = .starting
    /// Every reward already paid, by event id. This is what makes earning
    /// idempotent — a results page that appears twice pays once.
    var rewardedCompletionIDs: Set<String> = []
    /// Set as soon as the opening lesson starts, so Continue never repeats it.
    var hasStartedFirstRunTutorial = false
    /// The whole equipped loadout is one player decision. It is deliberately
    /// timestamped separately from earned inventory so sync can union progress
    /// while taking the latest intentional appearance choice.
    var lastModifiedAt: Date = .distantPast

    // Decoded leniently, so a profile written by an earlier build still opens.
    enum CodingKeys: String, CodingKey {
        case cosmeticCurrency, ownedCosmeticIDs, equipped, rewardedCompletionIDs,
             hasStartedFirstRunTutorial, lastModifiedAt
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cosmeticCurrency = try container.decodeIfPresent(Int.self, forKey: .cosmeticCurrency) ?? 0
        ownedCosmeticIDs = try container.decodeIfPresent(Set<String>.self, forKey: .ownedCosmeticIDs)
            ?? CosmeticCatalog.startingOwnedIDs
        equipped = try container.decodeIfPresent(EquippedCosmetics.self, forKey: .equipped) ?? .starting
        rewardedCompletionIDs = try container
            .decodeIfPresent(Set<String>.self, forKey: .rewardedCompletionIDs) ?? []
        hasStartedFirstRunTutorial = try container
            .decodeIfPresent(Bool.self, forKey: .hasStartedFirstRunTutorial) ?? false
        lastModifiedAt = try container.decodeIfPresent(Date.self, forKey: .lastModifiedAt) ?? .distantPast
        // A profile written before a category existed still has to wear
        // something in it.
        normalize()
    }

    mutating func merge(remote: PlayerProfile) {
        cosmeticCurrency = max(cosmeticCurrency, remote.cosmeticCurrency)
        ownedCosmeticIDs.formUnion(remote.ownedCosmeticIDs)
        rewardedCompletionIDs.formUnion(remote.rewardedCompletionIDs)
        hasStartedFirstRunTutorial = hasStartedFirstRunTutorial || remote.hasStartedFirstRunTutorial
        if remote.lastModifiedAt > lastModifiedAt { equipped = remote.equipped }
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
