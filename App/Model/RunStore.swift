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

    static func save(_ game: Game) {
        // A finished or abandoned Book is not worth resuming into.
        guard game.run.outcome == nil else { clearRun(); return }
        guard let data = try? game.encoded() else { return }
        try? data.write(to: runURL, options: .atomic)
        CloudSync.shared.publish(run: data)
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
        #if DEBUG
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

    static func clearRun() {
        try? FileManager.default.removeItem(at: runURL)
        CloudSync.shared.publish(run: nil)
    }

    private static func game(from data: Data?) -> Game? {
        guard let data, let game = try? Game(decoding: data), game.run.outcome == nil else {
            return nil
        }
        return game
    }

    // MARK: - What is unlocked

    struct Progress: Codable {
        var unlockedObstacle: Int = 1
        // Retain the old contiguous-volume counter for older app readers.
        var booksCompleted: Int = 0
        // Optional so the previous two-field save still decodes unchanged.
        // Raw IDs preserve unknown future volumes instead of losing progress.
        var completedBookIDs: Set<String>? = nil

        var completedBooks: Set<String> {
            completedBookIDs ?? Set(Book.allCases.filter {
                $0.volume <= booksCompleted
            }.map(\.rawValue))
        }

        @discardableResult
        mutating func recordCompletion(of book: Book) -> Bool {
            var completed = completedBooks
            guard completed.insert(book.rawValue).inserted else { return false }
            completedBookIDs = completed
            booksCompleted = Book.allCases.sorted { $0.volume < $1.volume }
                .prefix { completed.contains($0.rawValue) }.count
            unlockedObstacle = min(Obstacle.allCases.count, unlockedObstacle + 1)
            return true
        }
    }

    private static func progress() -> Progress {
        guard let data = try? Data(contentsOf: progressURL),
              let value = try? JSONDecoder().decode(Progress.self, from: data)
        else { return Progress() }
        return value
    }

    private static func write(_ value: Progress) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: progressURL, options: .atomic)
    }

    /// The hardest Obstacle the player has earned. One more is unlocked by
    /// finishing a Book, so the ladder is climbed rather than chosen.
    static var unlockedObstacle: Obstacle {
        Obstacle(rawValue: progress().unlockedObstacle) ?? .none
    }

    static func isUnlocked(_ obstacle: Obstacle) -> Bool {
        obstacle.rawValue <= progress().unlockedObstacle
    }

    static var booksCompleted: Int { progress().completedBooks.count }

    /// Books can be played in any order. A distinct completed volume advances
    /// the Obstacle ladder once; replaying it does not grant another unlock.
    static func recordBookCompleted(_ book: Book) {
        var value = progress()
        guard value.recordCompletion(of: book) else { return }
        write(value)
    }
}
