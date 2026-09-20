import XCTest
import SwiftUI
import UIKit
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class ScoringSourceHighlightTests: XCTestCase {
    func testMarkerOutlineRequiresTheActualVisiblePositionAndSource() throws {
        var game = Game(seed: "source-outline")
        try game.startPuzzle()
        let board = try XCTUnwrap(game.puzzle?.board)
        let square = try XCTUnwrap(board.blanks.first)
        let marker = OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1, pricePaid: 0,
                                 squares: [square])
        let visible = [square: marker]
        var beat = ScorePerformance.Beat(source: marker.def.name, value: "×4", kind: .points,
            sourceID: marker.defID, sourceInstanceID: marker.id, square: square)
        XCTAssertEqual(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: false), square)
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: true), "Fog must suppress even an old pending beat")
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: [:], markersAreHidden: false))
        beat.sourceID = "base.place"
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: false), "Ordinary placement receipts must not outline a Marker")
        beat.sourceID = marker.defID
        beat.sourceInstanceID = "mk_rose"
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: false))
    }

    func testGivenCoveredMarkerCannotBePresentedAsTriggered() throws {
        var game = Game(seed: "given-outline")
        try game.startPuzzle()
        let board = try XCTUnwrap(game.puzzle?.board)
        let square = try XCTUnwrap(Square.all.first { board.filledBy[$0.index] == .given })
        let marker = OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1, pricePaid: 0,
                                 squares: [square])
        let beat = ScorePerformance.Beat(source: marker.def.name, value: "×4", kind: .points,
            sourceID: marker.defID, sourceInstanceID: marker.id, square: square)
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: [square: marker], markersAreHidden: false))
    }

    func testExpandedClaimIdentityNeverHighlightsAnotherClaimOrFollowupSquare() throws {
        var game = Game(seed: "exact-marker-source")
        try game.startPuzzle()
        let board = try XCTUnwrap(game.puzzle?.board)
        let squares = Array(board.blanks.prefix(2))
        let marker = OwnedMarker(defID: Markers.route, boughtAtLevel: 1, pricePaid: 9, squares: squares)
        let claims = [MarkerClaim(id: "route.first", markerID: marker.defID, square: squares[0]),
                      MarkerClaim(id: "route.second", markerID: marker.defID, square: squares[1])]
        let visible = Dictionary(uniqueKeysWithValues: squares.map { ($0, marker) })
        var beat = ScorePerformance.Beat(source: marker.def.name, value: "+120", kind: .points,
            sourceID: marker.defID, sourceInstanceID: claims[0].id, square: squares[0])
        XCTAssertEqual(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: false, claims: claims), squares[0])
        beat.square = squares[1]
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: false, claims: claims))
        beat.square = squares[0]
        XCTAssertNil(ScoringSourceHighlights.markerSquare(for: beat, board: board,
            visibleMarkers: visible, markersAreHidden: true, claims: claims))
    }

    func testOnlyTheExactBookmarkCopyPulsesAndEachReceiptKeepsItsOwnIdentity() {
        let first = OwnedBookmark(defID: "bm_editorial_board", boughtAtLevel: 1, pricePaid: 0)
        let duplicate = OwnedBookmark(defID: first.defID, boughtAtLevel: 1, pricePaid: 0)
        let beat = ScorePerformance.Beat(source: "Editorial Board", value: "+2 Mult", kind: .multiplier,
            sourceID: first.defID, sourceInstanceID: first.id.uuidString)
        XCTAssertEqual(ScoringSourceHighlights.bookmarkBeatID(for: beat, bookmark: first), beat.id)
        XCTAssertNil(ScoringSourceHighlights.bookmarkBeatID(for: beat, bookmark: duplicate))
        XCTAssertNil(ScoringSourceHighlights.bookmarkBeatID(for: nil, bookmark: first))
        let next = ScorePerformance.Beat(source: beat.source, value: beat.value, kind: beat.kind,
            sourceID: first.defID, sourceInstanceID: first.id.uuidString)
        XCTAssertNotEqual(ScoringSourceHighlights.bookmarkBeatID(for: next, bookmark: first), beat.id,
                          "Two contributions by the same copy can pulse separately")
    }

    func testConsumedBuffHighlightsOnlyItsRecordedFormerSlotWithoutInventingAnItem() {
        let consumed = OwnedBuff(defID: Buffs.freshInk, pricePaid: 0)
        let duplicate = OwnedBuff(defID: Buffs.freshInk, pricePaid: 0)
        let remaining = [duplicate]
        var beat = ScorePerformance.Beat(source: "Fresh Ink", value: "+2 Mult", kind: .multiplier,
            sourceID: consumed.defID, sourceInstanceID: consumed.id.uuidString, sourceInventorySlot: 0)
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: remaining),
                     "A surviving copy sliding into the old slot must not be shown as the consumed source")
        XCTAssertEqual(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: []), 0)
        beat.sourceInventorySlot = 1
        XCTAssertEqual(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: remaining), 1)
        XCTAssertEqual(remaining.map(\.id), [duplicate.id])
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: [consumed, duplicate]),
                     "An unconsumed copy must not masquerade as a missing-slot receipt")
        beat.sourceInventorySlot = nil
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: remaining),
                     "Later uses of the ongoing modifier must not flash a stale inventory slot")
        beat.sourceInventorySlot = ItemKind.buff.capacity
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: remaining))
        beat.sourceInventorySlot = 0
        beat.sourceID = "bm_editorial_board"
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: remaining))
    }

    func testOutlineLeavesTheSquareInteriorAndLayoutUntouched() throws {
        func render(_ trigger: String?) throws -> (CGSize, [UInt8]) {
            let renderer = ImageRenderer(content: ScoringSourceOutline(trigger: trigger)
                .frame(width: 44, height: 44)
                .transaction { $0.disablesAnimations = true })
            renderer.scale = 1
            let image = try XCTUnwrap(renderer.uiImage)
            let cgImage = try XCTUnwrap(image.cgImage)
            var bytes = [UInt8](repeating: 0, count: 44 * 44 * 4)
            try bytes.withUnsafeMutableBytes { buffer in
                let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: 44, height: 44,
                    bitsPerComponent: 8, bytesPerRow: 44 * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(cgImage, in: CGRect(x: 0, y: 0, width: 44, height: 44))
            }
            return (image.size, bytes)
        }
        let resting = try render(nil)
        let active = try render("actual-receipt")
        XCTAssertEqual(resting.0, CGSize(width: 44, height: 44))
        XCTAssertEqual(active.0, resting.0)
        XCTAssertTrue(stride(from: 3, to: resting.1.count, by: 4).allSatisfy { resting.1[$0] == 0 })
        XCTAssertTrue(stride(from: 3, to: active.1.count, by: 4).contains { active.1[$0] > 0 })
        for row in 3..<41 {
            for column in 3..<41 {
                XCTAssertEqual(active.1[(row * 44 + column) * 4 + 3], 0,
                               "Source feedback must not paint text, tint, or marks across the cell interior")
            }
        }
    }
}
