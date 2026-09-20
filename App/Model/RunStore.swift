import Foundation
import CryptoKit
import ProbablySudokuEngine

/// Where a run lives between launches, and what the player has unlocked.
///
/// A Book is 27 Puzzles. Nobody finishes one in a sitting, so the run has to
/// survive being put down — and since `RunState` is Codable all the way down,
/// keeping it is a matter of writing the bytes somewhere.
enum RunStore {

    /// Exact-state difference used for compare-and-swap validation. A difference
    /// is not a second playable Book: the local authority always wins.
    struct Conflict {
        enum Choice: Equatable { case local, remote }

        let id = UUID()
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

    private static var progressURL: URL { directory.appendingPathComponent("progress.json") }

    // MARK: - The run in progress

    /// Older saves have no attempt UUID. Keep their existing identity fields
    /// together so abandoning one Book never hides an unrelated remote Book.
    struct DiscardedRunIdentity: Codable, Hashable {
        let seed: String
        let book: String
        let obstacle: Int

        init(_ game: Game) {
            seed = game.run.seed
            book = game.run.book.rawValue
            obstacle = game.run.obstacle.rawValue
        }

        static func merged(_ lhs: [Self], _ rhs: [Self]) -> [Self] {
            Array(Set(lhs).union(rhs)).sorted {
                if $0.seed != $1.seed { return $0.seed < $1.seed }
                if $0.book != $1.book { return $0.book < $1.book }
                return $0.obstacle < $1.obstacle
            }
        }
    }

    /// Run and completion-progress files share the same durable-write seam.
    /// Tests supply a temporary directory and an in-memory cloud transport.
    struct Storage {
        let directory: URL
        var remoteSnapshot: () -> CloudSync.RunSnapshot
        var publish: (Data?, [DiscardedRunIdentity]) -> Void
        var read: (URL) throws -> Data = { try Data(contentsOf: $0) }
        var write: (Data, URL) throws -> Void = { try $0.write(to: $1, options: .atomic) }
        var remove: (URL) throws -> Void = { try FileManager.default.removeItem(at: $0) }

        private var runURL: URL { directory.appendingPathComponent("run.json") }
        private var discardedURL: URL { directory.appendingPathComponent("discarded-runs.json") }
        private var progressURL: URL { directory.appendingPathComponent("progress.json") }

        private struct ArchivedSnapshot: Codable {
            let data: Data
            let cloudEnvelope: Data?
            let modifiedAt: Date?
            let reason: String
        }

