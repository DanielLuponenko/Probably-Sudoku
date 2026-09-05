import XCTest
import UIKit
@testable import ProbablySudoku

/// Tests readiness/ownership using in-memory pixels only. No app window,
/// renderer, animation clock or screen capture is involved.
@MainActor
final class MenuReturnTransitionTests: XCTestCase {
    func testBeginKeepsTheOutgoingSnapshotOpaqueUntilTheDestinationActuallyRenders() throws {
        let transition = MenuReturnTransition()
        let image = snapshot()
        let token = try XCTUnwrap(transition.begin(snapshot: image))

        XCTAssertTrue(transition.isActive)
        XCTAssertTrue(transition.snapshot === image)
        XCTAssertEqual(transition.token, token)
        XCTAssertEqual(transition.opacity, 1)
        // An unrelated scene's callback is not permission to expose the menu.
        XCTAssertFalse(transition.destinationDidRender(token: UUID()))
        XCTAssertTrue(transition.snapshot === image)
        XCTAssertEqual(transition.opacity, 1)
    }

    func testFirstMatchingFrameStartsOneDissolveAndRetainsPixelsUntilCompletion() throws {
        let transition = MenuReturnTransition()
        let image = snapshot()
        let token = try XCTUnwrap(transition.begin(snapshot: image))

        XCTAssertTrue(transition.destinationDidRender(token: token))
        XCTAssertEqual(transition.opacity, 0)
        XCTAssertTrue(transition.isActive)
        XCTAssertTrue(transition.snapshot === image,
                      "The dissolve still needs its outgoing pixels after opacity changes")
        XCTAssertEqual(transition.token, token)
        XCTAssertFalse(transition.destinationDidRender(token: token),
                       "Repeated render callbacks must not restart the dissolve")

        transition.finish(token: token)
        assertIdle(transition)
        transition.finish(token: token)
        XCTAssertFalse(transition.destinationDidRender(token: token))
        assertIdle(transition)
    }

    func testFinishBeforeTheFirstDestinationFrameCannotDropTheOpaqueCover() throws {
        let transition = MenuReturnTransition()
        let image = snapshot()
        let token = try XCTUnwrap(transition.begin(snapshot: image))

        transition.finish(token: token)
        XCTAssertTrue(transition.isActive)
        XCTAssertTrue(transition.snapshot === image)
        XCTAssertEqual(transition.token, token)
        XCTAssertEqual(transition.opacity, 1)

        XCTAssertTrue(transition.destinationDidRender(token: token))
        transition.finish(token: token)
        assertIdle(transition)
    }

    func testOldFrameAndCompletionCannotRevealOrClearANewerReturn() throws {
        let transition = MenuReturnTransition()
        let oldToken = try XCTUnwrap(transition.begin(snapshot: snapshot()))
        let newImage = snapshot(color: .black)
        let newToken = try XCTUnwrap(transition.begin(snapshot: newImage))
        XCTAssertNotEqual(newToken, oldToken)

        XCTAssertFalse(transition.destinationDidRender(token: oldToken))
        transition.finish(token: oldToken)
        XCTAssertTrue(transition.snapshot === newImage)
        XCTAssertEqual(transition.token, newToken)
        XCTAssertEqual(transition.opacity, 1)

        XCTAssertTrue(transition.destinationDidRender(token: newToken))
        transition.finish(token: newToken)
        assertIdle(transition)
    }

    func testBeginningDuringADissolveResetsReadinessAndRejectsTheOldAnimationCompletion() throws {
        let transition = MenuReturnTransition()
        let oldToken = try XCTUnwrap(transition.begin(snapshot: snapshot()))
        XCTAssertTrue(transition.destinationDidRender(token: oldToken))
        let newImage = snapshot(color: .black)
        let newToken = try XCTUnwrap(transition.begin(snapshot: newImage))

        transition.finish(token: oldToken)
        transition.finish(token: newToken)
        XCTAssertEqual(transition.opacity, 1,
                       "An earlier rendered scene cannot mark the new destination ready")
        XCTAssertTrue(transition.snapshot === newImage)
        XCTAssertEqual(transition.token, newToken)
        XCTAssertFalse(transition.destinationDidRender(token: oldToken))
        XCTAssertTrue(transition.destinationDidRender(token: newToken))
        transition.finish(token: newToken)
        assertIdle(transition)
    }

    func testMissingCaptureLeavesNoBarrierAndInvalidatesAnyEarlierReturn() throws {
        let transition = MenuReturnTransition()
        XCTAssertNil(transition.begin(snapshot: nil))
        assertIdle(transition)

        for alreadyRendered in [false, true] {
            let token = try XCTUnwrap(transition.begin(snapshot: snapshot()))
            if alreadyRendered { XCTAssertTrue(transition.destinationDidRender(token: token)) }

            XCTAssertNil(transition.begin(snapshot: nil))
            assertIdle(transition)
            XCTAssertFalse(transition.destinationDidRender(token: token))
            transition.finish(token: token)
            assertIdle(transition)
        }
    }

    func testCancellationInvalidatesCallbacksBothBeforeAndDuringTheDissolve() throws {
        let transition = MenuReturnTransition()
        for alreadyRendered in [false, true] {
            let token = try XCTUnwrap(transition.begin(snapshot: snapshot()))
            if alreadyRendered { XCTAssertTrue(transition.destinationDidRender(token: token)) }

            transition.cancel()
            transition.cancel()
            XCTAssertFalse(transition.destinationDidRender(token: token))
            transition.finish(token: token)
            assertIdle(transition)
        }

        let nextToken = try XCTUnwrap(transition.begin(snapshot: snapshot()))
        XCTAssertEqual(transition.opacity, 1)
        XCTAssertTrue(transition.destinationDidRender(token: nextToken))
        transition.finish(token: nextToken)
        assertIdle(transition)
    }

    func testOnlyTheMatchingCompletionCanReleaseTheRenderedSnapshot() throws {
        let transition = MenuReturnTransition()
        let image = snapshot()
        let token = try XCTUnwrap(transition.begin(snapshot: image))
        XCTAssertTrue(transition.destinationDidRender(token: token))

        transition.finish(token: UUID())
        XCTAssertTrue(transition.isActive)
        XCTAssertTrue(transition.snapshot === image)
        XCTAssertEqual(transition.token, token)
        transition.finish(token: token)
        assertIdle(transition)
    }

    private func snapshot(color: UIColor = .white) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1), format: format).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
    }

    private func assertIdle(_ transition: MenuReturnTransition,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertFalse(transition.isActive, file: file, line: line)
        XCTAssertNil(transition.snapshot, file: file, line: line)
        XCTAssertNil(transition.token, file: file, line: line)
        XCTAssertEqual(transition.opacity, 0, file: file, line: line)
    }
}
