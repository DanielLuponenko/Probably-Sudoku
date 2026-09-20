import Foundation

/// Saved Bookmarks observe accepted actions once. Calculation and offer reads
/// are pure; only the named lifecycle and decision methods change state.
public enum BookmarkMechanics {
    public static let reworkedIDs: Set<String> = [Bookmarks.morningEdition,
        Bookmarks.eveningEdition, Bookmarks.editorialBoard,
        Bookmarks.lettersToTheEditor, Bookmarks.stopThePresses]
    public static let newIDs = Set(Bookmarks.all.dropFirst(23).map(\.id))
    public static let managedHeldIDs: Set<String> = [Bookmarks.editorialBoard,
        Bookmarks.lettersToTheEditor, Bookmarks.stopThePresses, Bookmarks.doubleColumn,
        Bookmarks.numberIndex, Bookmarks.advancePayment, Bookmarks.readersCircle]

    public static func isSuspended(id: UUID, puzzle: PuzzleState?) -> Bool {
        puzzle?.bookmarkState.suspended.contains(id) == true
    }

    /// Boss silence deliberately does not disable passive budgets. Collateral does.
    public static func activeOwned(run: RunState, puzzle: PuzzleState? = nil) -> [OwnedBookmark] {
        let current = puzzle ?? run.puzzle
        return run.bookmarks.filter { !isSuspended(id: $0.id, puzzle: current) }
    }

    public static func owns(_ defID: String, run: RunState, puzzle: PuzzleState? = nil) -> Bool {
        activeOwned(run: run, puzzle: puzzle).contains { $0.defID == defID }
    }

    public static func activeScoring(run: RunState, puzzle: PuzzleState) -> [OwnedBookmark] {
        let held = puzzle.turnScoringState?.bookmarks ?? run.bookmarks
        let disabled: UUID?
        if let locked = puzzle.turnScoringState { disabled = locked.disabledBookmarkID }
        else { disabled = puzzle.disabledBookmark.flatMap { run.bookmarks.indices.contains($0) ? run.bookmarks[$0].id : nil } }
        return held.filter { $0.id != disabled && !puzzle.bookmarkState.suspended.contains($0.id) }
    }

    /// Right to Reply itself is not a random silence candidate. New scoring
    /// Bookmarks participate even though their structured rules are outside hooks.
    public static func hasGameplayHooks(_ bookmark: OwnedBookmark) -> Bool {
        let structured: Set<String> = [Bookmarks.marginNotes, Bookmarks.neighbourhoodNews,
            Bookmarks.serialStory, Bookmarks.doubleColumn, Bookmarks.carryover,
            Bookmarks.numberIndex, Bookmarks.overflowColumn, Bookmarks.carbonPaper,
            Bookmarks.advancePayment, Bookmarks.typeCase, Bookmarks.crossReference,
            Bookmarks.issueTracker, Bookmarks.correctionLedger, Bookmarks.referenceDesk,
            Bookmarks.readersCircle, Bookmarks.personalColumn, Bookmarks.archiveRoom]
        return !bookmark.def.hooks.isEmpty || structured.contains(bookmark.defID)
    }

    public static func capacity(run: RunState, puzzle: PuzzleState? = nil) -> Int {
        2 + (owns(Bookmarks.pocketInsert, run: run, puzzle: puzzle) ? 1 : 0)
    }

    public static func canRemove(id: UUID, run: RunState) -> Bool {
        guard let item = run.bookmarks.first(where: { $0.id == id }),
              !isSuspended(id: id, puzzle: run.puzzle) else { return false }
        if item.defID == Bookmarks.pocketInsert,
           !activeOwned(run: run).contains(where: { $0.id != id && $0.defID == Bookmarks.pocketInsert }),
           run.buffs.count > 2 { return false }
        return true
    }

    /// Used by non-sale transformations such as New Edition. No economy hooks.
    @discardableResult
    public static func retire(id: UUID, run: inout RunState) -> Bool {
        guard canRemove(id: id, run: run),
              let index = run.bookmarks.firstIndex(where: { $0.id == id }) else { return false }
        run.bookmarks.remove(at: index)
        // A previously locked Turn retains the sold copy's evaluated growth.
        // New Edition happens in Shop, where there is no such snapshot.
        if run.puzzle?.turnScoringState?.bookmarks.contains(where: { $0.id == id }) != true {
            run.bookmarkState.copies.removeValue(forKey: id)
            run.puzzle?.bookmarkState.copies.removeValue(forKey: id)
            run.puzzle?.bookmarkState.turn.copies.removeValue(forKey: id)
        }
        if let disabled = run.puzzle?.bossTurn?.disabledBookmark {
            run.puzzle?.bossTurn?.disabledBookmark = disabled == index ? nil : disabled - (disabled > index ? 1 : 0)
        }
        run.pendingItemDecisions.removeAll { $0.sourceInstanceID == id }
        return true
    }

