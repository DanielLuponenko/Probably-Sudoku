import XCTest
@testable import ProbablySudoku

final class BookstoreRackSpinTests: XCTestCase {
    func testDragSensitivityPreservesRotationForTheSameFractionOfEachScreen() {
        XCTAssertEqual(BookstoreRackSpin.radiansPerPoint(viewportWidth: 402), 0.009,
                       accuracy: 0.000000001)
        for width in [240.0, 320, 375, 402, 440, 744, 834, 1024, 1366] {
            let radians = width * 0.35 * BookstoreRackSpin.radiansPerPoint(viewportWidth: width)
            XCTAssertEqual(radians, 402 * 0.35 * 0.009, accuracy: 0.000000001,
                           "An equivalent swipe should not turn farther on a tablet")
        }
    }

    func testInvalidViewportWidthsUseTheBaselineAndTinyWidthsStayBounded() {
        let baseline = BookstoreRackSpin.radiansPerPoint(viewportWidth: 402)
        for width in [0.0, -1, Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(BookstoreRackSpin.radiansPerPoint(viewportWidth: width), baseline)
        }
        let smallestSensitivity = BookstoreRackSpin.radiansPerPoint(viewportWidth: 240)
        for width in [Double.leastNonzeroMagnitude, 1, 100, 239] {
            XCTAssertEqual(BookstoreRackSpin.radiansPerPoint(viewportWidth: width), smallestSensitivity)
        }
    }

    func testReleaseSpeedIsFiniteAndClampedWithoutLosingItsDirection() {
        for velocity in [-Double.greatestFiniteMagnitude, -100, -16, -8, 0, 8, 16, 100,
                         Double.greatestFiniteMagnitude] {
            let spin = makeSpin(velocity: velocity)
            XCTAssertEqual(spin.initialVelocity, min(16, max(-16, velocity)))
            XCTAssertTrue(spin.duration.isFinite)
            XCTAssertGreaterThan(spin.duration, 0)
            XCTAssertLessThan(spin.duration, 4)
            assertFiniteSamples(spin)
        }
        for invalid in [Double.nan, .infinity, -.infinity] {
            let spin = makeSpin(velocity: invalid)
            XCTAssertEqual(spin.initialVelocity, 0)
            XCTAssertEqual(spin.coastDuration, 0)
            assertFiniteSamples(spin)
        }
    }

    func testNonfiniteAnglesAreSanitizedAndInvalidSampleTimesNeverProduceNaN() {
        for invalid in [Double.nan, .infinity, -.infinity] {
            let invalidStart = BookstoreRackSpin(startAngle: invalid, releaseVelocity: 6, homeAngle: 0)
            XCTAssertEqual(invalidStart.startAngle, 0)
            assertFiniteSamples(invalidStart)
            let invalidHome = BookstoreRackSpin(startAngle: 0.2, releaseVelocity: -6, homeAngle: invalid)
            assertFiniteSamples(invalidHome)
            let invalidEverything = BookstoreRackSpin(startAngle: invalid, releaseVelocity: invalid,
                                                     homeAngle: invalid)
            assertFiniteSamples(invalidEverything)
        }
        let spin = makeSpin(velocity: 10)
        for elapsed in [Double.nan, .infinity, -.infinity] {
            XCTAssertTrue(spin.angle(at: elapsed).isFinite)
            XCTAssertTrue(spin.velocity(at: elapsed).isFinite)
        }
    }

    func testFasterReleasesCoastLongerAndFartherInBothDirections() {
        for direction in [-1.0, 1] {
            var previousDuration = 0.0
            var previousTravel = 0.0
            var previousFinalTravel = 0.0
            for speed in [2.0, 5, 10, 16] {
                let spin = makeSpin(velocity: speed * direction)
                let travel = (spin.angle(at: spin.coastDuration) - spin.startAngle) * direction
                let finalTravel = (spin.destinationAngle - spin.startAngle) * direction
                XCTAssertGreaterThan(spin.coastDuration, previousDuration)
                XCTAssertGreaterThan(travel, previousTravel)
                XCTAssertGreaterThan(finalTravel, previousFinalTravel)
                previousDuration = spin.coastDuration
                previousTravel = travel
                previousFinalTravel = finalTravel
            }
        }
    }

