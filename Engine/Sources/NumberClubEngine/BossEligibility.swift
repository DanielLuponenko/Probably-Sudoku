import Foundation

/// Encounter selection reads a copy of preparation state. An announced boss
/// is never reselected because the player later buys, sells, or spends an item.
public enum BossEligibility {
    public static func roll(run: inout RunState) -> BossModifier {
        let pool = candidates(run: run)
        let selected = pool[run.streams.boss.int(pool.count)]
        if run.bossRosterVersion >= 2 { run.bossEncounterHistory.append(selected) }
        return selected
    }

    public static func candidates(run: RunState) -> [BossModifier] {
        candidates(run: run) { stream, difficulty, givens in
            try Generator.generate(&stream, difficulty: difficulty, givens: givens)
        }
    }

    /// The injected generator lets tests prove route coverage and early exit
    /// without timing a Sudoku solver. Production always uses Generator above.
    static func candidates(run: RunState,
                           generatingWith generate: (inout RandomStream, Difficulty, Int) throws -> GeneratedPuzzle) -> [BossModifier] {
        let pool = run.bossRosterVersion >= 2
            ? (run.level == 9 ? BossModifier.finalBosses : BossModifier.regularBosses)
            : (run.level == 9 ? BossModifier.legacyFinalBosses : BossModifier.legacyRegularBosses)
        var accepted = Set<BossModifier>()
        var unresolved: [BossModifier] = []
        for boss in pool {
            if run.bossRosterVersion >= 2, boss == .fog {
                if !run.markers.isEmpty { unresolved.append(boss) }
                continue
            }
            if run.bossRosterVersion >= 2, boss == .unluckyLucky,
               !BookmarkMechanics.activeOwned(run: run).contains(where: { BookmarkMechanics.hasGameplayHooks($0) }) {
                continue
            }
            if !boss.isExpanded { accepted.insert(boss) }
            else if let quick = layoutIndependentEligibility(boss, run: run) {
                if quick { accepted.insert(boss) }
            } else { unresolved.append(boss) }
        }
        // A failed layout is enough to exclude a candidate. Generate the next
        // play/skip route only while some candidate still needs its proof.
        // Prefix caching avoids solving the same preceding ordinary board
        // twice; these are local value copies, never a global RNG/cache.
        var prefixes = ["": run.streams.board]
        func stream(after route: [PuzzleSlot]) throws -> RandomStream {
            let key = route.map { String($0.rawValue) }.joined(separator: ".")
            if let cached = prefixes[key] { return cached }
            guard let last = route.last else { return run.streams.board }
            var result = try stream(after: Array(route.dropLast()))
            _ = try generate(&result, last.difficulty, run.book.givens(for: last.difficulty))
            prefixes[key] = result
            return result
        }
        do {
            for route in upcomingRoutes(run: run) {
                guard !unresolved.isEmpty else { break }
                var source = try stream(after: route)
                let board = Board(try generate(&source, .boss, run.book.givens(for: .boss)))
                unresolved.removeAll { !isEligible($0, run: run, board: board) }
            }
            accepted.formUnion(unresolved)
        } catch {
            // An ungenerated layout cannot establish a remaining candidate's
            // eligibility. Already-proven layout-independent bosses are safe.
        }
        let eligible = pool.filter { accepted.contains($0) }
        // Both legacy pools contain unconditional encounters; preparation
        // failure therefore cannot lock a Book or spend a resource to escape.
        var varied = eligible.isEmpty ? [run.level == 9 ? .heavyLifter : .bookends] : eligible
        if run.bossRosterVersion >= 2 {
            let unplayed = varied.filter { !run.bossEncounterHistory.contains($0) }
            if !unplayed.isEmpty { varied = unplayed }
            if let previous = run.bossEncounterHistory.last {
                let different = varied.filter { $0.encounterFamily != previous.encounterFamily }
                if !different.isEmpty { varied = different }
            }
        }
        return varied
    }

