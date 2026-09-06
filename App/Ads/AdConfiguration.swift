import Foundation

/// Validated build metadata. Resolving it is pure: no consent or ads SDK work.
struct AdConfiguration: Equatable, Sendable {
    enum Mode: String, Sendable { case disabled, test, live }

    struct Runtime: Equatable, Sendable {
        let isDebug: Bool
        let isSimulator: Bool

        static var current: Runtime {
            #if DEBUG
            let isDebug = true
            #else
            let isDebug = false
            #endif
            #if targetEnvironment(simulator)
            let isSimulator = true
            #else
            let isSimulator = false
            #endif
            return Runtime(isDebug: isDebug, isSimulator: isSimulator)
        }
    }

    enum ConfigurationError: Error, LocalizedError, Equatable {
        case missingValue(String)
        case unsupportedMode(String)
        case mismatchedIdentifiers(Mode)

        var errorDescription: String? {
            switch self {
            case .missingValue(let key):
                return "Ad configuration is missing \(key)."
            case .unsupportedMode(let mode):
                return "Unsupported ad mode: \(mode)."
            case .mismatchedIdentifiers(let mode):
                return "The AdMob app and rewarded unit do not match the approved \(mode.rawValue) configuration."
            }
        }
    }

    static let demoAppID = "ca-app-pub-3940256099942544~1458002511"
    static let demoRewardedID = "ca-app-pub-3940256099942544/1712485313"
    static let productionAppID = "ca-app-pub-6970700553304979~2878649005"
    static let productionRewardedID = "ca-app-pub-6970700553304979/5201560013"

    /// Disabled stays disabled everywhere. Enabled Debug/simulator builds use test ads.
    let mode: Mode
    var isEnabled: Bool { mode != .disabled }
    /// The approved GADApplicationIdentifier in this bundle. Google reads this
    /// metadata itself; a test rewarded-unit override does not rewrite it.
    let appID: String
    let rewardedAdUnitID: String

    private init(mode: Mode, appID: String, rewardedAdUnitID: String) {
        self.mode = mode
        self.appID = appID
        self.rewardedAdUnitID = rewardedAdUnitID
    }

    static func resolve(mode rawMode: String?, appID: String?, rewardedAdUnitID: String?,
                        runtime: Runtime) throws -> AdConfiguration {
        guard let rawMode, !rawMode.isEmpty else {
            throw ConfigurationError.missingValue("NumberClubAdMode")
        }
        guard let mode = Mode(rawValue: rawMode) else {
            throw ConfigurationError.unsupportedMode(rawMode)
        }
        // An explicit ad-free build needs no Google identifiers. Discard any
        // inherited metadata instead of leaving a usable request configuration.
        if mode == .disabled {
            return AdConfiguration(mode: .disabled, appID: "", rewardedAdUnitID: "")
        }
        guard let appID, !appID.isEmpty else {
            throw ConfigurationError.missingValue("GADApplicationIdentifier")
        }
        guard let rewardedAdUnitID, !rewardedAdUnitID.isEmpty else {
            throw ConfigurationError.missingValue("NumberClubRewardedAdUnitID")
        }
        let expectedApp = mode == .test ? demoAppID : productionAppID
        let expectedUnit = mode == .test ? demoRewardedID : productionRewardedID
        // Validate the declared pair before applying the test-device override.
        // An unknown or mixed configuration must never reach UMP or Mobile Ads.
        guard appID == expectedApp, rewardedAdUnitID == expectedUnit else {
            throw ConfigurationError.mismatchedIdentifiers(mode)
        }
        let usesTestAds = mode == .test || runtime.isDebug || runtime.isSimulator
        return AdConfiguration(mode: usesTestAds ? .test : .live,
                               appID: appID,
                               rewardedAdUnitID: usesTestAds ? demoRewardedID : productionRewardedID)
    }

    static func resolve(infoDictionary: [String: Any], runtime: Runtime) throws -> AdConfiguration {
        try resolve(mode: infoDictionary["NumberClubAdMode"] as? String,
                    appID: infoDictionary["GADApplicationIdentifier"] as? String,
                    rewardedAdUnitID: infoDictionary["NumberClubRewardedAdUnitID"] as? String,
                    runtime: runtime)
    }

    static var current: Result<AdConfiguration, Error> {
        Result { try resolve(infoDictionary: Bundle.main.infoDictionary ?? [:], runtime: .current) }
    }
}
