import Foundation
import ProbablySudokuEngine

/// Where a run lives between launches, and what the player has unlocked.
///
/// A Book is 27 Puzzles. Nobody finishes one in a sitting, so the run has to
/// survive being put down — and since `RunState` is Codable all the way down,
/// keeping it is a matter of writing the bytes somewhere.
enum RunStore {

    /// Two valid Books are allowed to coexist after an offline divergence.
    /// Nothing turns either into the local run until the player explicitly
    /// chooses one at the front door.
    struct Conflict {
        enum Choice: Equatable { case local, remote }

        let local: Game
        let remote: Game

        func label(for choice: Choice) -> String {
            let game = choice == .local ? local : remote
            if game.run.outcome == .bookCompleted {
                return "Book \(game.run.book.volume) complete"
            }
            return "Book \(game.run.book.volume), Level \(game.run.level), Puzzle \(game.run.slot.rawValue + 1)"
        }
    }

    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static var runURL: URL { directory.appendingPathComponent("run.json") }
    private static var progressURL: URL { directory.appendingPathComponent("progress.json") }

    // MARK: - The run in progress

    static func save(_ game: Game, publishToCloud: Bool = true) {
        let encoded: Data?
        do { encoded = try dataForStorage(of: game) }
        catch { return } // An encoding error must not erase an existing save.
        guard let data = encoded else {
            clearRun(publishToCloud: publishToCloud)
            return
        }
        try? data.write(to: runURL, options: .atomic)
        if publishToCloud { CloudSync.shared.publish(run: data) }
    }

    /// A paid completion is a receipt awaiting the player's Close Book action,
    /// not another playable Puzzle. Retain it across relaunches; failed Books
    /// still disappear. Kept pure so compatibility tests never touch saves.
    static func dataForStorage(of game: Game) throws -> Data? {
        guard game.run.outcome != .failed else { return nil }
        return try game.encoded()
    }

    static func loadRun() -> Game? {
        game(from: try? Data(contentsOf: runURL))
    }

    /// The cloud copy is intentionally only read here. KAN-61 presents it as
    /// a choice instead of allowing a notification to replace a live Book.
    static func loadRemoteRun() -> Game? {
        game(from: CloudSync.shared.remoteRunData())
    }

    static func conflict() -> Conflict? {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-presentRunConflict") {
            var local = Game(seed: "local-conflict")
            var remote = Game(seed: "remote-conflict", book: .slightlyHarder)
            for _ in 0..<3 { _ = local.advance() }
            for _ in 0..<7 { _ = remote.advance() }
            return Conflict(local: local, remote: remote)
        }
        #endif
        guard let local = loadRun(), let remote = loadRemoteRun(),
              let localData = try? local.encoded(), let remoteData = try? remote.encoded(),
              localData != remoteData
        else { return nil }
        return Conflict(local: local, remote: remote)
    }

    /// Shows a remote-only Book on the shelf without writing it locally.
    static func displayedRun() -> Game? {
        loadRun() ?? loadRemoteRun()
    }

    /// A remote-only Book becomes local only after the player presses the
    /// normal Continue button. Conflicts never reach this method.
    static func resumeRun() -> Game? {
        if let local = loadRun() { return local }
        guard let remote = loadRemoteRun() else { return nil }
        save(remote)
        return remote
    }

    static func choose(_ choice: Conflict.Choice, from conflict: Conflict) -> Game {
        let chosen = choice == .local ? conflict.local : conflict.remote
        save(chosen)
        return chosen
    }

    static var hasRun: Bool { loadRun() != nil || loadRemoteRun() != nil }

    static func clearRun(publishToCloud: Bool = true) {
        try? FileManager.default.removeItem(at: runURL)
        if publishToCloud { CloudSync.shared.publish(run: nil) }
    }

    static func game(from data: Data?) -> Game? {
        // Decoding can migrate an old paid final-board/Shop save into a Book
        // completion. Let GameModel present and record that receipt exactly
        // once; never revive terminal failures or infer a win here.
        guard let data, let game = try? Game(decoding: data), game.run.outcome != .failed else {
            return nil
        }
        return game
    }

    // MARK: - What is unlocked

    struct Progress: Codable {
        // Retained for old readers/rollback only. It cannot identify which
        // Book earned an obstacle, so it is never used to grant access.
        var unlockedObstacle: Int = 1
        // Retain the old contiguous-volume counter for older app readers.
        var booksCompleted: Int = 0
        // Optional so the previous two-field save still decodes unchanged.
        // Raw IDs preserve unknown future volumes instead of losing progress.
        var completedBookIDs: Set<String>? = nil
        /// Highest completed obstacle, keyed by the engine Book's stable ID.
        /// Missing in older saves; their identified wins prove Obstacle I only.
        var completedObstaclesByBookID: [String: Int]? = nil

        var completedBooks: Set<String> {
            let legacy = completedBookIDs ?? Set(Book.allCases.filter {
                $0.volume <= booksCompleted
            }.map(\.rawValue))
            return legacy.union((completedObstaclesByBookID ?? [:]).filter { $0.value > 0 }.keys)
        }

        var completedObstacles: [String: Int] {
            var values = Dictionary(uniqueKeysWithValues: completedBooks.map { ($0, 1) })
            values.merge(completedObstaclesByBookID ?? [:], uniquingKeysWith: max)
            return values
        }

        func unlockedObstacle(for book: Book) -> Obstacle {
            let completed = max(0, min(Obstacle.allCases.count, completedObstacles[book.rawValue] ?? 0))
            return Obstacle(rawValue: min(Obstacle.allCases.count, completed + 1)) ?? .none
        }

        @discardableResult
        mutating func recordCompletion(of book: Book, obstacle: Obstacle = .none) -> Bool {
            var completed = completedBooks
            var obstacles = completedObstacles
            let isNewBook = completed.insert(book.rawValue).inserted
            let improvesObstacle = obstacle.rawValue > (obstacles[book.rawValue] ?? 0)
            guard isNewBook || improvesObstacle else { return false }
            obstacles[book.rawValue] = max(obstacles[book.rawValue] ?? 0, obstacle.rawValue)
            completedObstaclesByBookID = obstacles
            completedBookIDs = completed
            booksCompleted = Book.allCases.sorted { $0.volume < $1.volume }
                .prefix { completed.contains($0.rawValue) }.count
            return true
        }
    }

    static func progress() -> Progress {
        guard let data = try? Data(contentsOf: progressURL),
              let value = try? JSONDecoder().decode(Progress.self, from: data)
        else { return Progress() }
        return value
    }

    private static func write(_ value: Progress) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: progressURL, options: .atomic)
    }

    static var booksCompleted: Int { progress().completedBooks.count }

    /// Only finishing this Book on a harder obstacle advances its own ladder.
    /// Replaying the same obstacle cannot increment it again.
    static func recordBookCompleted(_ book: Book, obstacle: Obstacle) {
        var value = progress()
        guard value.recordCompletion(of: book, obstacle: obstacle) else { return }
        write(value)
    }
}
