import Foundation

/// Shop-only Buff effects use the Shop stream and retain the visit's ordinary
/// stock/payment lifecycle. These helpers do not publish partial Runs.
public enum BuffShop {
    public static let definitions: Set<String> = [Buffs.singleIssue, Buffs.reservation,
        Buffs.counteroffer, Buffs.freePress, Buffs.newEdition]

    static func hasLaterShop(_ run: RunState) -> Bool {
        // The Shop after Level 9's medium Puzzle leads directly to the final
        // boss, which has no Shop after it. Reserving there could never pay out.
        run.level < 9 || (run.level == 9 && run.slot == .easy)
    }

    static func offers(in run: RunState) -> [ShopOffer] {
        run.shop?.offers.filter { !$0.sold } ?? []
    }

    static func alternatives(to offer: ShopOffer, run: RunState) -> [ItemDef] {
        let otherStock = Set((run.shop?.offers ?? []).filter { $0.slot != offer.slot && !$0.sold }
            .filter { $0.def.kind == .bookmark || $0.def.kind == .marker }.map(\.defID))
        return Catalog.items(of: offer.def.kind, rarity: offer.def.rarity).filter {
            $0.id != offer.defID && !otherStock.contains($0.id)
                && ($0.kind != .bookmark || !run.owns(bookmark: $0.id))
        }
    }

    static func editionAlternatives(_ bookmark: OwnedBookmark, run: RunState) -> [ItemDef] {
        Catalog.items(of: .bookmark, rarity: bookmark.def.rarity).filter {
            $0.id != bookmark.defID && !run.owns(bookmark: $0.id)
        }
    }

    public static func options(_ definition: String, run: RunState, consuming sourceID: UUID? = nil) -> [BuffOption] {
        guard let shop = run.shop, run.outcome == nil else { return [] }
        switch definition {
        case Buffs.singleIssue:
            return offers(in: run).filter { !alternatives(to: $0, run: run).isEmpty }.map {
                BuffOption("offer.\($0.slot)", $0.def.name, .offer($0.slot))
            }
        case Buffs.reservation:
            guard run.buffState.reservation == nil, run.buffState.reservationIntent == nil,
                  hasLaterShop(run) else { return [] }
            return offers(in: run).map { BuffOption("offer.\($0.slot)", "\($0.def.name) · \($0.price) coins", .offer($0.slot)) }
        case Buffs.counteroffer:
            guard !run.buffState.counterofferVisits.contains(shop.visitID ?? -1) else { return [] }
            return offers(in: run).filter { $0.def.kind == .marker && $0.price > 1 }.map {
                BuffOption("offer.\($0.slot)", "\($0.def.name) · \(max(1, $0.price - 4)) coins", .offer($0.slot))
            }
        case Buffs.freePress:
            guard run.buffState.freePressVisit != shop.visitID || run.buffState.freePressSource == nil else { return [] }
            return [BuffOption("use", "Up to 6 coins off the next paid Reroll", .none)]
        case Buffs.newEdition:
            let afterCost = BuffRuntime.prospectiveConsumption(sourceID: sourceID, definition: definition, run: run)
            return run.bookmarks.filter {
                BookmarkMechanics.canRemove(id: $0.id, run: afterCost) && !editionAlternatives($0, run: run).isEmpty
            }.map { BuffOption($0.id.uuidString, $0.def.name, .bookmark($0.id)) }
        default: return []
        }
    }