    func testCoastingPreservesReleaseDirectionAndContinuouslyLosesSpeed() {
        for velocity in [-16.0, -8, -2, 2, 8, 16] {
            let spin = makeSpin(velocity: velocity)
            let direction = velocity > 0 ? 1.0 : -1.0
            var previousAngle = spin.startAngle
            var previousSpeed = abs(spin.initialVelocity)
            for sample in 1..<400 {
                let elapsed = spin.coastDuration * Double(sample) / 400
                let angle = spin.angle(at: elapsed)
                let speed = spin.velocity(at: elapsed)
                XCTAssertGreaterThan((angle - previousAngle) * direction, 0)
                XCTAssertGreaterThan(speed * direction, 0)
                XCTAssertLessThan(abs(speed), previousSpeed)
                previousAngle = angle
                previousSpeed = abs(speed)
            }
            XCTAssertEqual(spin.velocity(at: spin.coastDuration), 0)
            XCTAssertEqual(spin.coastDuration, spin.duration,
                           "A flick must not hand off to a second snap that accelerates again")
        }
    }

    func testReleaseAndRestEndpointsRemainContinuousWithoutASecondAcceleration() {
        let epsilon = 0.000001
        for start in [-0.7, 0.0, 0.7, 20 * Double.pi] {
            for velocity in [-16.0, -5, -2, -0.5, 0, 0.5, 2, 5, 16] {
                let spin = BookstoreRackSpin(startAngle: start, releaseVelocity: velocity, homeAngle: 0.18)
                let firstAngle = spin.angle(at: epsilon)
                XCTAssertEqual(firstAngle, spin.startAngle, accuracy: 0.00002)
                XCTAssertEqual(spin.velocity(at: epsilon), spin.initialVelocity, accuracy: 0.0003)
                XCTAssertEqual((firstAngle - spin.startAngle) / epsilon, spin.initialVelocity,
                               accuracy: 0.0002)
                XCTAssertEqual(spin.angle(at: spin.duration - epsilon), spin.destinationAngle,
                               accuracy: 0.0001)
                XCTAssertEqual(spin.velocity(at: spin.duration - epsilon), 0, accuracy: 0.001)
            }
        }
    }

    func testStrongFlickCanCrossAFullRevolutionWithoutWrappingItsAngle() {
        for direction in [-1.0, 1] {
            let spin = makeSpin(velocity: 16 * direction)
            let travelled = (spin.angle(at: spin.coastDuration) - spin.startAngle) * direction
            XCTAssertGreaterThan(travelled, 2 * .pi)

            let fullTurns = 20 * Double.pi * direction
            let shifted = BookstoreRackSpin(startAngle: spin.startAngle + fullTurns,
                                           releaseVelocity: spin.initialVelocity, homeAngle: 0)
            XCTAssertEqual(shifted.destinationAngle - spin.destinationAngle, fullTurns,
                           accuracy: 0.000000001)
            for sample in 0...400 {
                let elapsed = spin.duration * Double(sample) / 400
                XCTAssertEqual(shifted.angle(at: elapsed) - spin.angle(at: elapsed), fullTurns,
                               accuracy: 0.000000001)
                XCTAssertEqual(shifted.velocity(at: elapsed), spin.velocity(at: elapsed),
                               accuracy: 0.000000001)
            }
        }
    }