    private static func contribution(_ item: OwnedBookmark, flat: Int = 0,
                                     direct: Int = 0, coins: Int = 0) -> ScoreContribution {
        ScoreContribution(sourceID: item.defID, instanceID: item.id.uuidString,
                          name: item.def.name, flat: flat, directScore: direct, coins: coins)
    }

    private static func add(_ item: OwnedBookmark, flat: Int = 0, direct: Int = 0,
                            coins: Int = 0, into result: inout EffectResult) {
        guard flat != 0 || direct != 0 || coins != 0 else { return }
        result.flat += flat; result.directScore += direct; result.coins += coins
        result.contributions.append(contribution(item, flat: flat, direct: direct, coins: coins))
    }

    public static func actionAccepted(puzzle: inout PuzzleState) {
        BossEncounterRules.actionAccepted(puzzle: &puzzle)
        puzzle.bookmarkState.turn.actionTaken = true
        puzzle.bookmarkState.puzzleActionTaken = true
    }

    /// Called before held placement bonuses resolve, once after eligibility is
    /// known. Its returned flat bonuses must join the ordinary event before
    /// local multipliers. A counterfactual Carbon calculation never calls this.
    public static func beforePlacement(_ placement: CataloguePlacement,
                                       run: inout RunState, puzzle: inout PuzzleState) -> EffectResult {
        var result = EffectResult()
        actionAccepted(puzzle: &puzzle)
        guard !puzzle.bookmarkState.legacyTurn else { return result }
        let eligible = placement.isEligible && puzzle.phase == .playing
        let held = activeScoring(run: run, puzzle: puzzle)
        if eligible {
            puzzle.bookmarkState.turn.eligiblePlacements += 1
            puzzle.bookmarkState.turn.boxes |= 1 << placement.square.box
            puzzle.bookmarkState.turn.digitBoxes[placement.digit.rawValue, default: 0] |= 1 << placement.square.box
            puzzle.bookmarkState.boxTurns[placement.square.box, default: []].insert(puzzle.turnNumber)
        }
        let neighbours = Square.all.filter {
            abs($0.row - placement.square.row) + abs($0.col - placement.square.col) == 1
                && placement.boardBefore.filledBy[$0.index] == .player
        }.count
        let marked = !run.markers(covering: placement.square).isEmpty
        for item in held {
            var turn = puzzle.bookmarkState.turn.copies[item.id, default: .init()]
            var state = puzzle.bookmarkState.copies[item.id, default: .init()]
            var permanent = run.bookmarkState.copies[item.id, default: .init()]
            if item.defID == Bookmarks.typeCase, turn.typeDigit == placement.digit { turn.typeEnded = true }
            if !eligible {
                if item.defID == Bookmarks.serialStory { turn.serialLastDigit = nil; turn.serialLength = 0 }
            } else {
                switch item.defID {
                case Bookmarks.marginNotes:
                    if placement.square.row == 0 || placement.square.row == 8
                        || placement.square.col == 0 || placement.square.col == 8 { add(item, flat: 50, into: &result) }
                case Bookmarks.neighbourhoodNews:
                    if neighbours >= 2 { add(item, flat: 45, into: &result) }
                case Bookmarks.serialStory:
                    turn.serialLength = turn.serialLastDigit.map { $0.rawValue + 1 == placement.digit.rawValue } == true
                        ? turn.serialLength + 1 : 1
                    turn.serialLastDigit = placement.digit
                    if turn.serialLength >= 3 && !turn.serialUsed {
                        turn.serialUsed = true; add(item, flat: 120, into: &result)
                    }
                case Bookmarks.numberIndex:
                    state.numberIndexDigits |= 1 << (placement.digit.rawValue - 1)
                    if state.numberIndexDigits == 511 && !state.numberIndexAwarded {
                        state.numberIndexAwarded = true
                        permanent.numberIndexMult = min(10, permanent.numberIndexMult + 2)
                    }
                case Bookmarks.overflowColumn:
                    add(item, flat: 25 * min(4, max(0, placement.handBefore.count - puzzle.handSize)), into: &result)
                case Bookmarks.carbonPaper:
                    if !marked, turn.carbonPoints > 0 {
                        add(item, flat: turn.carbonPoints, into: &result); turn.carbonPoints = 0
                    } else if marked, !turn.carbonUsed, placement.markerExtraPoints > 0 {
                        turn.carbonUsed = true; turn.carbonPoints = min(180, placement.markerExtraPoints)
                    }
                case Bookmarks.typeCase:
                    if turn.typeDigit != nil && !turn.typeEnded && turn.typeBonuses < 3 {
                        turn.typeBonuses += 1; add(item, flat: 50, into: &result)
                    }
                case Bookmarks.archiveRoom:
                    if permanent.archivePoints > 0 {
                        add(item, flat: permanent.archivePoints, into: &result); permanent.archivePoints = 0
                    }
                default: break
                }
            }
            puzzle.bookmarkState.turn.copies[item.id] = turn
            puzzle.bookmarkState.copies[item.id] = state
            run.bookmarkState.copies[item.id] = permanent
        }
        puzzle.turnScoringState?.bookmarkCopies = run.bookmarkState.copies
        return result
    }

