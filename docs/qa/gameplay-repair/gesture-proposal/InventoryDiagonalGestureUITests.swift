// PROPOSAL ONLY — TYPECHECKED, NEVER RUN, NOT IN ANY PROJECT OR TEST SCHEME.
// Do not run without the user's explicit authorization to use XCTest UI input.
// A future isolated bundle.ui-testing target may include this file after approval.
// No application internals, private events, or synthetic path injection are used.
import XCTest

@MainActor
final class InventoryDiagonalGestureUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        // This is an execution guard, not a substitute for user authorization.
        try XCTSkipUnless(ProcessInfo.processInfo.environment[
            "NC_AUTHORIZED_XCTEST_GESTURES"] == "user-explicitly-approved",
            "Pending user authorization for this separate XCTest UI proposal.")
        app = XCUIApplication(bundleIdentifier: "com.numberclub.app")
        app.launchArguments = ["-skipStartScreen", "-seed", "GESTURE-PROPOSAL"]
        // Deliberately omit -persistQA. The QA fixture also disables persistence.
        app.launch()
        XCTAssertTrue(app.buttons["score.preview"].waitForExistence(timeout: 15))
        let frame = app.frame
        // This endpoint calculation is deliberately limited to the SE's 375×667
        // portrait viewport, with no bottom home-indicator inset. If different,
        // stop and remeasure; do not silently drag to a guessed trash location.
        XCTAssertEqual(frame.width, 375, accuracy: 1)
        XCTAssertEqual(frame.height, 667, accuracy: 1)
        try tap(app.buttons.matching(NSPredicate(format: "label == %@", "Settings")).firstMatch)
        try tap(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "QA TOOLS")).firstMatch)
        try tap(app.buttons["Scoring fixtures"])
        let fixture = app.buttons["qa.scoring.duplicateInventory"]
        for _ in 0..<6 {
            if fixture.exists && fixture.isHittable { break }
            app.swipeUp() // Public XCTest UI input, also requires authorization.
        }
        try tap(fixture)
        try tap(app.buttons["paper-slip.close"]) // Remaining Settings panel.
        XCTAssertTrue(app.buttons["score.preview"].waitForExistence(timeout: 5))
        assertCount(peeks, 2)
        assertWallet(5)
        XCTAssertEqual(items(prefix: "Op-Ed Column.").count, 1)
        XCTAssertEqual(items(prefix: "Stop the Presses.").count, 1)
        attach("fixture-before-gesture")
    }

    func testDiagonalReleaseOutsideCancelsForBuffAndBookmark() throws {
        let boardBefore = app.buttons["score.preview"].label
        let outside = CGPoint(x: app.frame.minX + 16, y: app.frame.maxY - 58)
        // The right-hand Peek moves both left and down, beyond the inventory row.
        try drag(peeks.element(boundBy: 1), to: outside, name: "buff-outside")
        assertCount(peeks, 2)
        assertWallet(5)
        XCTAssertFalse(app.buttons["paper-slip.close"].exists,
                       "A cancelled drag must not fall through into an item tap.")
        XCTAssertEqual(app.buttons["score.preview"].label, boardBefore)

        // Start at Stop (second Bookmark) so this path is also genuinely diagonal.
        try drag(items(prefix: "Stop the Presses.").firstMatch,
                 to: outside, name: "bookmark-outside")
        XCTAssertEqual(items(prefix: "Op-Ed Column.").count, 1)
        XCTAssertEqual(items(prefix: "Stop the Presses.").count, 1)
        assertCount(peeks, 2)
        assertWallet(5)
        XCTAssertEqual(app.buttons["score.preview"].label, boardBefore)
    }

    func testDiagonalBuffSaleRemovesOneCopyAndPreservesUsableSurvivor() throws {
        // Both Peeks have the same label and price. This proves count/refund and
        // survivor usability, NOT the UUID of the surviving duplicate. Pair with
        // the existing BuffIdentityTests described in README.md.
        try drag(peeks.element(boundBy: 1), to: trashCenter, name: "buff-sale")
        assertCount(peeks, 1)
        assertWallet(6) // One Peek sale refund is one coin.
        XCTAssertEqual(items(prefix: "Op-Ed Column.").count, 1)
        XCTAssertEqual(items(prefix: "Stop the Presses.").count, 1)
        try tap(peeks.firstMatch)
        XCTAssertTrue(app.staticTexts["buff.effect"].waitForExistence(timeout: 5))
        try tap(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Choose number")).firstMatch)
        let nine = app.buttons.matching(NSPredicate(format: "label == %@", "Number 9")).firstMatch
        try tap(nine) // Existing empty Latin board has a legal square for nine.
        assertCount(peeks, 0) // One remaining copy was usable and consumed at reveal.
        assertWallet(6)
        XCTAssertTrue(app.buttons["score.preview"].label.contains("Queued base 0"))
        attach("surviving-peek-used-after-one-sale")
    }

    func testDiagonalBookmarkSaleRemovesOnlyChosenItemOnce() throws {
        try drag(items(prefix: "Op-Ed Column.").firstMatch,
                 to: trashCenter, name: "bookmark-sale")
        XCTAssertEqual(items(prefix: "Op-Ed Column.").count, 0)
        XCTAssertEqual(items(prefix: "Stop the Presses.").count, 1)
        assertCount(peeks, 2)
        assertWallet(7) // One Op-Ed sale refund is two coins.
        try tap(app.buttons.matching(NSPredicate(format: "label == %@", "Run information")).firstMatch)
        try tap(app.buttons["paper-slip.close"])
        assertWallet(7)
        XCTAssertEqual(items(prefix: "Stop the Presses.").count, 1)
        attach("bookmark-sale-after-overlay")
    }

    private var peeks: XCUIElementQuery { items(prefix: "Peek.") }
    private func items(prefix: String) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
    }
    private var trashCenter: CGPoint {
        // Current InventoryDragPresenter: root maxY - 90 + 64/2.
        // Must be checked in the authorized recording before treating a miss as
        // an application defect. This proposal never finds private UI objects.
        CGPoint(x: app.frame.midX, y: app.frame.maxY - 58)
    }
    private func tap(_ element: XCUIElement) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
        element.tap()
    }
    private func drag(_ element: XCUIElement, to end: CGPoint, name: String) throws {
        XCTAssertTrue(element.exists && element.isHittable)
        let frame = element.frame
        let start = CGPoint(x: frame.midX, y: frame.midY)
        XCTAssertGreaterThan(abs(end.x - start.x), 20, "Need horizontal movement.")
        XCTAssertGreaterThan(abs(end.y - start.y), 100, "Need vertical movement beyond row.")
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let from = origin.withOffset(CGVector(dx: start.x - app.frame.minX,
                                             dy: start.y - app.frame.minY))
        let to = origin.withOffset(CGVector(dx: end.x - app.frame.minX,
                                           dy: end.y - app.frame.minY))
        let note = XCTAttachment(string: "\(name): start=\(start), end=\(end), app=\(app.frame)")
        note.lifetime = .keepAlways
        add(note)
        // Apple's public API takes one endpoint; this is not a curved path.
        from.press(forDuration: 0.35, thenDragTo: to,
                   withVelocity: .slow, thenHoldForDuration: 0.15)
        attach(name + "-released")
    }
    private func assertCount(_ query: XCUIElementQuery, _ expected: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            query.count == expected
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed,
                       "Expected \(expected) items; found \(query.count)", file: file, line: line)
    }
    private func assertWallet(_ expected: Int, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(app.staticTexts["\(expected) coins"].waitForExistence(timeout: 5),
                      "Wallet must be exactly \(expected)", file: file, line: line)
    }
    private func attach(_ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = name + "-accessibility"
        tree.lifetime = .keepAlways
        add(tree)
    }
}