    /// Returns false for a Reservation intent: its held copy is consumed only
    /// by leave(), after the selected unsold offer is revalidated.
    static func apply(_ definition: String, source: OwnedBuff, choice: BuffChoice,
                      run: inout RunState) throws -> Bool {
        guard var shop = run.shop else { throw BuffUseError.unavailable }
        guard options(definition, run: run, consuming: source.id).contains(where: { $0.choice == choice }) else {
            throw BuffUseError.invalidChoice
        }
        if shop.visitID == nil { shop.visitID = run.nextShopVisitID(); run.shop = shop }
        let visit = shop.visitID!
        switch (definition, choice) {
        case (Buffs.singleIssue, .offer(let slot)):
            guard let index = shop.offers.firstIndex(where: { $0.slot == slot && !$0.sold }),
                  let replacement = run.streams.shop.pick(alternatives(to: shop.offers[index], run: run)) else {
                throw BuffUseError.noLegalTarget
            }
            shop.offers[index] = ShopOffer(slot: slot, defID: replacement.id, price: replacement.listedPrice)
            if run.buffState.reservation?.destinationVisit == visit,
               run.buffState.reservation?.destinationSlot == slot {
                // Choosing to transform the reserved offer replaces that
                // exact physical offer, so the old reservation cannot return.
                run.buffState.reservation = nil
            }
            run.buffState.stockRevision += 1
        case (Buffs.reservation, .offer(let slot)):
            guard let offer = shop.offers.first(where: { $0.slot == slot && !$0.sold }) else {
                throw BuffUseError.noLegalTarget
            }
            run.buffState.reservationIntent = BuffReservationIntent(sourceBuff: source.id,
                context: BuffRuntime.context(run), slot: slot, definition: offer.defID, price: offer.price)
            return false
        case (Buffs.counteroffer, .offer(let slot)):
            guard let index = shop.offers.firstIndex(where: { $0.slot == slot && !$0.sold }) else {
                throw BuffUseError.noLegalTarget
            }
            let offer = shop.offers[index]
            shop.offers[index] = ShopOffer(slot: slot, defID: offer.defID, price: max(1, offer.price - 4))
            run.buffState.counterofferVisits.insert(visit)
            run.buffState.stockRevision += 1
        case (Buffs.freePress, .none):
            run.buffState.freePressVisit = visit
            run.buffState.freePressSource = source.id
        case (Buffs.newEdition, .bookmark(let id)):
            guard let index = run.bookmarks.firstIndex(where: { $0.id == id }),
                  let replacement = run.streams.shop.pick(editionAlternatives(run.bookmarks[index], run: run)) else {
                throw BuffUseError.noLegalTarget
            }
            var afterCost = BuffRuntime.prospectiveConsumption(sourceID: source.id, definition: definition, run: run)
            guard BookmarkMechanics.retire(id: id, run: &afterCost) else { throw BuffUseError.unavailable }
            // `perform` owns this value transaction. Its subsequent consume
            // hook records the actual source once; no intermediate copy escapes.
            run = afterCost
            run.buffState.transformationSerial += 1
            let fresh = OwnedBookmark(defID: replacement.id, boughtAtLevel: run.level, pricePaid: 0,
                id: SkipOffer.stableIdentity(seed: run.seed,
                    domain: "buff.new-edition.v1.\(visit).\(run.buffState.transformationSerial).\(source.id)"))
            run.bookmarks.insert(fresh, at: min(index, run.bookmarks.count))
            // Unsold copies of a now-owned Bookmark cease to be offers. A
            // sold stamp preserves slot addressing and cannot grant a reward.
            for i in shop.offers.indices where shop.offers[i].defID == fresh.defID {
                shop.offers[i].sold = true
            }
            run.buffState.stockRevision += 1
        default: throw BuffUseError.invalidChoice
        }
        run.shop = shop
        return true
    }

    public static func rerollPrice(_ run: RunState, ordinaryCost: Int? = nil) -> Int {
        guard let shop = run.shop else { return 0 }
        let credit = run.buffState.freePressVisit == shop.visitID && run.buffState.freePressSource != nil ? 6 : 0
        return max(0, (ordinaryCost ?? shop.rerollCost) - credit)
    }

    /// Call once after validating payment, before replacing stock. The normal
    /// Shop code still increments its undiscounted regular Reroll counter.
    public static func willReroll(_ run: inout RunState, ordinaryCost: Int? = nil) {
        if let shop = run.shop, (ordinaryCost ?? shop.rerollCost) > 0,
           run.buffState.freePressVisit == shop.visitID {
            run.buffState.freePressSource = nil
            run.buffState.freePressVisit = nil
        }
        run.buffState.reservationIntent = nil
        run.buffState.stockRevision += 1
    }