    /// Actual points deducted from queue and bank, after waivers and flooring.
    public static func wrongPlacement(digit: Digit, paidPenalty: Int,
                                      run: RunState, puzzle: inout PuzzleState) {
        actionAccepted(puzzle: &puzzle)
        guard !puzzle.bookmarkState.legacyTurn else { return }
        if puzzle.phase == .playing && paidPenalty > 0 { puzzle.bookmarkState.turn.paidPenalty = true }
        for item in activeScoring(run: run, puzzle: puzzle) {
            puzzle.bookmarkState.turn.copies[item.id, default: .init()].serialLastDigit = nil
            puzzle.bookmarkState.turn.copies[item.id, default: .init()].serialLength = 0
            if puzzle.bookmarkState.turn.copies[item.id]?.typeDigit == digit {
                puzzle.bookmarkState.turn.copies[item.id, default: .init()].typeEnded = true
            }
            if item.defID == Bookmarks.correctionLedger, puzzle.phase == .playing,
               paidPenalty > 0, puzzle.bookmarkState.copies[item.id]?.correctionArmed != true {
                puzzle.bookmarkState.copies[item.id, default: .init()].correctionArmed = true
                puzzle.bookmarkState.copies[item.id, default: .init()].correctionAmount = min(150, paidPenalty / 2)
            }
        }
    }

    /// After all placement and clear receipts exist. This method returns only
    /// direct/coin rewards; targeted draws move real Pool cards exactly once.
    public static func afterPlacement(_ placement: CataloguePlacement,
                                      run: inout RunState, puzzle: inout PuzzleState) -> EffectResult {
        var result = EffectResult()
        guard !puzzle.bookmarkState.legacyTurn, placement.isEligible, puzzle.phase == .playing else { return result }
        for item in activeScoring(run: run, puzzle: puzzle) {
            var state = puzzle.bookmarkState.copies[item.id, default: .init()]
            switch item.defID {
            case Bookmarks.personalColumn:
                if state.personalDigit == placement.digit && state.personalTriggers < 2 {
                    state.personalTriggers += 1
                    if puzzle.pool.take(placement.digit) { puzzle.appendHandDigits([placement.digit]) }
                }
            case Bookmarks.crossReference:
                if placement.positiveClearUnits.count >= 2 && state.crossReferenceTriggers < 2 {
                    state.crossReferenceTriggers += 1
                    if !BossRuntime.deferAutomaticDraw(count: 2, sourceID: item.defID,
                                                       sourceInstanceID: item.id, puzzle: &puzzle) {
                        puzzle.bookmarkState.pendingRefillDraws += 2
                    }
                }
            case Bookmarks.issueTracker:
                if placement.positiveClearUnits.contains(.box),
                   !puzzle.bookmarkState.clearedIssueBoxes.contains(placement.square.box) {
                    add(item, coins: min(3, puzzle.bookmarkState.boxTurns[placement.square.box]?.count ?? 0), into: &result)
                }
            case Bookmarks.correctionLedger:
                if state.correctionArmed && !state.correctionRecovered {
                    state.correctionPlacements += 1
                    if state.correctionPlacements == 3 {
                        state.correctionRecovered = true; add(item, direct: state.correctionAmount, into: &result)
                    }
                }
            case Bookmarks.referenceDesk:
                for unit in placement.positiveClearUnits {
                    let bit = unit == .row ? 1 : unit == .col ? 2 : 4
                    guard state.referenceTypes & bit == 0 else { continue }
                    state.referenceTypes |= bit
                    if puzzle.boss?.disablesClues != true && puzzle.bookmarkState.spentClues > 0 {
                        puzzle.bookmarkState.spentClues -= 1; puzzle.cluesRemaining += 1
                    }
                }
            default: break
            }
            puzzle.bookmarkState.copies[item.id] = state
        }
        if placement.positiveClearUnits.contains(.box) { puzzle.bookmarkState.clearedIssueBoxes.insert(placement.square.box) }
        return result
    }

    public static func clueSpent(puzzle: inout PuzzleState) {
        actionAccepted(puzzle: &puzzle)
        puzzle.bookmarkState.spentClues += 1
    }

    /// Pure held value. `previous` is the immediately preceding physical slot,
    /// even if it is asleep; filtered active arrays must not collapse adjacency.
    public static func heldEffect(_ item: OwnedBookmark, previous: OwnedBookmark? = nil,
                                  run: RunState, puzzle: PuzzleState) -> EffectResult {
        heldEffect(item, previous: previous, context: Resolver.context(.turnEnd, run: run, puzzle: puzzle),
            puzzle: puzzle, copies: run.bookmarkState.copies,
            activeIDs: Set(activeScoring(run: run, puzzle: puzzle).map(\.id)))
    }

