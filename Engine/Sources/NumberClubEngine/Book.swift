import Foundation

/// A published Book's standing advantage. Benefits belong to the Book itself;
/// there is no separate board archetype to choose or name.
public enum BookBenefit: CaseIterable, Hashable, Sendable {
    case extraNumber
    case openingFloat
    case marginClue
    case oneMoreTurn
    case extraToss
    case boxCoin
    case firstMistakeFree
    case placementBonus
    case unitBonus
    case interestCap
    case freeReroll
    case puzzleCoin

    public var title: String {
        switch self {
        case .extraNumber: return "+1 Hand Size"
        case .openingFloat: return "+10 Coins"
        case .marginClue: return "+1 Clue"
        case .oneMoreTurn: return "+1 Turn"
        case .extraToss: return "+1 Toss"
        case .boxCoin: return "+1 Coin per Box"
        case .firstMistakeFree: return "First Mistake Free"
        case .placementBonus: return "+10 Placement Score"
        case .unitBonus: return "+15 Clear Score"
        case .interestCap: return "+5 Interest Cap"
        case .freeReroll: return "First Reroll Free"
        case .puzzleCoin: return "+1 Win Coin"
        }
    }

    public var detail: String {
        switch self {
        case .extraNumber: return "Begin with 7 numbers instead of 6."
        case .openingFloat: return "Begin with 15 coins instead of 5."
        case .marginClue: return "Begin every puzzle with one clue."
        case .oneMoreTurn: return "Begin every puzzle with 11 turns instead of 10."
        case .extraToss: return "Toss 5 numbers per puzzle instead of 4."
        case .boxCoin: return "Earn 1 coin for each box you complete."
        case .firstMistakeFree: return "Waive one wrong-placement penalty each puzzle."
        case .placementBonus: return "Your correct placements gain 10 extra points."
        case .unitBonus: return "Your row, column and box clears gain 15 points."
        case .interestCap: return "Raise your interest payout cap from 10 to 15."
        case .freeReroll: return "The first reroll in every Shop costs no coins."
        case .puzzleCoin: return "Bank 6 base coins per puzzle instead of 5."
        }
    }

    public var before: Int {
        switch self {
        case .extraNumber: return Baseline.handSize
        case .openingFloat: return Baseline.coins
        case .marginClue: return Baseline.clues
        case .oneMoreTurn: return Baseline.turns
        case .extraToss: return Baseline.tossAllowance
        case .boxCoin, .firstMistakeFree, .placementBonus: return 0
        case .unitBonus: return 45
        case .interestCap: return Baseline.interestCap
        case .freeReroll: return ShopState.firstRerollCost
        case .puzzleCoin: return 5
        }
    }

    public var after: Int {
        switch self {
        case .extraNumber: return Baseline.handSize + handSizeDelta
        case .openingFloat: return Baseline.coins + coinsDelta
        case .marginClue: return Baseline.clues + clueDelta
        case .oneMoreTurn: return Baseline.turns + turnsDelta
        case .extraToss: return Baseline.tossAllowance + tossDelta
        case .boxCoin, .firstMistakeFree: return 1
        case .placementBonus: return 10
        case .unitBonus: return 60
        case .interestCap: return Baseline.interestCap + interestCapDelta
        case .freeReroll: return 0
        case .puzzleCoin: return 6
        }
    }

    public var handSizeDelta: Int { self == .extraNumber ? 1 : 0 }
    public var coinsDelta: Int { self == .openingFloat ? 10 : 0 }
    public var clueDelta: Int { self == .marginClue ? 1 : 0 }
    public var turnsDelta: Int { self == .oneMoreTurn ? 1 : 0 }
    public var tossDelta: Int { self == .extraToss ? 1 : 0 }
    public var interestCapDelta: Int { self == .interestCap ? 5 : 0 }
    public var winCoinsDelta: Int { self == .puzzleCoin ? 1 : 0 }
    public var hasFreeFirstReroll: Bool { self == .freeReroll }

    /// A Book is not an owned item: its advantage cannot be sold or put to
    /// sleep by a Boss. Scoring and protection still respect Clues and any
    /// cancellation already applied by the Boss or the square's Marker.
    func apply(to result: inout EffectResult, context: EffectContext) {
        guard !context.isClue, !result.zeroed else { return }
        switch self {
        case .boxCoin where context.event == .lineClear && context.unit == .box:
            result.coins += 1
        case .placementBonus where context.event == .place:
            result.flat += 10
        case .unitBonus where context.event == .lineClear:
            result.flat += 15
        case .firstMistakeFree where context.event == .wrongPlace:
            let key = "book.firstMistakeFree.used"
            guard context.puzzleState[key, default: 0] == 0 else { return }
            result.zeroed = true
            result.puzzleStateWrites[key] = 1
        default:
            break
        }
    }
}

/// The fixed rules of a published Sudoku Book. Obstacles are intentionally
/// separate: a Book changes the puzzle itself; an Obstacle changes the tools
/// available while solving it.
public enum Book: String, Codable, CaseIterable, Sendable {
    case probably
    case slightlyHarder
    case noPressure
    case bites
    case genuinely
    case snackBreak
    case trustMe
    case overthinking
    case smallVictories
    case rainyDay
    case secondThoughts
    case wellEarned

    public var benefit: BookBenefit {
        switch self {
        case .probably: return .extraNumber
        case .slightlyHarder: return .openingFloat
        case .noPressure: return .marginClue
        case .bites: return .oneMoreTurn
        case .genuinely: return .extraToss
        case .snackBreak: return .boxCoin
        case .trustMe: return .firstMistakeFree
        case .overthinking: return .placementBonus
        case .smallVictories: return .unitBonus
        case .rainyDay: return .interestCap
        case .secondThoughts: return .freeReroll
        case .wellEarned: return .puzzleCoin
        }
    }

    public var volume: Int {
        switch self {
        case .probably: return 1
        case .slightlyHarder: return 2
        case .noPressure: return 3
        case .bites: return 4
        case .genuinely: return 5
        case .snackBreak: return 6
        case .trustMe: return 7
        case .overthinking: return 8
        case .smallVictories: return 9
        case .rainyDay: return 10
        case .secondThoughts: return 11
        case .wellEarned: return 12
        }
    }

    /// Book 2 removes three givens at every normal slot. The generator still
    /// applies each slot's technique gate, so an easier gate is never used to
    /// compensate for the smaller clue count.
    public func givens(for difficulty: Difficulty) -> Int {
        let reduction: Int
        switch self {
        case .probably, .genuinely, .snackBreak, .trustMe, .overthinking,
             .smallVictories, .rainyDay, .secondThoughts, .wellEarned: reduction = 0
        case .slightlyHarder: reduction = 3
        case .noPressure: reduction = 3
        case .bites: reduction = 6
        }
        return max(17, difficulty.givens - reduction)
    }

    public func target(level: Int, slot: PuzzleSlot) -> Int {
        let multiplier: Double
        switch self {
        case .probably, .slightlyHarder, .genuinely, .snackBreak, .trustMe, .overthinking,
             .smallVictories, .rainyDay, .secondThoughts, .wellEarned: multiplier = 1
        case .noPressure: multiplier = 1.25
        case .bites: multiplier = 1.5
        }
        return Int((Double(Targets.target(level: level, slot: slot)) * multiplier).rounded(.down))
    }

    public var startingCoins: Int {
        switch self {
        case .bites: return 3
        case .probably, .slightlyHarder, .noPressure, .genuinely, .snackBreak, .trustMe,
             .overthinking, .smallVictories, .rainyDay, .secondThoughts, .wellEarned: return Baseline.coins
        }
    }
}