    func testTheMotionEndsExactlyOnAFaceAtRestAndClampsOutOfRangeTimes() {
        let home = 0.18
        for start in [-40.0, -0.8, 0, 0.8, 40] {
            for velocity in [-16.0, -0.3, 0, 0.3, 16] {
                let spin = BookstoreRackSpin(startAngle: start, releaseVelocity: velocity, homeAngle: home)
                let face = (spin.destinationAngle - home) / (.pi / 2)
                XCTAssertEqual(face, face.rounded(), accuracy: 0.000000001)
                XCTAssertEqual(spin.angle(at: -1), start)
                XCTAssertEqual(spin.angle(at: 0), start)
                XCTAssertEqual(spin.velocity(at: 0), spin.initialVelocity)
                for elapsed in [spin.duration, spin.duration + 1, spin.duration * 100] {
                    XCTAssertEqual(spin.angle(at: elapsed), spin.destinationAngle)
                    XCTAssertEqual(spin.velocity(at: elapsed), 0)
                }
                XCTAssertEqual(spin.angle(at: spin.duration - 0.000001), spin.destinationAngle,
                               accuracy: 0.0001, "The final exact-rest clamp must be visually negligible")
                XCTAssertEqual(spin.velocity(at: spin.duration - 0.000001), 0, accuracy: 0.001)
            }
        }
    }

    func testAStationaryReleaseHasNoCoastAndSettlesWithoutNaN() {
        for start in [-0.7, 0.0, 0.7] {
            let spin = BookstoreRackSpin(startAngle: start, releaseVelocity: 0, homeAngle: 0)
            XCTAssertEqual(spin.coastDuration, 0)
            XCTAssertEqual(spin.initialVelocity, 0)
            XCTAssertEqual(spin.destinationAngle, 0)
            assertFiniteSamples(spin)
        }
        let alreadyAligned = makeSpin(velocity: 0)
        for sample in 0...100 {
            let elapsed = alreadyAligned.duration * Double(sample) / 100
            XCTAssertEqual(alreadyAligned.angle(at: elapsed), 0)
            XCTAssertEqual(alreadyAligned.velocity(at: elapsed), 0)
        }
    }

    func testAbsoluteTimeSamplingAgreesAtThirtySixtyAndOneHundredTwentyHertz() {
        for velocity in [-16.0, -3, 0, 3, 16] {
            let spin = makeSpin(velocity: velocity)
            let at30 = samples(spin, framesPerSecond: 30)
            let at60 = samples(spin, framesPerSecond: 60)
            let at120 = samples(spin, framesPerSecond: 120)
            for index in at30.indices {
                XCTAssertEqual(at30[index].angle, at60[index * 2].angle, accuracy: 0.000000001)
                XCTAssertEqual(at30[index].angle, at120[index * 4].angle, accuracy: 0.000000001)
                XCTAssertEqual(at30[index].velocity, at60[index * 2].velocity, accuracy: 0.000000001)
                XCTAssertEqual(at30[index].velocity, at120[index * 4].velocity, accuracy: 0.000000001)
            }
            // A delayed render or an out-of-order inspection cannot change
            // subsequent poses: elapsed time, not frame count, owns motion.
            _ = spin.angle(at: spin.duration * 0.9)
            XCTAssertEqual(spin.angle(at: 0.5), at120[60].angle)
            XCTAssertEqual(spin.velocity(at: 0.5), at120[60].velocity)
        }
    }

    private func makeSpin(velocity: Double) -> BookstoreRackSpin {
        BookstoreRackSpin(startAngle: 0, releaseVelocity: velocity, homeAngle: 0)
    }

    private func samples(_ spin: BookstoreRackSpin, framesPerSecond: Int) -> [(angle: Double, velocity: Double)] {
        (0...(4 * framesPerSecond)).map { frame in
            let elapsed = Double(frame) / Double(framesPerSecond)
            return (spin.angle(at: elapsed), spin.velocity(at: elapsed))
        }
    }

    private func assertFiniteSamples(_ spin: BookstoreRackSpin,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(spin.startAngle.isFinite, file: file, line: line)
        XCTAssertTrue(spin.destinationAngle.isFinite, file: file, line: line)
        XCTAssertTrue(spin.duration.isFinite, file: file, line: line)
        for sample in 0...100 {
            let elapsed = spin.duration * Double(sample) / 100
            XCTAssertTrue(spin.angle(at: elapsed).isFinite, file: file, line: line)
            XCTAssertTrue(spin.velocity(at: elapsed).isFinite, file: file, line: line)
        }
    }
}
