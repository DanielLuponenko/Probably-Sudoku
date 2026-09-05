import GoogleMobileAds
import UIKit
import UserMessagingPlatform

@MainActor
final class GoogleRewardedAdAdapter: RewardedAdAdapter {
    private var hasStartedSDK = false
    private var initializationTask: Task<Void, Never>?
    private var isShowingConsentForm = false
    private var consentForm: ConsentForm?

    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }
    var privacyOptionsRequired: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
    var canPresent: Bool {
        !isShowingConsentForm && UIApplication.shared.applicationState == .active &&
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .contains { scene in
                scene.activationState == .foregroundActive &&
                scene.windows.contains { $0.isKeyWindow && $0.rootViewController != nil }
            }
    }

    func updateConsent() async throws {
        // No forced geography, saved-consent override, ATT request, or reset.
        try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
    }

    func loadRequiredConsent() async throws {
        consentForm = nil
        guard ConsentInformation.shared.consentStatus == .required else { return }
        // Split loading from presentation so leaving the offer while the form
        // loads cannot make a consent sheet appear over the bookstore later.
        let form = try await ConsentForm.load()
        try Task.checkCancellation()
        consentForm = form
    }

    func presentRequiredConsent() async throws {
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
        guard canPresent else { throw PresentationError.noForegroundWindow }
        isShowingConsentForm = true
        defer { isShowingConsentForm = false }
        try await ConsentForm.presentPrivacyOptionsForm(from: nil)
    }

    func loadAd() async throws -> any RewardedAdHandle {
        guard canRequestAds else { throw PresentationError.consentRequired }
        if !hasStartedSDK {
            // Initialization can preload ads, so it belongs behind consent too.
            if initializationTask == nil {
                initializationTask = Task { _ = await MobileAds.shared.start() }
            }
            await initializationTask?.value
            hasStartedSDK = true
            initializationTask = nil
        }
        try Task.checkCancellation()
        guard canRequestAds else { throw PresentationError.consentRequired }
        let ad = try await RewardedAd.load(with: RewardedAdService.demoRewardedID, request: Request())
        return GoogleRewardedAd(ad)
    }

    private enum PresentationError: Error {
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
