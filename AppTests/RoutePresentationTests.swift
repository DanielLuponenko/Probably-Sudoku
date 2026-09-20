import XCTest
import SwiftUI
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class RoutePresentationTests: XCTestCase {
    func testRouteKeepsThreeOrderedNamesAndACompactNumberedFootprint() {
        XCTAssertEqual(PuzzleSlot.allCases.map(RunRouteStrip.title), ["Easy", "Easy but hard", "Boss"])
        for width: CGFloat in [280, 300, 327, 365, 560, 964] {
            XCTAssertEqual(RunRouteStrip.height(for: width), 80)
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

    func testSkipClaimPaysOnceAndCannotConsumeTheNextOffer() throws {
        let model = GameModel(resuming: Game(seed: "coupon-single-claim"), savesProgress: false)
        let before = model.run.skipsUsed
        let claim = try XCTUnwrap(model.currentSkipClaim)
        XCTAssertTrue(model.takeSkip(ifCurrent: claim))
        let snapshot = try model.game.encoded()
        XCTAssertEqual(model.run.skipsUsed, before + 1)
        XCTAssertEqual(model.run.buffs.map(\.defID), [claim.offer.buffID])
        XCTAssertFalse(model.takeSkip(ifCurrent: claim))
        XCTAssertEqual(try model.game.encoded(), snapshot)
        XCTAssertEqual(model.run.skipsUsed, before + 1)
        XCTAssertEqual(model.run.slot, .medium)
    }

    func testSkipDoesNotCommitMerelyBecauseItWasPickedUp() throws {
        let model = GameModel(resuming: Game(seed: "coupon-cancel"), savesProgress: false)
        let before = model.run
        let claim = try XCTUnwrap(model.currentSkipClaim)
        // Presentation can cancel on background/cover/disappearance; no model
        // method is called until the final falling frame has completed.
        XCTAssertEqual(model.run.slot, before.slot)
        XCTAssertEqual(model.run.coins, before.coins)
        XCTAssertEqual(model.run.skipsUsed, before.skipsUsed)
        XCTAssertTrue(model.run.buffs.isEmpty)
        model.beginPuzzle()
        XCTAssertNil(model.currentSkipClaim)
        XCTAssertFalse(model.takeSkip(ifCurrent: claim))
        XCTAssertEqual(model.run.skipsUsed, before.skipsUsed)
    }

    func testBossNeverOffersASkip() {
        var run = RunState(seed: "boss-no-coupon")
        run.slot = .boss
        let model = GameModel(resuming: Game(run: run), savesProgress: false)
        XCTAssertNil(model.currentSkipClaim)
    }

    func testSkipCannotBeRedeemedByAnotherBookSession() throws {
        let first = GameModel(resuming: Game(seed: "identical-offer"), savesProgress: false)
        let other = GameModel(resuming: Game(seed: "identical-offer"), savesProgress: false)
        let claim = try XCTUnwrap(first.currentSkipClaim)
        let saved = try other.game.encoded()
        XCTAssertFalse(other.takeSkip(ifCurrent: claim))
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
