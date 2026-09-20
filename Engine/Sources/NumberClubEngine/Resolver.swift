import Foundation

/// §14 — turns an event into the three running totals of §6 by walking every
/// owned item in a fixed order: Boss Modifier, then the Markers on the square
/// being played, then Bookmarks in the locked visible slot order, then Buffs.
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
            bookmarkCount: scoringBookmarks(run: run, puzzle: puzzle).count,
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
                if context.event == .place,
                   BossScoring.suppressesImmediateMarker(square: square, isClue: context.isClue, run: run, puzzle: puzzle) {
                    // Run the real hook once, retaining resources, protection,
                    // negative trades and future growth. Gate only its own
                    // immediate positive placement operators.
                    result.flat = min(result.flat, before.flat)
                    result.multX = min(result.multX, before.multX)
                    result.eventMultX = min(result.eventMultX, before.eventMultX)
                    if let override = result.baseOverride, override.rawValue > (context.digit?.rawValue ?? 0) {
                        result.baseOverride = before.baseOverride
                    }
                }
                let claimID = run.markerState.claims.first {
                    $0.markerID == marker.defID && $0.square == square
                }?.id
                record(marker.def.id, instanceID: claimID, name: marker.def.name,
                       before: before, local: true, into: &result)
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
        // 3. Bookmarks in the locked visible order, or live order before lock.
        let bookmarks = scoringBookmarks(run: run, puzzle: puzzle)
        for (index, ad) in bookmarks.enumerated() {
            let sleeping = puzzle.scoringOrderLocked
                ? ad.id == puzzle.turnScoringState?.disabledBookmarkID
                : index == puzzle.disabledBookmark
            if sleeping || BookmarkMechanics.isSuspended(id: ad.id, puzzle: puzzle) { continue }
            let before = result
            let legacyDirect = ad.defID == Bookmarks.morningEdition || ad.defID == Bookmarks.eveningEdition
            if (!legacyDirect || puzzle.bookmarkState.legacyTurn),
               let hook = ad.def.hooks[context.event] { hook(context, &result) }
            if context.event.isScoring {
                let held = BookmarkMechanics.heldEffect(ad,
                    previous: BossScoring.physicalPrevious(of: ad, in: bookmarks, puzzle: puzzle), run: run, puzzle: puzzle)
                result.multAdd += held.multAdd
                result.multX *= held.multX
            }
            record(ad.def.id, instanceID: ad.id.uuidString, name: ad.def.name, before: before, into: &result)
        }

        // 4. Activated Buff effects outlive the consumed inventory item. Their
        // hooks read saved activation state, so holding extra copies neither
        // enables nor duplicates an effect (Bird Seed's per-Level coin).
        for buff in Buffs.all {
            let before = result
            if let hook = buff.hooks[context.event] { hook(context, &result) }
            record(buff.id, instanceID: run.activeBuffSources[buff.id]?.uuidString, name: buff.name, before: before, into: &result)
        }

    }

    static func scoringBookmarks(run: RunState, puzzle: PuzzleState) -> [OwnedBookmark] {
        puzzle.scoringVersion >= 2
            ? (puzzle.turnScoringState?.bookmarks ?? BossScoring.physicalOrder(run.bookmarks, puzzle: puzzle))
            : run.bookmarks
    }

    private static func record(_ id: String, instanceID: String? = nil, name: String, before: EffectResult,
                               local: Bool = false, into result: inout EffectResult) {
        let multiplier = before.multX == 0 ? 1 : result.multX / before.multX
        let eventMultiplier = before.eventMultX == 0 ? 1 : result.eventMultX / before.eventMultX
        let delta = ScoreContribution(sourceID: id, instanceID: instanceID, localMultX: local ? multiplier * eventMultiplier : eventMultiplier, name: name,
                                      flat: result.flat - before.flat,
                                      multAdd: result.multAdd - before.multAdd,
                                      multX: multiplier * eventMultiplier,
                                      directScore: result.directScore - before.directScore,
                                      coins: result.coins - before.coins,
                                      draws: result.draws == before.draws ? nil : result.draws - before.draws)
        if delta.flat != 0 || delta.multAdd != 0 || delta.multX != 1
            || delta.directScore != 0 || delta.coins != 0 || delta.draws != nil {
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

    /// Legacy event arithmetic retained for a version-1 saved Turn (§6):
    /// `floor((base + flat) x (1 + additive) x multiplicative x one-shot)`.
    public static func points(base: Int,
                              result: EffectResult,
                              globalAdditive: Double,
                              oneShotDoubler: Bool) -> Int {
        guard !result.zeroed else { return 0 }
        let additive = 1.0 + result.multAdd + globalAdditive
        let multiplier = additive * result.multX * result.eventMultX * (oneShotDoubler ? 2.0 : 1.0)
        return ScoreMath.integer((Double(base) + Double(result.flat)) * multiplier)
    }

    /// Persistent additive Mult. Version 1 appends this to its held total;
    /// version 2 seeds these effects before ordered Bookmark operations.
    public static func globalAdditive(_ puzzle: PuzzleState) -> Double {
        (puzzle.itemState[Markers.rose] ?? 0) + (puzzle.itemState[Buffs.freshInk] ?? 0)
    }
}

// MARK: - Applying a result

extension PuzzleState {
    mutating func absorb(_ result: EffectResult) {
        for (key, value) in result.puzzleStateWrites { itemState[key] = value }
        for flag in result.armFlags { armedFlags.insert(flag) }
        turnsMax += boss == .lastEdition ? 0 : result.extraTurns
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
