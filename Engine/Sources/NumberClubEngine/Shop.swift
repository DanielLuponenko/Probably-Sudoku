import Foundation

/// §9 — the Shop opens after every Puzzle. Stock is always five items:
/// 2 Bookmarks, 2 Markers, 1 Buff.
public struct ShopOffer: Codable, Sendable, Identifiable {
    /// Which of the five slots this offer sits in. Two offers in one Shop can
    /// share a `defID` — a second Golden Marker is a real purchase — so the
    /// slot, not the item id, is what addresses an offer.
    public let slot: Int
    public let defID: String
    public let price: Int
    public var sold: Bool = false

    public var id: Int { slot }
    public var def: ItemDef { Catalog.item(defID)! }
}

public struct ShopState: Codable, Sendable {
    public var offers: [ShopOffer]
    public var rerollCost: Int
    public var rerollsUsed: Int

    /// §9 — 2 coins, rising by 1 with each reroll in the same Shop. Auction
    /// Notices makes the first reroll of every Shop free.
    public static let firstRerollCost = 2
}

public enum Shop {

    /// §9 — the stock's shape never changes, only what fills it.
    static let composition: [(ItemKind, Int)] = [(.bookmark, 2), (.marker, 2), (.buff, 1)]

    /// §9 — rarity odds shift as the Book goes on.
    public static func rarityOdds(level: Int) -> [(Rarity, Double)] {
        switch level {
        case ...3: return [(.common, 0.70), (.uncommon, 0.25), (.rare, 0.05)]
        case 4...6: return [(.common, 0.55), (.uncommon, 0.33), (.rare, 0.12)]
        default: return [(.common, 0.45), (.uncommon, 0.35), (.rare, 0.20)]
        }
    }

    /// §9 — prices, rolled within a band.
    public static func priceBand(_ kind: ItemKind, _ rarity: Rarity) -> ClosedRange<Int> {
        switch (kind, rarity) {
        case (.bookmark, .common): return 4...5
        case (.bookmark, .uncommon): return 6...7
        case (.bookmark, .rare): return 7...8
        case (.marker, .common): return 5...6
        case (.marker, .uncommon): return 7...7
        case (.marker, .rare): return 8...9
        case (.buff, .common): return 3...3
        case (.buff, .uncommon): return 4...4
        case (.buff, .rare): return 4...4
        }
    }

    static func rollRarity(_ rng: inout RandomStream, level: Int) -> Rarity {
        let roll = rng.next()
        var cumulative = 0.0
        for (rarity, weight) in rarityOdds(level: level) {
            cumulative += weight
            if roll < cumulative { return rarity }
        }
        return .common
    }

    /// Picks one item of `kind`, dropping a rarity tier if the rolled tier has
    /// nothing left to offer (§9).
    static func rollOffer(_ rng: inout RandomStream,
                          slot: Int,
                          kind: ItemKind,
                          level: Int,
                          excluding taken: Set<String>) -> ShopOffer? {
        let rolled = rollRarity(&rng, level: level)
        // Drop one tier at a time: rare -> uncommon -> common.
        let ladder: [Rarity]
        switch rolled {
        case .rare: ladder = [.rare, .uncommon, .common]
        case .uncommon: ladder = [.uncommon, .common]
        case .common: ladder = [.common, .uncommon, .rare]
        }

        for rarity in ladder {
            let pool = Catalog.items(of: kind, rarity: rarity).filter { !taken.contains($0.id) }
            guard let pick = rng.pick(pool) else { continue }
            return ShopOffer(slot: slot, defID: pick.id,
                             price: rng.int(in: priceBand(kind, rarity)))
        }
        return nil
    }

    /// Bookmarks the player already owns are never offered again (§9). Markers and
    /// Buffs can repeat — a second Golden Marker is a real purchase.
    static func excluded(for run: RunState) -> Set<String> {
        Set(run.bookmarks.map(\.defID))
    }

    public static func stock(_ run: inout RunState) -> ShopState {
        var offers: [ShopOffer] = []
        var taken = excluded(for: run)
        for (kind, count) in composition {
            for _ in 0..<count {
                guard let offer = rollOffer(&run.streams.shop, slot: offers.count, kind: kind,
                                            level: run.level, excluding: taken) else { continue }
                offers.append(offer)
                // Do not offer the same Bookmark twice in one Shop.
                if kind == .bookmark { taken.insert(offer.defID) }
            }
        }
        return ShopState(offers: offers,
                         rerollCost: firstRerollCost(for: run),
                         rerollsUsed: 0)
    }

    static func firstRerollCost(for run: RunState) -> Int {
        run.owns(bookmark: Bookmarks.auctionNotices) ? 0 : ShopState.firstRerollCost
    }

