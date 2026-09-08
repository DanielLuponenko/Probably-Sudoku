import XCTest
import SwiftUI
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class RoutePresentationTests: XCTestCase {
    func testFunnyRouteNamesAndSquareGeometry() {
        XCTAssertEqual(PuzzleSlot.allCases.map(RunRouteStrip.title), ["Easy", "Easy but hard", "Boss"])
        for width: CGFloat in [280, 300, 327, 365, 560, 964] {
            let side = RunRouteStrip.boardSide(for: width)
            XCTAssertEqual(side * 3 + 36, min(width, 560), accuracy: 0.001)
            XCTAssertEqual(RunRouteStrip.height(for: width), side + 80)
        }
    }

    func testEveryBookPreviewUsesLegalDigitsAndItsActualClueDensity() {
        for book in Book.allCases {
            for slot in PuzzleSlot.allCases {
                let digits = RoutePreviewGrid.digits(for: slot, book: book)
                XCTAssertEqual(digits.count, 81)
                XCTAssertEqual(digits.compactMap { $0 }.count, book.givens(for: slot.difficulty))
                for n in 0..<9 {
                    let row = (0..<9).compactMap { digits[n * 9 + $0] }
                    let col = (0..<9).compactMap { digits[$0 * 9 + n] }
                    let boxRow = (n / 3) * 3
                    let boxCol = (n % 3) * 3
                    let box: [Int] = (0..<9).compactMap { offset in
                        let index = (boxRow + offset / 3) * 9 + boxCol + offset % 3
                        return digits[index]
                    }
                    XCTAssertEqual(Set(row).count, row.count)
                    XCTAssertEqual(Set(col).count, col.count)
                    XCTAssertEqual(Set(box).count, box.count)
                }
            }
        }
    }

    func testCouponClaimPaysOnceAndCannotConsumeTheNextOffer() throws {
        let model = GameModel(frozen: Game(seed: "coupon-single-claim"), page: .briefing)
        let before = model.run.skipsRemaining
        let claim = try XCTUnwrap(model.currentClippingClaim)
        XCTAssertTrue(model.takeClipping(ifCurrent: claim))
        let snapshot = try model.game.encoded()
        XCTAssertEqual(model.run.skipsRemaining, before - 1)
        XCTAssertFalse(model.takeClipping(ifCurrent: claim))
        XCTAssertEqual(try model.game.encoded(), snapshot)
        XCTAssertEqual(model.run.skipsRemaining, before - 1)
        XCTAssertEqual(model.run.slot, .medium)
    }

    func testCouponDoesNotCommitMerelyBecauseItWasPickedUp() throws {
        let model = GameModel(frozen: Game(seed: "coupon-cancel"), page: .briefing)
        let before = model.run
        let claim = try XCTUnwrap(model.currentClippingClaim)
        // Presentation can cancel on background/cover/disappearance; no model
        // method is called until the final falling frame has completed.
        XCTAssertEqual(model.run.slot, before.slot)
        XCTAssertEqual(model.run.coins, before.coins)
        XCTAssertEqual(model.run.skipsRemaining, before.skipsRemaining)
        model.beginPuzzle()
        XCTAssertNil(model.currentClippingClaim)
        XCTAssertFalse(model.takeClipping(ifCurrent: claim))
        XCTAssertEqual(model.run.skipsRemaining, before.skipsRemaining)
    }

    func testBossNeverOffersASkip() {
        var run = RunState(seed: "boss-no-coupon")
        run.slot = .boss
        let model = GameModel(frozen: Game(run: run), page: .briefing)
        XCTAssertNil(model.currentClippingClaim)
    }

    func testCouponCannotBeRedeemedByAnotherBookSession() throws {
        let first = GameModel(frozen: Game(seed: "identical-offer"), page: .briefing)
        let other = GameModel(frozen: Game(seed: "identical-offer"), page: .briefing)
        let claim = try XCTUnwrap(first.currentClippingClaim)
        let saved = try other.game.encoded()
        XCTAssertFalse(other.takeClipping(ifCurrent: claim))
        XCTAssertEqual(try other.game.encoded(), saved)
    }

    func testCouponHangsBeforeGravityAndDisappearsAtCompletion() {
        XCTAssertEqual(ClippingDeparture.at(0), .init(angle: 0, fall: 0, opacity: 1))
        XCTAssertLessThan(ClippingDeparture.at(0.15).angle, 0)
        XCTAssertGreaterThan(ClippingDeparture.at(0.4).angle, 0)
        XCTAssertEqual(ClippingDeparture.at(0.5).fall, 0)
        XCTAssertGreaterThan(ClippingDeparture.at(0.8).fall, ClippingDeparture.at(0.7).fall)
        XCTAssertEqual(ClippingDeparture.at(1).opacity, 0, accuracy: 0.001)
    }
}
