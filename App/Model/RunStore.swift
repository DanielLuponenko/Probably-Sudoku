import Foundation
import ProbablySudokuEngine

/// Where a run lives between launches, and what the player has unlocked.
///
/// A Book is 27 Puzzles. Nobody finishes one in a sitting, so the run has to
/// survive being put down — and since `RunState` is Codable all the way down,
/// keeping it is a matter of writing the bytes somewhere.
enum RunStore {

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
    }

    static func loadRun() -> Game? {
        guard let data = try? Data(contentsOf: runURL),
              let game = try? Game(decoding: data),
              game.run.outcome == nil else { return nil }
        return game
    }

    static var hasRun: Bool { loadRun() != nil }

    static func clearRun() {
        try? FileManager.default.removeItem(at: runURL)
    }

    // MARK: - What is unlocked

    private struct Progress: Codable {
        var unlockedObstacle: Int = 1
        var booksCompleted: Int = 0
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

    static var booksCompleted: Int { progress().booksCompleted }

    /// Called when a Book is finished. Only the next locked volume advances
    /// progress, so replaying Book 1 cannot skip the Book 2 requirement.
    static func recordBookCompleted(_ book: Book) {
        var value = progress()
        guard book.volume == value.booksCompleted + 1 else { return }
        value.booksCompleted += 1
        value.unlockedObstacle = min(Obstacle.allCases.count, value.unlockedObstacle + 1)
        write(value)
    }
}
