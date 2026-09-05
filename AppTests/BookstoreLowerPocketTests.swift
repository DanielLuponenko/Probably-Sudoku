import XCTest
import simd
@testable import ProbablySudoku

/// Physical pocket-space checks. No SceneKit renderer, camera or texture is
/// needed: collision is against the complete authored book's convex envelope.
final class BookstoreLowerPocketTests: XCTestCase {
    func testSeatingAndTippingNeverRaiseTheTopIntoTheBookAbove() {
        for index in 4...11 {
            let fixture = fixture(index: index)
            let initialTop = fixture.worldCorners(at: fixture.origin).map(\.y).max()!
            for sample in 0...200 {
                let progress = BookstoreLowerPocketPath.tipEnd * Float(sample) / 200
                let top = fixture.worldCorners(at: fixture.path.pose(at: progress)).map(\.y).max()!
                XCTAssertLessThanOrEqual(top, initialTop + tolerance,
                                        "Book index \(index) rises during seat/tip at \(progress)")
            }
        }
    }

    func testSlideAndPullRemainInFrontOfTheUpperBookWhereTheirHeightsOverlap() {
        for index in 4...11 {
            let fixture = fixture(index: index)
            let neighbor = upperNeighbor(of: index)
            let neighborCorners = neighbor.worldCorners(at: neighbor.origin)
            let neighborBottom = neighborCorners.map(\.y).min()!
            let neighborFront = neighborCorners.map(\.z).max()!

            for sample in 0...300 {
                let progress = BookstoreLowerPocketPath.tipEnd
                    + (BookstoreLowerPocketPath.clearEnd - BookstoreLowerPocketPath.tipEnd)
                    * Float(sample) / 300
                let crossSection = fixture.crossSection(at: fixture.path.pose(at: progress))
                let overlappingHeight = clippedAbove(crossSection, y: neighborBottom)
                if let back = overlappingHeight.map(\.y).min() {
                    XCTAssertGreaterThan(back + tolerance, neighborFront,
                                         "Book index \(index) enters upper book at \(progress)")
                }
            }
        }
    }

    func testSlideAndPullClearTheUpperPocketsLowestFrontWire() {
        for index in 4...11 {
            let fixture = fixture(index: index)
            let upperOffset: Float = index >= 8 ? 1.53 : 1.36
            let upperWire = Wire(y: upperOffset - 0.60, z: 0.24, radius: 0.021)
            for sample in 0...300 {
                let progress = BookstoreLowerPocketPath.tipEnd
                    + (BookstoreLowerPocketPath.clearEnd - BookstoreLowerPocketPath.tipEnd)
                    * Float(sample) / 300
                let section = fixture.crossSection(at: fixture.path.pose(at: progress))
                let separation = distance(from: upperWire.center, to: section)
                XCTAssertGreaterThanOrEqual(separation + tolerance, upperWire.radius,
                                            "Book index \(index) intersects upper pocket wire at \(progress)")
            }
        }
    }

    func testExtractionCreatesNoNewPenetrationOfEitherRetainingWire() {
        let wires = [Wire(y: -0.39, z: 0.25, radius: 0.023),
                     Wire(y: -0.60, z: 0.24, radius: 0.021)]
        for index in 4...11 {
            let fixture = fixture(index: index)
            let initialSection = fixture.crossSection(at: fixture.origin)
            for wire in wires {
                let initialPenetration = max(0, wire.radius - distance(from: wire.center, to: initialSection))
                for sample in 0...500 {
                    let progress = BookstoreLowerPocketPath.clearEnd * Float(sample) / 500
                    let section = fixture.crossSection(at: fixture.path.pose(at: progress))
                    let penetration = max(0, wire.radius - distance(from: wire.center, to: section))
                    XCTAssertLessThanOrEqual(penetration, initialPenetration + tolerance,
                                            "Book index \(index) newly enters front wire y=\(wire.center.x) at \(progress)")
                }
            }
        }
        // Authored books extend beneath the pocket's floor at rest. This test
        // intentionally does not assert impossible floor-rail clearance.
    }

