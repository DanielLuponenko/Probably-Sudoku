import Foundation
import ProbablySudokuEngine

/// The permanent record behind the in-app achievement page. It stores facts
/// about a player rather than transient view state, so earning is local-first
/// and safe to merge from another device.
struct AchievementProgress: Codable, Equatable {
    var highestLevelReached = 1
    var completedBookVolumes: Set<Int> = []
    /// A Boss victory is keyed by the run seed and Level, so re-entering a
    /// result page cannot count it twice and two devices can union safely.
    var completedBossEncounterIDs: Set<String> = []
    /// Optional for profiles written before obstacles belonged to each Book.
    var completedObstaclesByBookID: [String: Int]? = nil

    var completedObstacles: [String: Int] {
        // An old volume identity proves a win, but not which obstacle it used.
        var values = Dictionary(uniqueKeysWithValues: Book.allCases
            .filter { completedBookVolumes.contains($0.volume) }.map { ($0.rawValue, 1) })
        values.merge(completedObstaclesByBookID ?? [:], uniquingKeysWith: max)
        return values
    }

    var unlockedObstaclesByBookID: [String: Int] {
        let completed = completedObstacles
        return Dictionary(uniqueKeysWithValues: Book.allCases.map { book in
            let best = min(Obstacle.allCases.count, max(0, completed[book.rawValue] ?? 0))
            return (book.rawValue, min(Obstacle.allCases.count, best + 1))
        })
    }

    var hasCompletedAllBooks: Bool {
        Set(Book.allCases.map(\.volume)).isSubset(of: completedBookVolumes)
    }

    mutating func recordBookCompleted(_ book: Book, obstacle: Obstacle) {
        var values = completedObstacles
        values[book.rawValue] = max(values[book.rawValue] ?? 0, obstacle.rawValue)
        completedBookVolumes.insert(book.volume)
        completedObstaclesByBookID = values
    }

    /// Import only identity-bearing local facts, never the old global ceiling.
    mutating func merge(localProgress: RunStore.Progress) {
        var values = completedObstacles
        values.merge(localProgress.completedObstacles, uniquingKeysWith: max)
        completedObstaclesByBookID = values.isEmpty ? completedObstaclesByBookID : values
        completedBookVolumes.formUnion(Book.allCases.filter {
            (values[$0.rawValue] ?? 0) > 0
        }.map(\.volume))
    }

    mutating func merge(remote: AchievementProgress) {
        var values = completedObstacles
        values.merge(remote.completedObstacles, uniquingKeysWith: max)
        completedObstaclesByBookID = values.isEmpty ? completedObstaclesByBookID : values
        highestLevelReached = max(highestLevelReached, remote.highestLevelReached)
        completedBookVolumes.formUnion(remote.completedBookVolumes)
        completedBookVolumes.formUnion(Book.allCases.filter {
            (values[$0.rawValue] ?? 0) > 0
        }.map(\.volume))
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
    /// App Store Connect permits underscores, not hyphens. The local `id`
    /// remains unchanged so existing awards and iCloud merges keep their identity.
    var gameCenterID: String {
        "com.numberclub.app.achievement.\(id.replacingOccurrences(of: "-", with: "_"))"
    }

    var isRegisteredWithGameCenter: Bool {
        AchievementCatalog.registeredGameCenterLocalIDs.contains(id)
    }
}

enum AchievementCatalog {
    static let all: [AchievementDefinition] = [
        .init(id: "finish-book", category: .progress,
              title: "Cover to Cover", detail: "Finish a Book."),
        .init(id: "finish-every-book", category: .progress,
              title: "The Whole Shelf", detail: "Finish all \(Book.allCases.count) Books."),
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
              title: "Paperwork", detail: "Buy a Bookmark with coins in the Shop."),
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
              title: "One More Page", detail: "Keep Filling until you Full Clear a Puzzle."),

        .init(id: "first-correct-placement", category: .progress,
              title: "Ink Happens", detail: "Place a correct number in a Puzzle."),
        .init(id: "first-line-clear", category: .progress,
              title: "One Good Line", detail: "Complete a row, column, or box."),
        .init(id: "first-boss", category: .progress,
              title: "Management Meeting", detail: "Beat your first Boss."),
        .init(id: "finish-three-books", category: .progress,
              title: "Shelf Improvement", detail: "Finish three different Books."),

        .init(id: "double-clear", category: .mastery,
              title: "Two for One", detail: "Complete at least two of a row, column, and box with one placement."),
        .init(id: "half-million", category: .mastery,
              title: "A Bit Excessive", detail: "Bank 500,000 points in one Puzzle."),
        .init(id: "double-target", category: .mastery,
              title: "Overqualified", detail: "Bank at least twice the target score in one Puzzle."),
        .init(id: "five-turns-spare", category: .mastery,
              title: "Ahead of Schedule", detail: "Finish a Puzzle with at least five Turns remaining."),

