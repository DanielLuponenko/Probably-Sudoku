import Foundation
import Observation

/// The only SDK seam: consent, one loaded ad, and its presentation callbacks.
/// Tests use an in-memory adapter; gameplay never imports Google's SDK.
@MainActor
protocol RewardedAdAdapter: AnyObject {
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    var canPresent: Bool { get }
    func updateConsent() async throws
    func loadRequiredConsent() async throws
    func presentRequiredConsent() async throws
    func presentPrivacyOptions() async throws
    func loadAd() async throws -> any RewardedAdHandle
}

@MainActor
protocol RewardedAdHandle: AnyObject {
    func present(onReward: @escaping @MainActor () -> Void,
                 onDismiss: @escaping @MainActor () -> Void,
                 onFailure: @escaping @MainActor (Error) -> Void) throws
}

@MainActor
@Observable
final class RewardedAdService {
    enum State: Equatable {
        case idle
        case preparing
        case ready
        case presenting
        case unavailable(String)
    }

    static let shared = RewardedAdService(adapter: GoogleRewardedAdAdapter())
    /// Deliberately not conditional on DEBUG: TestFlight/Release are test ads too.
    static let demoAppID = "ca-app-pub-3940256099942544~1458002511"
    static let demoRewardedID = "ca-app-pub-3940256099942544/1712485313"
    static let cacheLifetime: TimeInterval = 55 * 60

    private(set) var state: State = .idle
    private(set) var privacyOptionsRequired = false
    private(set) var isPresentingPrivacyOptions = false
    private(set) var lastError: String?

    @ObservationIgnored private let adapter: any RewardedAdAdapter
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let networkTimeout: Duration
    @ObservationIgnored private var ad: (any RewardedAdHandle)?
    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var preparationID: UUID?
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var preparationCompletion: (() -> Void)?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var presentationID: UUID?
    @ObservationIgnored private var earnedReward = false
    @ObservationIgnored private var rewardCallback: (@MainActor () -> Void)?
    @ObservationIgnored private var dismissalCallback: (@MainActor () -> Void)?

    init(adapter: any RewardedAdAdapter, now: @escaping () -> Date = Date.init,
         networkTimeout: Duration = .seconds(45)) {
        self.adapter = adapter
        self.now = now
        self.networkTimeout = networkTimeout
        self.privacyOptionsRequired = adapter.privacyOptionsRequired
    }

    var isReady: Bool {
        guard state == .ready, ad != nil, let loadedAt else { return false }
        return now().timeIntervalSince(loadedAt) < Self.cacheLifetime && adapter.canRequestAds
    }

    var isPresenting: Bool { state == .presenting }

    /// Call only from the live, eligible results page, never from launch or a
    /// frozen page-flip snapshot. Cancellation invalidates late SDK completions.
    func prepare() async {
        await startPreparation(privacyOnly: false)
    }

    /// Safe for Settings on relaunch: updates UMP and the privacy entry point,
    /// but does not show a form, initialize the ads SDK, or request an ad.
    func refreshPrivacyStatus() async {
        await startPreparation(privacyOnly: true)
    }