    /// Most rules depend only on budgets or owned sources. In particular,
    /// opening an empty Book must not solve several future Sudoku boards just
    /// to reject bosses whose required items are absent.
    private static func layoutIndependentEligibility(_ boss: BossModifier, run: RunState) -> Bool? {
        let blankCount = 81 - run.book.givens(for: .boss)
        switch boss {
        case .collateral: return run.effectiveHandSize(boss: boss) >= 2 && blankCount >= 2
        case .splitEdition: return run.effectiveTurns(boss: boss) >= 2 && blankCount >= 2
        case .lastEdition: return blankCount > 0
        case .galleyQueue, .bookends, .reprintBan, .rebinder, .collator, .chainStitcher, .returnSlip, .orphanLine:
            return blankCount > 0
        case .pageCutter: return run.effectiveHandSize(boss: boss) > 4
        case .serialPublisher: return run.effectiveTurns(boss: boss) >= 3 && run.book.target(level: run.level, slot: .boss) > 0
        case .bindery: return BossScoring.hasOrderSensitiveLoadout(run: run)
        case .reviewBoard: return blankCount > 0
        case .rivalColumn: return run.effectiveTurns(boss: boss) >= 2
        case .backPage: return blankCount > 9 ? true : nil
        case .embargo:
            if hasUnconditionalOpeningBuff(run: run, boss: boss, preparationOnly: true, blankCount: blankCount) { return true }
            return run.buffs.contains { BossBuffRules.preparationBuffs.contains($0.defID) } ? nil : false
        case .royaltyContract:
            if hasUnconditionalOpeningBuff(run: run, boss: boss, preparationOnly: false, blankCount: blankCount) { return true }
            return run.buffs.isEmpty ? false : nil
        case .dryPress: return run.markers.reduce(0, { $0 + $1.squares.count }) < 2 ? false : nil
        case .publicist:
            if blankCount >= 2, BookmarkMechanics.activeOwned(run: run).contains(where: {
                $0.defID == Bookmarks.localGossip || $0.defID == Bookmarks.sportsSection
            }) { return true }
            let ids: Set<String> = [Bookmarks.localGossip, Bookmarks.sportsSection,
                Bookmarks.marginNotes, Bookmarks.neighbourhoodNews, Bookmarks.overflowColumn]
            return BookmarkMechanics.activeOwned(run: run).contains { ids.contains($0.defID) } ? nil : false
        case .wordCount:
            let localCopies = BookmarkMechanics.activeOwned(run: run).filter { $0.defID == Bookmarks.localGossip }.count
            let opportunities = min(blankCount, run.effectiveHandSize(boss: boss))
            // Local Gossip contributes30 on every ordinary placement, with
            // no finite entitlement or positional condition. This lower bound
            // matches the public numeric proof in hasWordCountLoadout.
            if localCopies * 30 * opportunities > 150 { return true }
            return run.bookmarks.isEmpty && run.markers.isEmpty ? false : nil
        case .lateCourier:
            let heldSource = BookmarkMechanics.activeOwned(run: run).contains {
                [Bookmarks.crosswordDaily, Bookmarks.crossReference].contains($0.defID)
                    || ($0.defID == Bookmarks.paperSalvage && run.effectiveTossAllowance(boss: boss) > 0)
            } || run.buffs.contains { $0.defID == Buffs.luckyDip }
            if heldSource { return blankCount > run.effectiveHandSize(boss: boss) }
            return run.markers.contains { [Markers.sapphire, Markers.prism].contains($0.defID) } ? nil : false
        default: return true
        }
    }

    /// Fresh puzzle state has no armed or spent effects. These existing
    /// activations need only a nonempty board (or a nonempty initial Pool), not
    /// a particular layout, digit, selected card, hidden solution or RNG roll.
    private static func hasUnconditionalOpeningBuff(run: RunState, boss: BossModifier,
                                                    preparationOnly: Bool, blankCount: Int) -> Bool {
        guard run.outcome == nil, blankCount > 0 else { return false }
        let unconditional: Set<String> = [Buffs.peek, Buffs.redraw, Buffs.overtime,
            Buffs.doubleDown, Buffs.insurance, Buffs.secondPrint, Buffs.freshInk,
            Buffs.litmus, Buffs.paperCrane]
        return run.buffs.contains { buff in
            guard !preparationOnly || BossBuffRules.preparationBuffs.contains(buff.defID) else { return false }
            if unconditional.contains(buff.defID) { return true }
            if buff.defID == Buffs.birdSeed { return run.runItemState[Buffs.birdSeed] != Double(run.level) }
            if buff.defID == Buffs.luckyDip { return blankCount > run.effectiveHandSize(boss: boss) }
            return false
        }
    }

