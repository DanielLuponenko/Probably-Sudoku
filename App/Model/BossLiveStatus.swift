import Foundation
import ProbablySudokuEngine

/// Concise public state in the existing boss header. Never probes a solution
/// or infers an unseen Marker location to explain a restriction.
enum BossLiveStatus {
    static func text(puzzle p: PuzzleState) -> String? {
        guard let boss = p.boss else { return nil }
        let state = p.bossState
        switch boss {
        case .galleyQueue: return "PLAY cards go first"
        case .bookends: return "Choose LOW or HIGH"
        case .reprintBan:
            let waiting = Set(p.hand.indices.filter {
                BossRuntime.placementRestricted(handIndex: $0, puzzle: p)
                    && !BuffRuntime.releaseAllows(handIndex: $0, puzzle: p)
            }.map { p.hand[$0] })
            if !waiting.isEmpty {
                let digits = waiting.sorted().map { String($0.rawValue) }.joined(separator: ", ")
                return "\(digits) already played · choose a new number"
            }
            let openRepeat = p.hand.indices.contains {
                state.usedDigits.contains(p.hand[$0])
                    && (!p.isBlocked(handIndex: $0) || BuffRuntime.releaseAllows(handIndex: $0, puzzle: p))
            }
            return openRepeat ? "Repeats are open" : "Play a new number"
        case .rebinder: return "Leftovers return before the next refill"
        case .lateCourier:
            let count = state.deferredDraws.reduce(0) { $0 + $1.count }
            return count == 0 ? "Bonus draws arrive after banking" : "\(count) draws due after banking"
        case .collator:
            return state.waitingIDs.isEmpty ? "Both packets open" : "\(min(2, state.correctFills))/2 fills · second packet waits"
        case .pageCutter: return "\(min(4, state.correctFills))/4 fills · then bank"
        case .chainStitcher:
            guard state.scoring.chainAnchor != nil else { return "Place a number to start the chain" }
            return "Follow the lit row, column or box"
        case .returnSlip:
            return state.sealedIDs.isEmpty ? "Wrong cards return sealed for this Turn" : "\(state.sealedIDs.count) cards sealed until next Turn"
        case .orphanLine:
            return "\(p.hand.count) left · −\(BossScoring.orphanDebit(p)) Points at bank"
        case .serialPublisher:
            let target = state.scoring.serialStartingTarget ?? p.target
            let limit = target / 3 + (target % 3 == 0 ? 0 : 1)
            return "Bank limit \(limit.formatted()) · \(state.scoring.serialCarry.formatted()) carried"
        case .bindery:
            return state.scoring.binderyPinned
                ? (p.turnNumber.isMultiple(of: 2) ? "Pinned · right to left" : "Pinned · left to right")
                : "Arrange Bookmarks before your first action"
        case .embargo: return state.placementStarted ? "Preparation sealed until next Turn" : "Preparation Buffs open"
        case .dryPress: return state.scoring.dryPressReady ? "Inked · Marker placement bonus ready" : "Dry · fill a plain square to re-ink"
        case .reviewBoard:
            return [(BossReviewUnit.row, "Row"), (.col, "Column"), (.box, "Box")]
                .map { "\($0.1) \(state.reviewApproved.contains($0.0) ? "✓" : "○")" }.joined(separator: " · ")
        case .rivalColumn:
            return state.scoring.rivalBenchmark.map { "Beat \($0.formatted()) at the next bank" } ?? "First positive bank sets the benchmark"
        case .royaltyContract:
            return state.royaltyCount < 3 ? "Buff cost: target +\(BossBuffRules.targetIncrease(puzzle: p)) · \(state.royaltyCount)/3" : "Target increases: 3/3"
        case .publicist:
            return state.scoring.publicistPaid.count == 1 ? "1 Bookmark bonus paid this Turn"
                : "\(state.scoring.publicistPaid.count) Bookmark bonuses paid this Turn"
        case .wordCount: return "\(max(0, 150 - state.scoring.wordCountSpent))/150 extra placement Points left"
        case .backPage: return "1 = 90 Points · 9 = 10 Points"
        case .collateral:
            if let card = state.encounter.pledgedCard {
                return "\(card.digit.rawValue) pledged · +\(Int(BossEncounterRules.collateralMultBonus)) Mult"
            }
            return state.encounter.turnCommitted ? "Pledge again next Turn" : "Pledge a held tile for extra Mult"
        case .splitEdition:
            return state.encounter.turnCommitted ? "Printing edition \(state.encounter.selectedEdition + 1)"
                : "Choose this Turn’s edition"
        case .lastEdition:
            return state.encounter.banksUsed == 0 ? "One bank · make it count" : "Edition printed"
        default: return nil
        }
    }
}
