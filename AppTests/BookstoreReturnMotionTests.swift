import XCTest
import simd
@testable import ProbablySudoku

final class BookstoreReturnMotionTests: XCTestCase {
    func testReturnRetracesEveryUpperAndLowerExtractionSampleOnAllRackFaces() {
        for index in 0..<12 {
            let path = motionPath(index: index)
            for sample in 0...400 {
                let returning = Float(sample) / 400
                assertTransform(path.returnTransform(at: returning), equals: path.transform(at: 1 - returning))
            }
            assertTransform(path.returnTransform(at: 0), equals: path.transform(at: 1))
            assertTransform(path.returnTransform(at: 1), equals: path.transform(at: 0))
            assertTransform(path.returnTransform(at: 1.2), equals: path.transform(at: 0))
        }
    }

    func testInterruptedExtractionReturnsFromItsCurrentPoseWithoutJumpingForward() {
        for index in 0..<12 {
            let path = motionPath(index: index)
            let interruptions: [Float] = [0, 0.03, 0.14, 0.32, 0.46, 0.56, 0.75, 1]
            for extracted in interruptions {
                assertTransform(path.returnTransform(at: 0, from: extracted), equals: path.transform(at: extracted))
                for sample in 0...100 {
                    let returning = Float(sample) / 100
                    assertTransform(path.returnTransform(at: returning, from: extracted),
                                    equals: path.transform(at: extracted * (1 - returning)))
                }
                assertTransform(path.returnTransform(at: 1, from: extracted), equals: path.transform(at: 0))
            }
        }
    }

    func testLowerReturnCompletesShrinkingBeforeReenteringTheWirePocket() {
        for index in 4..<12 {
            let path = motionPath(index: index)
            let original = BookstoreExtractionPose(transform: path.transform(at: 0))
            for sample in 0...100 {
                // The last 56% is the exact reverse of seat/tip/slide/clear.
                let returning = 1 - BookstoreLowerPocketPath.clearEnd
                    + BookstoreLowerPocketPath.clearEnd * Float(sample) / 100
                let pose = BookstoreExtractionPose(transform: path.returnTransform(at: returning))
                XCTAssertLessThan(simd_distance(pose.scale, original.scale), 0.00001,
                                  "Book \(index) cannot keep screen scale while crossing a pocket rail")
            }
        }
    }

    func testReturningRetainsEditionIdentityWithoutExposingLiveBookControls() {
        let focus = BookstoreBookFocus.returning("genuinely")
        XCTAssertEqual(focus.editionID, "genuinely")
        XCTAssertFalse(focus.isPresented)
        XCTAssertNotEqual(focus, .shelf)
    }

    private func motionPath(index: Int) -> BookstoreBookMotionPath {
        let width = Float(0.89 + Double(index % 3) * 0.025)
        let thickness = Float(0.14 + Double(index % 4) * 0.012)
        let minimum = SIMD3<Float>(-width * 0.5 - 0.01, -width * 0.7445, -(thickness * 0.5 + 0.052))
        let maximum = SIMD3<Float>(width * 0.7, width * 0.7005, thickness * 0.5 + 0.052)
        var origin = BookstoreExtractionPose(transform: matrix_identity_float4x4)
        origin.orientation = simd_quatf(angle: -0.10, axis: SIMD3(1, 0, 0))
        origin.scale.y = index >= 8 ? 1.15 : 1
        var destination = BookstoreExtractionPose(transform: matrix_identity_float4x4)
        destination.position = SIMD3(0.15, 0.1, 3)
        destination.scale = SIMD3(repeating: 3)
        var pocket = simd_float4x4(simd_quatf(angle: Float(index % 4) * .pi / 2, axis: SIMD3(0, 1, 0)))
        pocket.columns.3 = SIMD4(0, Float(index / 4) * -1.4, 0, 1)
        if index >= 4 {
            return BookstoreBookMotionPath(lower: BookstoreLowerPocketPath(
                origin: origin, destination: destination, minimum: minimum, maximum: maximum
            ), pocketTransform: pocket)
        }
        let worldOrigin = BookstoreExtractionPose(transform: pocket * origin.transform)
        let worldDestination = BookstoreExtractionPose(transform: pocket * destination.transform)
        let up = SIMD3<Float>(pocket.columns.1.x, pocket.columns.1.y, pocket.columns.1.z)
        let outward = SIMD3<Float>(pocket.columns.2.x, pocket.columns.2.y, pocket.columns.2.z)
        let lift = BookstoreExtractionPath.liftDistance(lowestPoint: minimum.y)
        let path = BookstoreExtractionPath(origin: worldOrigin.position, lifted: worldOrigin.position + up * lift,
                                          destination: worldDestination.position, outward: outward, up: up)
        return BookstoreBookMotionPath(upper: path, origin: worldOrigin, destination: worldDestination)
    }

    private func assertTransform(_ actual: simd_float4x4, equals expected: simd_float4x4,
                                 file: StaticString = #filePath, line: UInt = #line) {
        for column in 0..<4 {
            XCTAssertLessThan(simd_distance(actual[column], expected[column]), 0.00001, file: file, line: line)
        }
    }
}
