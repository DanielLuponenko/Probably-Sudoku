import Foundation
import GameKit
import Observation
import ProbablySudokuEngine
import UIKit

/// The app's deliberately quiet relationship with Game Center.
///
/// A Book never depends on this service. Authentication, dashboard presentation,
/// and score delivery can all fail without changing the local game or save.
/// Scores remain queued until GameKit accepts them, which makes an offline
/// finish indistinguishable from an online one to the player.
@MainActor
@Observable
final class GameCenterService {

    enum Leaderboard: String, CaseIterable {
        case highestPuzzleScore = "com.numberclub.app.highest_puzzle_score"
        case highestLevelReached = "com.numberclub.app.highest_level_reached"
        case booksCompleted = "com.numberclub.app.books_completed"
    }

    // Only the live singleton reads saved progress. Injected test services have
    // no history provider and never reach the player's profile, run, or cloud.
    static let shared = GameCenterService(historyProvider: {
        HistoricalProgress(profile: PlayerProfileStore.shared.profile,
                           progress: RunStore.progress(), run: RunStore.loadRun())
    })

    /// A pure projection of existing facts, not a way to earn local progress.
    struct HistoricalProgress {
        let scores: [Leaderboard: Int]
        let achievementIDs: Set<String>

        init(profile: PlayerProfile, progress: RunStore.Progress, run: Game?) {
            achievementIDs = Set(profile.earnedAchievementIDs.compactMap {
                guard let definition = AchievementCatalog.definition(for: $0),
                      definition.isRegisteredWithGameCenter else { return nil }
                return definition.gameCenterID
            })
            var scores: [Leaderboard: Int] = [:]
            let reachedLevel = profile.achievementProgress.highestLevelReached
            // Every fresh profile defaults to Level 1; that is not proof that
            // its player began a Puzzle. Never publish that default alone.
            if (2...9).contains(reachedLevel) { scores[.highestLevelReached] = reachedLevel }
            if let puzzle = run?.puzzle, (1...9).contains(puzzle.level) {
                scores[.highestLevelReached] = max(scores[.highestLevelReached] ?? 0, puzzle.level)
            }
            if let best = run?.run.bestPuzzleScore, best > 0 {
                // The engine records this exact value only when cashing out.
                // Neither an achievement threshold nor an unfinished score is
                // an authoritative replacement for a missing historical best.
                scores[.highestPuzzleScore] = best
                scores[.highestLevelReached] = max(scores[.highestLevelReached] ?? 0, 1)
            }
            var completion = profile.achievementProgress
            completion.merge(localProgress: progress)
            let completedBooks = Book.allCases.filter {
                (completion.completedObstacles[$0.rawValue] ?? 0) > 0
            }.count
            if completedBooks > 0 { scores[.booksCompleted] = completedBooks }
            self.scores = scores
        }
    }

    enum Dashboard: Equatable { case leaderboards, achievements }
    /// `requested` means a dashboard or a needed authentication screen was requested.
    enum DashboardResult: Equatable { case requested, signInRequired, unavailable }

    /// Diagnostics omit player identity and NSError userInfo.
    struct ServiceIssue: Equatable, Sendable {
        let domain: String
        let code: Int

        init(_ error: Error) {
            let error = error as NSError
            domain = error.domain
            code = error.code
        }
    }

    private enum StorageKey {
        static let pendingScores = "game-center.pending-scores.v1"
        static let pendingAchievements = "game-center.pending-achievements.v1"
    }

    private(set) var isAuthenticated = false
    private(set) var authenticationIssue: ServiceIssue?
    private(set) var scoreDeliveryIssue: ServiceIssue?
    private(set) var achievementDeliveryIssue: ServiceIssue?
    var pendingDeliveryCount: Int {
        pendingScores.count + pendingAchievementIDs.intersection(AchievementCatalog.registeredGameCenterIDs).count
    }
    var isDelivering: Bool { isFlushing || isFlushingAchievements }
    private var hasStarted = false
    private var appIsActive = true
    private var isFlushing = false
    private var pendingScores: [String: Int]
    private var pendingAchievementIDs: Set<String>
    private var isFlushingAchievements = false
    private var enqueuedHistoricalScores: [Leaderboard: Int] = [:]
    private var enqueuedHistoricalAchievements: Set<String> = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let client: any GameCenterClient
    @ObservationIgnored private let historyProvider: (() -> HistoricalProgress)?