        /// Rollback evidence only. Archives are never searched for a Continue
        /// candidate and are never pruned or overwritten with another snapshot.
        private func archive(_ data: Data, envelope: Data? = nil,
                             modifiedAt: Date? = nil, reason: String) throws {
            let folder = directory.appendingPathComponent("run-backups", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let digest = SHA256.hash(data: envelope ?? data).map { String(format: "%02x", $0) }.joined()
            let url = folder.appendingPathComponent("\(envelope == nil ? "local" : "cloud")-\(digest).json")
            if try readIfPresent(url) != nil { return }
            try write(JSONEncoder().encode(ArchivedSnapshot(data: data, cloudEnvelope: envelope,
                modifiedAt: modifiedAt, reason: reason)), url)
        }

        /// The same attempt may have an older checkpoint, not another Book.
        /// A different observed attempt is retained as evidence and retired so
        /// it cannot reappear when the authoritative local attempt ends.
        private func retainingAlternative(_ snapshot: CloudSync.RunSnapshot, to local: Game,
                                           discarded: [DiscardedRunIdentity]) throws -> [DiscardedRunIdentity] {
            guard let data = snapshot.data ?? (snapshot.isUnreadable ? snapshot.envelopeData : nil)
            else { return discarded }
            let remote = RunStore.game(from: data)
            if let remote, RunStore.conflict(local: local, remote: remote) == nil { return discarded }
            let sameAttempt = remote.map { DiscardedRunIdentity($0) == DiscardedRunIdentity(local) } ?? false
            try archive(data, envelope: snapshot.envelopeData, modifiedAt: snapshot.modifiedAt,
                        reason: sameAttempt ? "other-checkpoint-of-active-attempt" : "superseded-cloud-attempt")
            guard let remote, !sameAttempt else { return discarded }
            return DiscardedRunIdentity.merged(discarded, [DiscardedRunIdentity(remote)])
        }

        private func rememberAlternative(to local: Game) throws {
            let snapshot = remoteSnapshot()
            let receipt = try discardedReceipt()
            let old = try resolvedDiscarded(receipt)
            let base = DiscardedRunIdentity.merged(old, snapshot.discardedRuns)
            let discarded = try retainingAlternative(snapshot, to: local, discarded: base)
            if discarded != old || receipt.pending != nil { try writeDiscarded(discarded) }
        }

        private func readIfPresent(_ url: URL) throws -> Data? {
            do { return try read(url) }
            catch let error as CocoaError where error.code == .fileReadNoSuchFile { return nil }
        }

        private struct DiscardedReceipt: Codable {
            var discarded: [DiscardedRunIdentity]
            var pending: DiscardedRunIdentity? = nil
            /// A replacement commits only when its new run bytes are present.
            /// This also protects a remote-only old Book if the write fails.
            var replacement: DiscardedRunIdentity? = nil
        }

        private func discardedReceipt() throws -> DiscardedReceipt {
            guard let data = try readIfPresent(discardedURL) else { return DiscardedReceipt(discarded: []) }
            if let receipt = try? JSONDecoder().decode(DiscardedReceipt.self, from: data) { return receipt }
            // Retain compatibility with the initial array-only receipt.
            return DiscardedReceipt(discarded: try JSONDecoder().decode([DiscardedRunIdentity].self, from: data))
        }

        private func resolvedDiscarded(_ receipt: DiscardedReceipt) throws -> [DiscardedRunIdentity] {
            guard let pending = receipt.pending else { return receipt.discarded }
            let local = RunStore.game(from: try readIfPresent(runURL)).map(DiscardedRunIdentity.init)
            if let replacement = receipt.replacement {
                return local == replacement
                    ? DiscardedRunIdentity.merged(receipt.discarded, [pending]) : receipt.discarded
            }
            // A crash or failed remove before deletion leaves this run alive.
            // After deletion, pending metadata is enough to prevent resurrection,
            // even if finalizing the receipt could not be written.
            return local == pending ? receipt.discarded
                : DiscardedRunIdentity.merged(receipt.discarded, [pending])
        }

        private func writeReceipt(_ receipt: DiscardedReceipt) throws {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try write(JSONEncoder().encode(receipt), discardedURL)
        }

        private func writeDiscarded(_ discarded: [DiscardedRunIdentity]) throws {
            try writeReceipt(DiscardedReceipt(discarded: discarded))
        }

        func loadRun() -> Game? { RunStore.game(from: try? read(runURL)) }

        func loadRemoteRun() -> Game? {
            do {
                let snapshot = remoteSnapshot()
                let old = try resolvedDiscarded(discardedReceipt())
                let discarded = DiscardedRunIdentity.merged(old, snapshot.discardedRuns)
                // Retain cloud deletion metadata even after another device
                // later uploads an older, legacy envelope without that metadata.
                if discarded != old { try writeDiscarded(discarded) }
                guard let game = RunStore.game(from: snapshot.data),
                      !discarded.contains(DiscardedRunIdentity(game)) else { return nil }
                return game
            } catch { return nil }
        }

        @discardableResult
        func save(_ game: Game, publishToCloud: Bool = true) -> Bool {
            do {
                let localData = try readIfPresent(runURL)
                if let localData, let terminal = try? Game(decoding: localData), terminal.run.outcome == .failed {
                    if game.run.outcome == .failed {
                        return clearRun(publishToCloud: publishToCloud, discarding: DiscardedRunIdentity(terminal))
                    }
                    // A valid terminal legacy file is not a corrupt active
                    // save. Retire it atomically as the fresh attempt starts.
                    return replace(expected: terminal, with: game, publishToCloud: publishToCloud)
                }
                let local = RunStore.game(from: localData)
                guard localData == nil || local != nil else { return false }
                let snapshot = remoteSnapshot()
                let receipt = try discardedReceipt()
                let old = try resolvedDiscarded(receipt)
                var discarded = DiscardedRunIdentity.merged(old, snapshot.discardedRuns)
                if let local {
                    // Checkpoints cannot become an unconfirmed new Book.
                    guard DiscardedRunIdentity(local) == DiscardedRunIdentity(game) else { return false }
                    discarded = try retainingAlternative(snapshot, to: local, discarded: discarded)
                } else if snapshot.isUnreadable {
                    return false
                } else if let remoteData = snapshot.data {
                    guard let remote = try? Game(decoding: remoteData) else { return false }
                    if remote.run.outcome != .failed && !discarded.contains(DiscardedRunIdentity(remote)) {
                        // Covers a cloud arrival between the shelf check and
                        // the first save, as well as stale remote-only resume.
                        guard RunStore.conflict(local: game, remote: remote) == nil else { return false }
                    } else if remote.run.outcome == .failed {
                        try archive(remoteData, envelope: snapshot.envelopeData, modifiedAt: snapshot.modifiedAt,
                                    reason: "terminal-cloud-attempt")
                        discarded = DiscardedRunIdentity.merged(discarded, [DiscardedRunIdentity(remote)])
                    }
                }
                guard let data = try RunStore.dataForStorage(of: game) else {
                    return clearRun(publishToCloud: publishToCloud, discarding: DiscardedRunIdentity(game))
                }
                // Settle a pending deletion before an explicit same-seed start
                // creates matching local bytes again.
                if discarded != old || receipt.pending != nil { try writeDiscarded(discarded) }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try write(data, runURL)
                // A deliberate local start may reuse a named seed. Its local
                // bytes remain resumable, while ambiguous old remote attempts
                // with that identity remain excluded by the discarded receipt.
                if publishToCloud { publish(data, discarded) }
                return true
            } catch { return false }
        }

        /// Replace the exact Book named on the confirmation without a gap in
        /// the saved run. The pending receipt is inert until the atomic run
        /// overwrite succeeds; finalizing it is safe to retry after a crash.
        @discardableResult
        func replace(expected: Game, with replacement: Game, publishToCloud: Bool = true) -> Bool {
            do {
                let target = DiscardedRunIdentity(expected)
                let replacementID = DiscardedRunIdentity(replacement)
                guard target != replacementID,
                      let replacementData = try RunStore.dataForStorage(of: replacement) else { return false }
                let localData = try readIfPresent(runURL)
                let local = localData.flatMap { try? Game(decoding: $0) }
                guard localData == nil || local != nil else { return false }
                let snapshot = remoteSnapshot()
                let receipt = try discardedReceipt()
                var base = DiscardedRunIdentity.merged(try resolvedDiscarded(receipt), snapshot.discardedRuns)
                let remote = RunStore.game(from: snapshot.data).flatMap {
                    base.contains(DiscardedRunIdentity($0)) ? nil : $0
                }
                if local == nil && snapshot.isUnreadable { return false }
                if local == nil, let data = snapshot.data,
                   (try? Game(decoding: data)) == nil { return false }
                guard let current = local ?? remote,
                      RunStore.conflict(local: expected, remote: current) == nil else { return false }
                if let local {
                    base = try retainingAlternative(snapshot, to: local, discarded: base)
                }
                if let localData { try archive(localData, reason: "explicitly-replaced-local-attempt") }
                else if let data = snapshot.data {
                    try archive(data, envelope: snapshot.envelopeData, modifiedAt: snapshot.modifiedAt,
                                reason: "explicitly-replaced-cloud-attempt")
                }

                try writeReceipt(DiscardedReceipt(discarded: base, pending: target, replacement: replacementID))
                do {
                    try write(replacementData, runURL)
                } catch {
                    // A failed rollback is safe too: the replacement identity
                    // is not on disk, so the pending discard remains inert.
                    try? writeDiscarded(base)
                    return false
                }
                let discarded = DiscardedRunIdentity.merged(base, [target])
                try? writeDiscarded(discarded)
                if publishToCloud { publish(replacementData, discarded) }
                return true
            } catch { return false }
        }

        /// A failed or unreadable progress file must not acknowledge an earned
        /// unlock. Callers retain the completed Book receipt for a later retry.
        @discardableResult
        func recordBookCompleted(_ book: Book, obstacle: Obstacle) -> Bool {
            do {
                let data = try readIfPresent(progressURL)
                var progress = try data.map { try JSONDecoder().decode(Progress.self, from: $0) } ?? Progress()
                guard progress.recordCompletion(of: book, obstacle: obstacle) else { return true }
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try write(JSONEncoder().encode(progress), progressURL)
                return true
            } catch { return false }
        }

        @discardableResult
        func clearRun(publishToCloud: Bool = true, discarding identity: DiscardedRunIdentity? = nil) -> Bool {
            do {
                // A missing file is already cleared; an unreadable file is
                // not. Do not report abandonment after permission/I/O failure.
                let data = try readIfPresent(runURL)
                let local = data.flatMap { try? Game(decoding: $0) }
                guard data == nil || local != nil else { return false }
                let snapshot = remoteSnapshot()
                let receipt = try discardedReceipt()
                let old = try resolvedDiscarded(receipt)
                var base = DiscardedRunIdentity.merged(old, snapshot.discardedRuns)
                let remote = RunStore.game(from: snapshot.data)
                if local == nil && snapshot.isUnreadable { return false }
                if let identity, let current = local ?? remote,
                   DiscardedRunIdentity(current) != identity { return false }
                if local == nil, let data = snapshot.data,
                   (try? Game(decoding: data)) == nil { return false }
                if let local {
                    base = try retainingAlternative(snapshot, to: local, discarded: base)
                }
                if let data { try archive(data, reason: "retired-local-attempt") }
                else if let data = snapshot.data {
                    try archive(data, envelope: snapshot.envelopeData, modifiedAt: snapshot.modifiedAt,
                                reason: "retired-cloud-attempt")
                }
                let target = identity ?? local.map(DiscardedRunIdentity.init)
                    ?? RunStore.game(from: snapshot.data).map(DiscardedRunIdentity.init)
                let discarded = DiscardedRunIdentity.merged(base, target.map { [$0] } ?? [])
                let changed = discarded != old || receipt.pending != nil
                if changed {
                    try writeReceipt(DiscardedReceipt(discarded: base, pending: target))
                }
                do {
                    if data != nil { try remove(runURL) }
                } catch {
                    // Even if this rollback write also fails, the pending
                    // receipt sees the still-existing local run and is inert.
                    if changed { try? writeDiscarded(base) }
                    return false
                }
                // The deletion plus pending receipt is already durable. This
                // normalization is optional and safe to retry after relaunch.
                if changed { try? writeDiscarded(discarded) }
                if publishToCloud { publish(nil, discarded) }
                return true
            } catch { return false }
        }

        func displayedRun() -> Game? {
            do {
                if let data = try readIfPresent(runURL) {
                    guard let local = RunStore.game(from: data) else { return nil }
                    // A backup failure must not hide a valid Continue target.
                    // Mutating save/replace/clear paths require its durable retry.
                    try? rememberAlternative(to: local)
                    return local
                }
                return loadRemoteRun()
            } catch { return nil }
        }

        func conflict() -> Conflict? {
            nil
        }

        func resumeRun() -> Game? {
            do {
                if let data = try readIfPresent(runURL) {
                    guard let local = RunStore.game(from: data) else { return nil }
                    try? rememberAlternative(to: local)
                    return local
                }
                guard let remote = loadRemoteRun(), save(remote) else { return nil }
                return remote
            } catch { return nil }
        }

        func choose(_ choice: Conflict.Choice, from conflict: Conflict) -> Game? {
            // Compatibility only: the retired copy picker cannot replace the
            // authority if a delayed action from an older presentation arrives.
            guard choice == .local, let current = loadRun(),
                  RunStore.conflict(local: current, remote: conflict.local) == nil else { return nil }
            return resumeRun()
        }
    }

