import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class CatalogueReadingsTests: XCTestCase {
    private func fresh() throws -> RunState {
        var game = Game(seed: "paid-catalogue-readings")
        try game.startPuzzle()
        return game.run
    }

    private func use(_ definition: String, choice: BuffChoice = .none, run: inout RunState) throws {
        let buff = OwnedBuff(defID: definition, pricePaid: 0)
        run.buffs.append(buff)
        try BuffRuntime.use(.init(buffID: buff.id, context: BuffRuntime.context(run), choice: choice), run: &run)
    }

    func testNoUnpaidReadingsAndCanonicalNamesForAllPaidSources() throws {
        var run = try fresh()
        XCTAssertTrue(CatalogueReadings(run: run).isEmpty)
        try use(Buffs.inventoryCount, run: &run)
        let blank = try XCTUnwrap(run.puzzle?.board.blanks.first)
        try use(Buffs.proofSheet, choice: .unit(.row, blank.row), run: &run)
        try use(Buffs.foldTest, choice: .squares([blank]), run: &run)
        let source = MarkerSource(markerID: Markers.forecast, claimID: "paid", square: blank)
        run.puzzle!.markerState.turn.forecast = source
        run.puzzle!.markerState.turn.censusDigit = .five
        run.puzzle!.markerState.turn.crosscheck = MarkerTarget(source: source, square: blank)
        run.puzzle!.markerState.turn.bounty = MarkerTarget(source: source, square: blank)
        let readings = CatalogueReadings(run: run)
        XCTAssertEqual(Set(readings.entries.map(\.id)), [Buffs.inventoryCount, Buffs.proofSheet, Buffs.foldTest,
                                                        Markers.forecast, Markers.census, Markers.crosscheck, Markers.bounty])
        for entry in readings.entries { XCTAssertEqual(entry.title, Catalog.item(entry.id)?.name) }
        XCTAssertEqual(readings.entries.first { $0.id == Buffs.inventoryCount }?.rows.count, 9)
    }

    func testReadingsUpdateWithoutAdvancingDrawsOrUsingHiddenCandidates() throws {
        var run = try fresh()
        let blank = try XCTUnwrap(run.puzzle?.board.blanks.first)
        try use(Buffs.inventoryCount, run: &run)
        try use(Buffs.proofSheet, choice: .unit(.row, blank.row), run: &run)
        let source = MarkerSource(markerID: Markers.forecast, claimID: "paid", square: blank)
        run.puzzle!.markerState.turn.forecast = source
        run.puzzle!.markerState.turn.crosscheck = .init(source: source, square: blank)
        let before = try Game(run: run).encoded()
        let hidden = [Digit?](repeating: nil, count: 81)
        let snapshot = CatalogueReadings(run: run, visibleValues: hidden)
        for entry in snapshot.entries where [Buffs.proofSheet, Markers.crosscheck].contains(entry.id) {
            XCTAssertTrue(entry.rows.allSatisfy { $0.value == "1 · 2 · 3 · 4 · 5 · 6 · 7 · 8 · 9" })
        }
        for _ in 0..<12 { XCTAssertEqual(CatalogueReadings(run: run, visibleValues: hidden), snapshot) }
        XCTAssertEqual(try Game(run: run).encoded(), before)
        let digit = try XCTUnwrap(Digit.all.first { run.puzzle!.pool[$0] > 0 })
        let count = run.puzzle!.pool[digit]
        _ = run.puzzle!.pool.take(digit)
        let updated = CatalogueReadings(run: run).entries.first { $0.id == Buffs.inventoryCount }
        XCTAssertEqual(updated?.rows.first { $0.id == String(digit.rawValue) }?.value, String(count - 1))
    }

    func testFogHidesMarkerReadingsButKeepsIndependentlyPaidBuffInformation() throws {
        var run = try fresh()
        try use(Buffs.inventoryCount, run: &run)
        let blank = try XCTUnwrap(run.puzzle?.board.blanks.first)
        let source = MarkerSource(markerID: Markers.forecast, claimID: "paid", square: blank)
        run.puzzle!.markerState.turn.forecast = source
        run.puzzle!.markerState.turn.censusDigit = .three
        run.puzzle!.markerState.turn.crosscheck = .init(source: source, square: blank)
        run.puzzle!.markerState.turn.bounty = .init(source: source, square: blank)
        run.puzzle!.boss = .fog
        XCTAssertEqual(CatalogueReadings(run: run).entries.map(\.id), [Buffs.inventoryCount])
    }

    func testReadingsExpireAtTheirActualTurnOrSquareBoundary() throws {
        var run = try fresh()
        let blank = try XCTUnwrap(run.puzzle?.board.blanks.first)
        try use(Buffs.inventoryCount, run: &run)
        try use(Buffs.proofSheet, choice: .unit(.row, blank.row), run: &run)
        try use(Buffs.foldTest, choice: .squares([blank]), run: &run)
        run.puzzle!.turnNumber += 1
        XCTAssertEqual(CatalogueReadings(run: run).entries.map(\.id), [Buffs.foldTest])
        run.puzzle!.board.fill(blank, with: .one, by: .player)
        XCTAssertTrue(CatalogueReadings(run: run).isEmpty)
        run.puzzle!.phase = .won
        XCTAssertTrue(CatalogueReadings(run: run).isEmpty)
    }
}
