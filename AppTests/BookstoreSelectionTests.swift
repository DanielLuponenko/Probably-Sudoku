import XCTest
import SwiftUI
import CoreGraphics
import simd
import ProbablySudokuEngine
@testable import ProbablySudoku

final class BookstoreSelectionTests: XCTestCase {
    @MainActor
    func testAccessibleShelfActionsBrowseEveryVolumeWithoutSelectingOrChangingTheSceneDirectly() throws {
        let editions = BookEdition.shelf
        XCTAssertEqual(editions.count, 12)
        var current = try XCTUnwrap(editions.first)
        var requestedIDs: [String] = []
        var selectedIDs: [String] = []

        func selector(canBrowse: Bool = true) -> BookstoreShelfSelector {
            let displayed = current
            return BookstoreShelfSelector(editions: editions, selectedEdition: displayed,
                                           canBrowse: canBrowse,
                                           onSelect: { selectedIDs.append(displayed.id) },
                                           onBrowse: { requestedID in
                requestedIDs.append(requestedID)
                if let requested = editions.first(where: { $0.id == requestedID }) { current = requested }
            })
        }

        var visited: [String] = []
        for volume in 1...editions.count {
            let control = selector()
            visited.append(current.id)
            XCTAssertEqual(control.accessibilityValue, "Volume \(volume) of 12. \(current.title)")
            control.browse(.increment)
        }
        XCTAssertEqual(visited, editions.map(\.id), "Native browsing must reach every shelf edition in order.")
        XCTAssertEqual(current.id, editions[0].id, "Next Book wraps from the last volume to the first.")
        XCTAssertTrue(selectedIDs.isEmpty, "Browsing must not extract or open a Book.")

        selector().browse(.decrement)
        XCTAssertEqual(current.id, editions.last?.id, "Previous Book wraps back to the final volume.")
        selector().selectCurrentBook()
        XCTAssertEqual(selectedIDs, [current.id], "Activation keeps the existing Select action separate from browsing.")

        let requestsBeforeDisabledActions = requestedIDs
        selector(canBrowse: false).browse(.increment)
        selector(canBrowse: false).browse(.decrement)
        selector(canBrowse: false).selectCurrentBook()
        XCTAssertEqual(requestedIDs, requestsBeforeDisabledActions,
                       "Focused, returning or opening Books must reject stale browse actions.")
        XCTAssertEqual(selectedIDs.count, 1)
    }

