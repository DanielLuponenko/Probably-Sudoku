import Foundation

public enum BossAutomaticDrawPolicy: String, Codable, Sendable {
    case ordinary, absentFromHand
}

/// An owed attempt, never a reserved Pool card. Source order and filtering
/// survive restoring a Courier encounter without advancing either RNG early.
public struct BossDeferredDraw: Codable, Equatable, Sendable {
    public var count: Int
    public var sourceID: String
    public var sourceInstanceID: UUID?
    /// Marker claims are stable strings, not inventory UUIDs. Keep the exact
    /// claim even if Rebind later moves its board coordinate before delivery.
    public var sourceClaimID: String?
    public var policy: BossAutomaticDrawPolicy
    public init(count: Int, sourceID: String, sourceInstanceID: UUID? = nil, sourceClaimID: String? = nil,
                policy: BossAutomaticDrawPolicy = .ordinary) {
        self.count = max(0, count); self.sourceID = sourceID
        self.sourceInstanceID = sourceInstanceID; self.sourceClaimID = sourceClaimID; self.policy = policy
    }
}

public enum BossReviewUnit: String, Codable, CaseIterable, Sendable {
    case row, col, box
}

/// Puzzle-owned mechanical state. Rendering reads these committed values;
/// animation completion never clears a restriction or applies a reward.
public struct ExpandedBossState: Codable, Sendable {
    public var arrivalSerials: [String: Int] = [:]
    public var nextArrivalSerial = 0
    public var usedDigits: Set<Digit> = []
    public var waitingIDs: Set<UUID> = []
    public var correctFills = 0
    public var pendingAutoEnd = false
    public var sealedIDs: Set<UUID> = []
    public var deferredDraws: [BossDeferredDraw] = []
    public var placementStarted = false
    public var royaltyStartingTarget: Int?
    public var royaltyCount = 0
    public var reviewApproved: Set<BossReviewUnit> = []
    public var scoring = BossScoringState()
    public var encounter = BossEncounterState()

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case arrivalSerials, nextArrivalSerial, usedDigits, waitingIDs, correctFills,
             pendingAutoEnd, sealedIDs, deferredDraws, placementStarted,
             royaltyStartingTarget, royaltyCount, reviewApproved, scoring, encounter
    }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        arrivalSerials = try c.decodeIfPresent([String: Int].self, forKey: .arrivalSerials) ?? [:]
        nextArrivalSerial = try c.decodeIfPresent(Int.self, forKey: .nextArrivalSerial) ?? 0
        usedDigits = Set(try c.decodeIfPresent([Digit].self, forKey: .usedDigits) ?? [])
        waitingIDs = Set(try c.decodeIfPresent([UUID].self, forKey: .waitingIDs) ?? [])
        correctFills = try c.decodeIfPresent(Int.self, forKey: .correctFills) ?? 0
        pendingAutoEnd = try c.decodeIfPresent(Bool.self, forKey: .pendingAutoEnd) ?? false
        sealedIDs = Set(try c.decodeIfPresent([UUID].self, forKey: .sealedIDs) ?? [])
        deferredDraws = try c.decodeIfPresent([BossDeferredDraw].self, forKey: .deferredDraws) ?? []
        placementStarted = try c.decodeIfPresent(Bool.self, forKey: .placementStarted) ?? false
        royaltyStartingTarget = try c.decodeIfPresent(Int.self, forKey: .royaltyStartingTarget)
        royaltyCount = try c.decodeIfPresent(Int.self, forKey: .royaltyCount) ?? 0
        reviewApproved = Set(try c.decodeIfPresent([BossReviewUnit].self, forKey: .reviewApproved) ?? [])
        scoring = try c.decodeIfPresent(BossScoringState.self, forKey: .scoring) ?? .init()
        encounter = try c.decodeIfPresent(BossEncounterState.self, forKey: .encounter) ?? .init()
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(arrivalSerials, forKey: .arrivalSerials)
        try c.encode(nextArrivalSerial, forKey: .nextArrivalSerial)
        try c.encode(usedDigits.sorted(), forKey: .usedDigits)
        try c.encode(waitingIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .waitingIDs)
        try c.encode(correctFills, forKey: .correctFills)
        try c.encode(pendingAutoEnd, forKey: .pendingAutoEnd)
        try c.encode(sealedIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .sealedIDs)
        try c.encode(deferredDraws, forKey: .deferredDraws)
        try c.encode(placementStarted, forKey: .placementStarted)
        try c.encodeIfPresent(royaltyStartingTarget, forKey: .royaltyStartingTarget)
        try c.encode(royaltyCount, forKey: .royaltyCount)
        try c.encode(reviewApproved.sorted { $0.rawValue < $1.rawValue }, forKey: .reviewApproved)
        try c.encode(scoring, forKey: .scoring)
        try c.encode(encounter, forKey: .encounter)
    }
}
