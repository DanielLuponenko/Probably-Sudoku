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
        var result = EffectResult()

        // 1. Boss Modifier.
        puzzle.boss?.apply(to: &result, context: context, censoredDigit: puzzle.censoredDigit)

        // 2. Markers on the square being played. A Marker only fires for the
        //    square it owns, so a Line Clear elsewhere on the board does not
        //    trigger it.
        if let square = context.square {
            for marker in run.markers(covering: square) {
                if let hook = marker.def.hooks[context.event] { hook(context, &result) }
                if let hook = marker.def.hooks[.anyScore], context.event.isScoring {
                    hook(context, &result)
                }
            }
        }

        // 3. Bookmarks, in purchase order.
        for ad in run.bookmarks {
            if let hook = ad.def.hooks[context.event] { hook(context, &result) }
            if context.event.isScoring, let hook = ad.def.hooks[.anyScore] { hook(context, &result) }
        }

        // 4. Buffs with standing effects (Bird Seed's per-Level coin).
        for buff in run.buffs {
            if let hook = buff.def.hooks[context.event] { hook(context, &result) }
        }

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
        let multiplier = additive * result.multX * (oneShotDoubler ? 2.0 : 1.0)
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
