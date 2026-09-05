import XCTest
@testable import ProbablySudoku

final class AdConfigurationTests: XCTestCase {
    func testRoutineTestModeAlwaysUsesTheCompleteGoogleDemoPair() throws {
        for runtime in runtimes {
            let config = try AdConfiguration.resolve(mode: "test", appID: AdConfiguration.demoAppID,
                rewardedAdUnitID: AdConfiguration.demoRewardedID, runtime: runtime)
            XCTAssertEqual(config.mode, .test)
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
