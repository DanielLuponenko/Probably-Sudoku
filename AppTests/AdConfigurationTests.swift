import XCTest
@testable import ProbablySudoku

final class AdConfigurationTests: XCTestCase {
    #if !NUMBERCLUB_AD_FREE && os(iOS)
    func testRewardedHostIncludesValidatedGoogleMetadataAndNoTrackingPrompt() throws {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.bundleIdentifier, "com.numberclub.app")
        let config = try AdConfiguration.current.get()
        XCTAssertTrue(config.isEnabled, "The production app must retain its optional rescue offer.")
        XCTAssertNil(bundle.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription"),
                     "This release does not request ATT or IDFA access.")
        let networks = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "SKAdNetworkItems") as? [[String: String]])
        let identifiers = networks.compactMap { $0["SKAdNetworkIdentifier"] }
        XCTAssertEqual(identifiers.count, 50, "Keep the verified Google quick-start attribution list intact.")
        XCTAssertEqual(Set(identifiers).count, identifiers.count)
        XCTAssertTrue(identifiers.contains("cstr6suwn9.skadnetwork"))
        XCTAssertTrue(identifiers.allSatisfy { $0.range(of: "^[a-z0-9]{10}\\.skadnetwork$", options: .regularExpression) != nil })

        #if targetEnvironment(simulator)
        // Includes the Production configuration: metadata, not only the runtime
        // request override, must stay on the complete Google demo pair.
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "NumberClubAdMode") as? String, "test")
        XCTAssertEqual(config.mode, .test)
        XCTAssertEqual(config.appID, AdConfiguration.demoAppID)
        XCTAssertEqual(config.rewardedAdUnitID, AdConfiguration.demoRewardedID)
        #else
        let rawMode = try XCTUnwrap(bundle.object(forInfoDictionaryKey: "NumberClubAdMode") as? String)
        let declared = try AdConfiguration.resolve(infoDictionary: bundle.infoDictionary ?? [:],
            runtime: .init(isDebug: false, isSimulator: false))
        XCTAssertEqual(declared.mode.rawValue, rawMode)
        #endif
    }
    #endif

    #if NUMBERCLUB_AD_FREE && os(iOS)
    func testAppStoreHostContainsOnlyDisabledAdMetadata() throws {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.bundleIdentifier, "com.numberclub.app")
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "NumberClubAdMode") as? String, "disabled")
        for key in ["GADApplicationIdentifier", "NumberClubRewardedAdUnitID", "SKAdNetworkItems"] {
            XCTAssertNil(bundle.object(forInfoDictionaryKey: key), "Ad-free bundle must omit \(key).")
        }
        let config = try AdConfiguration.current.get()
        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.appID.isEmpty)
        XCTAssertTrue(config.rewardedAdUnitID.isEmpty)
        XCTAssertNil(bundle.url(forResource: "Info", withExtension: "plist", subdirectory: "App"),
                     "The beta Info.plist must not be copied as a resource.")
        XCTAssertNil(NSClassFromString("GADMobileAds"), "Google Ads must not be linked into this host.")
        XCTAssertNil(NSClassFromString("UMPConsentInformation"), "UMP must not be linked into this host.")
    }
    #endif

    func testExplicitDisabledModeStaysDisabledOnEveryRuntimeWithoutGoogleIdentifiers() throws {
        for runtime in runtimes {
            let config = try AdConfiguration.resolve(infoDictionary: ["NumberClubAdMode": "disabled"],
                                                     runtime: runtime)
            XCTAssertEqual(config.mode, .disabled)
            XCTAssertFalse(config.isEnabled)
            XCTAssertEqual(config.appID, "")
            XCTAssertEqual(config.rewardedAdUnitID, "")
        }
    }

    func testDisabledModeDiscardsInheritedIdentifiersRatherThanEnablingAnSDK() throws {
        for runtime in runtimes {
            for pair in [
                (AdConfiguration.demoAppID, AdConfiguration.demoRewardedID),
                (AdConfiguration.productionAppID, AdConfiguration.productionRewardedID),
                (AdConfiguration.demoAppID, AdConfiguration.productionRewardedID),
                ("$(NUMBERCLUB_ADMOB_APP_ID)", "$(NUMBERCLUB_REWARDED_AD_UNIT_ID)")
            ] {
                let config = try AdConfiguration.resolve(mode: "disabled", appID: pair.0,
                    rewardedAdUnitID: pair.1, runtime: runtime)
                XCTAssertFalse(config.isEnabled)
                XCTAssertEqual(config.mode, .disabled)
                XCTAssertTrue(config.appID.isEmpty)
                XCTAssertTrue(config.rewardedAdUnitID.isEmpty)
            }
        }
    }

    func testRoutineTestModeAlwaysUsesTheCompleteGoogleDemoPair() throws {
        for runtime in runtimes {
            let config = try AdConfiguration.resolve(mode: "test", appID: AdConfiguration.demoAppID,
                rewardedAdUnitID: AdConfiguration.demoRewardedID, runtime: runtime)
            XCTAssertEqual(config.mode, .test)
            XCTAssertTrue(config.isEnabled)
            XCTAssertEqual(config.appID, AdConfiguration.demoAppID)
            XCTAssertEqual(config.rewardedAdUnitID, AdConfiguration.demoRewardedID)
        }
    }

    func testOnlyNonDebugPhysicalLiveModeSelectsTheProductionRewardedUnit() throws {
        for runtime in runtimes {
            let config = try AdConfiguration.resolve(mode: "live", appID: AdConfiguration.productionAppID,
                rewardedAdUnitID: AdConfiguration.productionRewardedID, runtime: runtime)
            let permitsLive = !runtime.isDebug && !runtime.isSimulator
            XCTAssertEqual(config.mode, permitsLive ? .live : .test)
            XCTAssertEqual(config.appID, "ca-app-pub-6970700553304979~2878649005")
            XCTAssertEqual(config.rewardedAdUnitID, permitsLive
                           ? "ca-app-pub-6970700553304979/5201560013" : AdConfiguration.demoRewardedID)
        }
    }

    func testMixedAndUnknownIdentifiersFailClosedEvenInDebugAndSimulator() {
        for runtime in runtimes {
            for mode in ["test", "live"] {
                for pair in [
                    (AdConfiguration.demoAppID, AdConfiguration.productionRewardedID),
                    (AdConfiguration.productionAppID, AdConfiguration.demoRewardedID),
                    ("ca-app-pub-0000000000000000~0000000000", AdConfiguration.demoRewardedID),
                    (AdConfiguration.productionAppID, "ca-app-pub-0000000000000000/0000000000")
                ] {
                    XCTAssertThrowsError(try AdConfiguration.resolve(mode: mode, appID: pair.0,
                        rewardedAdUnitID: pair.1, runtime: runtime)) { error in
                        XCTAssertEqual(error as? AdConfiguration.ConfigurationError,
                                       .mismatchedIdentifiers(mode == "test" ? .test : .live))
                    }
                }
            }
            XCTAssertThrowsError(try AdConfiguration.resolve(mode: "test", appID: AdConfiguration.productionAppID,
                rewardedAdUnitID: AdConfiguration.productionRewardedID, runtime: runtime))
            XCTAssertThrowsError(try AdConfiguration.resolve(mode: "live", appID: AdConfiguration.demoAppID,
                rewardedAdUnitID: AdConfiguration.demoRewardedID, runtime: runtime))
        }
    }

    func testMissingAndUnexpandedBuildMetadataCannotEnableAnySDKActivity() {
        let physical = AdConfiguration.Runtime(isDebug: false, isSimulator: false)
        for invalid in [String?.none, "", "$(NUMBERCLUB_AD_MODE)", "production", "LIVE"] {
            XCTAssertThrowsError(try AdConfiguration.resolve(mode: invalid, appID: AdConfiguration.productionAppID,
                rewardedAdUnitID: AdConfiguration.productionRewardedID, runtime: physical))
        }
        for invalid in [String?.none, "", "$(NUMBERCLUB_ADMOB_APP_ID)"] {
            XCTAssertThrowsError(try AdConfiguration.resolve(mode: "live", appID: invalid,
                rewardedAdUnitID: AdConfiguration.productionRewardedID, runtime: physical))
        }
        for invalid in [String?.none, "", "$(NUMBERCLUB_REWARDED_AD_UNIT_ID)"] {
            XCTAssertThrowsError(try AdConfiguration.resolve(mode: "live", appID: AdConfiguration.productionAppID,
                rewardedAdUnitID: invalid, runtime: physical))
        }
    }

    func testBundleKeysResolveTheVerifiedProductionPairWithoutAnySDK() throws {
        let config = try AdConfiguration.resolve(infoDictionary: [
            "NumberClubAdMode": "live",
            "GADApplicationIdentifier": "ca-app-pub-6970700553304979~2878649005",
            "NumberClubRewardedAdUnitID": "ca-app-pub-6970700553304979/5201560013"
        ], runtime: .init(isDebug: false, isSimulator: false))
        XCTAssertEqual(config.mode, .live)
        XCTAssertThrowsError(try AdConfiguration.resolve(infoDictionary: ["NumberClubAdMode": true],
                                                       runtime: .init(isDebug: true, isSimulator: true)))
    }

    private var runtimes: [AdConfiguration.Runtime] {
        [
            .init(isDebug: true, isSimulator: true),
            .init(isDebug: true, isSimulator: false),
            .init(isDebug: false, isSimulator: true),
            .init(isDebug: false, isSimulator: false)
        ]
    }
}
