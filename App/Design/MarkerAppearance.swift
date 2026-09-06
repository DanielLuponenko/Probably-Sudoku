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
    ]

    static func forID(_ id: String) -> Self {
        catalog[id] ?? .init(hex: 0x8E8879, symbol: "questionmark")
    }
}
