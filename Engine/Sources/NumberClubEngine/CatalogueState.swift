import Foundation

/// A real Hand token. Equal digits retain separate identities through saved choices.
public struct CatalogueHandCard: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var digit: Digit
    public init(id: UUID, digit: Digit) { self.id = id; self.digit = digit }
}

/// Immutable observations taken around one accepted placement. No item needs to
/// read a solution to decide whether a visible action qualified for a reward.
public struct CataloguePlacement: Sendable {
    public var digit: Digit
    public var square: Square
    public var cardID: UUID?
    public var boardBefore: Board
    public var handBefore: [CatalogueHandCard]
    public var completedUnits: [Unit]
    public var positiveClearUnits: [Unit]
    public var isClue: Bool
    public var isEligible: Bool
    public var placementPoints: Int
    public var originalPlacementPoints: Int
    public var markerExtraPoints: Int
    public var turnNumber: Int

    public init(digit: Digit, square: Square, cardID: UUID? = nil, boardBefore: Board,
                handBefore: [CatalogueHandCard] = [], completedUnits: [Unit] = [],
                positiveClearUnits: [Unit] = [], isClue: Bool = false,
                isEligible: Bool = false, placementPoints: Int = 0,
                originalPlacementPoints: Int = 0, markerExtraPoints: Int = 0,
                turnNumber: Int = 1) {
        self.digit = digit; self.square = square; self.cardID = cardID
        self.boardBefore = boardBefore; self.handBefore = handBefore
        self.completedUnits = completedUnits; self.positiveClearUnits = positiveClearUnits
        self.isClue = isClue; self.isEligible = isEligible
        self.placementPoints = placementPoints; self.originalPlacementPoints = originalPlacementPoints
        self.markerExtraPoints = markerExtraPoints; self.turnNumber = turnNumber
    }
}

/// The engine publishes available choices. Views display these values without
/// inventing targets, spending resources, or resolving a choice a second time.
public struct ItemChoiceOption: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var title: String
    public var detail: String
    public var itemID: String?
    public var square: Square?
    public var digit: Digit?
    public var cardID: UUID?
    public init(id: String, title: String, detail: String = "", itemID: String? = nil,
                square: Square? = nil, digit: Digit? = nil, cardID: UUID? = nil) {
        self.id = id; self.title = title; self.detail = detail; self.itemID = itemID
        self.square = square; self.digit = digit; self.cardID = cardID
    }
}

public struct ItemDecision: Codable, Equatable, Sendable, Identifiable {
    public var id: UUID
    public var sourceID: String
    public var sourceInstanceID: UUID?
    public var contextKey: String
    public var kind: String
    public var title: String
    public var detail: String
    public var options: [ItemChoiceOption]
    public var minimum: Int
    public var maximum: Int
    public var ordered: Bool
    public var allowsCancel: Bool
    public var consumedOnReveal: Bool
    /// Engine-owned intent. Never interpreted by the presentation layer.
    public var payload: [String: String]
    public init(id: UUID, sourceID: String, sourceInstanceID: UUID? = nil,
                contextKey: String, kind: String, title: String, detail: String = "",
                options: [ItemChoiceOption], minimum: Int = 1, maximum: Int = 1,
                ordered: Bool = false, allowsCancel: Bool = true,
                consumedOnReveal: Bool = false, payload: [String: String] = [:]) {
        self.id = id; self.sourceID = sourceID; self.sourceInstanceID = sourceInstanceID
        self.contextKey = contextKey; self.kind = kind; self.title = title; self.detail = detail
        self.options = options; self.minimum = minimum; self.maximum = maximum
        self.ordered = ordered; self.allowsCancel = allowsCancel
        self.consumedOnReveal = consumedOnReveal; self.payload = payload
    }
    public func accepts(_ selected: [String]) -> Bool {
        selected.count >= minimum && selected.count <= maximum
            && Set(selected).count == selected.count
            && selected.allSatisfy { id in options.contains { $0.id == id } }
    }
}

public extension RunState {
    var itemContextKey: String {
        "\(seed):\(level):\(slot.rawValue):\(puzzle?.turnNumber ?? 0):\(shop?.visitID ?? -1)"
    }
    mutating func nextItemIdentity(domain: String) -> UUID {
        itemSerial += 1
        return SkipOffer.stableIdentity(seed: seed, domain: "catalogue.v1.\(domain).\(itemSerial)")
    }
    /// A fifth stream: item choices never disturb boards, Pool draws, stock or Boss rolls.
    mutating func itemRandomInt(_ upperBound: Int) -> Int {
        guard upperBound > 0 else { return 0 }
        var stream = itemRandom ?? RandomStream(seed: seed, stream: "catalogue.v1")
        let value = stream.int(upperBound)
        itemRandom = stream
        return value
    }
}

public extension PuzzleState {
    mutating func ensureHandIdentities(seed: String? = nil) {
        if handIdentityDomain.isEmpty {
            handIdentityDomain = (seed ?? board.solution.map { String($0.rawValue) }.joined())
                + ":\(level):\(slot.rawValue)"
        }
        if handCardIDs.count > hand.count { handCardIDs.removeLast(handCardIDs.count - hand.count) }
        while handCardIDs.count < hand.count {
            handCardSerial += 1
            handCardIDs.append(SkipOffer.stableIdentity(seed: handIdentityDomain,
                                                       domain: "hand.v1.\(handCardSerial)"))
        }
    }
    var handCards: [CatalogueHandCard] {
        var copy = self
        copy.ensureHandIdentities()
        return zip(copy.handCardIDs, copy.hand).map { CatalogueHandCard(id: $0.0, digit: $0.1) }
    }
    mutating func removeHandCard(at index: Int) -> CatalogueHandCard {
        ensureHandIdentities()
        let card = CatalogueHandCard(id: handCardIDs.remove(at: index), digit: hand.remove(at: index))
        if var state = bossTurn {
            state.blockedHandIndices = Set(state.blockedHandIndices.compactMap {
                $0 == index ? nil : ($0 > index ? $0 - 1 : $0)
            })
            bossTurn = state
        }
        BossRuntime.synchronizeHand(puzzle: &self)
        return card
    }
    mutating func appendHandCard(_ card: CatalogueHandCard) {
        ensureHandIdentities()
        hand.append(card.digit)
        handCardIDs.append(card.id)
        BossRuntime.synchronizeHand(puzzle: &self)
    }
    mutating func appendHandDigits(_ digits: [Digit]) {
        ensureHandIdentities()
        hand.append(contentsOf: digits)
        ensureHandIdentities()
        BossRuntime.synchronizeHand(puzzle: &self)
    }
    mutating func removeAllHandCards() -> [CatalogueHandCard] {
        ensureHandIdentities()
        let cards = handCards
        hand = []; handCardIDs = []
        bossTurn?.blockedHandIndices = []
        BossRuntime.synchronizeHand(puzzle: &self)
        return cards
    }
    mutating func restoreTossCharges(_ count: Int) {
        tossChargesSpent = max(0, (tossChargesSpent ?? tossedThisPuzzle) - max(0, count))
    }
    mutating func spendTossCharge(countsAsTossedCard: Bool = true) {
        tossChargesSpent = (tossChargesSpent ?? tossedThisPuzzle) + 1
        if countsAsTossedCard { tossedThisPuzzle += 1 }
    }
}