    private static var storage: Storage {
        Storage(directory: directory, remoteSnapshot: { CloudSync.shared.remoteRunSnapshot() },
                publish: { CloudSync.shared.publish(run: $0, discardedRuns: $1) })
    }

    @discardableResult
    static func save(_ game: Game, publishToCloud: Bool = true) -> Bool {
        storage.save(game, publishToCloud: publishToCloud)
    }

    @discardableResult
    static func replace(expected: Game, with replacement: Game) -> Bool {
        storage.replace(expected: expected, with: replacement)
    }

    /// A paid completion is a receipt awaiting the player's Close Book action,
    /// not another playable Puzzle. Retain it across relaunches; failed Books
    /// still disappear. Kept pure so compatibility tests never touch saves.
    static func dataForStorage(of game: Game) throws -> Data? {
        guard game.run.outcome != .failed else { return nil }
        return try game.encoded()
    }

    static func loadRun() -> Game? {
        storage.loadRun()
    }

    /// Raw eligible cloud data for diagnostics/transport. Player-facing
    /// Continue selection must use displayedRun/resumeRun instead.
    static func loadRemoteRun() -> Game? {
        storage.loadRemoteRun()
    }

    static func conflict() -> Conflict? {
        nil
    }

    /// Compare game state, not Set/dictionary serialization order. Keep this
    /// pure: differences remain useful for exact expected-state validation.
    static func conflict(local: Game, remote: Game) -> Conflict? {
        let lhs = local.puzzle
        let rhs = remote.puzzle
        guard lhs?.clueReveals == rhs?.clueReveals,
              lhs?.obstacleBlockedDigits == rhs?.obstacleBlockedDigits,
              lhs?.armedFlags == rhs?.armedFlags,
              lhs?.bossTurn?.blockedDigits == rhs?.bossTurn?.blockedDigits,
              lhs?.bossTurn?.blockedHandIndices == rhs?.bossTurn?.blockedHandIndices,
              lhs?.bossTurn?.greyed == rhs?.bossTurn?.greyed,
              lhs?.bossTurn?.fouled == rhs?.bossTurn?.fouled else {
            return Conflict(local: local, remote: remote)
        }
        if let localData = try? orderedComparisonData(local),
           let remoteData = try? orderedComparisonData(remote), localData == remoteData {
            return nil
        }
        // If either state cannot be encoded, do not silently choose or discard it.
        return Conflict(local: local, remote: remote)
    }