    func testEveryTallerBottomBookGetsMoreReleaseTravelAndEveryTailClearsTheRail() {
        for bottomIndex in 8...11 {
            let bottom = fixture(index: bottomIndex)
            let bottomSlide = simd_distance(bottom.path.released.position, bottom.path.tipped(at: 1).position)
            for middleIndex in 4...7 {
                let middle = fixture(index: middleIndex)
                let middleSlide = simd_distance(middle.path.released.position, middle.path.tipped(at: 1).position)
                XCTAssertGreaterThan(bottomSlide, middleSlide,
                                     "Bottom book \(bottomIndex)'s authored 1.15 height scale needs a longer release than index \(middleIndex)")
            }
        }
        for index in 4...11 {
            let fixture = fixture(index: index)
            let lowest = fixture.worldCorners(at: fixture.path.released).map(\.y).min()!
            XCTAssertEqual(lowest, BookstoreExtractionPath.railTop + BookstoreExtractionPath.clearance,
                           accuracy: tolerance, "Book index \(index) has not cleared the top retaining wire")
        }
    }

    func testNoPresentationScaleIsAppliedBeforeTheWholeBookClearsThePocket() {
        for index in 4...11 {
            let fixture = fixture(index: index)
            for sample in 0...200 {
                let progress = BookstoreLowerPocketPath.clearEnd * Float(sample) / 200
                assertVector(fixture.path.pose(at: progress).scale, equals: fixture.origin.scale)
            }
            let clearedBack = fixture.worldCorners(at: fixture.path.pose(at: BookstoreLowerPocketPath.clearEnd))
                .map(\.z).min()!
            XCTAssertGreaterThanOrEqual(clearedBack + tolerance, BookstoreLowerPocketPath.clearDepth)
            XCTAssertGreaterThan(fixture.path.pose(at: BookstoreLowerPocketPath.clearEnd + 0.05).scale.x,
                                 fixture.origin.scale.x)
        }
    }

    func testEveryLegIsContinuousAndTheExactOriginAndDestinationArePreserved() {
        let seams = [BookstoreLowerPocketPath.seatEnd, BookstoreLowerPocketPath.tipEnd,
                     BookstoreLowerPocketPath.slideEnd, BookstoreLowerPocketPath.clearEnd]
        for index in 4...11 {
            let fixture = fixture(index: index)
            assertPose(fixture.path.pose(at: -0.1), equals: fixture.origin)
            assertPose(fixture.path.pose(at: 0), equals: fixture.origin)
            assertPose(fixture.path.pose(at: 1), equals: fixture.destination)
            assertPose(fixture.path.pose(at: 1.1), equals: fixture.destination)
            for seam in seams {
                let before = fixture.worldCorners(at: fixture.path.pose(at: seam - 0.00001))
                let exact = fixture.worldCorners(at: fixture.path.pose(at: seam))
                let after = fixture.worldCorners(at: fixture.path.pose(at: seam + 0.00001))
                for corner in before.indices {
                    XCTAssertLessThan(simd_distance(before[corner], exact[corner]), 0.0001,
                                      "Book index \(index) jumps into leg ending at \(seam)")
                    XCTAssertLessThan(simd_distance(after[corner], exact[corner]), 0.0001,
                                      "Book index \(index) jumps out of leg ending at \(seam)")
                }
            }
        }
    }

    func testPoseRoundTripPreservesEveryBottomBooksNonuniformScaleAndTilt() {
        for index in 8...11 {
            let book = fixture(index: index)
            let origin = book.origin
            let roundTrip = BookstoreExtractionPose(transform: origin.transform)
            assertPose(roundTrip, equals: origin)
            for point in [book.minimum, book.maximum] {
                assertVector(roundTrip.point(point), equals: origin.point(point))
            }
        }
    }

    private let tolerance: Float = 0.00002

    private struct Fixture {
        let minimum: SIMD3<Float>
        let maximum: SIMD3<Float>
        let origin: BookstoreExtractionPose
        let destination: BookstoreExtractionPose

        var path: BookstoreLowerPocketPath {
            BookstoreLowerPocketPath(origin: origin, destination: destination, minimum: minimum, maximum: maximum)
        }

        func worldCorners(at pose: BookstoreExtractionPose) -> [SIMD3<Float>] {
            [minimum.x, maximum.x].flatMap { x in
                [minimum.y, maximum.y].flatMap { y in
                    [minimum.z, maximum.z].map { pose.point(SIMD3(x, y, $0)) }
                }
            }
        }

