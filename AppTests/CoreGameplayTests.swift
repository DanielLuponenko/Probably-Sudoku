import XCTest
@testable import ProbablySudoku

final class CoreGameplayTests: XCTestCase {
    func testBookShelfDebugRouteStartsAtTheCoreFlow() {
        XCTAssertEqual(FrontDoorRoute.launchRoute(arguments: ["app", "-bookRack"]), .bookShelf)
    }
}
