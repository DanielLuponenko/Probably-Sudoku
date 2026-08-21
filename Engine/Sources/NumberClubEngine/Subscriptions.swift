import Foundation

/// §14 — expensive, run-scoped upgrades. Unlike held items, Subscriptions do
/// not consume a Bookmark, Marker, or Buff slot and can never be sold.
public enum Subscriptions {
    public static let homeDelivery = "sub_home_delivery"
    public static let weekendEdition = "sub_weekend_edition"
    public static let wireService = "sub_wire_service"
    public static let clippingService = "sub_clipping_service"
    public static let tradeJournal = "sub_trade_journal"
    public static let annualRate = "sub_annual_rate"
    public static let overseasEdition = "sub_overseas_edition"

    private static func subscription(_ id: String, _ name: String, _ price: Int, _ text: String) -> ItemDef {
        ItemDef(id: id, kind: .subscription, name: name, rarity: .rare,
                listedPrice: price, text: text)
    }

    public static let all: [ItemDef] = [
        subscription(homeDelivery, "Home Delivery", 12, "+1 Hand size for this Book"),
        subscription(weekendEdition, "Weekend Edition", 14, "+1 Turn every Puzzle this Book"),
        subscription(wireService, "Wire Service", 14, "+2 Tosses every Puzzle this Book"),
        subscription(clippingService, "Clipping Service", 16, "Shops stock 6 items this Book"),
        subscription(tradeJournal, "Trade Journal", 16, "+10% Rare odds in every Shop this Book"),
        subscription(annualRate, "Annual Rate", 18, "Interest cap becomes 20 this Book"),
        subscription(overseasEdition, "Overseas Edition", 20, "+1 Marker slot for this Book"),
    ]
}

public struct OwnedSubscription: Codable, Sendable, Identifiable {
    public let defID: String
    public let pricePaid: Int
    public var id: String { defID }
    public var def: ItemDef { Catalog.item(defID)! }

    public init(defID: String, pricePaid: Int) {
        self.defID = defID
        self.pricePaid = pricePaid
    }
}
