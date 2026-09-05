import XCTest
@testable import ProbablySudoku

final class CoreGameplayTests: XCTestCase {
    func testBookRackDebugRouteUsesTheBookstoreEntrance() {
        // The 3D rack is BookstoreOpeningView inside the main-menu route,
        // not the older flat StartBookView reached through .bookShelf.
        XCTAssertEqual(FrontDoorRoute.launchRoute(arguments: ["app", "-bookRack"]), .mainMenu)
    }
}
