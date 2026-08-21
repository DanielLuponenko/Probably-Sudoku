import Foundation
import GameKit
import Observation

/// The app's deliberately quiet relationship with Game Center.
///
/// A Book never depends on this service. Authentication, access-point state,
/// and score delivery can all fail without changing the local game or save.
/// Scores remain queued until GameKit accepts them, which makes an offline
/// finish indistinguishable from an online one to the player.
@MainActor
@Observable
final class GameCenterService {

    enum Leaderboard: String, CaseIterable {
        case highestPuzzleScore = "com.numberclub.app.highest-puzzle-score"
        case highestLevelReached = "com.numberclub.app.highest-level-reached"
        case booksCompleted = "com.numberclub.app.books-completed"
    }

    static let shared = GameCenterService()

    private enum StorageKey {
        static let pendingScores = "game-center.pending-scores.v1"
    }

    private(set) var isAuthenticated = false
    private var hasStarted = false
    private var appIsActive = true
    private var wantsAccessPoint = true
    private var isFlushing = false
    private var pendingScores: [String: Int]

    private init() {
        pendingScores = UserDefaults.standard.dictionary(forKey: StorageKey.pendingScores)
            as? [String: Int] ?? [:]
    }

    /// Starts GameKit after the first frame has been composed. We deliberately
    /// ignore the view controller GameKit supplies for sign-in: signed-out is a
    /// complete, no-nag game state and the player can sign in from Settings.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] _, _ in
            Task { @MainActor in self?.refreshAuthentication() }
        }
        refreshAuthentication()
    }

    func setAppIsActive(_ active: Bool) {
        appIsActive = active
        updateAccessPoint()
    }

    /// The shelf and club room can host the Game Center control. A Book cannot:
    /// its pages own every corner while a Puzzle is in progress.
    func setAccessPointVisible(_ visible: Bool) {
        wantsAccessPoint = visible
        updateAccessPoint()
    }

    /// Queues the best value for a board. Values only ever move upward, so a
    /// replay or a second callback cannot lower a published score.
    func record(_ value: Int, for leaderboard: Leaderboard) {
        guard value > 0 else { return }
        let key = leaderboard.rawValue
        pendingScores[key] = max(value, pendingScores[key] ?? 0)
        persistPendingScores()
        flushPendingScores()
    }

    private func refreshAuthentication() {
        isAuthenticated = GKLocalPlayer.local.isAuthenticated
        updateAccessPoint()
        flushPendingScores()
    }

    private func updateAccessPoint() {
        let accessPoint = GKAccessPoint.shared
        // Bottom-leading leaves the Start shelf's title, gear, and main actions
        // untouched. GameKit supplies the actual accessible control.
        accessPoint.location = .bottomLeading
        accessPoint.isActive = isAuthenticated && appIsActive && wantsAccessPoint
    }

    private func flushPendingScores() {
        guard GKLocalPlayer.local.isAuthenticated,
              !pendingScores.isEmpty,
              !isFlushing else { return }

        isFlushing = true
        let snapshot = pendingScores
        Task { @MainActor [weak self] in
            guard let self else { return }
            for (identifier, score) in snapshot.sorted(by: { $0.key < $1.key }) {
                do {
                    try await GKLeaderboard.submitScore(
                        score,
                        context: 0,
                        player: GKLocalPlayer.local,
                        leaderboardIDs: [identifier]
                    )
                    if self.pendingScores[identifier] == score {
                        self.pendingScores.removeValue(forKey: identifier)
                        self.persistPendingScores()
                    }
                } catch {
                    // Offline, signed out, unconfigured App Store Connect, and
                    // service failures all remain queued and invisible here.
                }
            }
            let hasNewerScores = self.pendingScores.contains { identifier, score in
                snapshot[identifier] != score
            }
            self.isFlushing = false
            // Retry only if a newer score arrived while this snapshot was in
            // flight. A failed offline/unconfigured submission remains queued
            // for the next authentication or gameplay event, not a hot loop.
            if hasNewerScores { self.flushPendingScores() }
        }
    }

    private func persistPendingScores() {
        UserDefaults.standard.set(pendingScores, forKey: StorageKey.pendingScores)
    }
}
