import XCTest
import SwiftUI
import ProbablySudokuEngine
@testable import ProbablySudoku

final class BookmarkPressTests: XCTestCase {
    @MainActor
    func testBuffActivationOpensItsUseSlipExactlyOnceInsteadOfThePassivePopover() throws {
        var passivePopover = false
        var activations = 0
        let item = InventoryBookmark(
            def: try XCTUnwrap(Catalog.item("bf_insurance")),
            colour: Paper.coverBoard, ink: Paper.page, flagged: true,
            slot: 5, pulling: false, asleep: false, fired: false,
            explaining: Binding(get: { passivePopover }, set: { passivePopover = $0 }),
            onActivate: { activations += 1 })

        item.activate()

        XCTAssertEqual(activations, 1)
        XCTAssertFalse(passivePopover)
    }

    @MainActor
    func testBookmarkActivationStillOpensItsItemDetails() throws {
        var passivePopover = false
        let item = InventoryBookmark(
            def: try XCTUnwrap(Catalog.item(Bookmarks.syndication)),
            colour: Paper.pageWarm, ink: Paper.ink, flagged: false,
            slot: 0, pulling: false, asleep: false, fired: false,
            explaining: Binding(get: { passivePopover }, set: { passivePopover = $0 }))

        item.activate()

        XCTAssertTrue(passivePopover)
    }

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