    public static func heldEffect(_ item: OwnedBookmark, previous: OwnedBookmark? = nil,
                                  context: EffectContext, puzzle: PuzzleState,
                                  copies: [UUID: BookmarkRunCopyState], activeIDs: Set<UUID>) -> EffectResult {
        guard activeIDs.contains(item.id) else { return .init() }
        var effect = EffectResult()
        let facts = puzzle.bookmarkState.turn
        let eligible = facts.eligiblePlacements > 0
        if puzzle.bookmarkState.legacyTurn || !managedHeldIDs.contains(item.defID) {
            item.def.hooks[.anyScore]?(context, &effect)
            return effect
        }
        switch item.defID {
        case Bookmarks.editorialBoard: if facts.boxes.nonzeroBitCount >= 3 { effect.multAdd = 3 }
        case Bookmarks.lettersToTheEditor:
            if eligible && puzzle.difficulty == .boss && puzzle.bookmarkState.previousPaidPenalty { effect.multAdd = 3 }
        case Bookmarks.stopThePresses: if (1...2).contains(facts.eligiblePlacements) { effect.multX = 3 }
        case Bookmarks.doubleColumn: if facts.digitBoxes.values.contains(where: { $0.nonzeroBitCount >= 2 }) { effect.multAdd = 2 }
        case Bookmarks.numberIndex: effect.multAdd = Double(copies[item.id]?.numberIndexMult ?? 0)
        case Bookmarks.advancePayment:
            if eligible && puzzle.bookmarkState.copies[item.id]?.advancePaid == true { effect.multX = 2.5 }
        case Bookmarks.readersCircle:
            if eligible, let previous, previous.defID != Bookmarks.readersCircle {
                effect.multAdd = min(3, max(0, heldEffect(previous, context: context, puzzle: puzzle,
                    copies: copies, activeIDs: activeIDs).multAdd))
            }
        default: break
        }
        return effect
    }

    /// New direct bank awards. Existing legacy .turnEnd/.puzzleEnd hooks must
    /// be suppressed for Morning/Evening when legacyTurn is false.
    public static func turnEnd(run: RunState, puzzle: inout PuzzleState) -> EffectResult {
        var result = EffectResult()
        guard !puzzle.bookmarkState.legacyTurn, puzzle.phase == .playing,
              !puzzle.bookmarkState.turn.bankAwarded,
              puzzle.bookmarkState.turn.eligiblePlacements > 0 else { return result }
        puzzle.bookmarkState.turn.bankAwarded = true
        for item in activeScoring(run: run, puzzle: puzzle) {
            switch item.defID {
            case Bookmarks.morningEdition: add(item, direct: 100, into: &result)
            case Bookmarks.eveningEdition:
                if puzzle.turnNumber == 10 && puzzle.bookmarkState.copies[item.id]?.eveningAwarded != true {
                    puzzle.bookmarkState.copies[item.id, default: .init()].eveningAwarded = true
                    add(item, direct: 300, into: &result)
                }
            case Bookmarks.carryover:
                add(item, direct: min(300, puzzle.bookmarkState.previousOrdinaryBank / 10), into: &result)
            default: break
            }
        }
        return result
    }

    /// Call after ordinary bank and direct payouts, before incrementing Turn.
    public static func didBank(ordinaryBank: Int, puzzle: inout PuzzleState) {
        if puzzle.phase == .playing && BossEncounterRules.targetSatisfied(puzzle: puzzle)
            && puzzle.bookmarkState.winningTurn == nil {
            puzzle.bookmarkState.winningTurn = puzzle.turnNumber
        }
        puzzle.bookmarkState.previousOrdinaryBank = max(0, ordinaryBank)
        puzzle.bookmarkState.previousPaidPenalty = puzzle.bookmarkState.turn.paidPenalty
    }

    public static func turnStarted(puzzle: inout PuzzleState) {
        puzzle.bookmarkState.turn = .init()
        puzzle.bookmarkState.legacyTurn = false
    }

    public static func afterPlayableRefill(run: inout RunState, puzzle: inout PuzzleState) {
        guard puzzle.phase == .playing, puzzle.turnNumber <= puzzle.turnsMax else { return }
        let count = puzzle.bookmarkState.pendingRefillDraws
        puzzle.bookmarkState.pendingRefillDraws = 0
        if count > 0 {
            let drawn = puzzle.pool.draw(&run.streams.pool, count: count)
            puzzle.appendHandDigits(drawn)
            if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
        }
    }

