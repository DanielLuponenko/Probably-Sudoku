import Foundation

/// The permanent record behind the in-app achievement page. It stores facts
/// about a player rather than transient view state, so earning is local-first
/// and safe to merge from another device.
struct AchievementProgress: Codable, Equatable {
    var highestLevelReached = 1
    var completedBookVolumes: Set<Int> = []
    /// A Boss victory is keyed by the run seed and Level, so re-entering a
    /// result page cannot count it twice and two devices can union safely.
    var completedBossEncounterIDs: Set<String> = []

    mutating func merge(remote: AchievementProgress) {
        highestLevelReached = max(highestLevelReached, remote.highestLevelReached)
        completedBookVolumes.formUnion(remote.completedBookVolumes)
        completedBossEncounterIDs.formUnion(remote.completedBossEncounterIDs)
    }
}

enum AchievementCategory: String, CaseIterable, Identifiable {
    case progress = "Progress"
    case mastery = "Mastery"
    case economy = "Economy"
    case character = "Character"

    var id: String { rawValue }
}

struct AchievementDefinition: Identifiable, Hashable {
    let id: String
    let category: AchievementCategory
    let title: String
    let detail: String

    /// Keep the external identifier in one namespace. App Store Connect must
    /// use these exact identifiers before a signed-in player can receive the
    /// queued Game Center mirror.
    var gameCenterID: String { "com.numberclub.app.achievement.\(id)" }
}

enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        .init(id: "finish-book", category: .progress,
              title: "Cover to Cover", detail: "Finish a Book."),
        .init(id: "finish-every-book", category: .progress,
              title: "The Whole Shelf", detail: "Finish all four Books."),
        .init(id: "reach-level-5", category: .progress,
              title: "Getting Serious", detail: "Reach Level 5 in a Book."),
        .init(id: "reach-level-7", category: .progress,
              title: "Still Here", detail: "Reach Level 7 in a Book."),
        .init(id: "reach-level-9", category: .progress,
              title: "Last Chapter", detail: "Reach Level 9 in a Book."),
        .init(id: "beat-ten-bosses", category: .progress,
              title: "Regular Visitor", detail: "Beat 10 Bosses."),

        .init(id: "full-clear", category: .mastery,
              title: "All Inked", detail: "Fill every square in a Puzzle."),
        .init(id: "three-way-clear", category: .mastery,
              title: "Triple Entry", detail: "Clear a row, column, and box with one placement."),
        .init(id: "hundred-thousand", category: .mastery,
              title: "Six Figures", detail: "Score 100,000 points in one Puzzle."),
        .init(id: "flawless-boss", category: .mastery,
              title: "No Red Pencil", detail: "Beat a Boss without a wrong placement."),
        .init(id: "no-clue", category: .mastery,
              title: "Read the Room", detail: "Finish a Puzzle without using a Clue."),

        .init(id: "hold-thirty-coins", category: .economy,
              title: "Deep Pockets", detail: "Hold 30 coins in a Book."),
        .init(id: "buy-subscription", category: .economy,
              title: "Paperwork", detail: "Buy a Subscription."),
        .init(id: "five-bookmarks", category: .economy,
              title: "Well Marked", detail: "Own five Bookmarks at once."),
        .init(id: "same-shop-sale", category: .economy,
              title: "Buyer’s Remorse", detail: "Sell an item back in the Shop where you bought it."),

        .init(id: "obstacle-three-book", category: .character,
              title: "Against the Grain", detail: "Finish a Book on Obstacle III."),
        .init(id: "last-turn-win", category: .character,
              title: "Down to the Wire", detail: "Finish a Puzzle on its last Turn."),
        .init(id: "two-skips", category: .character,
              title: "Editorial Control", detail: "Take both skips in one Book."),
        .init(id: "keep-filling-full-clear", category: .character,
              title: "One More Page", detail: "Keep Filling until you Full Clear a Puzzle.")
    ]

    static let allBookVolumes = 4
    static func definition(for id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}
