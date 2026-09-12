import Foundation
import Observation
import OSLog

/// The only SDK seam: consent, one loaded ad, and its presentation callbacks.
/// Tests use an in-memory adapter; gameplay never imports Google's SDK.
@MainActor
protocol RewardedAdAdapter: AnyObject {
    /// Pure build capability. Reading this must never initialize an SDK.
    var isEnabled: Bool { get }
    /// Pure validation, before reading consent state or contacting either SDK.
    func validateConfiguration() throws
    var canRequestAds: Bool { get }
    var privacyOptionsRequired: Bool { get }
    var canPresent: Bool { get }
    func updateConsent() async throws
    func loadRequiredConsent() async throws
    func presentRequiredConsent() async throws
    func presentPrivacyOptions() async throws
    func loadAd() async throws -> any RewardedAdHandle
}

extension RewardedAdAdapter {
    // Existing injected test adapters retain their enabled behavior.
    var isEnabled: Bool { true }
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
    private static let log = Logger(subsystem: "com.numberclub.app", category: "RewardedAds")

    private enum PreparationStage: String {
        case consentUpdate, consentForm, consentPresentation, adLoad

        var failureMessage: String {
            switch self {
            case .consentUpdate, .consentForm: return "Privacy choices could not load. Try again."
            case .consentPresentation: return "Privacy choices could not open. Try again."
            case .adLoad: return "The video could not load. Try again."
            }
        }
    }

    enum State: Equatable {
        case idle
        case preparing
        case ready
        case presenting
        case unavailable(String)
    }

    static let shared = RewardedAdService(adapter: makeAdapter(configuration: AdConfiguration.current),
                                         presentationChanged: { GameAudio.shared.setAdPresented($0) })

    /// Resolve the ad-free path before even constructing the Google adapter.
    /// A factory seam proves this ordering without linking either Google SDK.
    static func makeAdapter(configuration: Result<AdConfiguration, Error>,
                            enabledAdapter: @MainActor (Result<AdConfiguration, Error>) -> any RewardedAdAdapter = { configuration in
                                #if NUMBERCLUB_AD_FREE
                                // This target does not link Google. Even wrong
                                // bundle metadata cannot introduce an SDK path.
                                DisabledRewardedAdAdapter()
                                #else
                                GoogleRewardedAdAdapter(configuration: configuration)
                                #endif
                            }) -> any RewardedAdAdapter {
        if case let .success(value) = configuration, !value.isEnabled {
            return DisabledRewardedAdAdapter()
        }
        return enabledAdapter(configuration)
    }
    /// Routine development uses this pair. Only the Production device archive
    /// selects live IDs; the separate ad-free rollback target omits both SDKs.
    static let demoAppID = AdConfiguration.demoAppID
    static let demoRewardedID = AdConfiguration.demoRewardedID
    static let cacheLifetime: TimeInterval = 55 * 60

    private(set) var state: State = .idle
    private(set) var privacyOptionsRequired = false
    private(set) var isPresentingPrivacyOptions = false
    private(set) var lastError: String?

    @ObservationIgnored private let adapter: any RewardedAdAdapter
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let networkTimeout: Duration
    @ObservationIgnored private let presentationChanged: (Bool) -> Void
    @ObservationIgnored private var externalPresentationCount = 0
    @ObservationIgnored private var ad: (any RewardedAdHandle)?
    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var preparationID: UUID?
    @ObservationIgnored private var preparationCancellation: PreparationCancellation?
    @ObservationIgnored private var preparationTask: Task<Void, Never>?
    @ObservationIgnored private var preparationCompletion: (() -> Void)?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    @ObservationIgnored private var presentationID: UUID?
    @ObservationIgnored private var earnedReward = false
    @ObservationIgnored private var rewardCallback: (@MainActor () -> Void)?
    @ObservationIgnored private var dismissalCallback: (@MainActor () -> Void)?

    init(adapter: any RewardedAdAdapter, now: @escaping () -> Date = Date.init,
         networkTimeout: Duration = .seconds(45),
         presentationChanged: @escaping (Bool) -> Void = { _ in }) {
        self.adapter = adapter
        self.now = now
        self.networkTimeout = networkTimeout
        self.presentationChanged = presentationChanged
        if validateAdapterConfiguration(), adapter.isEnabled {
            self.privacyOptionsRequired = adapter.privacyOptionsRequired
        }
    }

    var isEnabled: Bool { adapter.isEnabled }

