import Foundation

public enum SkipError: Error, Equatable, Sendable {
    case cannotSkip
    case staleOffer
    case inventoryFull
    case invalidReplacement
}

/// An immutable claim for exactly one undealt ordinary Puzzle. Reading it
/// never advances any gameplay stream, including after a save is resumed.
public struct SkipOffer: Codable, Sendable, Equatable, Identifiable {
    public let level: Int
    public let slot: PuzzleSlot
    public let buffID: String
    public let id: UUID
    public var buff: ItemDef { Catalog.item(buffID)! }

    // This is a versioned reward table, deliberately independent of catalogue
    // ordering. Do not reorder or extend v1: existing Books keep their offers.
    private static let versionOneBuffIDs = [
        "bf_peek", "bf_redraw", "bf_overtime", "bf_double_down", "bf_insurance",
        "bf_second_print", "bf_lucky_dip", "bf_bird_seed", "bf_fresh_ink",
        "bf_litmus", "bf_paper_crane",
    ]

    // Frozen v2 table. Future catalogue additions require a new table/version.
    private static let versionTwoBuffIDs = [
        "bf_peek",
        "bf_redraw",
        "bf_overtime",
        "bf_double_down",
        "bf_insurance",
        "bf_second_print",
        "bf_lucky_dip",
        "bf_bird_seed",
        "bf_fresh_ink",
        "bf_litmus",
        "bf_paper_crane",
        "bf_index_request",
        "bf_careful_cut",
        "bf_eraser_shavings",
        "bf_collation",
        "bf_fair_exchange",
        "bf_inventory_count",
        "bf_proof_sheet",
        "bf_fold_test",
        "bf_rebind",
        "bf_transposition",
        "bf_passage",
        "bf_release_note",
        "bf_single_issue",
        "bf_reservation",
        "bf_counteroffer",
        "bf_supplement",
        "bf_free_press",
        "bf_detour",
        "bf_boss_draft",
        "bf_tight_deadline",
        "bf_collateral",
        "bf_exchange_rate",
        "bf_return_receipt",
        "bf_clean_finish",
        "bf_cross_cut",
        "bf_open_bracket",
        "bf_new_edition",
        "bf_carbon_receipt",
        "bf_rain_check"
    ]

    static func offer(seed: String, level: Int, slot: PuzzleSlot, version: Int = 1) -> Self {
        let rewardVersion = version >= 2 ? 2 : 1
        let ids = rewardVersion == 2 ? versionTwoBuffIDs : versionOneBuffIDs
        let domain = "skip.buff.v\(rewardVersion).\(level).\(slot.rawValue)"
        var stream = RandomStream(seed: seed, stream: domain)
        return Self(level: level, slot: slot,
                    buffID: ids[stream.int(ids.count)],
                    id: stableIdentity(seed: seed, domain: domain))
    }

    /// Instance identity is separate from the selected catalogue entry, so
    /// two rewards for the same Buff always remain separately selectable.
    static func stableIdentity(seed: String, domain: String) -> UUID {
        let words = cyrb128(seed + ":" + domain + ".identity")
        let hex = String(format: "%08x%08x%08x%08x", words.0, words.1, words.2, words.3)
        let chars = Array(hex)
        let text = String(chars[0..<8]) + "-" + String(chars[8..<12]) + "-"
            + String(chars[12..<16]) + "-" + String(chars[16..<20]) + "-" + String(chars[20..<32])
        return UUID(uuidString: text)!
    }
}

/// The reward and replacement are saved alongside the skipped position.
/// Legacy Clipping history stays in its original runItemState keys.
public struct SkipRecord: Codable, Sendable, Equatable, Identifiable {
    public let offer: SkipOffer
    public let replacedBuffID: UUID?
    public var id: UUID { offer.id }
    public var rewardID: UUID { offer.id }
    public var level: Int { offer.level }
    public var slot: PuzzleSlot { offer.slot }
    public var buffID: String { offer.buffID }
}