    private let phoneViewports: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 393, height: 852),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]

    func testSharedCanvasCentersTheVisibleCoverAndBookmarkSilhouette() {
        for viewport in phoneViewports {
            let layout = BookstoreSelectionLayout(viewport: viewport)
            let canvas = CGRect(
                x: layout.coverCenter.x - layout.canvasSize.width / 2,
                y: layout.coverCenter.y - layout.canvasSize.height / 2,
                width: layout.canvasSize.width,
                height: layout.canvasSize.height
            )
            // LiveBook is top-leading in the larger canvas. Center the actual
            // cover-plus-bookmark silhouette while retaining its right gutter.
            XCTAssertEqual(layout.visualBookFrame.midX, viewport.width / 2,
                           accuracy: 0.000000001,
                           "The visible Book silhouette moved off center in \(viewport)")
            XCTAssertEqual(layout.visualBookFrame.width, layout.bookWidth * 1.107,
                           accuracy: 0.000000001,
                           "Optical centering includes the full bookmark silhouette.")
            XCTAssertLessThanOrEqual(layout.visualBookFrame.maxX, canvas.maxX)
            XCTAssertGreaterThan(layout.canvasSize.width, layout.bookWidth)
            XCTAssertEqual(canvas.midX, layout.coverCenter.x, accuracy: 0.000000001)
            XCTAssertEqual(canvas.midY, layout.coverCenter.y, accuracy: 0.000000001)
        }
    }

    func testPhoneSelectionClearsTheTopSignAndPlacesOpenDirectlyBelowTheBook() {
        for viewport in phoneViewports {
            let layout = BookstoreSelectionLayout(viewport: viewport)
            XCTAssertGreaterThan(layout.bookWidth, 0)
            XCTAssertLessThanOrEqual(layout.bookWidth, viewport.width * 0.80)
            XCTAssertEqual(layout.headerClearance, 160)
            XCTAssertGreaterThanOrEqual(layout.visualBookFrame.minY,
                                        layout.headerClearance - 0.000001)
            XCTAssertEqual(layout.openButtonFrame.minY - layout.visualBookFrame.maxY, 28,
                           accuracy: 0.000001, "Open must follow the Book: \(viewport)")
            XCTAssertEqual(layout.openButtonFrame.height, 52)
            XCTAssertEqual(layout.openButtonFrame.midX, viewport.width / 2, accuracy: 0.000001)
            XCTAssertLessThan(layout.openButtonFrame.width, layout.visualBookFrame.width)
            XCTAssertLessThanOrEqual(layout.openButtonFrame.width, 280)
            XCTAssertGreaterThanOrEqual(viewport.height - layout.openButtonFrame.maxY,
                                        layout.openButtonBottomPadding - 0.000001)
            XCTAssertEqual(layout.openButtonBottomPadding, 14)
        }
    }

    func testCompactPhoneReservesOnlyTheSignBookClearanceAndOpenAction() {
        let viewport = CGSize(width: 320, height: 568)
        let layout = BookstoreSelectionLayout(viewport: viewport)
        let availableHeight = viewport.height - 160 - 14 - 52 - 28
        XCTAssertEqual(layout.canvasSize.height, availableHeight, accuracy: 0.000001,
                       "The removed lower benefit plaque must not leave a reserved 112pt band.")
        XCTAssertEqual(layout.bookWidth, availableHeight / 1.445, accuracy: 0.000001)
        XCTAssertEqual(layout.visualBookFrame.minY, 160, accuracy: 0.000001)
        XCTAssertEqual(layout.openButtonFrame.maxY, viewport.height - 14, accuracy: 0.000001)
    }

    func testTallPhoneOpenActionIsRaisedWithTheBookInsteadOfPinnedToTheScreenBottom() {
        let viewport = CGSize(width: 390, height: 844)
        let layout = BookstoreSelectionLayout(viewport: viewport)
        XCTAssertEqual(layout.openButtonFrame.minY, layout.visualBookFrame.maxY + 28,
                       accuracy: 0.000001)
        XCTAssertGreaterThan(viewport.height - layout.openButtonFrame.maxY, 80,
                             "A tall viewport must not strand Open at the screen edge.")
    }

    func testTabletSelectionFitsTheBookBetweenTheTopSignAndFollowingOpenAction() {
        let tablets = [
            CGSize(width: 744, height: 1133), CGSize(width: 768, height: 1024),
            CGSize(width: 810, height: 1080), CGSize(width: 820, height: 1180),
            CGSize(width: 834, height: 1194), CGSize(width: 1024, height: 1366),
            CGSize(width: 1032, height: 1376), CGSize(width: 1024, height: 768)
        ]
        for viewport in tablets {
            let layout = BookstoreSelectionLayout(viewport: viewport)
            let bookTop = layout.coverCenter.y - layout.canvasSize.height / 2
            let bookBottom = layout.coverCenter.y + layout.canvasSize.height / 2
            XCTAssertGreaterThan(layout.bookWidth, 0)
            XCTAssertLessThanOrEqual(layout.bookWidth, viewport.width * 0.80)
            XCTAssertGreaterThanOrEqual(bookTop, layout.headerClearance - 0.000001,
                                        "Selected cover overlaps the top sign: \(viewport)")
            XCTAssertEqual(layout.visualBookFrame.midX, viewport.width / 2,
                           accuracy: 0.000001)
            XCTAssertEqual(layout.openButtonFrame.height, 52)
            XCTAssertGreaterThanOrEqual(viewport.height - layout.openButtonFrame.maxY,
                                        34 - 0.000001)
            XCTAssertEqual(layout.openButtonFrame.minY - bookBottom, 28, accuracy: 0.000001,
                           "The same viewport-only destination serves all twelve Books: \(viewport)")
        }
    }

    func testLiftDistanceClearsTheHighestRailEdgeWithTheRequiredMargin() {
        let clearHeight = BookstoreExtractionPath.railTop + BookstoreExtractionPath.clearance
        let lowestPoints: [Float] = [-1.2, -0.91, -0.52, -0.367, -0.297, -0.1, 0.2]
        for lowestPoint in lowestPoints {
            let lift = BookstoreExtractionPath.liftDistance(lowestPoint: lowestPoint)
            XCTAssertGreaterThanOrEqual(lift, 0)
            XCTAssertGreaterThanOrEqual(lowestPoint + lift + 0.000001, clearHeight)
            if lowestPoint < clearHeight {
                XCTAssertEqual(lowestPoint + lift, clearHeight, accuracy: 0.000001,
                               "The lowest tilted corner must clear the rail, not the book center")
            } else {
                XCTAssertEqual(lift, 0, "An already-clear book must not move down toward the rail")
            }
        }
    }

    func testFirstLegMovesOnlyUpWithoutMovingThroughTheFrontRail() {
        let rotations: [simd_quatf] = [
            simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0)),
            simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(0, 1, 0)),
            simd_quatf(angle: .pi / 7, axis: simd_normalize(SIMD3<Float>(1, 0, 1))),
        ]
        for rotation in rotations {
            let up = rotation.act(SIMD3<Float>(0, 1, 0))
            let outward = rotation.act(SIMD3<Float>(0, 0, 1))
            let path = makePath(up: up, outward: outward)
            var previousLift: Float = 0
            for sample in 0...100 {
                let progress = BookstoreExtractionPath.liftFraction * Float(sample) / 100
                let movement = path.position(at: progress) - path.origin
                let liftedDistance = simd_dot(movement, up)
                let lateralMovement = movement - up * liftedDistance
                XCTAssertEqual(simd_dot(movement, outward), 0, accuracy: 0.000001,
                               "The book must clear the pocket before moving outward")
                XCTAssertLessThan(simd_length(lateralMovement), 0.000001)
                XCTAssertGreaterThanOrEqual(liftedDistance + 0.000001, previousLift)
                previousLift = liftedDistance
            }
            assertVector(path.position(at: BookstoreExtractionPath.liftFraction), equals: path.lifted)
        }
    }

    func testScaleAndOrientationProgressStayAtShelfValuesUntilTheLiftFinishes() {
        let path = makePath()
        for sample in 0...100 {
            let progress = BookstoreExtractionPath.liftFraction * Float(sample) / 100
            XCTAssertEqual(path.presentationProgress(at: progress), 0,
                           "Scaling or rotating before the rail is cleared clips the book through it")
        }
        XCTAssertEqual(path.presentationProgress(at: -0.5), 0)
        XCTAssertGreaterThan(path.presentationProgress(at: BookstoreExtractionPath.liftFraction + 0.05), 0)
        XCTAssertEqual(path.presentationProgress(at: 1), 1)
        XCTAssertEqual(path.presentationProgress(at: 1.5), 1)

        var previous: Float = 0
        for sample in 0...100 {
            let current = path.presentationProgress(at: Float(sample) / 100)
            XCTAssertGreaterThanOrEqual(current, previous)
            XCTAssertLessThanOrEqual(current, 1)
            previous = current
        }
    }

    func testExtractionStartsAtTheShelfEndsAtTheSharedDestinationAndClampsOvershoot() {
        let path = makePath()
        assertVector(path.position(at: -0.2), equals: path.origin)
        assertVector(path.position(at: 0), equals: path.origin)
        assertVector(path.position(at: BookstoreExtractionPath.liftFraction), equals: path.lifted)
        assertVector(path.position(at: 1), equals: path.destination)
        assertVector(path.position(at: 1.2), equals: path.destination)
    }

    func testThereIsNoPositionJumpWhereLiftHandsOffToOutwardTravel() {
        let path = makePath()
        let seam = BookstoreExtractionPath.liftFraction
        let epsilon: Float = 0.0001
        let before = path.position(at: seam - epsilon)
        let after = path.position(at: seam + epsilon)

        XCTAssertLessThan(simd_distance(before, path.lifted), 0.00001)
        XCTAssertLessThan(simd_distance(after, path.lifted), 0.00001)
        XCTAssertLessThan(simd_distance(before, after), 0.00001,
                          "The second leg must start at the lifted shelf position, not the screen center")
        XCTAssertGreaterThan(simd_dot(path.position(at: seam + 0.05) - path.lifted, path.outward), 0,
                             "Once clear, the book should begin moving out of its pocket")
    }

    func testOnlyPresentedFocusExposesTheInteractiveBookWhileExtractionRetainsItsIdentity() {
        let firstID = "volume-one"
        let secondID = "volume-two"
        let lifecycle: [BookstoreBookFocus] = [.shelf, .extracting(firstID), .presented(firstID), .shelf]

        XCTAssertEqual(lifecycle.map(\.editionID), [nil, firstID, firstID, nil])
        XCTAssertEqual(lifecycle.map(\.isPresented), [false, false, true, false])
        XCTAssertNotEqual(BookstoreBookFocus.extracting(firstID), .presented(firstID))
        XCTAssertNotEqual(BookstoreBookFocus.presented(firstID), .presented(secondID))
        XCTAssertEqual(BookstoreBookFocus.extracting(firstID), .extracting(firstID))
    }

    private func makePath(up: SIMD3<Float> = SIMD3<Float>(0, 1, 0),
                          outward: SIMD3<Float> = SIMD3<Float>(0, 0, 1)) -> BookstoreExtractionPath {
        let origin = SIMD3<Float>(0.3, -0.7, -1.2)
        let lift = BookstoreExtractionPath.liftDistance(lowestPoint: -0.91)
        return BookstoreExtractionPath(
            origin: origin,
            lifted: origin + up * lift,
            destination: origin + up * 0.3 + outward * 2.2,
            outward: outward,
            up: up
        )
    }

    private func assertVector(_ actual: SIMD3<Float>, equals expected: SIMD3<Float>,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: 0.000001, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: 0.000001, file: file, line: line)
    }
}
