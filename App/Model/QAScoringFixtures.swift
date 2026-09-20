#if DEBUG && targetEnvironment(simulator)
import Foundation
import ProbablySudokuEngine

/// Setup only. No fixture invokes placement, a Buff, banking or payout.
/// Testers use the normal inventory, hand, board and End Turn controls.
enum QAScoringFixture: String, CaseIterable, Identifiable {
    case ordered, simultaneousClears, finalClue, tenthTurn, penalty, duplicateInventory, fractionalGrowth, modifierPreview
    var id: String { rawValue }

    var title: String {
        switch self {
        case .ordered: return "Ordered +1 then ×3"
        case .simultaneousClears: return "Two clears and Second Print"
        case .finalClue: return "Final Clue and Morning Edition"
        case .tenthTurn: return "Turn 10 direct payouts"
        case .penalty: return "Queued penalty and Insurance"
        case .duplicateInventory: return "Duplicate Buffs and freeform inventory"
        case .fractionalGrowth: return "Fractional Mult 1.875"
        case .modifierPreview: return "Crimson, Bookmarks and Fresh Ink"
        }
    }

    var instructions: String {
        switch self {
        case .ordered:
            return "Place 5 at R1C5, then End Turn: 50 × 6 = 300. Move Stop before Op-Ed before placing for 200. Reordering after placement keeps the current 300; the next five at R2C2 banks 200."
        case .simultaneousClears:
            return "Use Second Print, place 5 at R1C5. Row and box: 50 + 90 + 45 = 185 queued, +2 coins, and 2 cards drawn. End Turn banks 185."
        case .finalClue:
            return "Use Peek, choose the hand's 8, then place it at R9C9. Clue events score zero; automatic End Turn pays Morning Edition's 100 and wins."
        case .tenthTurn:
            return "Place 5 at R1C5, then End Turn: 50 × 6 + 100 Morning + 300 Evening = 700. Target 600."
        case .penalty:
            return "Place 8 at R1C8, then try 1 at R1C2. 80 − 50 = 30 queued Points; End Turn banks 90. Use Insurance before the mistake to preserve 80 × 3 = 240."
        case .duplicateInventory:
            return "Two separately owned Peek copies and Op-Ed → Stop. Drag either copy freely: release outside to cancel, or inside Sell to remove only that copy. Reorder Bookmarks before placing 5 at R1C5 for 200 instead of 300."
        case .modifierPreview:
            return "Place 4 on Crimson at R1C4: 160 Points × 6 = 960. Use the held Fresh Ink: 160 × 12 = 1,920. End Turn banks 1,920 toward the 3,000 target. Nothing is placed or consumed by loading this setup."
        case .fractionalGrowth:
            return "Syndication has one prior win. Place 5 at R1C5: 140 Points × 1.25 × 3 × 0.5 = 262.5. End Turn banks 262. The HUD and receipt must show Mult 1.875, never 1.88."
        }
    }

