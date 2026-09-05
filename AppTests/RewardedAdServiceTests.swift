import XCTest
@testable import ProbablySudoku

@MainActor
final class RewardedAdServiceTests: XCTestCase {
    func testEveryBuildUsesGoogleDemoIdentifiers() {
        XCTAssertEqual(RewardedAdService.demoRewardedID, "ca-app-pub-3940256099942544/1712485313")
        XCTAssertEqual(Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String,
                       RewardedAdService.demoAppID)
    }

    func testConsentRunsBeforeLoadAndReadyPreparationDoesNotLoadAgain() async {
        let adapter = Adapter()
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        XCTAssertEqual(adapter.calls, ["consent", "load form", "form", "load"])
        XCTAssertEqual(service.state, .ready)
        await service.prepare()
        XCTAssertEqual(adapter.loadCount, 1)
    }

    func testUnavailableConsentCannotLoadAnAd() async {
        let adapter = Adapter()
        adapter.canRequestAds = false
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        XCTAssertEqual(adapter.loadCount, 0)
        XCTAssertFalse(service.isReady)
        guard case .unavailable = service.state else { return XCTFail("Expected consent-gated unavailability") }
    }

    func testConsentFailureFailsClosedUnlessUMPStillAllowsAds() async {
        for previousConsent in [false, true] {
            let adapter = Adapter()
            adapter.consentError = TestError.failed
            adapter.canRequestAds = previousConsent
            let service = RewardedAdService(adapter: adapter)
            await service.prepare()
            XCTAssertEqual(service.isReady, previousConsent)
            XCTAssertEqual(adapter.loadCount, previousConsent ? 1 : 0)
            XCTAssertNotNil(service.lastError)
        }
    }

    func testOnlyEarnedCallbackRewardsAndBothCallbacksAreIdempotent() async {
        let adapter = Adapter()
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        var rewards = 0
        var dismissals = 0
        XCTAssertTrue(service.present(onReward: { rewards += 1 }, onDismiss: { dismissals += 1 }))
        XCTAssertTrue(service.isPresenting)
        XCTAssertFalse(service.present(onReward: { rewards += 100 }, onDismiss: { dismissals += 100 }))
        XCTAssertEqual(rewards, 0)
        adapter.ad.reward?()
        adapter.ad.reward?()
        XCTAssertEqual(rewards, 1, "Reward is synchronous, not deferred beyond dismissal")
        adapter.ad.dismiss?()
        adapter.ad.dismiss?()
        adapter.ad.reward?()
        XCTAssertEqual(dismissals, 1)
        XCTAssertEqual(rewards, 1)
        XCTAssertEqual(service.state, .idle)
    }

    func testSkippingOrPresentationFailureNeverRewards() async {
        for fails in [false, true] {
            let adapter = Adapter()
            let service = RewardedAdService(adapter: adapter)
            await service.prepare()
            var rewards = 0
            var dismissals = 0
            XCTAssertTrue(service.present(onReward: { rewards += 1 }, onDismiss: { dismissals += 1 }))
            if fails { adapter.ad.failure?(TestError.failed) } else { adapter.ad.dismiss?() }
            adapter.ad.reward?()
            adapter.ad.dismiss?()
            XCTAssertEqual(rewards, 0)
            XCTAssertEqual(dismissals, 1)
            XCTAssertFalse(service.isPresenting)
        }
    }

    func testSynchronousPresentationRejectionOwesNoCallbacks() async {
        let adapter = Adapter()
        adapter.ad.presentationError = TestError.failed
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        XCTAssertFalse(service.present(onReward: { XCTFail("No reward") }, onDismiss: { XCTFail("Not accepted") }))
        XCTAssertFalse(service.isReady)
    }

    func testBackgroundAndExpiredAdsCannotPresent() async {
        let adapter = Adapter()
        var time = Date(timeIntervalSince1970: 100)
        let service = RewardedAdService(adapter: adapter, now: { time })
        await service.prepare()
        adapter.canPresent = false
        XCTAssertFalse(service.present(onReward: { XCTFail() }, onDismiss: { XCTFail() }))
        adapter.canPresent = true
        time.addTimeInterval(RewardedAdService.cacheLifetime)
        XCTAssertFalse(service.isReady)
        XCTAssertFalse(service.present(onReward: { XCTFail() }, onDismiss: { XCTFail() }))
        XCTAssertEqual(adapter.ad.presentCount, 0)
    }

    func testCancelledLoadCannotReplaceANewerAd() async {
        let adapter = Adapter()
        adapter.holdLoads = true
        let service = RewardedAdService(adapter: adapter)
        let first = Task { await service.prepare() }
        await waitUntil { adapter.pendingLoads.count == 1 }
        first.cancel()
        await first.value
        XCTAssertEqual(service.state, .idle)
        let second = Task { await service.prepare() }
        await waitUntil { adapter.pendingLoads.count == 2 }
        let newerAd = Ad()
        adapter.pendingLoads[1].resume(returning: newerAd)
        await second.value
        adapter.pendingLoads[0].resume(returning: adapter.ad)
        await Task.yield()
        XCTAssertTrue(service.present(onReward: {}, onDismiss: {}))
        XCTAssertEqual(newerAd.presentCount, 1)
        XCTAssertEqual(adapter.ad.presentCount, 0)
        newerAd.dismiss?()
    }

