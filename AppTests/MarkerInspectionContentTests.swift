import XCTest
import CoreGraphics
import ProbablySudokuEngine
@testable import ProbablySudoku

final class MarkerInspectionContentTests: XCTestCase {
    @MainActor
    func testPresenterDoesNotMutateSelectionAndOnlyItsOwningTouchCanDismiss() throws {
        var run = try playableRun()
        let square = try XCTUnwrap(run.puzzle?.board.blanks.first)
        run.markers = [OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 0, squares: [square])]
        let model = GameModel(frozen: Game(run: run), page: .puzzle)
        model.tapHand(0)
        let before = try model.game.encoded()
        let selection = model.selectedHandIndex
        let presenter = MarkerInspectionPresenter()
        let first = UUID(), second = UUID()
        let frame = CGRect(x: 30, y: 240, width: 40, height: 40)
        var feedback = 0
        presenter.begin(square: square, model: model, cellFrame: frame, source: .touch(first)) { feedback += 1 }
        presenter.begin(square: square, model: model, cellFrame: frame, source: .touch(first)) { feedback += 1 }
        XCTAssertEqual(feedback, 1)
        presenter.begin(square: square, model: model, cellFrame: frame, source: .touch(second)) { feedback += 1 }
        presenter.endTouch(owner: first)
        XCTAssertEqual(presenter.session?.source, .touch(second))
        presenter.endTouch(owner: second)
        XCTAssertNil(presenter.session)
        XCTAssertEqual(model.selectedHandIndex, selection)
        XCTAssertEqual(try model.game.encoded(), before)