    var isReady: Bool {
        guard isEnabled, state == .ready, ad != nil, let loadedAt else { return false }
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
        guard isEnabled, !Task.isCancelled, !isPresenting,
              !isPresentingPrivacyOptions else { return }
        // A replacement view task can arrive before the canceled caller's
        // MainActor cleanup. Retire that request now instead of dropping retry.
        if let id = preparationID, preparationCancellation?.isCancelled == true {
            cancelPreparation(id: id)
        }
        guard preparationID == nil else { return }
        guard validateAdapterConfiguration() else { return }
        if !privacyOnly && isReady { return }
        discardAd()
        guard privacyOnly || adapter.canPresent else {
            state = .unavailable("Return to the game to load a video.")
            return
        }
        let id = UUID()
        let cancellation = PreparationCancellation()
        preparationID = id
        preparationCancellation = cancellation
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
            cancellation.cancel()
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
        guard isEnabled, !isPresenting, !isPresentingPrivacyOptions, preparationID == nil else { return false }
        guard validateAdapterConfiguration() else { return false }
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
        Self.log.notice("Presenting rewarded video")
        beginExternalPresentation()
        do {
            try ad.present(onReward: { [weak self] in
                guard let self, self.presentationID == id, !self.earnedReward else { return }
                self.earnedReward = true
                Self.log.notice("Reward earned")
                self.rewardCallback?()
            }, onDismiss: { [weak self] in
                self?.finishPresentation(id: id, error: nil)
            }, onFailure: { [weak self] error in
                self?.finishPresentation(id: id, error: error)
            })
            return true
        } catch {
            // A synchronous SDK failure never owns the app's audio session.
            if presentationID == id { endExternalPresentation() }
            presentationID = nil
            rewardCallback = nil
            dismissalCallback = nil
            discardAd()
            recordFailure(error, context: "presentation")
            state = .unavailable("The video could not open. Try again.")
            return false
        }
    }

    /// User-initiated Settings action. A changed choice invalidates cached ads;
    /// another explicit prepare is required before any subsequent ad request.
    func presentPrivacyOptions() async {
        guard isEnabled else { return }
        guard validateAdapterConfiguration() else { return }
        guard preparationID == nil, !isPresenting, !isPresentingPrivacyOptions,
              privacyOptionsRequired, adapter.canPresent else { return }
        discardAd()
        state = .idle
        isPresentingPrivacyOptions = true
        beginExternalPresentation()
        defer {
            endExternalPresentation()
            isPresentingPrivacyOptions = false
            privacyOptionsRequired = adapter.privacyOptionsRequired
        }
        do {
            try await adapter.presentPrivacyOptions()
            lastError = nil
        } catch {
            recordFailure(error, context: "privacyOptions")
            state = .unavailable("Privacy options could not open. Try again.")
        }
    }

