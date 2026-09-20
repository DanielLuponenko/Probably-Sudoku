import Foundation

public enum BuffRoutes {
    public static let definitions: Set<String> = [Buffs.detour, Buffs.bossDraft, Buffs.supplement]

    static func position(_ run: RunState) -> String { "\(run.level).\(run.slot.rawValue)" }

    public static func canUse(_ definition: String, run: RunState) -> Bool {
        guard run.outcome == nil, run.shop == nil else { return false }
        switch definition {
        case Buffs.supplement:
            return run.buffState.supplement == nil && !run.isFinalPuzzle
                && (run.puzzle == nil || run.puzzle?.phase == .playing)
                && run.puzzle?.boss?.disablesBuffs != true
        case Buffs.detour:
            return run.puzzle == nil && run.slot != .boss
                && !run.buffState.detourUsed.contains(position(run))
        case Buffs.bossDraft:
            return run.puzzle == nil && !run.buffState.bossDraftLevels.contains(run.level)
        default: return false
        }
    }

    /// These two information purchases spend on reveal. Their saved decision
    /// must be resumed, not rerolled or silently cancelled by navigation.
    static func reveal(_ definition: String, source: OwnedBuff, run: inout RunState) throws {
        guard canUse(definition, run: run), run.pendingItemDecisions.isEmpty else {
            throw BuffUseError.unavailable
        }
        let options: [ItemChoiceOption]
        if definition == Buffs.detour {
            var normalStream = run.streams.board
            let normal = try Generator.generate(&normalStream, difficulty: run.slot.difficulty,
                                                 givens: run.book.givens(for: run.slot.difficulty))
            var alternativeStream = RandomStream(seed: run.seed,
                stream: "buff.detour.v1.\(position(run))")
            let alternate = try Generator.generate(&alternativeStream, difficulty: run.slot.difficulty,
                                                    givens: run.book.givens(for: run.slot.difficulty))
            run.buffState.layoutChoice = BuffLayoutChoice(source: source.id, level: run.level, slot: run.slot,
                original: Board(normal), alternate: Board(alternate))
            run.buffState.detourUsed.insert(position(run))
            options = [ItemChoiceOption(id: "original", title: "Original layout"),
                       ItemChoiceOption(id: "alternate", title: "Alternative layout")]
        } else if definition == Buffs.bossDraft {
            run.ensurePendingBoss()
            guard let current = run.pendingBoss else { throw BuffUseError.noLegalTarget }
            var route = run
            if route.bossRosterVersion >= 2, route.bossEncounterHistory.last == current {
                route.bossEncounterHistory.removeLast()
            }
            // Compare alternatives with the preceding chapter, not with the
            // current announcement that this choice is about to replace.
            let eligible = BossEligibility.candidates(run: route).filter { $0 != current }
            var stream = RandomStream(seed: run.seed, stream: "buff.boss-draft.v1.\(run.level)")
            guard let alternate = stream.pick(eligible) else { throw BuffUseError.noLegalTarget }
            run.buffState.bossChoice = BuffBossChoice(source: source.id, level: run.level,
                original: current, alternate: alternate)
            run.buffState.bossDraftLevels.insert(run.level)
            options = [ItemChoiceOption(id: "original", title: current.name, detail: current.text),
                       ItemChoiceOption(id: "alternate", title: alternate.name, detail: alternate.text)]
        } else { throw BuffUseError.invalidChoice }
        let decisionID = run.nextItemIdentity(domain: "buff.route-choice")
        run.pendingItemDecisions.append(ItemDecision(id: decisionID, sourceID: definition,
            sourceInstanceID: source.id, contextKey: BuffRuntime.context(run), kind: "buff.route",
            title: source.def.name, detail: "This copy is spent. Choose which one to play.", options: options,
            allowsCancel: false, consumedOnReveal: true))
    }

    static func commit(_ decision: ItemDecision, selected: String, run: inout RunState) throws {
        guard decision.contextKey == BuffRuntime.context(run), selected == "original" || selected == "alternate" else {
            throw BuffUseError.staleContext
        }
        let alternate = selected == "alternate"
        if decision.sourceID == Buffs.detour {
            guard var choice = run.buffState.layoutChoice, choice.source == decision.sourceInstanceID,
                  choice.level == run.level, choice.slot == run.slot,
                  choice.selectedAlternate == nil else { throw BuffUseError.staleContext }
            choice.selectedAlternate = alternate
            run.buffState.layoutChoice = choice
        } else if decision.sourceID == Buffs.bossDraft {
            guard var choice = run.buffState.bossChoice, choice.source == decision.sourceInstanceID,
                  choice.level == run.level, choice.selectedAlternate == nil else { throw BuffUseError.staleContext }
            choice.selectedAlternate = alternate
            run.pendingBoss = alternate ? choice.alternate : choice.original
            if run.bossRosterVersion >= 2, let chosen = run.pendingBoss {
                if run.bossEncounterHistory.last == choice.original { run.bossEncounterHistory.removeLast() }
                run.bossEncounterHistory.append(chosen)
            }
            run.buffState.bossChoice = choice
        } else { throw BuffUseError.invalidChoice }
    }

    /// Call after the normal board stream has generated this slot once, before
    /// Pool/Hand construction. Both choices therefore advance that stream by
    /// the identical normal generation, preserving subsequent board deals.
    public static func selectedBoard(run: RunState) -> Board? {
        guard let choice = run.buffState.layoutChoice, choice.level == run.level,
              choice.slot == run.slot, let alternate = choice.selectedAlternate else { return nil }
        return alternate ? choice.alternate : choice.original
    }

    public static func previewLayouts(run: RunState) -> [[Digit?]] {
        guard let choice = run.buffState.layoutChoice, choice.level == run.level,
              choice.slot == run.slot else { return [] }
        // Do not surface either solution through a preview API.
        return [choice.original.placed, choice.alternate.placed]
    }

    public static func didStartPuzzle(_ run: inout RunState) {
        run.buffState.layoutChoice = nil
        if run.slot == .boss { run.buffState.bossChoice = nil }
    }
}
