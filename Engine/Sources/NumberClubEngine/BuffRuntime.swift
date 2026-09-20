import Foundation

/// All Buff transactions validate against a value snapshot and publish once.
/// The app presents ItemDecision values; it never computes legality or rewards.
public enum BuffRuntime {
    public static let copyable: Set<String> = [Buffs.peek, Buffs.redraw, Buffs.doubleDown,
        Buffs.insurance, Buffs.secondPrint, Buffs.luckyDip]
    static let keepFilling: Set<String> = [Buffs.peek, Buffs.redraw, Buffs.overtime, Buffs.luckyDip, Buffs.birdSeed]
    static let oncePerPuzzle: Set<String> = [Buffs.tightDeadline, Buffs.collateral, Buffs.exchangeRate,
        Buffs.cleanFinish, Buffs.openBracket, Buffs.carbonReceipt, Buffs.rainCheck]

    public static func context(_ run: RunState) -> String {
        run.itemContextKey + ":stock\(run.buffState.stockRevision)"
    }

    static func phaseAllows(_ definition: String, run: RunState, generatedEffect: Bool = false) -> Bool {
        guard run.outcome == nil else { return false }
        guard generatedEffect || !BossBuffRules.isEmbargoed(definition, puzzle: run.puzzle) else { return false }
        if BuffShop.definitions.contains(definition) { return run.shop != nil }
        if BuffRoutes.definitions.contains(definition) { return BuffRoutes.canUse(definition, run: run) }
        guard run.shop == nil, let puzzle = run.puzzle, puzzle.boss?.disablesBuffs != true else { return false }
        if [Buffs.rebind, Buffs.transposition].contains(definition), puzzle.boss?.hidesMarkedSquares == true { return false }
        return puzzle.phase == .playing || (puzzle.phase == .keepFilling && keepFilling.contains(definition))
    }

    public static func options(for definition: String, run: RunState, consuming sourceID: UUID? = nil) -> [BuffOption] {
        options(for: definition, run: run, consuming: sourceID, generatedEffect: false)
    }

    /// Embargo limits the owned preparation Buff, not Encore's generated
    /// inner effect. Every other phase, resource and target check still applies.
    private static func options(for definition: String, run: RunState, consuming sourceID: UUID? = nil,
                                generatedEffect: Bool) -> [BuffOption] {
        guard phaseAllows(definition, run: run, generatedEffect: generatedEffect) else { return [] }
        if BuffShop.definitions.contains(definition) { return BuffShop.options(definition, run: run, consuming: sourceID) }
        if BuffRoutes.definitions.contains(definition) {
            if definition == Buffs.supplement {
                return [ItemKind.bookmark, .marker, .buff].map { BuffOption($0.rawValue, $0.rawValue.capitalized, .category($0)) }
            }
            return [BuffOption("reveal", "Reveal the two choices", .none)]
        }
        guard let p = run.puzzle else { return [] }
        if oncePerPuzzle.contains(definition), p.buffState.usedOnce.contains(definition) { return [] }
        let action = [BuffOption("use", "Use \(Catalog.item(definition)?.name ?? "Buff")", .none)]
        let cards = p.handCards
        let tossable = cards.enumerated().filter { isTossable(handIndex: $0.offset, puzzle: p) }
        let blanks = p.board.blanks.filter { !p.isBarred($0) }
        switch definition {
        case Buffs.peek: return p.boss?.disablesClues == true ? [] : action
        case Buffs.redraw: return p.hand.isEmpty && p.pool.isEmpty ? [] : action
        case Buffs.overtime: return p.boss == .lastEdition ? [] : action
        case Buffs.doubleDown: return p.armedFlags.contains(.doubleDown) ? [] : action
        case Buffs.insurance: return p.armedFlags.contains(.insurance) ? [] : action
        case Buffs.secondPrint: return p.armedFlags.contains(.secondPrint) ? [] : action
        case Buffs.luckyDip: return p.pool.isEmpty ? [] : action
        case Buffs.birdSeed: return run.runItemState[Buffs.birdSeed] == Double(p.level) ? [] : action
        case Buffs.freshInk: return action
        case Buffs.litmus:
            guard p.boss?.disablesClues != true, !p.armedFlags.contains(.litmus) else { return [] }
            return Digit.all.map { BuffOption("digit.\($0.rawValue)", "\($0.rawValue)", .digit($0)) }
        case Buffs.paperCrane:
            return Digit.all.map { BuffOption("digit.\($0.rawValue)", "\($0.rawValue)", .digit($0)) }
        case Buffs.indexRequest:
            return Digit.all.filter { p.pool[$0] > 0 }.map { BuffOption("digit.\($0.rawValue)", "\($0.rawValue)", .digit($0)) }
        case Buffs.carefulCut:
            return tossable.map { BuffOption($0.element.id.uuidString, "Return \($0.element.digit.rawValue)", .cards([$0.element.id])) }
        case Buffs.eraserShavings:
            return (p.tossChargesSpent ?? p.tossedThisPuzzle) > 0 ? action : []
        case Buffs.collation:
            return p.pool.isEmpty || !p.pool.scheduledDraws.isEmpty || run.buffState.collationChoice != nil ? [] : action
        case Buffs.fairExchange:
            return tossable.filter { card in Digit.all.contains { $0 != card.element.digit && p.pool[$0] > 0 } }
                .map { BuffOption($0.element.id.uuidString, "Return \($0.element.digit.rawValue)", .cards([$0.element.id])) }
        case Buffs.inventoryCount: return p.buffState.inventoryCountTurn == p.turnNumber ? [] : action
        case Buffs.proofSheet:
            guard p.buffState.proof?.turn != p.turnNumber else { return [] }
            return [Unit.row, .col, .box].flatMap { unit in
                (0..<9).compactMap { index in
                    let cells = cells(unit, index)
                    guard cells.contains(where: { p.board.isBlank($0) }) else { return nil }
                    return BuffOption("\(unit.rawValue).\(index)", "\(unit.rawValue == "col" ? "Column" : unit.rawValue.capitalized) \(index + 1)", .unit(unit, index))
                }
            }
        case Buffs.foldTest:
            guard p.boss?.disablesClues != true else { return [] }
            return blanks.filter { p.buffState.parity[$0] == nil }.map { BuffOption("square.\($0.index)", $0.description, .squares([$0])) }
        case Buffs.rebind, Buffs.transposition:
            return MarkerRuntime.relocatableClaims(run: run).filter { claim in
                if definition == Buffs.rebind {
                    return blanks.contains { MarkerRuntime.canRelocateClaim(id: claim.id, to: $0, run: run) }
                }
                return MarkerRuntime.relocatableClaims(run: run).contains {
                    MarkerRuntime.canSwapClaims(first: claim.id, second: $0.id, run: run)
                }
            }.map { BuffOption($0.id, "\(Catalog.item($0.markerID)?.name ?? $0.markerID) · \($0.square)", .claims($0.id, $0.id)) }
        case Buffs.passage:
            guard p.buffState.passageSquare == nil else { return [] }
            return p.board.blanks.filter { bossBars($0, puzzle: p) && p.markerState.turn.blotterSquare != $0 }
                .map { BuffOption("square.\($0.index)", $0.description, .squares([$0])) }
        case Buffs.releaseNote:
            guard p.buffState.releasedCard == nil else { return [] }
            return cards.enumerated().filter { p.isBlocked(handIndex: $0.offset) }
                .map { BuffOption($0.element.id.uuidString, "Release \($0.element.digit.rawValue)", .cards([$0.element.id])) }
        case Buffs.tightDeadline: return p.turnNumber < p.turnsMax ? action : []
        case Buffs.collateral:
            guard !p.scoringOrderLocked, p.pendingBase == 0, p.turnScoringOperations.isEmpty else { return [] }
            let afterCost = prospectiveConsumption(sourceID: sourceID, definition: definition, run: run)
            return run.bookmarks.enumerated().filter { index, owned in
                index != p.disabledBookmark && !p.bookmarkState.suspended.contains(owned.id)
                    && BookmarkMechanics.canRemove(id: owned.id, run: afterCost)
            }.map { BuffOption($0.element.id.uuidString, $0.element.def.name, .bookmark($0.element.id)) }
        case Buffs.exchangeRate:
            return (1...3).filter { $0 <= run.coins }.map { BuffOption("amount.\($0)", "Pay \($0) · +\($0) Mult this Turn", .amount($0)) }
        case Buffs.returnReceipt:
            return p.buffState.spent.filter { isRecoverable($0, puzzle: p) }
                .map { BuffOption($0.owned.id.uuidString, $0.owned.def.name, .recovered($0.owned.id)) }
        case Buffs.cleanFinish: return cards.count >= 3 && p.buffState.cleanFinish == nil ? action : []
        case Buffs.crossCut: return p.buffState.crossCut == nil ? action : []
        case Buffs.openBracket:
            guard Set(blanks.map(\.box)).count >= 2 else { return [] }
            return blanks.map { BuffOption("square.\($0.index)", $0.description, .squares([$0])) }
        case Buffs.carbonReceipt:
            guard let copied = p.buffState.lastEligibleUse, copyable.contains(copied),
                  !options(for: copied, run: run, generatedEffect: true).isEmpty else { return [] }
            return [BuffOption("use", "Repeat \(Catalog.item(copied)!.name)", .none)]
        case Buffs.rainCheck:
            guard p.turnNumber < p.turnsMax else { return [] }
            let maximum = min(100, availableRainCheckPoints(p))
            guard maximum >= 20 else { return [] }
            return (20...maximum).map { BuffOption("amount.\($0)", "Defer \($0) Points · return \($0 * 2)", .amount($0)) }
        default: return []
        }
    }

