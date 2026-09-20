import Foundation

/// One identity per Marker type, shared by the board, Shop and inspector.
/// Symbols supplement (not replace) color for color-vision accessibility.
struct MarkerAppearance {
    let hex: UInt32
    let symbol: String

    static let catalog: [String: MarkerAppearance] = [
        "mk_crimson": .init(hex: 0xB43143, symbol: "diamond.fill"),
        "mk_golden": .init(hex: 0xD4A329, symbol: "sun.max.fill"),
        "mk_azure": .init(hex: 0x258CC8, symbol: "drop.fill"),
        "mk_ivory": .init(hex: 0xEBDFB7, symbol: "shield.fill"),
        "mk_emerald": .init(hex: 0x427A32, symbol: "leaf.fill"),
        "mk_onyx": .init(hex: 0x34353E, symbol: "moon.fill"),
        "mk_silver": .init(hex: 0x9299A5, symbol: "circle.lefthalf.filled"),
        "mk_sapphire": .init(hex: 0x303A98, symbol: "triangle.fill"),
        "mk_rose": .init(hex: 0xD7769A, symbol: "heart.fill"),
        "mk_copper": .init(hex: 0x9C5A2E, symbol: "hexagon.fill"),
        "mk_violet": .init(hex: 0x854DB7, symbol: "star.fill"),
        "mk_jade": .init(hex: 0x129C90, symbol: "arrow.uturn.backward"),
        "mk_eraser": .init(hex: 0xB49353, symbol: "eraser"),
        "mk_exchange": .init(hex: 0x129C90, symbol: "arrow.left.arrow.right"),
        "mk_echo": .init(hex: 0x5146B9, symbol: "waveform"),
        "mk_prism": .init(hex: 0x854DB7, symbol: "circle.grid.cross.fill"),
        "mk_fork": .init(hex: 0x393BC0, symbol: "arrow.triangle.branch"),
        "mk_forecast": .init(hex: 0x9299A5, symbol: "eye"),
        "mk_escapement": .init(hex: 0x9C5A2E, symbol: "hourglass"),
        "mk_lamp": .init(hex: 0xD4A329, symbol: "lightbulb"),
        "mk_ledger": .init(hex: 0xD4A329, symbol: "equal"),
        "mk_umbrella": .init(hex: 0x427A32, symbol: "umbrella.fill"),
        "mk_hearth": .init(hex: 0xB43143, symbol: "flame.fill"),
        "mk_constellation": .init(hex: 0x854DB7, symbol: "sparkles"),
        "mk_rhythm": .init(hex: 0x9C5A2E, symbol: "metronome"),
        "mk_bridge": .init(hex: 0x427A32, symbol: "link"),
        "mk_crossroads": .init(hex: 0xB43143, symbol: "plus"),
        "mk_voucher": .init(hex: 0xD4A329, symbol: "ticket"),
        "mk_interest": .init(hex: 0xD4A329, symbol: "percent"),
        "mk_pledge": .init(hex: 0x9C5A2E, symbol: "arrow.down.circle"),
        "mk_collection": .init(hex: 0xD4A329, symbol: "tray.full"),
        "mk_debt": .init(hex: 0x34353E, symbol: "minus.circle"),
        "mk_stipend": .init(hex: 0x427A32, symbol: "banknote"),
        "mk_route": .init(hex: 0x129C90, symbol: "point.3.connected.trianglepath.dotted"),
        "mk_ladder": .init(hex: 0x9C5A2E, symbol: "ladder"),
        "mk_counterweight": .init(hex: 0x9299A5, symbol: "scalemass"),
        "mk_keystone": .init(hex: 0x427A32, symbol: "square.dashed"),
        "mk_finale": .init(hex: 0xB43143, symbol: "flag.checkered"),
        "mk_crosscheck": .init(hex: 0x258CC8, symbol: "checkmark.seal"),
        "mk_carbon": .init(hex: 0x34353E, symbol: "square.on.square"),
        "mk_pressmark": .init(hex: 0xB43143, symbol: "printer"),
        "mk_tiebreaker": .init(hex: 0x303A98, symbol: "checklist"),
        "mk_blotter": .init(hex: 0xC6A35C, symbol: "xmark.square"),
        "mk_patina": .init(hex: 0x9C5A2E, symbol: "spiral"),
        "mk_windlass": .init(hex: 0x9C5A2E, symbol: "gearshape"),
        "mk_beacon": .init(hex: 0xD4A329, symbol: "antenna.radiowaves.left.and.right"),
        "mk_sweep": .init(hex: 0x427A32, symbol: "paintbrush"),
        "mk_census": .init(hex: 0x9299A5, symbol: "number.circle"),
        "mk_bounty": .init(hex: 0x258CC8, symbol: "scope"),
        "mk_harvest": .init(hex: 0x427A32, symbol: "leaf"),
    ]

    static func forID(_ id: String) -> Self {
        catalog[id] ?? .init(hex: 0x8E8879, symbol: "questionmark")
    }
}
