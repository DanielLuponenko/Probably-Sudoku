import Foundation

/// Facts belong to the played Turn, while limited effects belong to an owned
/// copy. Moving or replacing an item cannot transfer another copy's charges.
public struct BookmarkTurnState: Codable, Sendable, Equatable {
    public var actionTaken = false
    public var eligiblePlacements = 0
    public var boxes = 0
    public var digitBoxes: [Int: Int] = [:]
    public var paidPenalty = false
    public var bankAwarded = false
    @StableMap public var copies: [UUID: BookmarkTurnCopyState] = [:]
    public init() {}
}

public struct BookmarkTurnCopyState: Codable, Sendable, Equatable {
    public var serialLastDigit: Digit?
    public var serialLength = 0
    public var serialUsed = false
    public var carbonPoints = 0
    public var carbonUsed = false
    public var typeDigit: Digit?
    public var typeChoiceResolved = false
    public var typeBonuses = 0
    public var typeEnded = false
    public var duplicateChoiceResolved = false
    public init() {}
}

public struct BookmarkPuzzleCopyState: Codable, Sendable, Equatable {
    public var numberIndexDigits = 0
    public var numberIndexAwarded = false
    public var eveningAwarded = false
    public var duplicateUsed = false
    public var paperSalvageUsed = false
    public var advancePaid = false
    public var advanceChoiceResolved = false
    public var personalDigit: Digit?
    public var personalChoiceResolved = false
    public var personalTriggers = 0
    public var crossReferenceTriggers = 0
    public var correctionArmed = false
    public var correctionAmount = 0
    public var correctionPlacements = 0
    public var correctionRecovered = false
    public var referenceTypes = 0
    public var rightToReplyUsed = false
    public init() {}
}

public struct BookmarkPuzzleState: Codable, Sendable, Equatable {
    public var turn = BookmarkTurnState()
    @StableMap public var copies: [UUID: BookmarkPuzzleCopyState] = [:]
    /// Collateral suspends both passive and scoring effects, without selling.
    @StableSet public var suspended: Set<UUID> = []
    public var previousPaidPenalty = false
    public var previousOrdinaryBank = 0
    public var winningTurn: Int?
    public var spentClues = 0
    public var pendingRefillDraws = 0
    @StableSetMap public var boxTurns: [Int: Set<Int>] = [:]
    @StableSet public var clearedIssueBoxes: Set<Int> = []
    public var puzzleActionTaken = false
    public var payoutRecorded = false
    /// A missing expansion state on a historical live Turn is handled by the
    /// shared decoder. It must not infer earlier eligible actions.
    public var legacyTurn = false
    public init() {}
}

public struct BookmarkRunCopyState: Codable, Sendable, Equatable {
    public var numberIndexMult = 0
    public var archivePoints = 0
    public var purchasedBuffReceipts = 0
    public init() {}
}

public struct BookmarkShopState: Codable, Sendable, Equatable {
    public var visitID: Int
    @StableSet public var ownedOnEntry: Set<UUID>
    public var purchases = 0
    public var rerolls = 0
    public var buffPurchased = false
    @StableSet public var buybackUsed: Set<UUID> = []
    @StableMap public var recycledChoices: [UUID: [String]] = [:]
    @StableSet public var recycledEligible: Set<UUID> = []
    @StableSet public var recycledClaimed: Set<UUID> = []
    @StableSet public var recycledDismissed: Set<UUID> = []
    public var exitAwarded = false
    public init(visitID: Int, ownedOnEntry: Set<UUID>) {
        self.visitID = visitID
        self.ownedOnEntry = ownedOnEntry
    }
}

public struct BookmarkRunState: Codable, Sendable, Equatable {
    @StableMap public var copies: [UUID: BookmarkRunCopyState] = [:]
    public var shop: BookmarkShopState?
    public init() {}
}

public enum BookmarkChoiceError: Error, Equatable, Sendable {
    case staleChoice, invalidDigit, insufficientCoins, inventoryFull
    case invalidReplacement, itemUnavailable, unresolvedCapacity
}