    init(defaults: UserDefaults = .standard, client: (any GameCenterClient)? = nil,
         historyProvider: (() -> HistoricalProgress)? = nil) {
        self.defaults = defaults
        self.client = client ?? AppleGameCenterClient()
        self.historyProvider = historyProvider
        let storedScores = defaults.dictionary(forKey: StorageKey.pendingScores)
            as? [String: Int] ?? [:]
        let storedAchievements = Set(defaults.stringArray(forKey: StorageKey.pendingAchievements) ?? [])
        pendingScores = Self.normalizedPendingScores(storedScores)
        pendingAchievementIDs = Self.normalizedPendingAchievements(storedAchievements)
        // Keep the v1 shapes readable by older builds. A retry or a later
        // downgrade/re-upgrade can only preserve or raise each queued score.
        if pendingScores != storedScores { persistPendingScores() }
        if pendingAchievementIDs != storedAchievements { persistPendingAchievements() }
    }

    static func normalizedPendingScores(_ scores: [String: Int]) -> [String: Int] {
        scores.reduce(into: [:]) { result, entry in
            let identifier = Leaderboard.allCases.first {
                $0.rawValue.replacingOccurrences(of: "_", with: "-") == entry.key
            }?.rawValue ?? entry.key
            result[identifier] = result[identifier].map { max($0, entry.value) } ?? entry.value
        }
    }

    static func normalizedPendingAchievements(_ identifiers: Set<String>) -> Set<String> {
        Set(identifiers.map(normalizedAchievementID))
    }

    static func normalizedAchievementID(_ identifier: String) -> String {
        // Do not normalize arbitrary keys or local award IDs: only aliases
        // actually emitted by our earlier catalog are part of this migration.
        AchievementCatalog.all.first {
            "com.numberclub.app.achievement.\($0.id)" == identifier
        }?.gameCenterID ?? identifier
    }

    /// Starts GameKit after the first frame has been composed. We deliberately
    /// retain, but never automatically present, GameKit's sign-in controller:
    /// signed-out remains a complete, no-nag game state.
    func start() {
        client.hideAccessPoint()
        guard !hasStarted else { return }
        hasStarted = true
        client.startAuthentication { [weak self] issue in
            self?.authenticationIssue = issue
            self?.refreshAuthentication()
        }
        refreshAuthentication()
    }

    func setAppIsActive(_ active: Bool) {
        let becameActive = active && !appIsActive
        appIsActive = active
        client.hideAccessPoint()
        // Retry failed offline deliveries once on return, without waiting for
        // another gameplay/authentication event or starting a polling loop.
        if becameActive && hasStarted { refreshAuthentication() }
    }

