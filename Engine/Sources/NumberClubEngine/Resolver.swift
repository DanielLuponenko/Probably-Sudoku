import Foundation

/// §14 — turns an event into the three running totals of §6 by walking every
/// owned item in a fixed order: Boss Modifier, then the Markers on the square
/// being played, then Bookmarks in the order they were bought, then Buffs.
///
/// Effects only read a snapshot, so a bump an item makes during an event takes
/// effect from the *next* event onwards. That is what makes Rolling Presses
/// score x1 on the Line Clear that starts it and x1.5 on the one after.
public enum Resolver {

    public static func context(_ event: GameEvent,
                               run: RunState,
                               puzzle: PuzzleState,
                               digit: Digit? = nil,
                               square: Square? = nil,
                               unit: Unit? = nil,
                               isClue: Bool = false,
                               boardCountBefore: Int = 0,
                               completesLine: Bool = false,
                               completedUnitCount: Int = 0) -> EffectContext {
        EffectContext(
            event: event,
            digit: digit,
            square: square,
            unit: unit,
            isClue: isClue,
            level: puzzle.level,
            slot: puzzle.slot,
            difficulty: puzzle.difficulty,
            bookmarkCount: run.bookmarks.count,
            boardCountBefore: boardCountBefore,
            completesLine: completesLine,
            completedUnitCount: completedUnitCount,
            puzzleState: puzzle.itemState,
            runState: run.runItemState
        )
    }

    public static func dispatch(_ context: EffectContext,
                                run: RunState,
                                puzzle: PuzzleState) -> EffectResult {
        var result = square(context, run: run, puzzle: puzzle)
        holdings(context, run: run, puzzle: puzzle, into: &result)
        return result
    }

    /// Bosses and Markers belong to the square being resolved.
    public static func square(_ context: EffectContext,
                              run: RunState,
                              puzzle: PuzzleState) -> EffectResult {
        var result = EffectResult()

        // 1. Boss Modifier.
        puzzle.boss?.apply(to: &result, context: context, censoredDigit: puzzle.censoredDigit)

        // 2. Markers on the square being played. A Marker only fires for the
        //    square it owns, so a Line Clear elsewhere on the board does not
        //    trigger it.
        if let square = context.square {
            for marker in run.markers(covering: square) {
                let before = result
                if let hook = marker.def.hooks[context.event] { hook(context, &result) }
                if let hook = marker.def.hooks[.anyScore], context.event.isScoring {
                    hook(context, &result)
                }
                record(marker.def.id, name: marker.def.name, before: before, into: &result)
            }
        }

        return result
    }

    /// Bookmarks and Buffs are held by the player, so their multiplier is
    /// collected once for the Turn rather than spent per event.
    public static func holdings(_ context: EffectContext,
                                run: RunState,
                                puzzle: PuzzleState,
                                into result: inout EffectResult) {
        let beforeBook = result
        run.book.benefit.apply(to: &result, context: context)
        record("book-benefit", name: "Book bonus", before: beforeBook, into: &result)
        // 3. Bookmarks, in purchase order.
        for (index, ad) in run.bookmarks.enumerated() where index != puzzle.disabledBookmark {
            let before = result
            if let hook = ad.def.hooks[context.event] { hook(context, &result) }
            if context.event.isScoring, let hook = ad.def.hooks[.anyScore] { hook(context, &result) }
            record(ad.def.id, name: ad.def.name, before: before, into: &result)
        }

        // 4. Activated Buff effects outlive the consumed inventory item. Their
        // hooks read saved activation state, so holding extra copies neither
        // enables nor duplicates an effect (Bird Seed's per-Level coin).
        for buff in Buffs.all {
            let before = result
            if let hook = buff.hooks[context.event] { hook(context, &result) }
            record(buff.id, name: buff.name, before: before, into: &result)
        }

    }

    private static func record(_ id: String, name: String, before: EffectResult,
                               into result: inout EffectResult) {
        let multiplier = before.multX == 0 ? 1 : result.multX / before.multX
        let eventMultiplier = before.eventMultX == 0 ? 1 : result.eventMultX / before.eventMultX
        let delta = ScoreContribution(sourceID: id, name: name,
                                      flat: result.flat - before.flat,
                                      multAdd: result.multAdd - before.multAdd,
                                      multX: multiplier * eventMultiplier,
                                      directScore: result.directScore - before.directScore,
                                      coins: result.coins - before.coins)
        if delta.flat != 0 || delta.multAdd != 0 || delta.multX != 1
            || delta.directScore != 0 || delta.coins != 0 {
            result.contributions.append(delta)
        }
    }

    public static func holdings(_ context: EffectContext,
                                run: RunState,
                                puzzle: PuzzleState) -> EffectResult {
        var result = EffectResult()
        holdings(context, run: run, puzzle: puzzle, into: &result)
        return result
    }

    /// Every scoring event resolves through this one formula (§6):
    /// `floor((base + flat) x (1 + additive) x multiplicative x one-shot)`.
    public static func points(base: Int,
                              result: EffectResult,
                              globalAdditive: Double,
                              oneShotDoubler: Bool) -> Int {
        guard !result.zeroed else { return 0 }
        let additive = 1.0 + result.multAdd + globalAdditive
        let multiplier = additive * result.multX * result.eventMultX * (oneShotDoubler ? 2.0 : 1.0)
        return Int((Double(base + result.flat) * multiplier).rounded(.down))
    }

    /// Additive mult that applies to every scoring event this Puzzle,
    /// regardless of which square was played: the Rose Marker's accumulated
    /// bonus and Fresh Ink.
    public static func globalAdditive(_ puzzle: PuzzleState) -> Double {
        (puzzle.itemState[Markers.rose] ?? 0) + (puzzle.itemState[Buffs.freshInk] ?? 0)
    }
}

// MARK: - Applying a result

extension PuzzleState {
    mutating func absorb(_ result: EffectResult) {
        for (key, value) in result.puzzleStateWrites { itemState[key] = value }
        for flag in result.armFlags { armedFlags.insert(flag) }
        turnsMax += result.extraTurns
        cluesRemaining += result.extraClues
    }

    /// One-shot arms are consumed by the first qualifying event.
    mutating func consume(_ flag: OneShotFlag) -> Bool {
        armedFlags.remove(flag) != nil
    }
}

extension RunState {
    mutating func absorb(_ result: EffectResult) {
        for (key, value) in result.runStateWrites { runItemState[key] = value }
        coins += result.coins
    }
}