    /// The actual creation path can also call this with its generated board.
    /// It intentionally inspects public positions/counts, never correctness.
    public static func isEligible(_ boss: BossModifier, run: RunState, board: Board) -> Bool {
        let blanks = board.blanks
        guard !blanks.isEmpty else { return !boss.isExpanded }
        switch boss {
        case .fog:
            return blanks.contains { !run.markers(covering: $0).isEmpty }
        case .collateral: return run.effectiveHandSize(boss: boss) >= 2 && blanks.count >= 2
        case .splitEdition: return run.effectiveTurns(boss: boss) >= 2 && blanks.count >= 2
        case .lastEdition: return !blanks.isEmpty
        case .lateCourier:
            return hasAutomaticDrawSource(run: run, board: board)
                && blanks.count > run.effectiveHandSize(boss: boss)
        case .pageCutter:
            return run.effectiveHandSize(boss: boss) > 4
        case .serialPublisher:
            return run.effectiveTurns(boss: boss) >= 3 && run.book.target(level: run.level, slot: .boss) > 0
        case .bindery:
            return BossScoring.hasOrderSensitiveLoadout(run: run)
        case .embargo:
            return hasOpeningBuff(run: run, board: board, boss: boss, preparationOnly: true)
        case .royaltyContract:
            return hasOpeningBuff(run: run, board: board, boss: boss, preparationOnly: false)
        case .dryPress:
            let marked = blanks.filter { !run.markers(covering: $0).isEmpty }
            let positive = BossScoring.positiveImmediateMarkerSquares(run: run, board: board)
            return positive.count >= 2 && marked.count < blanks.count
        case .reviewBoard:
            return [Geometry.rows, Geometry.cols, Geometry.boxes].contains { units in
                units.contains { unit in unit.contains { board.isBlank($0) } }
            }
        case .rivalColumn:
            return run.effectiveTurns(boss: boss) >= 2
        case .publicist:
            guard blanks.count >= 2 else { return false }
            let repeatable: Set<String> = [Bookmarks.localGossip, Bookmarks.sportsSection,
                Bookmarks.marginNotes, Bookmarks.neighbourhoodNews, Bookmarks.overflowColumn]
            return BookmarkMechanics.activeOwned(run: run).contains { item in
                guard repeatable.contains(item.defID) else { return false }
                if item.defID == Bookmarks.marginNotes {
                    return blanks.filter { $0.row == 0 || $0.row == 8 || $0.col == 0 || $0.col == 8 }.count >= 2
                }
                if item.defID == Bookmarks.neighbourhoodNews {
                    return blanks.filter { square in
                        Square.all.filter { abs($0.row - square.row) + abs($0.col - square.col) == 1 }
                            .filter { board.isBlank($0) || board.filledBy[$0.index] == .player }.count >= 2
                    }.count >= 2
                }
                // Overflow is a conditional flat bonus. Its extra-draw engine
                // must actually exist before that potential can qualify.
                if item.defID == Bookmarks.overflowColumn { return hasAutomaticDrawSource(run: run, board: board) }
                return true
            }
        case .wordCount:
            return BossScoring.hasWordCountLoadout(run: run, board: board)
        case .backPage:
            return Digit.all.contains { $0.rawValue != 5 && board.count(of: $0) < 9 }
        default:
            return true
        }
    }

    public static func hasAutomaticDrawSource(run: RunState, board: Board) -> Bool {
        if BookmarkMechanics.owns(Bookmarks.crosswordDaily, run: run) { return true }
        if BookmarkMechanics.owns(Bookmarks.paperSalvage, run: run), run.effectiveTossAllowance(boss: .lateCourier) > 0 { return true }
        if BookmarkMechanics.owns(Bookmarks.crossReference, run: run) { return true }
        if run.buffs.contains(where: { $0.defID == Buffs.luckyDip }) { return true }
        return board.blanks.contains { square in
            run.markers(covering: square).contains { $0.defID == Markers.sapphire || $0.defID == Markers.prism }
        }
    }

    private static func hasOpeningBuff(run: RunState, board: Board, boss: BossModifier, preparationOnly: Bool) -> Bool {
        var preview = run
        preview.shop = nil
        preview.slot = .boss
        preview.pendingItemDecisions = []
        var pool = Pool(blanksOf: board)
        let handSize = run.effectiveHandSize(boss: boss)
        let hand = pool.draw(&preview.streams.pool, count: handSize)
        var puzzle = PuzzleState(level: run.level, slot: .boss, difficulty: .boss,
            board: board, pool: pool, hand: hand, handSize: handSize, turnNumber: 1,
            turnsMax: run.effectiveTurns(boss: boss), tossedThisPuzzle: 0,
            tossAllowance: run.effectiveTossAllowance(boss: boss), score: 0,
            target: run.book.target(level: run.level, slot: .boss),
            cluesRemaining: run.effectiveClues(boss: boss), boss: boss,
            censoredDigit: nil, blockedDigit: nil, bossTurn: nil, phase: .playing, keepFillingCoins: 0)
        puzzle.ensureHandIdentities(seed: run.seed)
        puzzle.startObstacleTurn(&preview)
        preview.puzzle = puzzle
        return preview.buffs.contains { buff in
            (!preparationOnly || BossBuffRules.preparationBuffs.contains(buff.defID))
                && !BuffRuntime.options(for: buff.defID, run: preview, consuming: buff.id).isEmpty
        }
    }

    private static func upcomingRoutes(run: RunState) -> [[PuzzleSlot]] {
        // Skipping ordinary puzzles does not advance board RNG. Check every
        // remaining play/skip route before announcing a board-sensitive boss.
        // No preview advances any of the live board/Pool/Shop/boss streams.
        var paths: [[PuzzleSlot]] = [[]]
        let remaining: [PuzzleSlot]
        switch run.slot {
        case .easy: remaining = run.puzzle == nil && run.shop == nil ? [.easy, .medium] : [.medium]
        case .medium: remaining = run.puzzle == nil && run.shop == nil ? [.medium] : []
        case .boss: remaining = []
        }
        for slot in remaining { paths += paths.map { $0 + [slot] } }
        return paths
    }
}

public extension BossModifier {
    var isExpanded: Bool {
        switch self {
        case .galleyQueue, .bookends, .reprintBan, .rebinder, .lateCourier, .collator, .pageCutter,
             .chainStitcher, .returnSlip, .orphanLine, .serialPublisher, .bindery, .embargo,
             .dryPress, .reviewBoard, .rivalColumn, .royaltyContract, .publicist, .wordCount, .backPage,
             .collateral, .splitEdition, .lastEdition:
            return true
        default: return false
        }
    }
}