        /// Ordered convex YZ rectangle; all pre-clear rotations are about X.
        /// Unlike a world AABB, this preserves which depths occur at wire height.
        func crossSection(at pose: BookstoreExtractionPose) -> [SIMD2<Float>] {
            [(minimum.y, minimum.z), (maximum.y, minimum.z),
             (maximum.y, maximum.z), (minimum.y, maximum.z)].map { y, z in
                let point = pose.point(SIMD3(0, y, z))
                return SIMD2(point.y, point.z)
            }
        }
    }

    private func fixture(index: Int, position: SIMD3<Float> = .zero) -> Fixture {
        // Union of every component in makeEditionBook: covers/page block,
        // overhanging spine, LiveBook face + bookmarks, and rear printed plane.
        // These are NOT just the front-cover dimensions. The asymmetric face
        // supplies the lowest corner; both printed planes supply full depth.
        let width = Float(0.89 + Double(index % 3) * 0.025)
        let thickness = Float(0.14 + Double(index % 4) * 0.012)
        let minimum = SIMD3<Float>(-width * 0.5 - 0.01, -width * 0.7445, -(thickness * 0.5 + 0.052))
        let maximum = SIMD3<Float>(width * 0.7, width * 0.7005, thickness * 0.5 + 0.052)
        let origin = pose(position: position, angle: -0.10,
                          scale: SIMD3(1, index >= 8 ? 1.15 : 1, 1))
        let destination = pose(position: SIMD3(0.15, 0.1, 3.0), angle: 0, scale: SIMD3(repeating: 3))
        return Fixture(minimum: minimum, maximum: maximum, origin: origin, destination: destination)
    }

    private func upperNeighbor(of index: Int) -> Fixture {
        fixture(index: index - 4, position: SIMD3(0, index >= 8 ? 1.53 : 1.36, 0))
    }

    private func pose(position: SIMD3<Float>, angle: Float, scale: SIMD3<Float>) -> BookstoreExtractionPose {
        var result = BookstoreExtractionPose(transform: matrix_identity_float4x4)
        result.position = position
        result.orientation = simd_quatf(angle: angle, axis: SIMD3(1, 0, 0))
        result.scale = scale
        return result
    }

    private struct Wire {
        let center: SIMD2<Float>
        let radius: Float
        init(y: Float, z: Float, radius: Float) {
            center = SIMD2(y, z)
            self.radius = radius
        }
    }

    private func clippedAbove(_ polygon: [SIMD2<Float>], y: Float) -> [SIMD2<Float>] {
        guard var previous = polygon.last else { return [] }
        var result: [SIMD2<Float>] = []
        for current in polygon {
            let previousInside = previous.x >= y
            let currentInside = current.x >= y
            if previousInside != currentInside {
                let fraction = (y - previous.x) / (current.x - previous.x)
                result.append(previous + (current - previous) * fraction)
            }
            if currentInside { result.append(current) }
            previous = current
        }
        return result
    }

    private func distance(from point: SIMD2<Float>, to polygon: [SIMD2<Float>]) -> Float {
        var minimumDistance = Float.infinity
        var signs: [Float] = []
        for index in polygon.indices {
            let a = polygon[index], b = polygon[(index + 1) % polygon.count]
            let edge = b - a
            let relative = point - a
            signs.append(edge.x * relative.y - edge.y * relative.x)
            let projection = min(1, max(0, simd_dot(relative, edge) / simd_length_squared(edge)))
            minimumDistance = min(minimumDistance, simd_distance(point, a + edge * projection))
        }
        let inside = signs.allSatisfy { $0 >= 0 } || signs.allSatisfy { $0 <= 0 }
        return inside ? 0 : minimumDistance
    }

    private func assertPose(_ actual: BookstoreExtractionPose, equals expected: BookstoreExtractionPose,
                            file: StaticString = #filePath, line: UInt = #line) {
        assertVector(actual.position, equals: expected.position, file: file, line: line)
        assertVector(actual.scale, equals: expected.scale, file: file, line: line)
        XCTAssertEqual(abs(simd_dot(actual.orientation.vector, expected.orientation.vector)), 1,
                       accuracy: tolerance, file: file, line: line)
    }

    private func assertVector(_ actual: SIMD3<Float>, equals expected: SIMD3<Float>,
                              file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.x, expected.x, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: tolerance, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: tolerance, file: file, line: line)
    }
}