    /// Called after the new Shop has its final visit ID. The Supplement is
    /// initial-stock only; a carried reservation also survives ordinary rerolls.
    public static func didOpen(_ run: inout RunState, initialStock: Bool) {
        guard var shop = run.shop, let visit = shop.visitID else { return }
        if var reservation = run.buffState.reservation {
            if reservation.destinationVisit == nil { reservation.destinationVisit = visit }
            if reservation.destinationVisit == visit {
                let owned = reservation.category == .bookmark && run.owns(bookmark: reservation.definition)
                if owned { run.buffState.reservation = nil }
                else if let i = shop.offers.firstIndex(where: { $0.def.kind == reservation.category }) {
                    let slot = shop.offers[i].slot
                    // Remove same-stock duplicates without manufacturing a
                    // second reserved slot. Ordinary stock may be exhausted.
                    for j in shop.offers.indices where j != i && shop.offers[j].defID == reservation.definition {
                        var exclusions = Shop.excluded(for: run)
                        exclusions.formUnion(shop.offers.filter { $0.slot != shop.offers[j].slot }.map(\.defID))
                        if let replacement = Shop.rollOffer(&run.streams.shop, slot: shop.offers[j].slot,
                            kind: reservation.category, level: run.level, excluding: exclusions) {
                            shop.offers[j] = replacement
                        } else { shop.offers[j].sold = true }
                    }
                    shop.offers[i] = ShopOffer(slot: slot, defID: reservation.definition, price: reservation.price)
                    reservation.destinationSlot = slot
                    run.buffState.reservation = reservation
                }
            }
        }
        if initialStock, let kind = run.buffState.supplement {
            var exclusions = Shop.excluded(for: run)
            exclusions.formUnion(shop.offers.filter { $0.def.kind == .bookmark || $0.def.kind == .marker }.map(\.defID))
            if let offer = Shop.rollOffer(&run.streams.shop, slot: (shop.offers.map(\.slot).max() ?? -1) + 1,
                                          kind: kind, level: run.level, excluding: exclusions) {
                shop.offers.append(offer)
            }
            run.buffState.supplement = nil
        }
        run.shop = shop
    }

    public static func didBuy(slot: Int, run: inout RunState) {
        if run.buffState.reservation?.destinationVisit == run.shop?.visitID,
           run.buffState.reservation?.destinationSlot == slot { run.buffState.reservation = nil }
        if run.buffState.reservationIntent?.slot == slot { run.buffState.reservationIntent = nil }
        run.buffState.stockRevision += 1
    }

    /// Run on the same copied Run as the actual Shop departure. Merely opening
    /// a panel or cancelling a page turn does not spend Reservation.
    public static func leave(_ run: inout RunState) {
        guard let shop = run.shop else { return }
        if run.buffState.reservation?.destinationVisit == shop.visitID { run.buffState.reservation = nil }
        if let intent = run.buffState.reservationIntent,
           let index = run.buffs.firstIndex(where: { $0.id == intent.sourceBuff && $0.defID == Buffs.reservation }),
           let offer = shop.offers.first(where: { $0.slot == intent.slot && !$0.sold }),
           offer.defID == intent.definition, offer.price == intent.price,
           run.buffState.reservation == nil, hasLaterShop(run) {
            let consumed = run.buffs.remove(at: index)
            run.buffState.reservation = BuffReservation(definition: offer.defID, price: offer.price,
                category: offer.def.kind, sourceVisit: shop.visitID ?? 0)
            BookmarkMechanics.buffConsumed(consumed, run: &run)
        }
        run.buffState.reservationIntent = nil
        run.buffState.freePressVisit = nil
        run.buffState.freePressSource = nil
    }

    public static func cancelReservation(_ run: inout RunState) { run.buffState.reservationIntent = nil }
}