    func testLoadTimeoutReturnsWithoutWaitingForUncooperativeSDK() async {
        let adapter = Adapter()
        adapter.holdLoads = true
        let service = RewardedAdService(adapter: adapter, networkTimeout: .milliseconds(20))
        await service.prepare()
        guard case .unavailable = service.state else { return XCTFail("Expected bounded timeout") }
        XCTAssertEqual(adapter.pendingLoads.count, 1)
        adapter.pendingLoads.first?.resume(returning: adapter.ad)
        await Task.yield()
        XCTAssertFalse(service.isReady)
    }

    func testConsentNetworkStagesTimeOutWithoutLateFormsOrAds() async {
        for stage in ["consent", "load form"] {
            let adapter = Adapter()
            adapter.heldConsentStage = stage
            let service = RewardedAdService(adapter: adapter, networkTimeout: .milliseconds(20))
            await service.prepare()
            guard case .unavailable = service.state else { return XCTFail("Expected timeout in \(stage)") }
            adapter.pendingConsent?.resume()
            await Task.yield()
            XCTAssertFalse(adapter.calls.contains("form"))
            XCTAssertEqual(adapter.loadCount, 0)
            XCTAssertFalse(service.isReady)
        }
    }

    func testNoFillLeavesRetryAvailable() async {
        let adapter = Adapter()
        adapter.loadError = TestError.failed
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        guard case .unavailable = service.state else { return XCTFail("Expected load failure") }
        adapter.loadError = nil
        await service.prepare()
        XCTAssertTrue(service.isReady)
    }

    func testPrivacyChangeInvalidatesReadyAdWithoutRequestingAnother() async {
        let adapter = Adapter()
        adapter.privacyOptionsRequired = true
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        XCTAssertTrue(service.privacyOptionsRequired)
        await service.presentPrivacyOptions()
        XCTAssertFalse(service.isReady)
        XCTAssertFalse(service.isPresentingPrivacyOptions)
        XCTAssertEqual(adapter.calls.last, "privacy")
        XCTAssertEqual(adapter.loadCount, 1)
    }

    func testSettingsRefreshExposesCachedRequirementAndNeverLoadsOrPresents() async {
        let adapter = Adapter()
        adapter.privacyOptionsRequired = true
        adapter.canRequestAds = false
        let service = RewardedAdService(adapter: adapter)
        XCTAssertTrue(service.privacyOptionsRequired, "Available immediately after relaunch")
        await service.refreshPrivacyStatus()
        XCTAssertEqual(adapter.calls, ["consent"])
        XCTAssertEqual(service.state, .idle)
        XCTAssertEqual(adapter.loadCount, 0)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<1_000 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Expected async adapter call")
    }

    private enum TestError: Error { case failed }

    private final class Adapter: RewardedAdAdapter {
        var canRequestAds = true
        var privacyOptionsRequired = false
        var canPresent = true
        var calls: [String] = []
        var loadCount = 0
        var consentError: Error?
        var loadError: Error?
        var heldConsentStage: String?
        var pendingConsent: CheckedContinuation<Void, Never>?
        var holdLoads = false
        var pendingLoads: [CheckedContinuation<any RewardedAdHandle, Error>] = []
        let ad = Ad()

        func updateConsent() async throws {
            calls.append("consent")
            if heldConsentStage == "consent" {
                await withCheckedContinuation { pendingConsent = $0 }
            }
            if let consentError { throw consentError }
        }
        func loadRequiredConsent() async throws {
            calls.append("load form")
            if heldConsentStage == "load form" {
                await withCheckedContinuation { pendingConsent = $0 }
            }
        }
        func presentRequiredConsent() async throws { calls.append("form") }
        func presentPrivacyOptions() async throws {
            calls.append("privacy")
            canRequestAds = false
        }
        func loadAd() async throws -> any RewardedAdHandle {
            calls.append("load")
            loadCount += 1
            if let loadError { throw loadError }
            if holdLoads { return try await withCheckedThrowingContinuation { pendingLoads.append($0) } }
            return ad
        }
    }

    private final class Ad: RewardedAdHandle {
        var presentCount = 0
        var presentationError: Error?
        var reward: (@MainActor () -> Void)?
        var dismiss: (@MainActor () -> Void)?
        var failure: (@MainActor (Error) -> Void)?

        func present(onReward: @escaping @MainActor () -> Void,
                     onDismiss: @escaping @MainActor () -> Void,
                     onFailure: @escaping @MainActor (Error) -> Void) throws {
            if let presentationError { throw presentationError }
            presentCount += 1
            reward = onReward
            dismiss = onDismiss
            failure = onFailure
        }
    }
}