    public enum ShopError: Error, Equatable, Sendable {
        case notEnoughCoins, alreadySold, noSuchOffer, slotsFull, noShopOpen
    }

    /// Opens the Shop between Puzzles.
    public static func open(_ run: inout RunState) {
        run.shop = stock(&run)
    }

    public static func reroll(_ run: inout RunState) throws {
        guard let shop = run.shop else { throw ShopError.noShopOpen }
        guard run.coins >= shop.rerollCost else { throw ShopError.notEnoughCoins }
        run.coins -= shop.rerollCost
        let used = shop.rerollsUsed + 1
        var fresh = stock(&run)
        fresh.rerollsUsed = used
        // 2 coins, then 3, then 4… within this Shop. Auction Notices only ever
        // discounts the first reroll, so subsequent ones climb from the base.
        fresh.rerollCost = ShopState.firstRerollCost + used - (run.owns(bookmark: Bookmarks.auctionNotices) ? 1 : 0)
        run.shop = fresh
    }

    public static func buy(_ run: inout RunState, slot: Int) throws {
        guard var shop = run.shop else { throw ShopError.noShopOpen }
        guard let index = shop.offers.firstIndex(where: { $0.slot == slot }) else {
            throw ShopError.noSuchOffer
        }
        guard !shop.offers[index].sold else { throw ShopError.alreadySold }
        let offer = shop.offers[index]
        guard run.coins >= offer.price else { throw ShopError.notEnoughCoins }

        let def = offer.def
        switch def.kind {
        case .bookmark:
            guard run.bookmarks.count < ItemKind.bookmark.capacity else { throw ShopError.slotsFull }
            run.bookmarks.append(OwnedBookmark(defID: def.id, boughtAtLevel: run.level, pricePaid: offer.price))
        case .marker:
            guard run.markers.count < ItemKind.marker.capacity else { throw ShopError.slotsFull }
            run.markers.append(OwnedMarker(defID: def.id, boughtAtLevel: run.level, pricePaid: offer.price))
        case .buff:
            guard run.buffs.count < ItemKind.buff.capacity else { throw ShopError.slotsFull }
            run.buffs.append(OwnedBuff(defID: def.id, pricePaid: offer.price))
        }

        run.coins -= offer.price
        shop.offers[index].sold = true
        run.shop = shop
    }

    // MARK: - Selling and Marker squares

    public static func sellBookmark(_ run: inout RunState, at index: Int) {
        guard run.bookmarks.indices.contains(index) else { return }
        run.coins += RunState.sellValue(pricePaid: run.bookmarks[index].pricePaid)
        run.bookmarks.remove(at: index)
    }
    public static func sellMarker(_ run: inout RunState, at index: Int) {
        guard run.markers.indices.contains(index) else { return }
        run.coins += RunState.sellValue(pricePaid: run.markers[index].pricePaid)
        run.markers.remove(at: index)
    }
    public static func sellBuff(_ run: inout RunState, at index: Int) {
        guard run.buffs.indices.contains(index) else { return }
        run.coins += RunState.sellValue(pricePaid: run.buffs[index].pricePaid)
        run.buffs.remove(at: index)
    }

    public enum MarkerError: Error, Equatable, Sendable {
        case noSuchMarker, squareTaken, noPendingSquares, notEnoughCoins, squareNotOwned
    }

    /// §11 — claim a square the Marker is entitled to. Free.
    public static func claimSquare(_ run: inout RunState, markerIndex: Int, square: Square) throws {
        guard run.markers.indices.contains(markerIndex) else { throw MarkerError.noSuchMarker }
        guard run.markers[markerIndex].pendingSquares(atLevel: run.level) > 0 else {
            throw MarkerError.noPendingSquares
        }
        guard run.squareIsFree(square) else { throw MarkerError.squareTaken }
        run.markers[markerIndex].squares.append(square)
    }

    /// §8 — moving an already-placed square costs 2 coins.
    public static func moveSquare(_ run: inout RunState, markerIndex: Int,
                                  from old: Square, to new: Square) throws {
        guard run.markers.indices.contains(markerIndex) else { throw MarkerError.noSuchMarker }
        guard let position = run.markers[markerIndex].squares.firstIndex(of: old) else {
            throw MarkerError.squareNotOwned
        }
        guard run.squareIsFree(new) else { throw MarkerError.squareTaken }
        guard run.coins >= RunState.moveSquareCost else { throw MarkerError.notEnoughCoins }
        run.coins -= RunState.moveSquareCost
        run.markers[markerIndex].squares[position] = new
    }
}
