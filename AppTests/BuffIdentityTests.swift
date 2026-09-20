import XCTest
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class BuffIdentityTests: XCTestCase {
    func testDelayedSaleRejectsAnIdenticalCopyInTheOriginalSlot() throws {
        var run = RunState(seed: "buff-identical-sale")
        let selected = OwnedBuff(defID: Buffs.redraw, pricePaid: 0)
        let spare = OwnedBuff(defID: Buffs.redraw, pricePaid: 0)
        run.buffs = [selected, spare]
        let sale = InventorySale(buff: selected, index: 0)
        let drag = InventoryDragPresenter()
        drag.rootFrame = CGRect(x: 0, y: 0, width: 390, height: 844)
        drag.begin(owner: UUID(), sale: sale, itemFrame: CGRect(x: 8, y: 100, width: 44, height: 44),
                   bookmarkFrames: [], start: CGPoint(x: 30, y: 122), point: CGPoint(x: 150, y: 240))
        let pulled = try XCTUnwrap(drag.session)

        XCTAssertNotEqual(selected.id, spare.id)
        XCTAssertEqual(pulled.sale.resolvedIndex(in: run), 0)
        _ = try Shop.sell(&run, kind: sale.kind, index: 0)

        XCTAssertEqual(run.buffs.map(\.id), [spare.id])
        XCTAssertFalse(sale.matches(run))
        XCTAssertNil(pulled.sale.resolvedIndex(in: run),
                     "An old drag must not sell the identical copy that moves into its slot.")

        run.buffs = [OwnedBuff(defID: Buffs.redraw, pricePaid: 0)]
        XCTAssertNil(sale.resolvedIndex(in: run),
                     "A later free copy is not the earlier selected reward.")
    }

    func testDelayedUseFollowsTheSelectedCopyWhenAnotherItemIsRemoved() throws {
        var game = Game(seed: "buff-shifted-use")
        try game.startPuzzle()
        let first = OwnedBuff(defID: Buffs.redraw, pricePaid: 0)
        let selected = OwnedBuff(defID: Buffs.redraw, pricePaid: 0)
        var run = game.run
        run.buffs = [first, selected]
        let selection = InventorySale(buff: selected, index: 1)
        _ = try Shop.sell(&run, kind: .buff, index: 0)
        let model = GameModel(frozen: Game(run: run), page: .puzzle)

        XCTAssertEqual(model.run.buffs.map(\.id), [selected.id])
        let currentIndex = try XCTUnwrap(selection.resolvedIndex(in: model.run))
        XCTAssertEqual(currentIndex, 0)
        XCTAssertTrue(model.useBuff(at: currentIndex))
        XCTAssertTrue(model.run.buffs.isEmpty)
        XCTAssertNil(selection.resolvedIndex(in: model.run),
                     "The same retained use selection cannot consume another copy.")
    }

    func testSavedCopiesKeepDistinctActionIdentitiesAfterResume() throws {
        var run = RunState(seed: "buff-resume-identities")
        run.buffs = [OwnedBuff(defID: Buffs.peek, pricePaid: 0),
                     OwnedBuff(defID: Buffs.peek, pricePaid: 0)]
        let first = InventorySale(buff: run.buffs[0], index: 0)
        let second = InventorySale(buff: run.buffs[1], index: 1)
        var resumed = try JSONDecoder().decode(RunState.self, from: JSONEncoder().encode(run))

        XCTAssertNotEqual(first.buffID, second.buffID)
        XCTAssertEqual(first.resolvedIndex(in: resumed), 0)
        XCTAssertEqual(second.resolvedIndex(in: resumed), 1)
        resumed.buffs.removeFirst()
        XCTAssertNil(first.resolvedIndex(in: resumed))
        XCTAssertEqual(second.resolvedIndex(in: resumed), 0)
    }
}