    private func prepareAd(id: UUID, privacyOnly: Bool) async {
        guard isCurrentPreparation(id) else { return }
        var stage = PreparationStage.consentUpdate
        do {
            startTimeout(id: id, stage: stage)
            do {
                try await adapter.updateConsent()
            } catch {
                guard isCurrentPreparation(id) else { return }
                recordFailure(error, context: stage.rawValue)
                // UMP explicitly allows a still-valid previous-session choice
                // after update failure. Never infer consent in app storage.
                guard adapter.canRequestAds else { throw error }
            }
            guard isCurrentPreparation(id) else { return }
            privacyOptionsRequired = adapter.privacyOptionsRequired
            if privacyOnly {
                finishPreparation(id: id, state: .idle)
                return
            }
            stage = .consentForm
            startTimeout(id: id, stage: stage)
            try await adapter.loadRequiredConsent()
            guard isCurrentPreparation(id) else { return }
            timeoutTask?.cancel()
            // Do not impose a timeout on a person's consent decision.
            stage = .consentPresentation
            try await presentConsentWithAudioSuspended()
            guard isCurrentPreparation(id) else { return }
            privacyOptionsRequired = adapter.privacyOptionsRequired
            guard adapter.canRequestAds else {
                finishPreparation(id: id, state: .unavailable("A video is not available with the current privacy settings."))
                return
            }
            stage = .adLoad
            startTimeout(id: id, stage: stage)
            let loaded = try await adapter.loadAd()
            guard isCurrentPreparation(id) else { return }
            guard adapter.canRequestAds else {
                finishPreparation(id: id, state: .unavailable("Privacy settings changed. Try again."))
                return
            }
            ad = loaded
            loadedAt = now()
            lastError = nil
            Self.log.notice("Rewarded video loaded and ready")
            finishPreparation(id: id, state: .ready)
            expiryTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(Self.cacheLifetime))
                guard !Task.isCancelled, let self, self.state == .ready else { return }
                self.discardAd()
                self.state = .idle
            }
        } catch {
            guard isCurrentPreparation(id) else { return }
            recordFailure(error, context: stage.rawValue)
            privacyOptionsRequired = adapter.privacyOptionsRequired
            let failure = RewardedAdFailure.classify(error, fallback: stage.failureMessage)
            finishPreparation(id: id, state: .unavailable(failure.playerMessage))
        }
    }

    private func validateAdapterConfiguration() -> Bool {
        do {
            try adapter.validateConfiguration()
            return true
        } catch {
            discardAd()
            privacyOptionsRequired = false
            recordFailure(error, context: "configuration")
            state = .unavailable("Video ads are unavailable in this build.")
            return false
        }
    }

    private func presentConsentWithAudioSuspended() async throws {
        beginExternalPresentation()
        defer { endExternalPresentation() }
        try await adapter.presentRequiredConsent()
    }

    /// Runs synchronously before the SDK takes over, not in a later SwiftUI
    /// observation pass. The count also keeps audio paused if a canceled
    /// preparation's consent form is still finishing its dismissal.
    private func beginExternalPresentation() {
        externalPresentationCount += 1
        if externalPresentationCount == 1 { presentationChanged(true) }
    }

    private func endExternalPresentation() {
        guard externalPresentationCount > 0 else { return }
        externalPresentationCount -= 1
        if externalPresentationCount == 0 { presentationChanged(false) }
    }

    /// Keep SDK details in local diagnostics, never in the player's message.
    private func recordFailure(_ error: Error, context: String) {
        let original = ((error as? RewardedAdFailure)?.underlyingError ?? error) as NSError
        lastError = "\(context): \(original.domain) (\(original.code)): \(original.localizedDescription)"
        Self.log.error("\(context, privacy: .public): \(original.domain, privacy: .public) (\(original.code)): \(original.localizedDescription, privacy: .private)")
    }

    private func startTimeout(id: UUID, stage: PreparationStage) {
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self, networkTimeout] in
            try? await Task.sleep(for: networkTimeout)
            guard !Task.isCancelled, let self, self.isCurrentPreparation(id) else { return }
            let error = URLError(.timedOut)
            self.recordFailure(error, context: stage.rawValue)
            self.finishPreparation(id: id, state: .unavailable(
                RewardedAdFailure.classify(error, fallback: stage.failureMessage).playerMessage))
        }
    }

    private func cancelPreparation(id: UUID) {
        finishPreparation(id: id, state: .idle)
    }

    private func isCurrentPreparation(_ id: UUID) -> Bool {
        preparationID == id && preparationCancellation?.isCancelled == false && !Task.isCancelled
    }

    private func finishPreparation(id: UUID, state: State) {
        guard preparationID == id else { return }
        preparationID = nil
        preparationCancellation = nil
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
        endExternalPresentation()
        presentationID = nil
        rewardCallback = nil
        let dismissal = dismissalCallback
        dismissalCallback = nil
        discardAd()
        if let error {
            recordFailure(error, context: "playback")
            state = .unavailable("The video could not play. Try again.")
        } else {
            Self.log.notice("Rewarded video dismissed")
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

/// Cancellation handlers run outside MainActor. Publish only this signal
/// synchronously; request ownership and SDK cleanup stay on the actor.
private final class PreparationCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false

    var isCancelled: Bool { lock.withLock { cancelled } }

    func cancel() { lock.withLock { cancelled = true } }
}

/// No Google imports, consent reads, requests, notifications or preload work.
/// Defensive throwing methods also prevent direct callers from requesting ads.
@MainActor
private final class DisabledRewardedAdAdapter: RewardedAdAdapter {
    private enum Disabled: Error { case adsUnavailable }
    var isEnabled: Bool { false }
    var canRequestAds: Bool { false }
    var privacyOptionsRequired: Bool { false }
    var canPresent: Bool { false }
    func validateConfiguration() {}
    func updateConsent() async throws { throw Disabled.adsUnavailable }
    func loadRequiredConsent() async throws { throw Disabled.adsUnavailable }
    func presentRequiredConsent() async throws { throw Disabled.adsUnavailable }
    func presentPrivacyOptions() async throws { throw Disabled.adsUnavailable }
    func loadAd() async throws -> any RewardedAdHandle { throw Disabled.adsUnavailable }
}