    public static func canUse(buffID: UUID, run: RunState) -> Bool {
        guard run.pendingItemDecisions.isEmpty,
              let buff = run.buffs.first(where: { $0.id == buffID }) else { return false }
        return !options(for: buff.defID, run: run, consuming: buffID).isEmpty
    }

    /// Capacity is checked after this exact held copy will be consumed. The
    /// preview does not run hooks or publish an intermediate inventory.
    static func prospectiveConsumption(sourceID: UUID?, definition: String, run: RunState) -> RunState {
        var prospective = run
        if let source = run.buffs.first(where: {
            $0.defID == definition && (sourceID == nil || $0.id == sourceID)
        }) { prospective.buffs.removeAll { $0.id == source.id } }
        return prospective
    }

    /// An older save can contain an already-paid Litmus arm without a locked
    /// digit. Preserve the purchase by asking once; never grant a replacement
    /// item or restore the old unlimited digit-switching reveal.
    public static func prepareLegacyLitmus(_ run: inout RunState) {
        guard let p = run.puzzle, p.phase == .playing, p.armedFlags.contains(.litmus),
              p.buffState.litmusDigit == nil,
              !run.pendingItemDecisions.contains(where: { $0.kind == "buff.litmus-legacy" }) else { return }
        let id = run.nextItemIdentity(domain: "buff.legacy-litmus")
        run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: Buffs.litmus,
            contextKey: context(run), kind: "buff.litmus-legacy", title: "Litmus: choose one number",
            detail: "Your saved Litmus is already paid for. This number stays fixed until your next placement.",
            options: Digit.all.map { ItemChoiceOption(id: String($0.rawValue), title: String($0.rawValue), digit: $0) },
            allowsCancel: false, consumedOnReveal: true))
    }

    /// Opens target selection, or commits a target-free effect. Information
    /// purchases (Collation/Detour/Boss Draft) consume on revealing their choice.
    @discardableResult
    public static func begin(buffID: UUID, run: inout RunState) throws -> BuffUseOutcome {
        var next = run
        guard next.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        guard let source = next.buffs.first(where: { $0.id == buffID }) else { throw BuffUseError.missingCopy }
        let available = options(for: source.defID, run: next, consuming: source.id)
        guard !available.isEmpty else { throw BuffUseError.noLegalTarget }
        if source.defID == Buffs.detour || source.defID == Buffs.bossDraft {
            try BuffRoutes.reveal(source.defID, source: source, run: &next)
            consume(source, effect: source.defID, run: &next)
            var outcome = BuffUseOutcome(); outcome.consumedID = source.id; outcome.requiresDecision = true
            run = next; return outcome
        }
        if source.defID == Buffs.collation {
            try revealCollation(source, run: &next)
            consume(source, effect: source.defID, run: &next)
            var outcome = BuffUseOutcome(); outcome.consumedID = source.id; outcome.requiresDecision = true
            run = next; return outcome
        }
        if available.count == 1, available[0].choice == .none {
            let result = try perform(BuffUseRequest(buffID: buffID, context: context(next)), run: &next)
            run = next; return result
        }
        var decision = makeDecision(source: source, options: available, run: &next)
        if source.defID == Buffs.carefulCut { decision.maximum = min(3, available.count) }
        if source.defID == Buffs.openBracket { decision.minimum = 2; decision.maximum = 2 }
        next.pendingItemDecisions.append(decision)
        run = next
        var outcome = BuffUseOutcome(); outcome.requiresDecision = true; return outcome
    }

    @discardableResult
    public static func use(_ request: BuffUseRequest, run: inout RunState) throws -> BuffUseOutcome {
        guard run.pendingItemDecisions.isEmpty else { throw BuffUseError.pendingChoice }
        var next = run
        let outcome = try perform(request, run: &next)
        run = next
        return outcome
    }

    @discardableResult
    public static func commit(decisionID: UUID, selected: [String], run: inout RunState) throws -> BuffUseOutcome {
        var next = run
        guard let decision = next.pendingItemDecisions.first, decision.id == decisionID,
              decision.kind.hasPrefix("buff."), decision.contextKey == context(next) else {
            throw BuffUseError.staleContext
        }
        guard decision.accepts(selected) else { throw BuffUseError.invalidChoice }
        var outcome = BuffUseOutcome()
        if decision.kind == "buff.litmus-legacy" {
            guard var p = next.puzzle, p.armedFlags.contains(.litmus), p.buffState.litmusDigit == nil,
                  let number = Int(selected[0]), let digit = Digit(number) else { throw BuffUseError.staleContext }
            p.buffState.litmusDigit = digit
            MarkerRuntime.interrupt(.solutionAssistance, puzzle: &p)
            BookmarkMechanics.actionAccepted(puzzle: &p)
            next.puzzle = p
        } else if decision.kind == "buff.route" {
            try BuffRoutes.commit(decision, selected: selected[0], run: &next)
        } else if decision.kind == "buff.collation" {
            guard let choice = next.buffState.collationChoice, choice.source == decision.sourceInstanceID,
                  var p = next.puzzle else { throw BuffUseError.staleContext }
            let indices = selected.compactMap(Int.init)
            guard Set(indices) == Set(choice.sample.indices), indices.count == choice.sample.count,
                  p.pool.scheduleDraws(indices.map { choice.sample[$0] }) else { throw BuffUseError.invalidChoice }
            next.puzzle = p
            next.buffState.collationChoice = nil
        } else {
            guard let sourceID = decision.sourceInstanceID,
                  let source = next.buffs.first(where: { $0.id == sourceID }) else { throw BuffUseError.missingCopy }
            let choices = try selected.map { try decodeChoice(decision.payload[$0]) }
            if decision.kind == "buff.select", [Buffs.fairExchange, Buffs.rebind, Buffs.transposition].contains(source.defID) {
                let second = try followup(source: source, choice: choices[0], run: &next)
                next.pendingItemDecisions[0] = second
                run = next; outcome.requiresDecision = true; return outcome
            }
            let choice: BuffChoice
            if source.defID == Buffs.carefulCut {
                choice = .cards(choices.flatMap { if case .cards(let ids) = $0 { return ids }; return [] })
            } else if source.defID == Buffs.openBracket {
                choice = .squares(choices.flatMap { if case .squares(let squares) = $0 { return squares }; return [] })
            } else { choice = choices[0] }
            outcome = try perform(BuffUseRequest(buffID: sourceID, context: decision.contextKey, choice: choice), run: &next)
        }
        next.pendingItemDecisions.removeFirst()
        run = next
        return outcome
    }

    @discardableResult
    public static func cancel(decisionID: UUID, run: inout RunState) -> Bool {
        guard let decision = run.pendingItemDecisions.first, decision.id == decisionID,
              decision.kind.hasPrefix("buff."), decision.allowsCancel, !decision.consumedOnReveal else { return false }
        run.pendingItemDecisions.removeFirst()
        return true
    }

    static func makeDecision(source: OwnedBuff, options: [BuffOption], run: inout RunState,
                             kind: String = "buff.select") -> ItemDecision {
        let id = run.nextItemIdentity(domain: "buff.choice")
        return ItemDecision(id: id, sourceID: source.defID, sourceInstanceID: source.id,
            contextKey: context(run), kind: kind, title: source.def.name,
            detail: source.def.text + (BossBuffRules.explanation(definition: source.defID, puzzle: run.puzzle).map { "\n\n" + $0 } ?? ""),
            options: options.map { option in
                var item = ItemChoiceOption(id: option.id, title: option.label)
                switch option.choice {
                case .digit(let digit): item.digit = digit
                case .cards(let ids):
                    item.cardID = ids.first
                    item.digit = run.puzzle?.handCards.first(where: { $0.id == ids.first })?.digit
                case .squares(let squares): item.square = squares.first
                case .exchange(let id, let digit): item.cardID = id; item.digit = digit
                case .claim(_, let destination): item.square = destination
                case .claims(let first, let second):
                    let id = first == second ? first : second
                    let claim = MarkerRuntime.relocatableClaims(run: run).first { $0.id == id }
                    item.square = claim?.square; item.itemID = claim?.markerID
                case .bookmark(let id): item.itemID = run.bookmarks.first { $0.id == id }?.defID
                case .offer(let slot): item.itemID = run.shop?.offers.first { $0.slot == slot }?.defID
                case .recovered(let id): item.itemID = run.puzzle?.buffState.spent.first { $0.owned.id == id }?.owned.defID
                default: break
                }
                return item
            }, payload: Dictionary(uniqueKeysWithValues: options.map { ($0.id, encodeChoice($0.choice)) }))
    }

    static func encodeChoice(_ choice: BuffChoice) -> String {
        // Every case consists solely of Codable values; encoding cannot fail.
        String(data: try! JSONEncoder().encode(choice), encoding: .utf8)!
    }
    static func decodeChoice(_ value: String?) throws -> BuffChoice {
        guard let value, let bytes = value.data(using: .utf8), let choice = try? JSONDecoder().decode(BuffChoice.self, from: bytes) else {
            throw BuffUseError.invalidChoice
        }
        return choice
    }

    static func followup(source: OwnedBuff, choice: BuffChoice, run: inout RunState) throws -> ItemDecision {
        guard let p = run.puzzle else { throw BuffUseError.unavailable }
        let options: [BuffOption]
        switch (source.defID, choice) {
        case (Buffs.fairExchange, .cards(let cards)):
            guard cards.count == 1, let index = p.handCards.firstIndex(where: { $0.id == cards[0] }),
                  isTossable(handIndex: index, puzzle: p) else { throw BuffUseError.invalidChoice }
            options = Digit.all.filter { $0 != p.hand[index] && p.pool[$0] > 0 }.map {
                BuffOption("digit.\($0.rawValue)", "Take \($0.rawValue)", .exchange(card: cards[0], digit: $0))
            }
        case (Buffs.rebind, .claims(let id, _)):
            options = p.board.blanks.filter { MarkerRuntime.canRelocateClaim(id: id, to: $0, run: run) }.map {
                BuffOption("square.\($0.index)", $0.description, .claim(id, destination: $0))
            }
        case (Buffs.transposition, .claims(let id, _)):
            options = MarkerRuntime.relocatableClaims(run: run).filter {
                MarkerRuntime.canSwapClaims(first: id, second: $0.id, run: run)
            }.map { BuffOption($0.id, "\(Catalog.item($0.markerID)?.name ?? $0.markerID) · \($0.square)", .claims(id, $0.id)) }
        default: throw BuffUseError.invalidChoice
        }
        guard !options.isEmpty else { throw BuffUseError.noLegalTarget }
        return makeDecision(source: source, options: options, run: &run, kind: "buff.commit")
    }

    static func revealCollation(_ source: OwnedBuff, run: inout RunState) throws {
        guard let p = run.puzzle, !p.pool.isEmpty, p.pool.scheduledDraws.isEmpty else { throw BuffUseError.noLegalTarget }
        var sampling = p.pool
        let sample = sampling.draw(&run.streams.pool, count: 3)
        run.buffState.collationChoice = BuffCollationChoice(source: source.id, context: context(run), sample: sample)
        let id = run.nextItemIdentity(domain: "buff.collation")
        run.pendingItemDecisions.append(ItemDecision(id: id, sourceID: source.defID,
            sourceInstanceID: source.id, contextKey: context(run), kind: "buff.collation",
            title: "Choose the draw order", detail: "These numbers stay in the Pool until drawn.",
            options: sample.enumerated().map { ItemChoiceOption(id: String($0.offset), title: String($0.element.rawValue), digit: $0.element) },
            minimum: sample.count, maximum: sample.count, ordered: true, allowsCancel: false, consumedOnReveal: true))
    }

    static func consume(_ source: OwnedBuff, effect: String, generated: Bool = false, run: inout RunState) {
        run.buffs.removeAll { $0.id == source.id }
        guard var p = run.puzzle else {
            BookmarkMechanics.buffConsumed(source, run: &run)
            return
        }
        p.buffState.spent.append(SpentBuff(owned: source, effectID: effect, generated: generated))
        BossScoring.pinBookmarkOrder(run: run, puzzle: &p)
        // Carbon Receipt's generated effect is one outer owned consumption.
        // It is deliberately counted once here, outside effect recursion.
        BossBuffRules.consumptionCommitted(puzzle: &p)
        BookmarkMechanics.actionAccepted(puzzle: &p)
        if copyable.contains(source.defID), !generated { p.buffState.lastEligibleUse = source.defID }
        if flag(effect) != nil { p.buffState.armedSources[effect] = source.id }
        run.puzzle = p
        BookmarkMechanics.buffConsumed(source, run: &run, puzzle: p)
    }

    static func flag(_ definition: String) -> OneShotFlag? {
        switch definition {
        case Buffs.doubleDown: return .doubleDown
        case Buffs.insurance: return .insurance
        case Buffs.secondPrint: return .secondPrint
        case Buffs.litmus: return .litmus
        default: return nil
        }
    }

    static func isRecoverable(_ source: SpentBuff, puzzle: PuzzleState) -> Bool {
        guard [Buffs.insurance, Buffs.doubleDown, Buffs.secondPrint].contains(source.effectID),
              !source.generated, !source.triggered, !source.recovered,
              source.owned.defID == source.effectID, let armed = flag(source.effectID) else { return false }
        return puzzle.armedFlags.contains(armed) && puzzle.buffState.armedSources[source.effectID] == source.owned.id
    }

    static func cells(_ unit: Unit, _ index: Int) -> [Square] {
        guard (0..<9).contains(index) else { return [] }
        switch unit { case .row: return Geometry.rows[index]; case .col: return Geometry.cols[index]; case .box: return Geometry.boxes[index] }
    }

    static func perform(_ request: BuffUseRequest, run: inout RunState) throws -> BuffUseOutcome {
        guard request.context == context(run) else { throw BuffUseError.staleContext }
        guard let source = run.buffs.first(where: { $0.id == request.buffID }) else { throw BuffUseError.missingCopy }
        let definition = source.defID
        guard phaseAllows(definition, run: run) else { throw BuffUseError.unavailable }
        if oncePerPuzzle.contains(definition), run.puzzle?.buffState.usedOnce.contains(definition) == true {
            throw BuffUseError.unavailable
        }
        var outcome = BuffUseOutcome()
        if BuffShop.definitions.contains(definition) {
            if try BuffShop.apply(definition, source: source, choice: request.choice, run: &run) {
                consume(source, effect: definition, run: &run); outcome.consumedID = source.id
            }
            return outcome
        }
        if definition == Buffs.supplement {
            guard case .category(let category) = request.choice,
                  [.bookmark, .marker, .buff].contains(category), BuffRoutes.canUse(definition, run: run) else {
                throw BuffUseError.invalidChoice
            }
            run.buffState.supplement = category
            consume(source, effect: definition, run: &run); outcome.consumedID = source.id
            return outcome
        }
        if definition == Buffs.detour || definition == Buffs.bossDraft || definition == Buffs.collation {
            throw BuffUseError.invalidChoice // These require the consume-on-reveal begin path.
        }
        guard var p = run.puzzle else { throw BuffUseError.unavailable }
        p.ensureHandIdentities(seed: run.seed)
        run.puzzle = p
        let beforeHand = p.handCards
        var effect = definition
        let generated = definition == Buffs.carbonReceipt
        if generated {
            guard case .none = request.choice, let copied = p.buffState.lastEligibleUse,
                  copyable.contains(copied), !options(for: copied, run: run, generatedEffect: true).isEmpty else {
                throw BuffUseError.noLegalTarget
            }
            effect = copied
        }
        if let def = Catalog.item(effect), let onUse = def.onUse {
            let available = options(for: effect, run: run, generatedEffect: generated)
            guard available.contains(where: { $0.choice == request.choice }) else { throw BuffUseError.invalidChoice }
            let digit: Digit?
            if case .digit(let choice) = request.choice { digit = choice } else { digit = nil }
            var result = EffectResult()
            onUse(Resolver.context(.shopEnter, run: run, puzzle: p, digit: digit), &result)
            guard result.armFlags.isDisjoint(with: p.armedFlags) else { throw BuffUseError.unavailable }
            run.absorb(result)
            p.absorb(result)
            let key = effect == Buffs.paperCrane ? Buffs.paperCraneKey(digit!) : effect
            p.scoringBuffSources[key, default: []].append(source.id)
            if effect == Buffs.birdSeed { run.activeBuffSources[effect] = source.id }
            if effect == Buffs.litmus { p.buffState.litmusDigit = digit }
            if result.redrawHand {
                invalidateCards(Set(p.handCards.map(\.id)), puzzle: &p)
                MarkerRuntime.interrupt(.exchange, puzzle: &p)
                let returned = p.removeAllHandCards()
                for card in returned { p.pool.put(card.digit) }
                let drawn = p.pool.draw(&run.streams.pool, count: p.drawableHandSize)
                p.appendHandDigits(drawn)
                if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &p) }
            }
            if result.draws > 0 {
                if !BossRuntime.deferAutomaticDraw(count: result.draws, sourceID: effect,
                    sourceInstanceID: source.id, puzzle: &p) {
                    let drawn = p.pool.draw(&run.streams.pool, count: result.draws)
                    p.appendHandDigits(drawn)
                    if !drawn.isEmpty { MarkerRuntime.ordinaryDrawOccurred(puzzle: &p) }
                }
            }
            if effect == Buffs.litmus { MarkerRuntime.interrupt(.solutionAssistance, puzzle: &p) }
        } else {
            switch (definition, request.choice) {
            case (Buffs.indexRequest, .digit(let digit)):
                guard p.pool.take(digit) else { throw BuffUseError.noLegalTarget }
                p.appendHandDigits([digit])
            case (Buffs.carefulCut, .cards(let cards)):
                guard (1...3).contains(cards.count), Set(cards).count == cards.count else { throw BuffUseError.invalidChoice }
                let indices = cards.compactMap { id in p.handCards.firstIndex { $0.id == id } }
                guard indices.count == cards.count, indices.allSatisfy({ isTossable(handIndex: $0, puzzle: p) }) else {
                    throw BuffUseError.noLegalTarget
                }
                invalidateCards(Set(cards), puzzle: &p)
                MarkerRuntime.interrupt(.toss, puzzle: &p)
                for index in indices.sorted(by: >) {
                    let returned = p.removeHandCard(at: index)
                    p.pool.put(returned.digit)
                }
                outcome.shouldEndTurn = p.hand.isEmpty
            case (Buffs.eraserShavings, .none):
                guard (p.tossChargesSpent ?? p.tossedThisPuzzle) > 0 else { throw BuffUseError.noLegalTarget }
                p.restoreTossCharges(2)
            case (Buffs.fairExchange, .exchange(let id, let digit)):
                guard let index = p.handCards.firstIndex(where: { $0.id == id }),
                      isTossable(handIndex: index, puzzle: p), p.hand[index] != digit,
                      p.pool[digit] > 0 else { throw BuffUseError.noLegalTarget }
                // Take first: the requested digit must predate the return.
                guard p.pool.take(digit) else { throw BuffUseError.noLegalTarget }
                invalidateCards([id], puzzle: &p)
                MarkerRuntime.interrupt(.exchange, puzzle: &p)
                let returned = p.removeHandCard(at: index)
                p.pool.put(returned.digit)
                p.appendHandDigits([digit])
            case (Buffs.inventoryCount, .none):
                guard p.buffState.inventoryCountTurn != p.turnNumber else { throw BuffUseError.unavailable }
                p.buffState.inventoryCountTurn = p.turnNumber
            case (Buffs.proofSheet, .unit(let unit, let index)):
                guard p.buffState.proof?.turn != p.turnNumber, (0..<9).contains(index),
                      cells(unit, index).contains(where: { p.board.isBlank($0) }) else { throw BuffUseError.invalidChoice }
                p.buffState.proof = BuffProofUnit(unit: unit, index: index, turn: p.turnNumber)
            case (Buffs.foldTest, .squares(let squares)):
                guard squares.count == 1, let square = squares.first, p.board.isBlank(square),
                      !p.isBarred(square), p.buffState.parity[square] == nil,
                      p.boss?.disablesClues != true else { throw BuffUseError.noLegalTarget }
                p.buffState.parity[square] = p.board.correctDigit(at: square).rawValue.isMultiple(of: 2)
                MarkerRuntime.interrupt(.solutionAssistance, puzzle: &p)
            case (Buffs.rebind, .claim(let id, let destination)):
                run.puzzle = p
                guard MarkerRuntime.relocateClaim(id: id, to: destination, run: &run) else { throw BuffUseError.noLegalTarget }
                p = run.puzzle!
            case (Buffs.transposition, .claims(let first, let second)):
                run.puzzle = p
                guard MarkerRuntime.swapClaims(first: first, second: second, run: &run) else { throw BuffUseError.noLegalTarget }
                p = run.puzzle!
            case (Buffs.passage, .squares(let squares)):
                guard squares.count == 1, let square = squares.first, p.board.isBlank(square),
                      bossBars(square, puzzle: p), p.markerState.turn.blotterSquare != square,
                      p.buffState.passageSquare == nil else { throw BuffUseError.noLegalTarget }
                p.buffState.passageSquare = square; p.buffState.passageTurn = p.turnNumber
            case (Buffs.releaseNote, .cards(let cards)):
                guard cards.count == 1, let id = cards.first, let index = p.handCards.firstIndex(where: { $0.id == id }),
                      p.isBlocked(handIndex: index), p.buffState.releasedCard == nil else { throw BuffUseError.noLegalTarget }
                p.buffState.releasedCard = id; p.buffState.releaseTurn = p.turnNumber
            case (Buffs.tightDeadline, .none):
                guard p.turnNumber < p.turnsMax else { throw BuffUseError.noLegalTarget }
                p.turnsMax -= 1
                p.buffState.turnMult.append(BuffTurnMult(source: source.id, definition: definition, amount: 3, turn: p.turnNumber))
            case (Buffs.collateral, .bookmark(let id)):
                guard options(for: definition, run: run, consuming: source.id).contains(where: { $0.choice == request.choice }) else {
                    throw BuffUseError.noLegalTarget
                }
                p.bookmarkState.suspended.insert(id)
                p.buffState.handSizeBonus = 2
                run.puzzle = p
                // The root standing-modifier hook excludes the pledged
                // passive and includes this persisted refill-target bonus.
                p.handSize = run.effectiveHandSize(boss: p.boss)
            case (Buffs.exchangeRate, .amount(let amount)):
                guard (1...3).contains(amount), run.coins >= amount else { throw BuffUseError.insufficientCoins }
                run.coins -= amount
                p.buffState.turnMult.append(BuffTurnMult(source: source.id, definition: definition,
                    amount: Double(amount), turn: p.turnNumber))
            case (Buffs.returnReceipt, .recovered(let id)):
                guard let index = p.buffState.spent.firstIndex(where: { $0.owned.id == id && isRecoverable($0, puzzle: p) }),
                      !run.buffs.contains(where: { $0.id == id }) else { throw BuffUseError.noLegalTarget }
                let recovered = p.buffState.spent[index]
                p.buffState.spent[index].recovered = true
                if let flag = flag(recovered.effectID) { p.armedFlags.remove(flag) }
                p.buffState.armedSources[recovered.effectID] = nil
                p.scoringBuffSources[recovered.effectID]?.removeAll { $0 == id }
                run.buffs.append(recovered.owned)
            case (Buffs.cleanFinish, .none):
                guard p.handCards.count >= 3, p.buffState.cleanFinish == nil else { throw BuffUseError.noLegalTarget }
                p.buffState.cleanFinish = BuffChallenge(source: source.id, cards: Set(p.handCards.map(\.id)), turn: p.turnNumber)
            case (Buffs.crossCut, .none):
                guard p.buffState.crossCut == nil else { throw BuffUseError.unavailable }
                p.buffState.crossCut = source.id
            case (Buffs.openBracket, .squares(let squares)):
                guard squares.count == 2, Set(squares).count == 2, squares[0].box != squares[1].box,
                      squares.allSatisfy({ p.board.isBlank($0) && !p.isBarred($0) }) else { throw BuffUseError.invalidChoice }
                p.buffState.bracket = BuffBracket(source: source.id, squares: squares)
            case (Buffs.rainCheck, .amount(let amount)):
                guard (20...100).contains(amount), p.turnNumber < p.turnsMax,
                      availableRainCheckPoints(p) >= amount, p.pendingBase >= amount else { throw BuffUseError.noLegalTarget }
                var left = amount
                for i in p.buffState.pointLots.indices where left > 0 {
                    guard p.buffState.pointLots[i].eligible, p.buffState.pointLots[i].originalPlacement else { continue }
                    let debit = min(left, p.buffState.pointLots[i].remaining)
                    p.buffState.pointLots[i].debited += debit; left -= debit
                }
                let before = p.pendingBase
                p.pendingBase -= amount
                p.turnScoringOperations.append(ScoreOperation(id: "buff.rain-check.debit.\(source.id)",
                    sourceID: definition, sourceInstanceID: source.id.uuidString, sourceName: source.def.name,
                    trigger: .place, scope: .turn, kind: .addPoints, amount: -Double(amount),
                    before: ScoreValues(points: Double(before)), after: ScoreValues(points: Double(p.pendingBase))))
                p.buffState.rainCheck = BuffDeferredPoints(source: source.id, turn: p.turnNumber + 1, points: amount * 2)
            default: throw BuffUseError.invalidChoice
            }
        }
        if oncePerPuzzle.contains(definition) { p.buffState.usedOnce.insert(definition) }
        BossScoring.refreshDryState(run: run, puzzle: &p)
        p.assertConservation()
        run.puzzle = p
        consume(source, effect: effect, generated: generated, run: &run)
        outcome.consumedID = source.id
        outcome.handChanged = beforeHand != p.handCards
        return outcome
    }

    // MARK: - Shared action hooks

    public static func passageAllows(_ square: Square, puzzle: PuzzleState) -> Bool {
        puzzle.buffState.passageSquare == square && puzzle.buffState.passageTurn == puzzle.turnNumber
            && puzzle.markerState.turn.blotterSquare != square
    }
    static func bossBars(_ square: Square, puzzle: PuzzleState) -> Bool {
        puzzle.bossTurn?.fouled[square] != nil || puzzle.bossTurn?.greyed.contains(square) == true
    }
    static func isTossable(handIndex: Int, puzzle: PuzzleState) -> Bool {
        !puzzle.isTossBlocked(handIndex: handIndex) || releaseAllows(handIndex: handIndex, puzzle: puzzle)
    }

    public static func releaseAllows(cardID: UUID, puzzle: PuzzleState) -> Bool {
        puzzle.buffState.releasedCard == cardID && puzzle.buffState.releaseTurn == puzzle.turnNumber
    }
    public static func releaseAllows(handIndex: Int, puzzle: PuzzleState) -> Bool {
        guard puzzle.handCards.indices.contains(handIndex) else { return false }
        return releaseAllows(cardID: puzzle.handCards[handIndex].id, puzzle: puzzle)
    }

    /// Call only once an action passed ALL ordinary validation. Rejected
    /// actions cannot spend Passage, Release Note, Litmus, or any contract.
    public static func acceptedAttempt(cardID: UUID?, square: Square?, puzzle: inout PuzzleState) {
        if let square, passageAllows(square, puzzle: puzzle) {
            puzzle.buffState.passageSquare = nil; puzzle.buffState.passageTurn = nil
        }
        if let cardID, releaseAllows(cardID: cardID, puzzle: puzzle) {
            puzzle.buffState.releasedCard = nil; puzzle.buffState.releaseTurn = nil
        }
        if square != nil {
            puzzle.buffState.litmusDigit = nil
            markTriggered(Buffs.litmus, puzzle: &puzzle)
        }
    }

    /// For wrong placements, Tosses, exchanges, Redraw, and explicit returns.
    /// A Jade return is still a wrong placement and fails the tracked card.
    public static func invalidateCards(_ ids: Set<UUID>, puzzle: inout PuzzleState) {
        if let released = puzzle.buffState.releasedCard, ids.contains(released) {
            puzzle.buffState.releasedCard = nil
            puzzle.buffState.releaseTurn = nil
        }
        if var challenge = puzzle.buffState.cleanFinish, !challenge.paid,
           !challenge.cards.isDisjoint(with: ids) {
            challenge.failed = true; puzzle.buffState.cleanFinish = challenge
        }
    }

    /// Keep exact source recovery state synchronized with successful flag
    /// consumption. Legacy anonymous flags intentionally have no recoverable copy.
    public static func markTriggered(_ definition: String, puzzle: inout PuzzleState) {
        guard let id = puzzle.buffState.armedSources.removeValue(forKey: definition) else { return }
        if let index = puzzle.buffState.spent.firstIndex(where: { $0.owned.id == id && !$0.recovered }) {
            puzzle.buffState.spent[index].triggered = true
        }
    }

    /// Called alongside appending a real scoring receipt. Split any ineligible
    /// or Buff-derived part into its own lot; receipts, not solution checks,
    /// decide provenance. Repeated receipt delivery is idempotent.
    public static func recordPoints(id: String, points: Int, eligible: Bool,
                                    originalPlacement: Bool, puzzle: inout PuzzleState) {
        guard points > 0, !puzzle.buffState.pointLots.contains(where: { $0.id == id }) else { return }
        puzzle.buffState.pointLots.append(BuffPointLot(id: id, points: points,
            eligible: eligible, originalPlacement: originalPlacement))
    }

    /// Call with the exact queued part of a wrong-placement penalty. Taking
    /// points from the queue must also remove their eligibility/funding value.
    public static func debitQueuedPoints(_ amount: Int, puzzle: inout PuzzleState) {
        var left = max(0, amount)
        for i in puzzle.buffState.pointLots.indices where left > 0 {
            let taken = min(left, puzzle.buffState.pointLots[i].remaining)
            puzzle.buffState.pointLots[i].debited += taken; left -= taken
        }
    }

    public static func eligibleQueuedPoints(_ puzzle: PuzzleState) -> Int {
        min(puzzle.pendingBase, puzzle.buffState.pointLots.filter(\.eligible).reduce(0) { ScoreMath.add($0, $1.remaining) })
    }
    public static func availableRainCheckPoints(_ puzzle: PuzzleState) -> Int {
        min(puzzle.pendingBase, puzzle.buffState.pointLots.filter { $0.eligible && $0.originalPlacement }
            .reduce(0) { ScoreMath.add($0, $1.remaining) })
    }
    public static func additionalEligibleMult(_ puzzle: PuzzleState) -> Double {
        puzzle.buffState.turnMult.filter { $0.turn == puzzle.turnNumber }.reduce(0) { $0 + $1.amount }
    }

    /// After all real placement/clear receipts, before Full Clear phase change
    /// and empty-Hand auto-banking. Returned awards are already queued; they
    /// are presentation evidence and must never be applied again by callers.
    @discardableResult
    public static func didPlace(_ event: CataloguePlacement, run: inout RunState) -> [BuffPointAward] {
        guard var p = run.puzzle else { return [] }
        let eventID = "\(event.turnNumber).\(event.square.index)"
        guard p.buffState.processedPlacements.insert(eventID).inserted else { return [] }
        let eligible = event.isEligible && event.placementPoints > 0 && !event.isClue && p.phase == .playing
        var awards: [BuffPointAward] = []
        func award(_ definition: String, _ source: UUID, _ points: Int) {
            awards.append(BuffPointAward(definition: definition, source: source, points: points))
        }
        if var challenge = p.buffState.cleanFinish, !challenge.failed, !challenge.paid,
           let cardID = event.cardID, challenge.cards.contains(cardID) {
            if eligible && challenge.turn == event.turnNumber {
                challenge.completed.insert(cardID)
                if challenge.completed == challenge.cards {
                    challenge.paid = true; award(Buffs.cleanFinish, challenge.source, 150)
                }
            } else { challenge.failed = true }
            p.buffState.cleanFinish = challenge
        }
        if let source = p.buffState.crossCut, eligible, event.positiveClearUnits.count >= 2 {
            p.buffState.crossCut = nil
            award(Buffs.crossCut, source, event.positiveClearUnits.count >= 3 ? 180 : 120)
        }
        if var bracket = p.buffState.bracket, !bracket.failed, !bracket.paid,
           bracket.squares.contains(event.square) {
            if eligible {
                bracket.completed.insert(event.square)
                if bracket.completed.count == 2 {
                    bracket.paid = true; award(Buffs.openBracket, bracket.source, 200)
                }
            } else { bracket.failed = true }
            p.buffState.bracket = bracket
        }
        if let deferred = p.buffState.rainCheck, deferred.turn == event.turnNumber, eligible {
            p.buffState.rainCheck = nil
            award(Buffs.rainCheck, deferred.source, deferred.points)
        }
        p.buffState.parity[event.square] = nil
        for value in awards { queue(value, eventID: eventID, puzzle: &p) }
        run.puzzle = p
        return awards
    }

    static func queue(_ award: BuffPointAward, eventID: String, puzzle: inout PuzzleState) {
        let before = puzzle.pendingBase
        puzzle.pendingBase = ScoreMath.add(before, award.points)
        let applied = puzzle.pendingBase - before
        recordPoints(id: "buff.\(award.source).\(eventID)", points: applied,
            eligible: true, originalPlacement: false, puzzle: &puzzle)
        puzzle.turnScoringOperations.append(ScoreOperation(id: "buff.\(award.source).\(eventID)",
            sourceID: award.definition, sourceInstanceID: award.source.uuidString,
            sourceName: Catalog.item(award.definition)?.name ?? "Buff", trigger: .place, scope: .turn,
            kind: .addPoints, amount: Double(applied), before: ScoreValues(points: Double(before)),
            after: ScoreValues(points: Double(puzzle.pendingBase))))
    }

    /// Called after a Turn's bank, before increasing its Turn number. Effects
    /// expire at the boundary even when the next Turn is a rescue or failure.
    public static func didBank(puzzle: inout PuzzleState) {
        puzzle.buffState.pointLots = []
        puzzle.buffState.turnMult = []
        puzzle.buffState.inventoryCountTurn = nil
        puzzle.buffState.proof = nil
        puzzle.buffState.passageSquare = nil; puzzle.buffState.passageTurn = nil
        puzzle.buffState.releasedCard = nil; puzzle.buffState.releaseTurn = nil
        if var challenge = puzzle.buffState.cleanFinish, challenge.turn <= puzzle.turnNumber, !challenge.paid {
            challenge.failed = true; puzzle.buffState.cleanFinish = challenge
        }
        if let rain = puzzle.buffState.rainCheck, rain.turn <= puzzle.turnNumber { puzzle.buffState.rainCheck = nil }
    }

    public static func didEndPuzzle(_ run: inout RunState) {
        if var p = run.puzzle {
            p.bookmarkState.suspended = []
            p.buffState.handSizeBonus = 0
            run.puzzle = p
            // Existing excess cards stay conserved in Hand; only its future
            // normal refill target returns to the unsuspended value.
            p.handSize = run.effectiveHandSize(boss: p.boss)
            run.puzzle = p
        }
        run.puzzle?.buffState.rainCheck = nil
        run.puzzle?.buffState.litmusDigit = nil
        run.buffState.collationChoice = nil
        run.pendingItemDecisions.removeAll { $0.kind.hasPrefix("buff.") }
        if run.outcome != nil {
            run.buffState.reservation = nil
            run.buffState.reservationIntent = nil
            run.buffState.supplement = nil
            run.buffState.layoutChoice = nil
            run.buffState.bossChoice = nil
            run.buffState.freePressVisit = nil
            run.buffState.freePressSource = nil
        }
    }

    // MARK: - Paid information (pure reading, no RNG or effect dispatch)

    public static func poolCounts(_ puzzle: PuzzleState) -> [Digit: Int]? {
        guard puzzle.buffState.inventoryCountTurn == puzzle.turnNumber else { return nil }
        return Dictionary(uniqueKeysWithValues: Digit.all.map { ($0, puzzle.pool[$0]) })
    }

    /// Caller supplies the actually visible values. Fogged values must be nil;
    /// this API never reads Board.solution or secretly eliminates candidates.
    public static func proofCandidates(puzzle: PuzzleState, visibleValues: [Digit?]) -> [Square: [Digit]] {
        guard visibleValues.count == 81, let proof = puzzle.buffState.proof,
              proof.turn == puzzle.turnNumber else { return [:] }
        var result: [Square: [Digit]] = [:]
        for square in cells(proof.unit, proof.index) where puzzle.board.isBlank(square) {
            let occupied = Set(Geometry.peers[square.index].compactMap { visibleValues[$0] })
            result[square] = Digit.all.filter { !occupied.contains($0) }
        }
        return result
    }

    public static func litmusReading(at square: Square, puzzle: PuzzleState) -> Bool? {
        guard puzzle.armedFlags.contains(.litmus), let digit = puzzle.buffState.litmusDigit,
              puzzle.board.isBlank(square), !puzzle.isBarred(square), puzzle.boss?.disablesClues != true else { return nil }
        return puzzle.board.correctDigit(at: square) == digit
    }
}
