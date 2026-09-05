import Foundation
import XCTest

final class DistributionMetadataTests: XCTestCase {
    func testAppBundleIncludesItsUserDefaultsPrivacyDeclarationWithoutTracking() throws {
        // These are hosted app tests: inspect the shipped resource, not a
        // source-tree plist that might be missing from Copy Bundle Resources.
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)

        let accessedAPIs = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = try XCTUnwrap(accessedAPIs.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        })
        XCTAssertEqual(userDefaults["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    func testAppBundleDeclaresPortraitCompatibilityAndExportMetadata() {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.bundleIdentifier, "com.numberclub.app")
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "UISupportedInterfaceOrientations") as? [String],
                       ["UIInterfaceOrientationPortrait"])
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "UIRequiresFullScreen") as? Bool, true)
        XCTAssertEqual(bundle.object(forInfoDictionaryKey: "ITSAppUsesNonExemptEncryption") as? Bool, false)
    }
}
