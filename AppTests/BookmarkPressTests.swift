import XCTest
@testable import ProbablySudoku

final class BookmarkPressTests: XCTestCase {
    func testSameGestureUpdatesDoNotRestartTheHold() throws {
        var press = BookmarkPressState()
        let generation = try XCTUnwrap(press.begin(itemKey: 0))
        XCTAssertNil(press.begin(itemKey: 0))
        XCTAssertTrue(press.isCurrent(itemKey: 0, generation: generation))
    }

    func testASecondPressOnTheSameSlotRejectsTheFirstDelayedWakeup() throws {
        var press = BookmarkPressState()
        let first = try XCTUnwrap(press.begin(itemKey: 0))
        press.cancel() // First finger lifts before its 220 ms callback.
        let second = try XCTUnwrap(press.begin(itemKey: 0))

        XCTAssertNotEqual(first, second)
        XCTAssertFalse(press.isCurrent(itemKey: 0, generation: first))
        XCTAssertTrue(press.isCurrent(itemKey: 0, generation: second))
    }

    func testAnotherSlotCannotActivateAnEarlierHold() throws {
        var press = BookmarkPressState()
        let first = try XCTUnwrap(press.begin(itemKey: 1))
        let second = try XCTUnwrap(press.begin(itemKey: 100))

        XCTAssertFalse(press.isCurrent(itemKey: 1, generation: first))
        XCTAssertFalse(press.isCurrent(itemKey: 100, generation: first))
        XCTAssertTrue(press.isCurrent(itemKey: 100, generation: second))
    }

    func testReleaseOrDisappearanceInvalidatesEveryPendingWakeup() throws {
        var press = BookmarkPressState()
        let generation = try XCTUnwrap(press.begin(itemKey: 2))
        press.cancel()
        press.cancel()

        XCTAssertNil(press.activeItemKey)
        XCTAssertFalse(press.isCurrent(itemKey: 2, generation: generation))
        let fresh = try XCTUnwrap(press.begin(itemKey: 2))
        XCTAssertTrue(press.isCurrent(itemKey: 2, generation: fresh))
        XCTAssertFalse(press.isCurrent(itemKey: 2, generation: generation))
    }
}