    func makeGame() throws -> Game {
        var game = Game(seed: "QA-ORDERED-SCORING-V2")
        try game.startPuzzle()
        var run = game.run
        guard var puzzle = game.puzzle else { throw FixtureError.missingPuzzle }
        let blanks: Set<Int>
        let hand: [Digit]
        let bookmarkIDs: [String]
        let buffIDs: [String]
        switch self {
        case .modifierPreview:
            blanks = Set(0..<81); hand = [.four, .nine, .two]
            bookmarkIDs = ["bm_op_ed", "bm_stop_the_presses"]; buffIDs = [Buffs.freshInk]
        case .ordered:
            blanks = Set(0..<81); hand = [.five, .five, .nine]
            bookmarkIDs = ["bm_op_ed", "bm_stop_the_presses"]; buffIDs = []
        case .simultaneousClears:
            blanks = Set((0..<81).filter { $0 == 4 || ($0 / 9 != 0 && Square($0).box != 1) })
            hand = [.five, .nine]
            bookmarkIDs = ["bm_finance_pages", "bm_crossword_daily"]; buffIDs = ["bf_second_print"]
        case .finalClue:
            blanks = [80]; hand = [.eight]
            bookmarkIDs = ["bm_morning_edition"]; buffIDs = [Buffs.peek]
        case .tenthTurn:
            blanks = Set(0..<81); hand = [.five, .nine]
            bookmarkIDs = ["bm_morning_edition", "bm_evening_edition", "bm_op_ed", "bm_stop_the_presses"]
            buffIDs = []
        case .penalty:
            blanks = Set(0..<81); hand = [.eight, .one, .nine]
            bookmarkIDs = ["bm_stop_the_presses"]; buffIDs = ["bf_insurance"]
        case .duplicateInventory:
            blanks = Set(0..<81); hand = [.five, .five, .nine]
            bookmarkIDs = ["bm_op_ed", "bm_stop_the_presses"]; buffIDs = [Buffs.peek, Buffs.peek]
        case .fractionalGrowth:
            blanks = Set((0..<81).filter { $0 == 4 || ($0 / 9 != 0 && Square($0).box != 1) })
            hand = [.five, .nine]
            bookmarkIDs = [Bookmarks.syndication, "bm_stop_the_presses"]; buffIDs = []
        }
        puzzle.board = try Self.latinBoard(blanks: blanks)
        puzzle.pool = Pool(blanksOf: puzzle.board)
        for digit in hand {
            guard puzzle.pool.take(digit) else { throw FixtureError.missingNumber }
        }
        puzzle.hand = hand
        puzzle.score = 0
        puzzle.target = self == .modifierPreview ? 3_000 : self == .finalClue ? 100 : self == .tenthTurn ? 600 : 1_000
        puzzle.turnNumber = self == .tenthTurn ? 10 : 1
        puzzle.cluesRemaining = 0
        puzzle.phase = .playing
        run.bookmarks = bookmarkIDs.map {
            OwnedBookmark(defID: $0, boughtAtLevel: 1, pricePaid: Catalog.item($0)!.listedPrice)
        }
        run.buffs = buffIDs.map { OwnedBuff(defID: $0, pricePaid: Catalog.item($0)!.listedPrice) }
        if self == .modifierPreview {
            run.markers = [OwnedMarker(defID: "mk_crimson", boughtAtLevel: 1,
                                       pricePaid: Catalog.item("mk_crimson")!.listedPrice, squares: [Square(3)])]
        }
        if self == .fractionalGrowth {
            run.runItemState[Bookmarks.syndication] = 1
            puzzle.boss = .sashimi
        }
        run.puzzle = puzzle
        guard Conservation.check(board: puzzle.board, pool: puzzle.pool, hand: puzzle.hand) == nil else {
            throw FixtureError.conservation
        }
        return Game(run: run)
    }

    private enum FixtureError: Error { case missingPuzzle, missingNumber, conservation }

    /// Board's public API intentionally cannot rewrite Givens. A Debug fixture
    /// uses its normal Codable format to arrange a fixed valid Sudoku solution,
    /// without widening the production board-mutation API for testing.
    private static func latinBoard(blanks: Set<Int>) throws -> Board {
        struct BoardFixture: Encodable {
            let solution: [Digit]
            let isGiven: [Bool]
            let placed: [Digit?]
            let filledBy: [Provenance?]
        }
        let solution = (0..<81).map { index in
            Digit((index / 9 * 3 + index / 27 + index % 9) % 9 + 1)!
        }
        let fixture = BoardFixture(solution: solution,
            isGiven: (0..<81).map { !blanks.contains($0) },
            placed: (0..<81).map { blanks.contains($0) ? nil : solution[$0] },
            filledBy: (0..<81).map { blanks.contains($0) ? nil : .given })
        return try JSONDecoder().decode(Board.self, from: JSONEncoder().encode(fixture))
    }
}
#endif
