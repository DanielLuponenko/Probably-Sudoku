import Foundation

/// Restrictions and target costs apply to committed owned Buff consumption.
/// Opening a slip or cancelling a choice never calls the mutation hook.
public enum BossBuffRules {
    public static let preparationBuffs: Set<String> = [Buffs.peek, Buffs.redraw, Buffs.overtime,
        Buffs.doubleDown, Buffs.insurance, Buffs.secondPrint, Buffs.luckyDip, Buffs.birdSeed,
        Buffs.freshInk, Buffs.litmus, Buffs.paperCrane]

    public static func isEmbargoed(_ definition: String, puzzle: PuzzleState?) -> Bool {
        puzzle?.boss == .embargo && puzzle?.bossState.placementStarted == true
            && preparationBuffs.contains(definition)
    }

    public static func targetIncrease(puzzle: PuzzleState?) -> Int {
        guard let puzzle, puzzle.boss == .royaltyContract, puzzle.phase == .playing,
              puzzle.bossState.royaltyCount < 3 else { return 0 }
        let starting = puzzle.bossState.royaltyStartingTarget ?? puzzle.target
        return starting / 20 + (starting % 20 == 0 ? 0 : 1)
    }

    public static func consumptionCommitted(puzzle: inout PuzzleState) {
        let increase = targetIncrease(puzzle: puzzle)
        guard increase > 0 else { return }
        if puzzle.bossState.royaltyStartingTarget == nil { puzzle.bossState.royaltyStartingTarget = puzzle.target }
        puzzle.bossState.royaltyCount += 1
        puzzle.target = (puzzle.bossState.royaltyStartingTarget ?? puzzle.target)
            + puzzle.bossState.royaltyCount * increase
    }

    public static func explanation(definition: String, puzzle: PuzzleState?) -> String? {
        if isEmbargoed(definition, puzzle: puzzle) { return "The Embargo: use this before your first placement next Turn." }
        let increase = targetIncrease(puzzle: puzzle)
        if increase > 0 { return "The Royalty Contract: spending this Buff also adds \(increase) to the target." }
        return nil
    }
}