    public static func afterToss(run: inout RunState, puzzle: inout PuzzleState) {
        actionAccepted(puzzle: &puzzle)
        guard puzzle.phase == .playing else { return }
        for item in activeOwned(run: run, puzzle: puzzle) where item.defID == Bookmarks.paperSalvage {
            guard puzzle.bookmarkState.copies[item.id]?.paperSalvageUsed != true else { continue }
            puzzle.bookmarkState.copies[item.id, default: .init()].paperSalvageUsed = true
            if BossRuntime.deferAutomaticDraw(count: 1, sourceID: item.defID, sourceInstanceID: item.id, puzzle: &puzzle) { continue }
            if let digit = puzzle.pool.draw(&run.streams.pool) {
                puzzle.appendHandDigits([digit])
                MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle)
            }
        }
    }

    public static func poolForecast(run: RunState, puzzle: PuzzleState) -> [Digit] {
        guard owns(Bookmarks.forthcomingEdition, run: run, puzzle: puzzle) else { return [] }
        var pool = puzzle.pool; var stream = run.streams.pool
        return pool.draw(&stream, count: 2)
    }

    public static func puzzleStarted(puzzle: inout PuzzleState) {
        puzzle.bookmarkState = .init()
    }

    public static func earlyDeadlineCoins(run: RunState, puzzle: PuzzleState) -> Int {
        guard let won = puzzle.bookmarkState.winningTurn, won <= 5 else { return 0 }
        return 4 * activeOwned(run: run, puzzle: puzzle).filter { $0.defID == Bookmarks.earlyDeadline }.count
    }

    /// One cash-out path. Skips do not call this, so archived packets survive.
    public static func puzzleWon(run: inout RunState, puzzle: inout PuzzleState) {
        guard !puzzle.bookmarkState.payoutRecorded else { return }
        puzzle.bookmarkState.payoutRecorded = true
        puzzle.bookmarkState.pendingRefillDraws = 0
        for item in activeOwned(run: run, puzzle: puzzle) where item.defID == Bookmarks.archiveRoom {
            run.bookmarkState.copies[item.id, default: .init()].archivePoints = run.isFinalPuzzle ? 0
                : min(150, max(0, puzzle.boss?.disablesClues == true ? 0 : puzzle.cluesRemaining) * 50)
        }
    }

    public static func redirectBossSilence(proposedIndex: Int?, run: RunState,
                                          puzzle: inout PuzzleState) -> Int? {
        guard let proposedIndex, run.bookmarks.indices.contains(proposedIndex) else { return proposedIndex }
        let target = run.bookmarks[proposedIndex]
        guard target.defID != Bookmarks.rightToReply else { return proposedIndex }
        if let index = run.bookmarks.indices.first(where: {
            run.bookmarks[$0].defID == Bookmarks.rightToReply
                && !puzzle.bookmarkState.suspended.contains(run.bookmarks[$0].id)
                && puzzle.bookmarkState.copies[run.bookmarks[$0].id]?.rightToReplyUsed != true
        }) {
            puzzle.bookmarkState.copies[run.bookmarks[index].id, default: .init()].rightToReplyUsed = true
            return index
        }
        return proposedIndex
    }

    // MARK: Shop lifecycle and provenance

    public static func shopOpened(run: inout RunState) {
        guard let visit = run.shop?.visitID,
              run.bookmarkState.shop?.visitID != visit else { return }
        var state = BookmarkShopState(visitID: visit, ownedOnEntry: Set(run.bookmarks.map(\.id)))
        for item in activeOwned(run: run) where item.defID == Bookmarks.recycledInsert {
            if run.bookmarkState.copies[item.id, default: .init()].purchasedBuffReceipts >= 3 {
                state.recycledEligible.insert(item.id)
            }
        }
        run.bookmarkState.shop = state
    }

    /// An old Shop has no reliable entry snapshot. Preserve it without inventing
    /// a clean visit, a refundable entry item, or an already-spent discount.
    public static func restoreShopStateIfNeeded(run: inout RunState) {
        guard let shop = run.shop, let visit = shop.visitID,
              run.bookmarkState.shop?.visitID != visit else { return }
        var state = BookmarkShopState(visitID: visit, ownedOnEntry: [])
        state.purchases = max(1, shop.offers.filter(\.sold).count)
        state.rerolls = shop.rerollsUsed
        state.buffPurchased = true
        run.bookmarkState.shop = state
    }

    public static func purchasePrice(_ offer: ShopOffer, run: RunState) -> Int {
        guard offer.def.kind == .buff, owns(Bookmarks.bulkNotice, run: run),
              let visit = run.shop?.visitID, run.bookmarkState.shop?.visitID == visit,
              run.bookmarkState.shop?.buffPurchased == false else { return offer.price }
        return max(1, offer.price - 1)
    }

    public static func didPurchase(kind: ItemKind, run: inout RunState) {
        restoreShopStateIfNeeded(run: &run)
        run.bookmarkState.shop?.purchases += 1
        if kind == .buff { run.bookmarkState.shop?.buffPurchased = true }
    }

    public static func didReroll(run: inout RunState) {
        restoreShopStateIfNeeded(run: &run)
        run.bookmarkState.shop?.rerolls += 1
    }

    private static func buybackSource(for item: OwnedBookmark, run: RunState) -> OwnedBookmark? {
        guard let state = run.bookmarkState.shop, state.visitID == run.shop?.visitID,
              state.ownedOnEntry.contains(item.id), item.boughtInShopVisitID != state.visitID else { return nil }
        return activeOwned(run: run).first {
            $0.defID == Bookmarks.buybackColumn && $0.id != item.id && !state.buybackUsed.contains($0.id)
        }
    }

    public static func salePrice(for item: OwnedBookmark, run: RunState) -> Int {
        buybackSource(for: item, run: run) == nil ? RunState.sellValue(pricePaid: item.pricePaid) : max(0, item.pricePaid)
    }

    /// Called before the sold copy leaves ownership, only after confirmation.
    public static func didSell(_ item: OwnedBookmark, run: inout RunState) {
        if let source = buybackSource(for: item, run: run) {
            run.bookmarkState.shop?.buybackUsed.insert(source.id)
        }
    }

    /// Navigation calls this only at committed Shop Continue, before clearing
    /// run.shop. Reopening an offer or restoring the same visit cannot pay.
    @discardableResult
    public static func shopLeaving(run: inout RunState) -> Int {
        guard let state = run.bookmarkState.shop, state.visitID == run.shop?.visitID,
              !state.exitAwarded else { return 0 }
        run.bookmarkState.shop?.exitAwarded = true
        guard state.purchases == 0 && state.rerolls == 0 else { return 0 }
        let amount = 3 * activeOwned(run: run).filter { $0.defID == Bookmarks.windowShopping }.count
        run.coins += amount
        return amount
    }

    public static func buffConsumed(_ buff: OwnedBuff, run: inout RunState, puzzle: PuzzleState? = nil) {
        // Shop prices are >=1, including discounted purchases. All free grants
        // carry pricePaid=0; old positive-price purchases remain valid evidence.
        guard buff.pricePaid > 0 else { return }
        for item in activeOwned(run: run, puzzle: puzzle) where item.defID == Bookmarks.recycledInsert {
            run.bookmarkState.copies[item.id, default: .init()].purchasedBuffReceipts += 1
        }
    }

    // MARK: Optional decisions

    public static func enqueueChoices(run: inout RunState) {
        if run.shop != nil { enqueueShopChoices(run: &run); return }
        guard let puzzle = run.puzzle, puzzle.phase == .playing,
              !puzzle.bookmarkState.legacyTurn, !puzzle.bookmarkState.turn.actionTaken else { return }
        for item in activeScoring(run: run, puzzle: puzzle) {
            let state = puzzle.bookmarkState.copies[item.id, default: .init()]
            let turn = puzzle.bookmarkState.turn.copies[item.id, default: .init()]
            let firstPuzzleAction = !puzzle.bookmarkState.puzzleActionTaken
            let kind: String
            var digits: [Digit] = []
            switch item.defID {
            case Bookmarks.duplicateDispatch where !state.duplicateUsed && !turn.duplicateChoiceResolved:
                kind = "bookmark.duplicate"
                digits = Digit.all.filter { digit in
                    let indices = puzzle.hand.indices.filter { puzzle.hand[$0] == digit }
                    return indices.count >= 3 && indices.allSatisfy {
                        !puzzle.isIndependentlyBlocked(handIndex: $0) || BuffRuntime.releaseAllows(handIndex: $0, puzzle: puzzle)
                    }
                }
            case Bookmarks.advancePayment where firstPuzzleAction && !state.advanceChoiceResolved && run.coins >= 3:
                kind = "bookmark.advance"
            case Bookmarks.typeCase where !turn.typeChoiceResolved:
                kind = "bookmark.type"
                digits = Array(Set(puzzle.hand)).sorted()
            case Bookmarks.personalColumn where firstPuzzleAction && !state.personalChoiceResolved:
                kind = "bookmark.personal"
                digits = Digit.all
            default: continue
            }
            if kind != "bookmark.advance" && digits.isEmpty { continue }
            guard !run.pendingItemDecisions.contains(where: {
                $0.sourceInstanceID == item.id && $0.kind == kind && $0.contextKey == run.itemContextKey
            }) else { continue }
            let options = kind == "bookmark.advance"
                ? [ItemChoiceOption(id: "pay", title: "Pay 3 coins", detail: "×2.5 Turn Mult this Puzzle")]
                : digits.map { ItemChoiceOption(id: String($0.rawValue), title: String($0.rawValue), digit: $0) }
            let id = run.nextItemIdentity(domain: kind)
            run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: item.defID,
                sourceInstanceID: item.id, contextKey: run.itemContextKey, kind: kind,
                title: item.def.name, detail: item.def.text, options: options))
        }
    }

    private static func enqueueShopChoices(run: inout RunState) {
        guard let state = run.bookmarkState.shop, state.visitID == run.shop?.visitID else { return }
        for item in activeOwned(run: run) where item.defID == Bookmarks.recycledInsert {
            guard state.recycledEligible.contains(item.id), !state.recycledClaimed.contains(item.id),
                  !state.recycledDismissed.contains(item.id),
                  run.bookmarkState.copies[item.id, default: .init()].purchasedBuffReceipts >= 3,
                  !run.pendingItemDecisions.contains(where: { $0.sourceInstanceID == item.id && $0.kind.hasPrefix("bookmark.recycled") }) else { continue }
            var choices = run.bookmarkState.shop?.recycledChoices[item.id] ?? []
            if choices.isEmpty {
                var pool = Buffs.all.filter { $0.rarity == .common }.map(\.id).sorted()
                while choices.count < 2 && !pool.isEmpty { choices.append(pool.remove(at: run.itemRandomInt(pool.count))) }
                run.bookmarkState.shop?.recycledChoices[item.id] = choices
            }
            guard !choices.isEmpty else { continue }
            let id = run.nextItemIdentity(domain: "bookmark.recycled")
            run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: item.defID,
                sourceInstanceID: item.id, contextKey: run.itemContextKey, kind: "bookmark.recycled",
                title: "Recycled Insert", detail: "Spend 3 purchased-Buff receipts. Choose one free Buff.",
                options: choices.compactMap { key in Catalog.item(key).map {
                    ItemChoiceOption(id: key, title: $0.name, detail: $0.text, itemID: key)
                } }))
        }
    }

    /// Queued offers close when actual play begins, rather than blocking play
    /// or reopening a declined decision after a later save/load.
    public static func invalidateActionChoices(run: inout RunState) {
        run.pendingItemDecisions.removeAll { ["bookmark.duplicate", "bookmark.advance", "bookmark.type", "bookmark.personal"].contains($0.kind) }
    }

    public static func reopenRecycledChoice(bookmarkID: UUID, run: inout RunState) {
        run.bookmarkState.shop?.recycledDismissed.remove(bookmarkID)
        enqueueShopChoices(run: &run)
    }

    /// Selling the capacity item requires an explicit second item decision.
    /// Both sales commit together; cancellation leaves both inventories intact.
    public static func requestCapacitySale(bookmarkID: UUID, run: inout RunState) throws {
        guard let item = run.bookmarks.first(where: { $0.id == bookmarkID && $0.defID == Bookmarks.pocketInsert }),
              !isSuspended(id: bookmarkID, puzzle: run.puzzle), run.buffs.count == 3,
              !canRemove(id: bookmarkID, run: run) else { throw BookmarkChoiceError.itemUnavailable }
        guard !run.pendingItemDecisions.contains(where: { $0.kind == "bookmark.capacitySale" && $0.sourceInstanceID == bookmarkID }) else { return }
        let id = run.nextItemIdentity(domain: "bookmark.capacitySale")
        run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: item.defID,
            sourceInstanceID: bookmarkID, contextKey: run.itemContextKey, kind: "bookmark.capacitySale",
            title: "Sell Pocket Insert", detail: "Choose one Buff to sell with it, or cancel to keep all three slots.",
            options: run.buffs.map { ItemChoiceOption(id: $0.id.uuidString, title: "Sell \($0.def.name)",
                detail: "+\(RunState.sellValue(pricePaid: $0.pricePaid)) coins", itemID: $0.defID) }))
    }

    @discardableResult
    public static func resolveDecision(id: UUID, selected: [String]?, run: inout RunState) throws -> Bool {
        guard let decision = run.pendingItemDecisions.first(where: { $0.id == id && $0.kind.hasPrefix("bookmark.") }),
              let instance = decision.sourceInstanceID,
              let item = run.bookmarks.first(where: { $0.id == instance }),
              decision.contextKey == run.itemContextKey else { throw BookmarkChoiceError.staleChoice }
        if let selected, !decision.accepts(selected) { throw BookmarkChoiceError.invalidDigit }
        var next = run
        if decision.kind == "bookmark.capacitySale" {
            if let selected, let buffID = selected.first.flatMap(UUID.init(uuidString:)) {
                guard item.defID == Bookmarks.pocketInsert, !isSuspended(id: instance, puzzle: run.puzzle),
                      next.buffs.count == 3, let buffIndex = next.buffs.firstIndex(where: { $0.id == buffID }),
                      let bookmarkIndex = next.bookmarks.firstIndex(where: { $0.id == instance }) else {
                    throw BookmarkChoiceError.staleChoice
                }
                _ = try Shop.sell(&next, kind: .buff, index: buffIndex)
                _ = try Shop.sell(&next, kind: .bookmark, index: bookmarkIndex)
            }
        } else if decision.kind.hasPrefix("bookmark.recycled") {
            try resolveRecycled(decision, item: item, selected: selected, run: &next)
        } else {
            guard var puzzle = next.puzzle, puzzle.phase == .playing,
                  !puzzle.bookmarkState.turn.actionTaken,
                  activeScoring(run: next, puzzle: puzzle).contains(where: { $0.id == instance }) else {
                throw BookmarkChoiceError.staleChoice
            }
            var state = puzzle.bookmarkState.copies[instance, default: .init()]
            var turn = puzzle.bookmarkState.turn.copies[instance, default: .init()]
            let option = selected?.first.flatMap { key in decision.options.first { $0.id == key } }
            switch decision.kind {
            case "bookmark.advance":
                guard !puzzle.bookmarkState.puzzleActionTaken, !state.advanceChoiceResolved else { throw BookmarkChoiceError.staleChoice }
                if selected != nil {
                    guard next.coins >= 3 else { throw BookmarkChoiceError.insufficientCoins }
                    next.coins -= 3; state.advancePaid = true
                }
                state.advanceChoiceResolved = true
            case "bookmark.personal":
                guard !puzzle.bookmarkState.puzzleActionTaken, !state.personalChoiceResolved else { throw BookmarkChoiceError.staleChoice }
                state.personalDigit = option?.digit; state.personalChoiceResolved = true
            case "bookmark.type":
                guard !turn.typeChoiceResolved else { throw BookmarkChoiceError.staleChoice }
                if let digit = option?.digit, !puzzle.hand.contains(digit) { throw BookmarkChoiceError.invalidDigit }
                turn.typeDigit = option?.digit; turn.typeChoiceResolved = true
            case "bookmark.duplicate":
                guard !state.duplicateUsed, !turn.duplicateChoiceResolved else { throw BookmarkChoiceError.staleChoice }
                if let digit = option?.digit {
                    let indices = puzzle.hand.indices.filter { puzzle.hand[$0] == digit }
                    guard indices.count >= 3, indices.allSatisfy({
                        !puzzle.isIndependentlyBlocked(handIndex: $0) || BuffRuntime.releaseAllows(handIndex: $0, puzzle: puzzle)
                    }) else { throw BookmarkChoiceError.invalidDigit }
                    var returned: Set<UUID> = []
                    for index in indices.dropFirst().reversed() {
                        let card = puzzle.removeHandCard(at: index)
                        returned.insert(card.id)
                        puzzle.pool.put(card.digit)
                    }
                    BuffRuntime.invalidateCards(returned, puzzle: &puzzle)
                    MarkerRuntime.interrupt(.exchange, puzzle: &puzzle)
                    let drawn = puzzle.pool.draw(&next.streams.pool, count: indices.count - 1)
                    puzzle.appendHandDigits(drawn)
                    if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &puzzle) }
                    state.duplicateUsed = true
                    // An accepted exchange is the Turn's first action. Other
                    // unaccepted setup choices cannot inspect its new draw.
                    actionAccepted(puzzle: &puzzle)
                    invalidateActionChoices(run: &next)
                }
                turn.duplicateChoiceResolved = true
            default: throw BookmarkChoiceError.staleChoice
            }
            puzzle.bookmarkState.copies[instance] = state
            puzzle.bookmarkState.turn.copies[instance] = turn
            next.puzzle = puzzle
        }
        next.pendingItemDecisions.removeAll { $0.id == id }
        run = next
        return selected != nil
    }

    private static func resolveRecycled(_ decision: ItemDecision, item: OwnedBookmark,
                                        selected: [String]?, run: inout RunState) throws {
        guard let shop = run.bookmarkState.shop, shop.visitID == run.shop?.visitID,
              shop.recycledEligible.contains(item.id), !shop.recycledClaimed.contains(item.id),
              run.bookmarkState.copies[item.id, default: .init()].purchasedBuffReceipts >= 3,
              !isSuspended(id: item.id, puzzle: run.puzzle) else { throw BookmarkChoiceError.staleChoice }
        guard let selected, let selectedID = selected.first else {
            run.bookmarkState.shop?.recycledDismissed.insert(item.id)
            return
        }
        let buffID: String
        var replacement: UUID?
        if decision.kind == "bookmark.recycled" {
            buffID = selectedID
            if run.buffs.count >= capacity(run: run) {
                let id = run.nextItemIdentity(domain: "bookmark.recycledReplacement")
                run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: item.defID,
                    sourceInstanceID: item.id, contextKey: run.itemContextKey, kind: "bookmark.recycledReplacement",
                    title: "Make room for \(Catalog.item(buffID)!.name)",
                    detail: "Choose a Buff to replace, or cancel to keep everything.",
                    options: run.buffs.map { ItemChoiceOption(id: $0.id.uuidString,
                        title: $0.def.name, detail: $0.def.text, itemID: $0.defID) }, payload: ["buffID": buffID]))
                return
            }
        } else {
            guard let offered = decision.payload["buffID"], let id = UUID(uuidString: selectedID),
                  run.buffs.count == capacity(run: run), run.buffs.contains(where: { $0.id == id }) else {
                throw BookmarkChoiceError.invalidReplacement
            }
            buffID = offered; replacement = id
        }
        guard shop.recycledChoices[item.id]?.contains(buffID) == true else { throw BookmarkChoiceError.staleChoice }
        if let replacement { run.buffs.removeAll { $0.id == replacement } }
        guard run.buffs.count < capacity(run: run) else { throw BookmarkChoiceError.inventoryFull }
        let id = run.nextItemIdentity(domain: "bookmark.recycledReward")
        run.buffs.append(OwnedBuff(defID: buffID, pricePaid: 0, id: id))
        run.bookmarkState.copies[item.id, default: .init()].purchasedBuffReceipts -= 3
        run.bookmarkState.shop?.recycledClaimed.insert(item.id)
    }
}
