import XCTest
@testable import ProbablySudoku

final class ShopMarkerHandoffTests: XCTestCase {
    func testPurchaseWaitsForOfferDismissalAndIsHandedOffExactlyOnce() {
        var pending = PendingMarkerPurchase()
        pending.record(markerIndex: 0)

        XCTAssertEqual(pending.markerIndex, 0, "Keep the purchased Marker while the native offer is still leaving")
        XCTAssertEqual(pending.takeAfterOfferDismissal(), 0)
        XCTAssertNil(pending.markerIndex)
        XCTAssertNil(pending.takeAfterOfferDismissal(), "A repeated dismissal cannot open another placement slip")
    }

    func testDuplicatePurchaseCallbackCannotReplaceTheWaitingMarker() {
        var pending = PendingMarkerPurchase()
        pending.record(markerIndex: 2)
        pending.record(markerIndex: 3)
        XCTAssertEqual(pending.takeAfterOfferDismissal(), 2)

        pending.record(markerIndex: 4)
        XCTAssertEqual(pending.takeAfterOfferDismissal(), 4, "A subsequent genuine purchase starts its own handoff")
    }

    func testClosingAnUnpurchasedOfferDoesNotRequestMarkerPlacement() {
        var pending = PendingMarkerPurchase()
        XCTAssertNil(pending.takeAfterOfferDismissal())
    }
}
