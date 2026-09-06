#if !NUMBERCLUB_AD_FREE
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

@MainActor
final class GoogleRewardedAdAdapter: RewardedAdAdapter {
    private let configuration: Result<AdConfiguration, Error>
    private var hasStartedSDK = false
    private var initializationTask: Task<Void, Never>?
    private var isShowingConsentForm = false
    private var consentForm: ConsentForm?

    init(configuration: Result<AdConfiguration, Error> = AdConfiguration.current) {
        self.configuration = configuration
    }

    func validateConfiguration() throws {
        _ = try enabledConfiguration()
    }

    var isEnabled: Bool { (try? configuration.get().isEnabled) == true }

    private func enabledConfiguration() throws -> AdConfiguration {
        let value = try configuration.get()
        guard value.isEnabled else { throw PresentationError.adsDisabled }
        return value
    }

    var canRequestAds: Bool { isEnabled && ConsentInformation.shared.canRequestAds }
    var privacyOptionsRequired: Bool {
        isEnabled && ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    var canPresent: Bool {
        isEnabled && !isShowingConsentForm && UIApplication.shared.applicationState == .active &&
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .contains { scene in
                scene.activationState == .foregroundActive &&
                scene.windows.contains { $0.isKeyWindow && $0.rootViewController != nil }
            }
    }

    func updateConsent() async throws {
        try validateConfiguration()
        // No forced geography, saved-consent override, ATT request, or reset.
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
    }

    func loadRequiredConsent() async throws {
        try validateConfiguration()
        consentForm = nil
        guard ConsentInformation.shared.consentStatus == .required else { return }
        // Split loading from presentation so leaving the offer while the form
        // loads cannot make a consent sheet appear over the bookstore later.
        let form = try await ConsentForm.load()
        try Task.checkCancellation()
        consentForm = form
    }

    func presentRequiredConsent() async throws {
        try validateConfiguration()
        guard ConsentInformation.shared.consentStatus == .required else { return }
        guard let form = consentForm else { throw PresentationError.consentRequired }
        consentForm = nil
        try Task.checkCancellation()
        guard canPresent else { throw PresentationError.noForegroundWindow }
        isShowingConsentForm = true
        defer { isShowingConsentForm = false }
        try await form.present(from: nil)
    }

    func presentPrivacyOptions() async throws {
        try validateConfiguration()
        guard canPresent else { throw PresentationError.noForegroundWindow }
        isShowingConsentForm = true
        defer { isShowingConsentForm = false }
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    func loadAd() async throws -> any RewardedAdHandle {
        let configuration = try enabledConfiguration()
        guard canRequestAds else { throw PresentationError.consentRequired }
        if !hasStartedSDK {
            // Initialization can preload ads, so it belongs behind consent too.
            if initializationTask == nil {
                Self.configureRequestPrivacy(MobileAds.shared.requestConfiguration)
                initializationTask = Task { _ = await MobileAds.shared.start() }
            }
            await initializationTask?.value
            hasStartedSDK = true
            initializationTask = nil
        }
        try Task.checkCancellation()
        guard canRequestAds else { throw PresentationError.consentRequired }
        // Keep the actual SDK boundary safe even when a configuration was
        // injected for validation: Debug and simulators never request live ads.
        let runtime = AdConfiguration.Runtime.current
        let unitID = runtime.isDebug || runtime.isSimulator
            ? AdConfiguration.demoRewardedID : configuration.rewardedAdUnitID
        let ad = try await RewardedAd.load(with: unitID, request: Self.makeRequest())
        return GoogleRewardedAd(ad)
    }

    /// Apply before SDK start as initialization may preload ads. These are
    /// publisher restrictions, not inferred consent, age flags, or ATT approval.
    static func configureRequestPrivacy(_ settings: RequestConfiguration) {
        settings.setPublisherFirstPartyIDEnabled(false)
        settings.publisherPrivacyPersonalizationState = .disabled
        settings.maxAdContentRating = .general
    }

    /// NPA remains subject to UMP consent. Do not pass player IDs, saved games,
    /// Game Center aliases, custom targeting, or any other gameplay data.
    static func makeRequest() -> Request {
        let request = Request()
        let extras = Extras()
        extras.additionalParameters = ["npa": "1"]
        request.register(extras)
        return request
    }

    private enum PresentationError: Error {
        case adsDisabled
        case noForegroundWindow
        case consentRequired
    }
}

/// Retained by the service for the whole presentation (Google's delegate is weak).
@MainActor
private final class GoogleRewardedAd: NSObject, RewardedAdHandle, FullScreenContentDelegate {
    private let ad: RewardedAd
    private var onReward: (@MainActor () -> Void)?
    private var onDismiss: (@MainActor () -> Void)?
    private var onFailure: (@MainActor (Error) -> Void)?

    init(_ ad: RewardedAd) {
        self.ad = ad
        super.init()
        ad.fullScreenContentDelegate = self
    }

    func present(onReward: @escaping @MainActor () -> Void,
                 onDismiss: @escaping @MainActor () -> Void,
                 onFailure: @escaping @MainActor (Error) -> Void) throws {
        try ad.canPresent(from: nil)
        self.onReward = onReward
        self.onDismiss = onDismiss
        self.onFailure = onFailure
        // Google explicitly supports nil for SwiftUI and delivers this callback
        // on the main thread. Do not enqueue a Task: persist the earned reward
        // before its dismissal callback can update the gameplay presentation.
        ad.present(from: nil) { [weak self] in
            MainActor.assumeIsolated { self?.onReward?() }
        }
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        let completion = onDismiss
        clearCallbacks()
        completion?()
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let completion = onFailure
        clearCallbacks()
        completion?(error)
    }

    private func clearCallbacks() {
        onReward = nil
        onDismiss = nil
        onFailure = nil
    }
}
#endif
