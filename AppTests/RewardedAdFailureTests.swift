import XCTest
@testable import ProbablySudoku
#if !NUMBERCLUB_AD_FREE
import GoogleMobileAds
#endif

final class RewardedAdFailureTests: XCTestCase {
    private let privateDetail = "Private SDK response with identifiers and request details"
    private let consentFallback = "Privacy settings couldn't load. Try again."

    func testURLConnectivityFailuresHaveActionableTextWithoutExposingRawDetails() {
        for code in [NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost,
                     NSURLErrorDNSLookupFailed, NSURLErrorInternationalRoamingOff,
                     NSURLErrorCallIsActive, NSURLErrorDataNotAllowed] {
            let original = error(domain: NSURLErrorDomain, code: code)
            let failure = RewardedAdFailure.classify(original, fallback: consentFallback)
            XCTAssertEqual(failure.kind, .network)
            XCTAssertTrue(failure.playerMessage.contains("Check your internet connection"))
            assertRetainedAndSafe(failure, original: original)
        }
    }

    func testURLTimeoutIsNotReportedAsNoInventory() {
        let original = error(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let failure = RewardedAdFailure.classify(original, fallback: consentFallback)
        XCTAssertEqual(failure.kind, .timeout)
        XCTAssertTrue(failure.playerMessage.contains("took too long"))
        assertRetainedAndSafe(failure, original: original)
    }

    func testForeignDomainWithConnectivityCodeKeepsStageFallback() {
        let original = error(domain: "ConsentFailure", code: NSURLErrorNotConnectedToInternet)
        let failure = RewardedAdFailure.classify(original, fallback: consentFallback)
        XCTAssertEqual(failure.kind, .other)
        XCTAssertEqual(failure.playerMessage, consentFallback)
        assertRetainedAndSafe(failure, original: original)
    }

    func testUnclassifiedURLErrorKeepsStageFallback() {
        let original = error(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        let failure = RewardedAdFailure.classify(original, fallback: consentFallback)
        XCTAssertEqual(failure.kind, .other)
        XCTAssertEqual(failure.playerMessage, consentFallback)
        assertRetainedAndSafe(failure, original: original)
    }

    func testClassifiedFailureKeepsItsMeaningAndOriginalErrorAcrossServiceBoundary() {
        let original = error(domain: "AdProvider", code: 1)
        let adFailure = RewardedAdFailure(kind: .noFill, underlyingError: original)
        let failure = RewardedAdFailure.classify(adFailure, fallback: consentFallback)
        XCTAssertEqual(failure.kind, .noFill)
        XCTAssertEqual(failure.playerMessage, adFailure.playerMessage)
        assertRetainedAndSafe(failure, original: original)
    }

    #if !NUMBERCLUB_AD_FREE
    @MainActor
    func testGoogleLoadErrorsUseDomainAndOfficialCodeToDistinguishFailureCauses() {
        for (code, kind) in [
            (RequestError.Code.noFill, RewardedAdFailure.Kind.noFill),
            (.networkError, .network), (.timeout, .timeout),
            (.invalidRequest, .other), (.serverError, .other)
        ] {
            let original = error(domain: GADErrorDomain, code: code.rawValue)
            let failure = GoogleRewardedAdAdapter.loadFailure(for: original)
            XCTAssertEqual(failure.kind, kind)
            assertRetainedAndSafe(failure, original: original)
        }
    }

    @MainActor
    func testNonGoogleDomainWithGoogleCodeIsNeverClassifiedAsNoFill() {
        for code in [RequestError.Code.noFill, .networkError, .timeout] {
            let original = error(domain: "OtherSDK", code: code.rawValue)
            let failure = GoogleRewardedAdAdapter.loadFailure(for: original)
            XCTAssertEqual(failure.kind, .other)
            XCTAssertFalse(failure.playerMessage.contains("No video is available"))
            assertRetainedAndSafe(failure, original: original)
        }
    }

    @MainActor
    func testAdLoadBoundaryAlsoRecognizesURLConnectivityFailure() {
        let original = error(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let failure = GoogleRewardedAdAdapter.loadFailure(for: original)
        XCTAssertEqual(failure.kind, .network)
        assertRetainedAndSafe(failure, original: original)
    }
    #endif

    private func error(domain: String, code: Int) -> NSError {
        NSError(domain: domain, code: code, userInfo: [NSLocalizedDescriptionKey: privateDetail])
    }

    private func assertRetainedAndSafe(_ failure: RewardedAdFailure, original: NSError,
                                      file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue((failure.underlyingError as NSError) === original, file: file, line: line)
        XCTAssertEqual(failure.localizedDescription, failure.playerMessage, file: file, line: line)
        XCTAssertFalse(failure.playerMessage.contains(privateDetail), file: file, line: line)
        XCTAssertTrue(failure.playerMessage.contains("Try again") || failure.playerMessage.contains("try again"),
                      file: file, line: line)
    }
}