        model.qaSetBoss(.fog)
        let hiddenBefore = try model.game.encoded()
        presenter.begin(square: square, model: model, cellFrame: frame, source: .accessibility) { feedback += 1 }
        XCTAssertNil(presenter.session)
        XCTAssertEqual(feedback, 2, "Concealment must not reveal a location through haptics")
        XCTAssertEqual(try model.game.encoded(), hiddenBefore)
    }

    func testPopupClampsEvenAStaleAnchorDuringViewportChanges() {
        let viewport = CGRect(x: 8, y: 20, width: 359, height: 355)
        for anchor in [CGRect(x: -70, y: -80, width: 40, height: 40),
                       CGRect(x: 600, y: 700, width: 40, height: 40)] {
            let popup = MarkerPopupPlacement(viewport: viewport, cell: anchor,
                                             contentHeight: 900, wideText: true).frame
            XCTAssertTrue(viewport.contains(popup))
        }
    }

    func testEveryMarkerUsesTheCatalogueExplanationWithoutChangingTheRun() throws {
        var run = try playableRun()
        let square = try XCTUnwrap(run.puzzle?.board.blanks.first)
        XCTAssertEqual(Markers.all.count, 50)
        for definition in Markers.all {
            run.markers = [OwnedMarker(defID: definition.id, boughtAtLevel: 1,
                                       pricePaid: 0, squares: [square])]
            let before = try Game(run: run).encoded()
            let info = try XCTUnwrap(MarkerInspectionInfo.make(square: square, run: run))
            XCTAssertEqual(info.title, definition.name)
            XCTAssertEqual(info.explanation, definition.text,
                           "The hold popup and question-mark map must use the same catalogue copy")
            XCTAssertEqual(info.compactExplanation, definition.id == Markers.jade
                ? definition.text : CatalogueDetails.item(definition.id)?.shortEffect ?? definition.text)
            XCTAssertEqual(info.availability, .available)
            XCTAssertEqual(info.marker.defID, definition.id)
            XCTAssertEqual(info.square, square)
            XCTAssertEqual(try Game(run: run).encoded(), before,
                           "Reading marker information must not alter the run or any random stream")
        }
    }

    func testJadeExplainsHandReturnAndDoesNotPromisePenaltyProtection() throws {
        var run = try playableRun()
        let square = try XCTUnwrap(run.puzzle?.board.blanks.first)
        run.markers = [OwnedMarker(defID: Markers.jade, boughtAtLevel: 1, pricePaid: 0, squares: [square])]
        let info = try XCTUnwrap(MarkerInspectionInfo.make(square: square, run: run))
        XCTAssertEqual(info.explanation, Catalog.item(Markers.jade)?.text)
        XCTAssertTrue(info.explanation.contains("Hand"))
        XCTAssertTrue(info.explanation.localizedCaseInsensitiveContains("does not cancel"))
        XCTAssertTrue(info.explanation.localizedCaseInsensitiveContains("penalt"))
    }

    func testGivenCoveredAndFilledMarkersHaveDifferentAvailability() throws {
        var run = try playableRun()
        let puzzle = try XCTUnwrap(run.puzzle)
        let given = try XCTUnwrap(Square.all.first { puzzle.board.filledBy[$0.index] == .given })
        let filled = try XCTUnwrap(puzzle.board.blanks.first)
        run.markers = [OwnedMarker(defID: Markers.rose, boughtAtLevel: 1, pricePaid: 0,
                                   squares: [given, filled])]
        run.puzzle?.board.fill(filled, with: .one, by: .player)
        run.puzzle?.itemState[Markers.rose] = 3
        let before = try Game(run: run).encoded()

        let givenInfo = try XCTUnwrap(MarkerInspectionInfo.make(square: given, run: run))
        XCTAssertEqual(givenInfo.availability, .givenCovered)
        XCTAssertEqual(givenInfo.inspectionNotice, "Inactive under a given.")
        XCTAssertTrue(givenInfo.availabilityText.contains("cannot trigger"))
        XCTAssertTrue(givenInfo.availabilityText.contains("later puzzles"))
        let filledInfo = try XCTUnwrap(MarkerInspectionInfo.make(square: filled, run: run))
        XCTAssertEqual(filledInfo.availability, .filled)
        XCTAssertNil(filledInfo.inspectionNotice, "Filled squares do not need boilerplate in the hold popup")
        XCTAssertTrue(filledInfo.availabilityText.contains("Effects already earned keep their stated duration"))
        XCTAssertEqual(run.puzzle?.itemState[Markers.rose], 3)
        XCTAssertEqual(try Game(run: run).encoded(), before)
    }

    func testTemporarilyBarredMessageDoesNotOverridePermanentOccupancy() throws {
        var run = try playableRun()
        let puzzle = try XCTUnwrap(run.puzzle)
        let empty = try XCTUnwrap(puzzle.board.blanks.first)
        let given = try XCTUnwrap(Square.all.first { puzzle.board.filledBy[$0.index] == .given })
        run.markers = [OwnedMarker(defID: Markers.ivory, boughtAtLevel: 1, pricePaid: 0,
                                   squares: [empty, given])]
        var turn = BossTurnState()
        turn.greyed = [empty, given]
        run.puzzle?.bossTurn = turn

        let barredInfo = try XCTUnwrap(MarkerInspectionInfo.make(square: empty, run: run))
        XCTAssertEqual(barredInfo.availability, .temporarilyBarred)
        XCTAssertEqual(barredInfo.inspectionNotice, "Temporarily barred.")
        XCTAssertTrue(barredInfo.availabilityText.contains("becomes available again"))
        XCTAssertEqual(MarkerInspectionInfo.make(square: given, run: run)?.availability, .givenCovered)
        run.puzzle?.bossTurn?.greyed = []
        XCTAssertEqual(MarkerInspectionInfo.make(square: empty, run: run)?.availability, .available)
    }

    func testFogConcealsInspectionForAllMarkerTypesAndAllBoardPositions() throws {
        var run = try playableRun()
        run.markers = Markers.all.enumerated().map { index, definition in
            OwnedMarker(defID: definition.id, boughtAtLevel: 1, pricePaid: 0,
                        squares: [Square.all[index]])
        }
        XCTAssertEqual(MarkerInspectionInfo.visibleMarkers(in: run).count, 50)
        run.puzzle?.boss = .fog
        let before = try Game(run: run).encoded()
        XCTAssertTrue(MarkerInspectionInfo.visibleMarkers(in: run).isEmpty)
        for square in Square.all {
            XCTAssertNil(MarkerInspectionInfo.make(square: square, run: run))
        }
        XCTAssertEqual(try Game(run: run).encoded(), before)
        run.puzzle?.boss = nil
        XCTAssertEqual(MarkerInspectionInfo.visibleMarkers(in: run).count, 50,
                       "Concealment must not erase the owned marker positions")
    }

    func testUnmarkedSquaresNeverProduceInspectionAndBetweenPuzzleMapKeepsOwnership() throws {
        var run = RunState(seed: "marker-inspection-between-puzzles")
        let marked = Square.all[0]
        let unmarked = Square.all[1]
        XCTAssertNil(MarkerInspectionInfo.make(square: marked, run: run))
        run.markers = [OwnedMarker(defID: Markers.onyx, boughtAtLevel: 1, pricePaid: 0,
                                   squares: [marked])]
        XCTAssertNil(MarkerInspectionInfo.make(square: unmarked, run: run))
        XCTAssertEqual(MarkerInspectionInfo.make(square: marked, run: run)?.availability, .betweenPuzzles)
    }

    private func playableRun() throws -> RunState {
        var game = Game(run: RunState(seed: "marker-inspection-content"))
        try game.startPuzzle()
        return game.run
    }
}