    private func startPreparation(privacyOnly: Bool) async {
        guard !Task.isCancelled, preparationID == nil, !isPresenting,
              !isPresentingPrivacyOptions else { return }
        if !privacyOnly && isReady { return }
        discardAd()
        guard privacyOnly || adapter.canPresent else {
            state = .unavailable("Return to the game to load a video.")
            return
        }
        let id = UUID()
        preparationID = id
        state = .preparing
        lastError = nil
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                preparationCompletion = { continuation.resume() }
                preparationTask = Task { [weak self] in
                    await self?.prepareAd(id: id, privacyOnly: privacyOnly)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelPreparation(id: id) }
        }
    }

    func cancelPreparation() {
        if let id = preparationID { cancelPreparation(id: id) }
    }

    /// False means no presentation was accepted and neither callback is owed.
    /// Once accepted, dismissal/failure invokes onDismiss exactly once. Only
    /// Google's earned callback invokes onReward, synchronously on MainActor.
    @discardableResult
    func present(onReward: @escaping @MainActor () -> Void,
                 onDismiss: @escaping @MainActor () -> Void) -> Bool {
        guard !isPresenting, !isPresentingPrivacyOptions, preparationID == nil else { return false }
        guard isReady, let ad else {
            discardAd()
            state = .unavailable("The video is not ready. Try again.")
            return false
        }
        guard adapter.canPresent else { return false }
        let id = UUID()
        presentationID = id
        earnedReward = false
        rewardCallback = onReward
        dismissalCallback = onDismiss
        expiryTask?.cancel()
        state = .presenting
        do {
            try ad.present(onReward: { [weak self] in
                guard let self, self.presentationID == id, !self.earnedReward else { return }
                self.earnedReward = true
                self.rewardCallback?()
            }, onDismiss: { [weak self] in
                self?.finishPresentation(id: id, error: nil)
            }, onFailure: { [weak self] error in
                self?.finishPresentation(id: id, error: error)
            })
            return true
        } catch {
            presentationID = nil
            rewardCallback = nil
            dismissalCallback = nil
            discardAd()
            lastError = error.localizedDescription
            state = .unavailable("The video could not open. Try again.")
            return false
        }
    }

    /// User-initiated Settings action. A changed choice invalidates cached ads;
    /// another explicit prepare is required before any subsequent ad request.
    func presentPrivacyOptions() async {
        guard preparationID == nil, !isPresenting, !isPresentingPrivacyOptions,
              privacyOptionsRequired, adapter.canPresent else { return }
        discardAd()
        state = .idle
        isPresentingPrivacyOptions = true
        defer {
            isPresentingPrivacyOptions = false
            privacyOptionsRequired = adapter.privacyOptionsRequired
        }
        do {
            try await adapter.presentPrivacyOptions()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            state = .unavailable("Privacy options could not open. Try again.")
        }
    }

    private func prepareAd(id: UUID, privacyOnly: Bool) async {
        do {
            startTimeout(id: id)
            do {
                try await adapter.updateConsent()
            } catch {
                guard preparationID == id else { return }
                lastError = error.localizedDescription
                // UMP explicitly allows a still-valid previous-session choice
                // after update failure. Never infer consent in app storage.
                guard adapter.canRequestAds else { throw error }
            }
            guard preparationID == id, !Task.isCancelled else { return }
            privacyOptionsRequired = adapter.privacyOptionsRequired
            if privacyOnly {
                finishPreparation(id: id, state: .idle)
                return
            }
            startTimeout(id: id)
            try await adapter.loadRequiredConsent()
            guard preparationID == id, !Task.isCancelled else { return }
            timeoutTask?.cancel()
            // Do not impose a timeout on a person's consent decision.
            try await adapter.presentRequiredConsent()
            guard preparationID == id, !Task.isCancelled else { return }
            privacyOptionsRequired = adapter.privacyOptionsRequired
            guard adapter.canRequestAds else {
                finishPreparation(id: id, state: .unavailable("A video is not available with the current privacy settings."))
                return
            }
            startTimeout(id: id)
            let loaded = try await adapter.loadAd()
            guard preparationID == id, !Task.isCancelled else { return }
            guard adapter.canRequestAds else {
                finishPreparation(id: id, state: .unavailable("Privacy settings changed. Try again."))
                return
            }
            ad = loaded
            loadedAt = now()
            finishPreparation(id: id, state: .ready)
            expiryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.cacheLifetime))
                guard !Task.isCancelled, let self, self.state == .ready else { return }
                self.discardAd()
                self.state = .idle
            }
        } catch {
            guard preparationID == id else { return }
            lastError = error.localizedDescription
            privacyOptionsRequired = adapter.privacyOptionsRequired
            finishPreparation(id: id, state: .unavailable("No video is available right now. Try again later."))
        }
    }

    private func startTimeout(id: UUID) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, networkTimeout] in
            try? await Task.sleep(for: networkTimeout)
            guard !Task.isCancelled, let self, self.preparationID == id else { return }
            self.lastError = "Ad preparation network timeout"
            self.finishPreparation(id: id, state: .unavailable("The video took too long to load. Try again."))
        }
    }

    private func cancelPreparation(id: UUID) {
        finishPreparation(id: id, state: .idle)
    }

    private func finishPreparation(id: UUID, state: State) {
        guard preparationID == id else { return }
        preparationID = nil
        timeoutTask?.cancel()
        timeoutTask = nil
        preparationTask?.cancel()
        preparationTask = nil
        self.state = state
        let completion = preparationCompletion
        preparationCompletion = nil
        completion?()
    }

    private func finishPresentation(id: UUID, error: Error?) {
        guard presentationID == id else { return }
        presentationID = nil
        rewardCallback = nil
        let dismissal = dismissalCallback
        dismissalCallback = nil
        discardAd()
        if let error {
            lastError = error.localizedDescription
            state = .unavailable("The video could not play. Try again.")
        } else {
            state = .idle
        }
        dismissal?()
    }

    private func discardAd() {
        expiryTask?.cancel()
        expiryTask = nil
        ad = nil
        loadedAt = nil
    }
}
