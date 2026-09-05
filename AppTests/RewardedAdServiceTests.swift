import XCTest
@testable import ProbablySudoku

@MainActor
final class RewardedAdServiceTests: XCTestCase {
    func testDemoIdentifiersStayAvailableForRoutineBuilds() {
        XCTAssertEqual(RewardedAdService.demoRewardedID, "ca-app-pub-3940256099942544/1712485313")
        XCTAssertEqual(RewardedAdService.demoAppID, "ca-app-pub-3940256099942544~1458002511")
    }

    func testInvalidConfigurationStopsBeforeReadingConsentOrLoading() async {
        let adapter = Adapter()
        adapter.configurationError = AdConfiguration.ConfigurationError.mismatchedIdentifiers(.live)
        let service = RewardedAdService(adapter: adapter)
        XCTAssertEqual(adapter.privacyReadCount, 0, "Configuration must be checked before UMP state is read.")
        XCTAssertFalse(service.privacyOptionsRequired)
        guard case .unavailable = service.state else { return XCTFail("Invalid build must fail closed.") }

        await service.prepare()
        await service.refreshPrivacyStatus()
        await service.presentPrivacyOptions()
        XCTAssertFalse(service.present(onReward: { XCTFail("No reward") }, onDismiss: { XCTFail("No ad") }))
        XCTAssertTrue(adapter.calls.isEmpty, "No consent request, form, SDK load or presentation is allowed.")
        XCTAssertEqual(adapter.privacyReadCount, 0)
        XCTAssertEqual(adapter.loadCount, 0)
        XCTAssertNotNil(service.lastError)
    }