        .init(id: "buy-marker", category: .economy,
              title: "Colour Commitment", detail: "Buy a Marker with coins in the Shop."),
        .init(id: "use-buff", category: .economy,
              title: "Helpful Footnote", detail: "Use a Buff that takes effect."),

        .init(id: "no-outside-help", category: .character,
              title: "No Outside Help", detail: "Finish a Puzzle without a wrong placement, Clue, or Toss."),
        .init(id: "obstacle-nine-book", category: .character,
              title: "Glutton for Punishment", detail: "Finish a Book on Obstacle IX.")
    ]

    /// Only these existing awards have App Store Connect records. New local
    /// awards must not poison a GameKit batch with unregistered identifiers.
    /// Keep this explicit until their metadata has actually been registered.
    static let registeredGameCenterLocalIDs: Set<String> = [
        "finish-book", "finish-every-book", "reach-level-5", "reach-level-7",
        "reach-level-9", "beat-ten-bosses", "full-clear", "three-way-clear",
        "hundred-thousand", "flawless-boss", "no-clue", "hold-thirty-coins",
        "buy-subscription", "five-bookmarks", "same-shop-sale", "obstacle-three-book",
        "last-turn-win", "two-skips", "keep-filling-full-clear"
    ]
    static let registeredGameCenterIDs = Set(all.filter(\.isRegisteredWithGameCenter).map(\.gameCenterID))

    static let allBookVolumes = Book.allCases.count
    static func definition(for id: String) -> AchievementDefinition? {
        all.first { $0.id == id }
    }
}

/// Pure eligibility at the existing engine-event boundaries. These rules do
/// not write player data or infer actions from a UI opening or a preview.
enum AchievementRules {
    static func bossesDefeated(_ count: Int) -> Set<String> {
        guard count > 0 else { return [] }
        return count >= 10 ? ["first-boss", "beat-ten-bosses"] : ["first-boss"]
    }

    static func placement(_ outcome: PlacementOutcome, duringKeepFilling: Bool) -> Set<String> {
        guard outcome.correct else { return [] }
        var awards: Set<String> = ["first-correct-placement"]
        if outcome.fullClear { awards.insert("full-clear") }
        if outcome.fullClear && duringKeepFilling { awards.insert("keep-filling-full-clear") }
        let clearedKinds = Set(outcome.lineClears.map(\.rawValue))
        if !clearedKinds.isEmpty { awards.insert("first-line-clear") }
        if clearedKinds.count >= 2 { awards.insert("double-clear") }
        if clearedKinds == ["row", "col", "box"] { awards.insert("three-way-clear") }
        return awards
    }

    static func puzzleFinished(score: Int, target: Int, wasBoss: Bool,
                               hadWrongPlacement: Bool, usedClue: Bool,
                               tossesUsed: Int, turnsRemaining: Int,
                               hasCompleteHistory: Bool = true) -> Set<String> {
        // Called after a successful cash-out, with the pre-payout Puzzle.
        guard target > 0, score >= target else { return [] }
        var awards: Set<String> = []
        if score >= 100_000 { awards.insert("hundred-thousand") }
        if score >= 500_000 { awards.insert("half-million") }
        // Division avoids overflow when a late-game target is large.
        if score / target >= 2 { awards.insert("double-target") }
        if hasCompleteHistory && wasBoss && !hadWrongPlacement { awards.insert("flawless-boss") }
        if hasCompleteHistory && !usedClue { awards.insert("no-clue") }
        // End Turn banks the score, then advances turnNumber even on a win.
        // The winning final Turn therefore leaves zero, not one, remaining.
        if turnsRemaining == 0 { awards.insert("last-turn-win") }
        if turnsRemaining >= 5 { awards.insert("five-turns-spare") }
        if hasCompleteHistory && !hadWrongPlacement && !usedClue && tossesUsed == 0 {
            awards.insert("no-outside-help")
        }
        return awards
    }

    static func bookCompleted(progress: AchievementProgress, obstacle: Obstacle) -> Set<String> {
        var awards: Set<String> = ["finish-book"]
        let knownVolumes = Set(Book.allCases.map(\.volume))
        if progress.completedBookVolumes.intersection(knownVolumes).count >= 3 {
            awards.insert("finish-three-books")
        }
        if progress.hasCompletedAllBooks { awards.insert("finish-every-book") }
        if obstacle == .shortHandedAndBlocked { awards.insert("obstacle-three-book") }
        if obstacle == .finalEdition { awards.insert("obstacle-nine-book") }
        return awards
    }

    static func purchase(kind: ItemKind, bookmarkCount: Int) -> Set<String> {
        var awards: Set<String> = []
        // The legacy local/server ID stays stable, but the unreachable old
        // Subscription wording now describes the live coin-only Bookmark shop.
        if kind == .bookmark { awards.insert("buy-subscription") }
        if kind == .marker { awards.insert("buy-marker") }
        if bookmarkCount >= 5 { awards.insert("five-bookmarks") }
        return awards
    }
}
