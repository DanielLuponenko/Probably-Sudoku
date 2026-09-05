import XCTest
import SwiftUI
@testable import ProbablySudoku

final class StudioLogoTests: XCTestCase {
    func testHandoffOccursAtFirstFullDotFrameWithoutWhiteHold() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874),
                     CGSize(width: 1024, height: 1366)] {
            let time = DLALogo.handoffTime(for: size)
            let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0),
                           CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)]
            let atHandoff = DLALogo.dot.applying(DLALogo.camera(elapsed: time, size: size))
            let previousFrame = DLALogo.dot.applying(DLALogo.camera(elapsed: time - 1.0 / 120, size: size))
            XCTAssertTrue(corners.allSatisfy { atHandoff.contains($0) })
            XCTAssertFalse(corners.allSatisfy { previousFrame.contains($0) })
            XCTAssertLessThan(time, DLALogo.duration)
        }
    }

    func testLettersShareCapHeightAndBaseline() {
        for path in [DLALogo.d, DLALogo.l, DLALogo.a] {
            XCTAssertEqual(path.boundingRect.minY, 174, accuracy: 0.001)
            XCTAssertEqual(path.boundingRect.maxY, 383.7, accuracy: 0.001)
        }
        XCTAssertEqual(DLALogo.inscription, "This is not an i")
        XCTAssertTrue(DLALogo.l.contains(DLALogo.dotCenter))
    }

    func testFinalDotCoversWholeScreenAtGameHandoff() {
        for size in [CGSize(width: 320, height: 568), CGSize(width: 402, height: 874),
                     CGSize(width: 1024, height: 1366)] {
            let camera = DLALogo.camera(elapsed: DLALogo.duration, size: size)
            let dot = DLALogo.dot.applying(camera)
            for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0),
                           CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
                XCTAssertTrue(dot.contains(corner), "Dot must cover \(corner) on \(size)")
            }
            let center = DLALogo.dotCenter.applying(camera)
            XCTAssertEqual(center.x, size.width / 2, accuracy: 0.001)
            XCTAssertEqual(center.y, size.height / 2, accuracy: 0.001)
        }
    }

    func testCameraZoomNeverStopsOrReversesDuringMove() {
        let size = CGSize(width: 402, height: 874)
        var previous: CGFloat = 0
        for frame in 1...191 {
            let time = 0.35 + Double(frame) / 60
            let transform = DLALogo.camera(elapsed: time, size: size)
            let scale = hypot(transform.a, transform.b)
            XCTAssertGreaterThan(scale, previous)
            XCTAssertTrue(transform.tx.isFinite && transform.ty.isFinite)
            previous = scale
        }
    }

    func testReduceMotionCameraStaysStill() {
        let size = CGSize(width: 402, height: 874)
        let start = DLALogo.camera(elapsed: 0, size: size, reduceMotion: true)
        XCTAssertEqual(start, DLALogo.camera(elapsed: DLALogo.reducedDuration, size: size, reduceMotion: true))
        XCTAssertEqual(start.b, 0)
        XCTAssertEqual(start.c, 0)
    }
}