    private static func orderedComparisonData(_ game: Game) throws -> Data {
        var run = game.run
        // These seven fields were compared above using their actual collection
        // semantics. Empty only the copies: sortedKeys alone cannot stabilize
        // Sets or the Square-keyed foul map, which Codable writes as arrays.
        run.puzzle?.clueReveals.removeAll()
        run.puzzle?.obstacleBlockedDigits.removeAll()
        run.puzzle?.armedFlags.removeAll()
        run.puzzle?.bossTurn?.blockedDigits.removeAll()
        run.puzzle?.bossTurn?.blockedHandIndices.removeAll()
        run.puzzle?.bossTurn?.greyed.removeAll()
        run.puzzle?.bossTurn?.fouled.removeAll()
        let encoder = JSONEncoder()
        // The remaining dictionaries (runItemState/itemState) have String keys.
        // Every ordered array—including Hand, board, Pool and offers—is untouched.
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(run)
    }

    /// Shows a remote-only Book on the shelf without writing it locally.
    static func displayedRun() -> Game? {
        storage.displayedRun()
    }

    /// Continue always resumes the local authority. Remote-only data becomes
    /// local only after this explicit action succeeds durably.
    static func resumeRun() -> Game? {
        storage.resumeRun()
    }

    static func choose(_ choice: Conflict.Choice, from conflict: Conflict) -> Game? {
        storage.choose(choice, from: conflict)
    }

    static var hasRun: Bool { displayedRun() != nil }

    @discardableResult
    static func clearRun(publishToCloud: Bool = true) -> Bool {
        storage.clearRun(publishToCloud: publishToCloud)
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

    static var booksCompleted: Int { progress().completedBooks.count }

    /// Only finishing this Book on a harder obstacle advances its own ladder.
    /// Replaying the same obstacle cannot increment it again.
    @discardableResult
    static func recordBookCompleted(_ book: Book, obstacle: Obstacle) -> Bool {
        storage.recordBookCompleted(book, obstacle: obstacle)
    }
}
