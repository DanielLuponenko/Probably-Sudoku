import XCTest
@testable import ProbablySudoku

final class AppLinksTests: XCTestCase {
    func testSupportAndPrivacyUseTheSameAppSpecificHTTPSHost() {
        for url in [AppLinks.support, AppLinks.privacyPolicy] {
            XCTAssertEqual(url.scheme, "https")
            XCTAssertEqual(url.host, "probably-sudoku-support.dannyluponenko.chatgpt.site")
            XCTAssertNil(url.user)
            XCTAssertNil(url.password)
            XCTAssertNil(url.query)
        }
        XCTAssertEqual(AppLinks.privacyPolicy.path, "/privacy")
    }
}
