import XCTest
import CoreGraphics
import simd
@testable import ProbablySudoku

final class BookstoreSelectionTests: XCTestCase {
    private let phoneViewports: [CGSize] = [
        CGSize(width: 320, height: 568),
        CGSize(width: 375, height: 667),
        CGSize(width: 390, height: 844),
        CGSize(width: 393, height: 852),
        CGSize(width: 402, height: 874),
        CGSize(width: 430, height: 932),
        CGSize(width: 440, height: 956),
    ]

    func testPlaqueHasEqualScreenGuttersForEveryPhoneAndObstacleHeight() {
        for viewport in phoneViewports {
            let layout = BookstoreSelectionLayout(viewport: viewport)
            for height in [CGFloat(84), CGFloat(122)] {
                let frame = layout.plaqueFrame(height: height)
                let leftGap = frame.minX
                let rightGap = viewport.width - frame.maxX

                XCTAssertGreaterThan(leftGap, 0)
                XCTAssertGreaterThan(rightGap, 0)
                // Floating-point roundoff is not a visual margin. This is
                // tighter than one millionth of a display pixel.
                XCTAssertEqual(leftGap, rightGap, accuracy: 0.000000001,
                               "Unequal plaque gutters in \(viewport)")
                XCTAssertEqual(frame.midX, viewport.width / 2, accuracy: 0.000000001)
                XCTAssertEqual(frame.height, height)
                for scale in [CGFloat(2), CGFloat(3)] {
                    XCTAssertEqual((leftGap * scale).rounded(), (rightGap * scale).rounded(),
                                   "Plaque gutters differ at \(scale)x in \(viewport)")
                }
            }
        }
    }

    func testSharedCanvasCentersTheCoverBodyAndKeepsPlaqueBelowTheFinalBook() {
        for viewport in phoneViewports {
            let layout = BookstoreSelectionLayout(viewport: viewport)
            let canvas = CGRect(
                x: layout.coverCenter.x - layout.canvasSize.width / 2,
                y: layout.coverCenter.y - layout.canvasSize.height / 2,
                width: layout.canvasSize.width,
                height: layout.canvasSize.height
            )
            // LiveBook is top-leading in the larger canvas so its bookmarks
            // can extend beyond the front cover without recentering the body.
            let coverLeft = canvas.minX
            let coverRight = coverLeft + layout.bookWidth
            XCTAssertEqual(coverLeft, viewport.width - coverRight, accuracy: 0.000000001,
                           "The physical cover body moved off the screen center in \(viewport)")
            XCTAssertGreaterThan(layout.canvasSize.width, layout.bookWidth)
            XCTAssertEqual(canvas.midX, layout.coverCenter.x, accuracy: 0.000000001)
            XCTAssertEqual(canvas.midY, layout.coverCenter.y, accuracy: 0.000000001)

            let plain = layout.plaqueFrame(height: 84)
            let obstacle = layout.plaqueFrame(height: 122)
            XCTAssertEqual(plain.minY - canvas.maxY, 10, accuracy: 0.000000001)
            XCTAssertEqual(obstacle.minY, plain.minY)
            XCTAssertEqual(obstacle.minX, plain.minX)
            XCTAssertEqual(obstacle.width, plain.width)
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