    /// A user action, not a launch prompt. Signed-out play remains complete.
    @discardableResult
    func openDashboard(_ dashboard: Dashboard) -> DashboardResult {
        client.hideAccessPoint()
        isAuthenticated = client.isAuthenticated
        guard appIsActive else { return .unavailable }
        guard isAuthenticated else { return client.presentAuthentication() }
        guard client.presentDashboard(dashboard) else { return .unavailable }
        return .requested
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

    /// Game Center is a delivery target, not achievement truth. Local profile
    /// state earns first; the identifier remains queued while signed out or
    /// while delivery is unavailable. Unregistered awards stay in the local
    /// profile and are picked up by history backfill after registration.
    func recordAchievement(_ identifier: String) {
        let normalized = Self.normalizedAchievementID(identifier)
        guard AchievementCatalog.registeredGameCenterIDs.contains(normalized) else { return }
        pendingAchievementIDs.insert(normalized)
        persistPendingAchievements()
        flushPendingAchievements()
    }

    private func refreshAuthentication() {
        isAuthenticated = client.isAuthenticated
        if isAuthenticated { authenticationIssue = nil }
        client.hideAccessPoint()
        enqueueHistoricalProgress()
        flushPendingScores()
        flushPendingAchievements()
    }

    private func enqueueHistoricalProgress() {
        guard let history = historyProvider?() else { return }
        var scoresChanged = false
        for (leaderboard, value) in history.scores where value > (enqueuedHistoricalScores[leaderboard] ?? 0) {
            enqueuedHistoricalScores[leaderboard] = value
            let key = leaderboard.rawValue
            if value > (pendingScores[key] ?? 0) {
                pendingScores[key] = value
                scoresChanged = true
            }
        }
        let newAchievements = history.achievementIDs.subtracting(enqueuedHistoricalAchievements)
        enqueuedHistoricalAchievements.formUnion(newAchievements)
        let previousAchievements = pendingAchievementIDs
        pendingAchievementIDs.formUnion(newAchievements)
        // Persist the complete batch before any request can clear an accepted
        // value. Keep the v1 queue shapes for downgrade/re-upgrade safety; the
        // profile/run remain untouched. Each launch can safely replay history,
        // while repeated foreground/auth callbacks enqueue only newly seen facts.
        if scoresChanged { persistPendingScores() }
        if pendingAchievementIDs != previousAchievements { persistPendingAchievements() }
    }

    private func flushPendingScores() {
        guard client.isAuthenticated,
              !pendingScores.isEmpty,
              !isFlushing else { return }

        isFlushing = true
        scoreDeliveryIssue = nil
        let snapshot = pendingScores
        Task { @MainActor [weak self] in
            guard let self else { return }
            for (identifier, score) in snapshot.sorted(by: { $0.key < $1.key }) {
                guard self.client.isAuthenticated else { break }
                do {
                    try await self.client.submitScore(score, leaderboardID: identifier)
                    if self.pendingScores[identifier] == score {
                        self.pendingScores.removeValue(forKey: identifier)
                        self.persistPendingScores()
                    }
                } catch {
                    self.scoreDeliveryIssue = ServiceIssue(error)
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
            // for the next foreground, authentication or gameplay event, not a hot loop.
            if hasNewerScores { self.flushPendingScores() }
        }
    }

    private func persistPendingScores() {
        defaults.set(pendingScores, forKey: StorageKey.pendingScores)
    }

    private func flushPendingAchievements() {
        // Preserve unfamiliar legacy queue entries for forward compatibility,
        // but never send them in a batch with Apple's registered awards.
        let snapshot = pendingAchievementIDs.intersection(AchievementCatalog.registeredGameCenterIDs)
        guard client.isAuthenticated,
              !snapshot.isEmpty,
              !isFlushingAchievements else { return }

        isFlushingAchievements = true
        achievementDeliveryIssue = nil
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await self.client.reportAchievements(snapshot.sorted())
                self.pendingAchievementIDs.subtract(snapshot)
                self.persistPendingAchievements()
            } catch {
                self.achievementDeliveryIssue = ServiceIssue(error)
                // Keep queued; outage and incomplete App Store Connect setup
                // must never change the local achievement page.
            }
            let hasNewerAchievements = !self.pendingAchievementIDs
                .intersection(AchievementCatalog.registeredGameCenterIDs).isSubset(of: snapshot)
            self.isFlushingAchievements = false
            if hasNewerAchievements { self.flushPendingAchievements() }
        }
    }

    private func persistPendingAchievements() {
        defaults.set(pendingAchievementIDs.sorted(), forKey: StorageKey.pendingAchievements)
    }
}

/// Tests replace this boundary and never report invented progress to GameKit.
@MainActor
protocol GameCenterClient: AnyObject {
    var isAuthenticated: Bool { get }
    func startAuthentication(onChange: @escaping @MainActor (GameCenterService.ServiceIssue?) -> Void)
    func hideAccessPoint()
    func presentAuthentication() -> GameCenterService.DashboardResult
    func presentDashboard(_ dashboard: GameCenterService.Dashboard) -> Bool
    func submitScore(_ score: Int, leaderboardID: String) async throws
    func reportAchievements(_ identifiers: [String]) async throws
}

@MainActor
private final class AppleGameCenterClient: GameCenterClient {
    private var isOpeningDashboard = false
    private var authenticationViewController: UIViewController?
    private weak var presentedAuthenticationViewController: UIViewController?
    private var isOpeningAuthentication = false
    var isAuthenticated: Bool { GKLocalPlayer.local.isAuthenticated }

