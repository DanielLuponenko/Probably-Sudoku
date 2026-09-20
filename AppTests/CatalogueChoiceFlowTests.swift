import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class CatalogueChoiceFlowTests: XCTestCase {
    private func model(buff: String) throws -> GameModel {
        var game = Game(seed: "catalogue-choice-flow")
        try game.startPuzzle()
        var run = game.run
        run.buffs = [OwnedBuff(defID: buff, pricePaid: 5), OwnedBuff(defID: buff, pricePaid: 5)]
        return GameModel(resuming: Game(run: run), savesProgress: false)
    }

    func testDigitChoiceCancelResumeAndDuplicateCommitPreserveExactCopies() throws {
        let model = try model(buff: Buffs.paperCrane)
        model.tapHand(0)
        let selected = model.handCards[0].id
        let copies = model.run.buffs.map(\.id)
        let board = model.puzzle?.board.placed
        XCTAssertTrue(model.useBuff(at: 0))
        let decision = try XCTUnwrap(model.pendingItemDecision)
        XCTAssertEqual(decision.options.count, 9)
        XCTAssertFalse(model.acceptsPuzzleInput)
        XCTAssertEqual(model.run.buffs.map(\.id), copies)
        XCTAssertTrue(model.resolveItemDecision(id: decision.id, selected: nil))
        XCTAssertEqual(model.handCards[try XCTUnwrap(model.selectedHandIndex)].id, selected)
        XCTAssertEqual(model.puzzle?.board.placed, board)
        XCTAssertTrue(model.useBuff(at: 0))
        let saved = try XCTUnwrap(RunStore.dataForStorage(of: model.game))
        let restored = GameModel(resuming: try XCTUnwrap(RunStore.game(from: saved)), savesProgress: false)
        let resumedChoice = try XCTUnwrap(restored.pendingItemDecision)
        XCTAssertEqual(resumedChoice, model.pendingItemDecision)
        let target = try XCTUnwrap(resumedChoice.options.first?.id)
        XCTAssertTrue(restored.resolveItemDecision(id: resumedChoice.id, selected: [target]))
        XCTAssertEqual(restored.run.buffs.map(\.id), [copies[1]])
        let committed = try restored.game.encoded()
        XCTAssertFalse(restored.resolveItemDecision(id: resumedChoice.id, selected: [target]))
        XCTAssertEqual(try restored.game.encoded(), committed)
    }

    func testInformationBuffPresentsPaidResultsAndKeepsThemAfterDismissal() throws {
        let model = try model(buff: Buffs.inventoryCount)
        let poolBefore = model.puzzle?.pool.total
        XCTAssertTrue(model.useBuff(at: 0))
        XCTAssertNotNil(model.requestedCatalogueReading)
        XCTAssertFalse(CatalogueReadings(run: model.run).isEmpty)
        model.dismissCatalogueReading()
        XCTAssertNil(model.requestedCatalogueReading)
        XCTAssertEqual(model.puzzle?.pool.total, poolBefore)
        let restored = GameModel(resuming: try Game(decoding: model.game.encoded()), savesProgress: false)
        XCTAssertEqual(CatalogueReadings(run: restored.run), CatalogueReadings(run: model.run))
    }

    func testThirdSlotSourceHighlightRequiresTheActualCapacity() {
        let id = UUID()
        var beat = ScorePerformance.Beat(source: "Insurance", value: "Armed", kind: .points,
                                         sourceID: Buffs.insurance, sourceInstanceID: id.uuidString)
        beat.sourceInventorySlot = 2
        XCTAssertNil(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: []))
        XCTAssertEqual(ScoringSourceHighlights.consumedBuffSlot(for: beat, buffs: [], capacity: 3), 2)
    }

    func testFogConcealsPendingMarkerSourceAfterSaveResumeWithoutChangingChoices() throws {
        var game = Game(seed: "fog-saved-choice")
        try game.startPuzzle()
        var run = game.run
        run.puzzle?.boss = .fog
        for definition in Markers.all {
            let decision = ItemDecision(id: UUID(), sourceID: definition.id,
                contextKey: run.itemContextKey, kind: "marker.exchange", title: definition.name,
                detail: definition.text, options: [ItemChoiceOption(id: "one", title: "Take 1", digit: .one)])
            run.pendingItemDecisions = [decision]
            let restored = try Game(decoding: Game(run: run).encoded())
            let model = GameModel(frozen: restored, page: .puzzle)
            let saved = try XCTUnwrap(model.pendingItemDecision)
            let before = try model.game.encoded()
            let slip = ItemDecisionSlip(model: model, decision: saved)
            XCTAssertEqual(slip.presentedTitle, "Choose")
            XCTAssertNil(slip.instruction)
            XCTAssertEqual(saved, decision)
            XCTAssertEqual(try model.game.encoded(), before)

            var visibleRun = run
            visibleRun.puzzle?.boss = nil
            let visible = ItemDecisionSlip(model: GameModel(frozen: Game(run: visibleRun), page: .puzzle), decision: saved)
            XCTAssertEqual(visible.presentedTitle, definition.name)
            XCTAssertEqual(visible.instruction, definition.text)
        }
    }
}
