import Foundation

/// Choices are data, not callbacks. A stale UI cannot silently choose a new
/// inventory occupant after an animation, purchase, return, or save restore.
public enum BuffChoice: Codable, Sendable, Equatable {
    case none
    case digit(Digit)
    case cards([UUID])
    case exchange(card: UUID, digit: Digit)
    case unit(Unit, Int)
    case squares([Square])
    case claim(String, destination: Square)
    case claims(String, String)
    case offer(Int)
    case category(ItemKind)
    case bookmark(UUID)
    case amount(Int)
    case recovered(UUID)
    case order([Int])
    case alternative(Bool)
}

public struct BuffUseRequest: Codable, Sendable, Equatable {
    public let buffID: UUID
    public let context: String
    public let choice: BuffChoice
    public init(buffID: UUID, context: String, choice: BuffChoice = .none) {
        self.buffID = buffID; self.context = context; self.choice = choice
    }
}

public enum BuffUseError: Error, Equatable, Sendable {
    case unavailable, staleContext, missingCopy, invalidChoice, noLegalTarget
    case buffDisabled, clueDisabled, pendingChoice, insufficientCoins
}

public struct BuffOption: Sendable, Equatable, Identifiable {
    public var id: String
    public var label: String
    public var choice: BuffChoice
    public init(_ id: String, _ label: String, _ choice: BuffChoice) {
        self.id = id; self.label = label; self.choice = choice
    }
}

public struct BuffUseOutcome: Sendable {
    public var consumedID: UUID?
    public var requiresDecision = false
    public var handChanged = false
    public var shouldEndTurn = false
    public init() {}
}

public struct SpentBuff: Codable, Sendable {
    public var owned: OwnedBuff
    public var effectID: String
    public var recovered = false
    public var triggered = false
    /// Carbon-generated effects have Carbon's real source, not a synthetic
    /// owned copy of the repeated definition.
    public var generated = false
    public init(owned: OwnedBuff, effectID: String, generated: Bool = false) {
        self.owned = owned; self.effectID = effectID; self.generated = generated
    }
}

public struct BuffChallenge: Codable, Sendable {
    public var source: UUID
    @StableSet public var cards: Set<UUID>
    @StableSet public var completed: Set<UUID> = []
    public var turn: Int
    public var failed = false
    public var paid = false
    public init(source: UUID, cards: Set<UUID>, completed: Set<UUID> = [], turn: Int,
                failed: Bool = false, paid: Bool = false) {
        self.source = source; self.cards = cards; self.completed = completed
        self.turn = turn; self.failed = failed; self.paid = paid
    }
}

public struct BuffBracket: Codable, Sendable {
    public var source: UUID
    public var squares: [Square]
    @StableSet public var completed: Set<Square> = []
    public var failed = false
    public var paid = false
    public init(source: UUID, squares: [Square], completed: Set<Square> = [],
                failed: Bool = false, paid: Bool = false) {
        self.source = source; self.squares = squares; self.completed = completed
        self.failed = failed; self.paid = paid
    }
}

public struct BuffPointLot: Codable, Sendable {
    public var id: String
    public var points: Int
    public var eligible: Bool
    /// Only an original placement receipt can fund Rain Check. Line clears,
    /// returned Rain Check points and other Buff awards cannot be pledged.
    public var originalPlacement: Bool
    public var debited = 0
    public init(id: String, points: Int, eligible: Bool, originalPlacement: Bool) {
        self.id = id; self.points = points; self.eligible = eligible
        self.originalPlacement = originalPlacement
    }
    public var remaining: Int { max(0, points - debited) }
}

public struct BuffTurnMult: Codable, Sendable {
    public var source: UUID
    public var definition: String
    public var amount: Double
    public var turn: Int
}

public struct BuffDeferredPoints: Codable, Sendable {
    public var source: UUID
    public var turn: Int
    public var points: Int
}

public struct BuffProofUnit: Codable, Sendable {
    public var unit: Unit
    public var index: Int
    public var turn: Int
}

public struct BuffPuzzleState: Codable, Sendable {
    public var spent: [SpentBuff] = []
    @StableSet public var usedOnce: Set<String> = []
    public var armedSources: [String: UUID] = [:]
    public var litmusDigit: Digit?
    public var inventoryCountTurn: Int?
    public var proof: BuffProofUnit?
    @StableMap public var parity: [Square: Bool] = [:]
    public var passageSquare: Square?
    public var passageTurn: Int?
    public var releasedCard: UUID?
    public var releaseTurn: Int?
    public var handSizeBonus = 0
    public var turnMult: [BuffTurnMult] = []
    public var pointLots: [BuffPointLot] = []
    public var lastEligibleUse: String?
    public var cleanFinish: BuffChallenge?
    public var crossCut: UUID?
    public var bracket: BuffBracket?
    public var rainCheck: BuffDeferredPoints?
    @StableSet public var processedPlacements: Set<String> = []
    public init() {}
}

public struct BuffPointAward: Sendable, Equatable {
    public var definition: String
    public var source: UUID
    public var points: Int
}

public struct BuffReservation: Codable, Sendable {
    public var definition: String
    public var price: Int
    public var category: ItemKind
    public var sourceVisit: Int
    public var destinationVisit: Int?
    public var destinationSlot: Int?
}

public struct BuffReservationIntent: Codable, Sendable {
    public var sourceBuff: UUID
    public var context: String
    public var slot: Int
    public var definition: String
    public var price: Int
}

public struct BuffLayoutChoice: Codable, Sendable {
    public var source: UUID
    public var level: Int
    public var slot: PuzzleSlot
    public var original: Board
    public var alternate: Board
    public var selectedAlternate: Bool?
}

public struct BuffBossChoice: Codable, Sendable {
    public var source: UUID
    public var level: Int
    public var original: BossModifier
    public var alternate: BossModifier
    public var selectedAlternate: Bool?
}

public struct BuffCollationChoice: Codable, Sendable {
    public var source: UUID
    public var context: String
    public var sample: [Digit]
}

public struct BuffRunState: Codable, Sendable {
    public var reservation: BuffReservation?
    public var reservationIntent: BuffReservationIntent?
    public var supplement: ItemKind?
    @StableSet public var counterofferVisits: Set<Int> = []
    public var freePressVisit: Int?
    public var freePressSource: UUID?
    public var stockRevision = 0
    public var transformationSerial = 0
    @StableSet public var detourUsed: Set<String> = []
    @StableSet public var bossDraftLevels: Set<Int> = []
    public var layoutChoice: BuffLayoutChoice?
    public var bossChoice: BuffBossChoice?
    public var collationChoice: BuffCollationChoice?
    public init() {}
}