    func testConfigurationFailureInvalidatesAnAlreadyPreparedAd() async {
        let adapter = Adapter()
        let service = RewardedAdService(adapter: adapter)
        await service.prepare()
        XCTAssertTrue(service.isReady)
        adapter.configurationError = AdConfiguration.ConfigurationError.unsupportedMode("unknown")
        XCTAssertFalse(service.present(onReward: { XCTFail("No reward") }, onDismiss: { XCTFail("No ad") }))
        XCTAssertFalse(service.isReady)
        XCTAssertEqual(adapter.ad.presentCount, 0)
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

    func testAudioPausesSynchronouslyBeforeAdAndResumesExactlyOnceAfterEveryExit() async {
        for exit in ["dismiss", "failure", "throw"] {
            let adapter = Adapter()
            var events: [String] = []
            let service = RewardedAdService(adapter: adapter, presentationChanged: {
                events.append($0 ? "pause" : "resume")
            })
            await service.prepare()
            events.removeAll() // Required consent has its own presentation boundary.
            adapter.ad.onPresent = { events.append("SDK present") }
            if exit == "throw" { adapter.ad.presentationError = TestError.failed }

            let accepted = service.present(onReward: { events.append("reward") },
                                           onDismiss: { events.append("client dismiss") })
            XCTAssertEqual(accepted, exit != "throw")
            if exit == "throw" {
                XCTAssertEqual(events, ["pause", "SDK present", "resume"])
            } else {
                XCTAssertEqual(events, ["pause", "SDK present"], "Audio must remain suspended for the whole ad.")
                adapter.ad.reward?()
                XCTAssertEqual(events, ["pause", "SDK present", "reward"], "Earning a reward does not dismiss the ad.")
                if exit == "failure" { adapter.ad.failure?(TestError.failed) }
                else { adapter.ad.dismiss?() }
                XCTAssertEqual(events, ["pause", "SDK present", "reward", "resume", "client dismiss"])
                adapter.ad.dismiss?()
                adapter.ad.failure?(TestError.failed)
                XCTAssertEqual(events.filter { $0 == "resume" }.count, 1, "Late callbacks cannot resume twice.")
            }
        }
    }

    func testRejectedAdAndPrivacyRefreshDoNotChangeAudioPresentationState() async {
        let adapter = Adapter()
        var transitions: [Bool] = []
        let service = RewardedAdService(adapter: adapter, presentationChanged: { transitions.append($0) })
        XCTAssertFalse(service.present(onReward: {}, onDismiss: {}))
        await service.refreshPrivacyStatus()
        await service.presentPrivacyOptions() // No form is required.
        XCTAssertTrue(transitions.isEmpty)
        await service.prepare()
        transitions.removeAll()
        adapter.canPresent = false
        XCTAssertFalse(service.present(onReward: {}, onDismiss: {}))
        XCTAssertTrue(transitions.isEmpty)
    }

    func testRequiredConsentKeepsAudioPausedUntilFormReturnsOrThrows() async {
        for fails in [false, true] {
            let adapter = Adapter()
            adapter.holdPresentations = true
            if fails { adapter.formPresentationError = TestError.failed }
            var events: [String] = []
            adapter.onFormPresentation = { events.append("SDK \($0)") }
            let service = RewardedAdService(adapter: adapter, presentationChanged: {
                events.append($0 ? "pause" : "resume")
            })
            let preparation = Task { await service.prepare() }
            await waitUntil { adapter.pendingPresentations["form"] != nil }
            XCTAssertEqual(events, ["pause", "SDK form"])
            XCTAssertEqual(adapter.loadCount, 0)
            adapter.pendingPresentations.removeValue(forKey: "form")?.resume()
            await preparation.value
            XCTAssertEqual(events, ["pause", "SDK form", "resume"])
            XCTAssertEqual(adapter.loadCount, fails ? 0 : 1)
            XCTAssertEqual(service.isReady, !fails)
        }
    }

    func testPrivacyOptionsKeepsAudioPausedUntilFormReturnsOrThrows() async {
        for fails in [false, true] {
            let adapter = Adapter()
            adapter.privacyOptionsRequired = true
            adapter.holdPresentations = true
            if fails { adapter.formPresentationError = TestError.failed }
            var events: [String] = []
            adapter.onFormPresentation = { events.append("SDK \($0)") }
            let service = RewardedAdService(adapter: adapter, presentationChanged: {
                events.append($0 ? "pause" : "resume")
            })
            let presentation = Task { await service.presentPrivacyOptions() }
            await waitUntil { adapter.pendingPresentations["privacy"] != nil }
            XCTAssertEqual(events, ["pause", "SDK privacy"])
            XCTAssertTrue(service.isPresentingPrivacyOptions)
            adapter.pendingPresentations.removeValue(forKey: "privacy")?.resume()
            await presentation.value
            XCTAssertEqual(events, ["pause", "SDK privacy", "resume"])
            XCTAssertFalse(service.isPresentingPrivacyOptions)
            XCTAssertEqual(service.lastError != nil, fails)
            XCTAssertEqual(adapter.loadCount, 0)
        }
    }

    func testCancelledConsentStillOwnsAudioUntilItsLastOverlappingFormFinishes() async {
        let adapter = Adapter()
        adapter.privacyOptionsRequired = true
        adapter.holdPresentations = true
        var transitions: [Bool] = []
        let service = RewardedAdService(adapter: adapter, presentationChanged: { transitions.append($0) })
        let preparation = Task { await service.prepare() }
        await waitUntil { adapter.pendingPresentations["form"] != nil }
        service.cancelPreparation()
        await preparation.value
        XCTAssertEqual(transitions, [true], "Cancellation does not mean the SDK form has disappeared.")

        let privacy = Task { await service.presentPrivacyOptions() }
        await waitUntil { adapter.pendingPresentations["privacy"] != nil }
        XCTAssertEqual(transitions, [true], "Overlapping forms share one suspended interval.")
        adapter.pendingPresentations.removeValue(forKey: "privacy")?.resume()
        await privacy.value
        XCTAssertEqual(transitions, [true], "The canceled required-consent form is still open.")
        adapter.pendingPresentations.removeValue(forKey: "form")?.resume()
        await waitUntil { transitions.count == 2 }
        XCTAssertEqual(transitions, [true, false])
        XCTAssertEqual(adapter.loadCount, 0, "The canceled preparation cannot request an ad after dismissal.")
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
        private var needsPrivacyOptions = false
        var privacyReadCount = 0
        var privacyOptionsRequired: Bool {
            get {
                privacyReadCount += 1
                return needsPrivacyOptions
            }
            set { needsPrivacyOptions = newValue }
        }
        var canPresent = true
        var configurationError: Error?
        var calls: [String] = []
        var loadCount = 0
        var consentError: Error?
        var loadError: Error?
        var heldConsentStage: String?
        var pendingConsent: CheckedContinuation<Void, Never>?
        var holdPresentations = false
        var pendingPresentations: [String: CheckedContinuation<Void, Never>] = [:]
        var formPresentationError: Error?
        var onFormPresentation: ((String) -> Void)?
        var holdLoads = false
        var pendingLoads: [CheckedContinuation<any RewardedAdHandle, Error>] = []
        let ad = Ad()

        func validateConfiguration() throws {
            if let configurationError { throw configurationError }
        }

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
        func presentRequiredConsent() async throws {
            calls.append("form")
            try await presentForm("form")
        }
        func presentPrivacyOptions() async throws {
            calls.append("privacy")
            try await presentForm("privacy")
            canRequestAds = false
        }
        private func presentForm(_ name: String) async throws {
            onFormPresentation?(name)
            if holdPresentations {
                await withCheckedContinuation { pendingPresentations[name] = $0 }
            }
            if let formPresentationError { throw formPresentationError }
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
        var onPresent: (() -> Void)?
        var reward: (@MainActor () -> Void)?
        var dismiss: (@MainActor () -> Void)?
        var failure: (@MainActor (Error) -> Void)?

        func present(onReward: @escaping @MainActor () -> Void,
                     onDismiss: @escaping @MainActor () -> Void,
                     onFailure: @escaping @MainActor (Error) -> Void) throws {
            onPresent?()
            if let presentationError { throw presentationError }
            presentCount += 1
            reward = onReward
            dismiss = onDismiss
            failure = onFailure
        }
    }
}
