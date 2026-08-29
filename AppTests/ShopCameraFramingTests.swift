import XCTest
@testable import ProbablySudoku

final class ShopCameraFramingTests: XCTestCase {
    private let accuracy: CGFloat = 0.0001

    private func horizontalFieldOfView(_ verticalDegrees: CGFloat, aspect: CGFloat) -> CGFloat {
        2 * atan(aspect * tan(verticalDegrees * .pi / 360)) * 180 / .pi
    }

    func testBaselineViewportIsUnchanged() {
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: 42,
            usableWidth: ShopCameraFraming.baselineViewport.width,
            viewportHeight: ShopCameraFraming.baselineViewport.height
        )
        XCTAssertEqual(fieldOfView, 42, accuracy: accuracy)
    }

    func testNarrowerAspectWidensToPreserveBaselineHorizontalFieldOfView() {
        let usableWidth: CGFloat = 320
        let height = ShopCameraFraming.baselineViewport.height
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: 42,
            usableWidth: usableWidth,
            viewportHeight: height
        )
        XCTAssertGreaterThan(fieldOfView, 42)

        let baselineAspect = ShopCameraFraming.baselineViewport.width / ShopCameraFraming.baselineViewport.height
        let baselineHorizontal = horizontalFieldOfView(ShopCameraFraming.baselineFieldOfView, aspect: baselineAspect)
        let resultHorizontal = horizontalFieldOfView(fieldOfView, aspect: usableWidth / height)
        XCTAssertEqual(resultHorizontal, baselineHorizontal, accuracy: 0.01)
    }

    func testWiderAspectPassesThroughUnchanged() {
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: 45,
            usableWidth: 500,
            viewportHeight: 874
        )
        XCTAssertEqual(fieldOfView, 45, accuracy: accuracy)
    }

    func testResultNeverExceedsCeiling() {
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: 42,
            usableWidth: 90,
            viewportHeight: 900
        )
        XCTAssertEqual(fieldOfView, 58, accuracy: accuracy)
    }

    func testMiniAspectMatchesBaselineAndIsNotFalselyWidened() {
        let fieldOfView = ShopCameraFraming.aspectAwareFieldOfView(
            heightAdjustedFieldOfView: 42,
            usableWidth: 375,
            viewportHeight: 812
        )
        XCTAssertEqual(fieldOfView, 42, accuracy: accuracy)
    }
}