    func startAuthentication(onChange: @escaping @MainActor (GameCenterService.ServiceIssue?) -> Void) {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            Task { @MainActor in
                self?.authenticationViewController = controller
                onChange(error.map(GameCenterService.ServiceIssue.init))
            }
        }
    }

    func hideAccessPoint() {
        GKAccessPoint.shared.isActive = false
    }

    func presentAuthentication() -> GameCenterService.DashboardResult {
        guard let controller = authenticationViewController else { return .signInRequired }
        guard !isOpeningDashboard, !isPresentingAuthentication,
              !GKAccessPoint.shared.isPresentingGameCenter,
              let window = foregroundWindow(),
              let presenter = stableTopmostController(from: window.rootViewController),
              presenter.viewIfLoaded?.window != nil,
              controller.presentingViewController == nil,
              !controller.isBeingPresented, !controller.isBeingDismissed else { return .unavailable }
        isOpeningAuthentication = true
        presentedAuthenticationViewController = controller
        presenter.present(controller, animated: true) { [weak self] in
            self?.isOpeningAuthentication = false
        }
        // No queued dashboard destination: after sign-in and dismissal, the
        // player can explicitly open either dashboard with another tap.
        return .requested
    }

    func presentDashboard(_ dashboard: GameCenterService.Dashboard) -> Bool {
        let accessPoint = GKAccessPoint.shared
        guard isAuthenticated, !isOpeningDashboard, !isPresentingAuthentication,
              !accessPoint.isPresentingGameCenter, let window = foregroundWindow(),
              stableTopmostController(from: window.rootViewController) != nil else { return false }
        accessPoint.isActive = false
        accessPoint.parentWindow = window
        isOpeningDashboard = true
        // The dashboard can be opened programmatically without its floating badge.
        accessPoint.trigger(state: dashboard == .leaderboards ? .leaderboards : .achievements) { [weak self] in
            Task { @MainActor in
                self?.isOpeningDashboard = false
                GKAccessPoint.shared.isActive = false
            }
        }
        return true
    }

    private var isPresentingAuthentication: Bool {
        isOpeningAuthentication || presentedAuthenticationViewController.map {
            $0.presentingViewController != nil || $0.isBeingPresented || $0.isBeingDismissed
        } == true
    }

    private func foregroundWindow() -> UIWindow? {
        guard UIApplication.shared.applicationState == .active else { return nil }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow)
    }

    private func stableTopmostController(from controller: UIViewController?) -> UIViewController? {
        guard let controller, !controller.isBeingPresented, !controller.isBeingDismissed else { return nil }
        if let presented = controller.presentedViewController {
            return stableTopmostController(from: presented)
        }
        if let navigation = controller as? UINavigationController {
            return stableTopmostController(from: navigation.visibleViewController)
        }
        if let tabs = controller as? UITabBarController {
            return stableTopmostController(from: tabs.selectedViewController)
        }
        return controller is UIAlertController ? nil : controller
    }

    func submitScore(_ score: Int, leaderboardID: String) async throws {
        try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                            leaderboardIDs: [leaderboardID])
    }

    func reportAchievements(_ identifiers: [String]) async throws {
        let achievements = identifiers.map { identifier in
            let achievement = GKAchievement(identifier: identifier)
            achievement.percentComplete = 100
            return achievement
        }
        try await GKAchievement.report(achievements)
    }
}
