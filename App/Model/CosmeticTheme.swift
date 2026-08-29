import SwiftUI

// MARK: - Skins
//
// A skin is a set of materials, never a set of rules. Nothing here can change
// what a square is worth, hide a Given, or make a wrong placement look right —
// every skin has to keep the four things the board says: what was printed,
// what you wrote, what is selected, and what is wrong.

struct PaperSkin: Equatable {
    let id: String
    let page: Color
    let warm: Color
    let edge: Color
    let grain: Double
    let treatment: PaperTreatment

    /// Page copy is a property of the stock, not a global colour. Most sheets
    /// are dark ink on cream; Night Sky is the deliberate inverse.
    var ink: Color { treatment == .nightSky ? Color(hex: 0xFFF9E7) : Paper.ink }
    var softInk: Color { treatment == .nightSky ? Color(hex: 0xDCE6F2) : Paper.inkSoft }
    var faintInk: Color { treatment == .nightSky ? Color(hex: 0xAABDD2) : Paper.inkFaint }
    var ruleInk: Color { treatment == .nightSky ? Color(hex: 0xC6D6E7) : Paper.rule }
    var accentInk: Color { treatment == .nightSky ? Color(hex: 0xE6C671) : Paper.sageDeep }
    var isDark: Bool { treatment == .nightSky }

    func handwritingInk(_ selectedMarker: Color) -> Color {
        isDark ? Color(hex: 0xE6C671) : selectedMarker
    }
}

/// A material treatment, not a gameplay state. It is shared by the live page
/// and shop preview so a purchased sheet never promises something it cannot do.
enum PaperTreatment: Equatable {
    case plain, freshWhite, utilityRoll, graph, ledger, onionSkin, carbon, telegram
    case garden, nightSky, ocean
}

/// The physical finish carried by the live puzzle rule. Shop samples consume
/// this same value, so an animated rule cannot exist only on the sales counter.
enum BoardFinish: Equatable {
    case printed, fine, heavy, sage, blueprint, gilt, laser

    var dash: [CGFloat] {
        switch self {
        case .blueprint: [4, 2]
        case .gilt: [8, 1.5]
        default: []
        }
    }

    var glowColor: Color? {
        switch self {
        case .laser: Color(hex: 0x5EF4E7)
        case .gilt: Color(hex: 0xD6A84E)
        default: nil
        }
    }

    var isAnimated: Bool { self == .laser }
}

struct BoardSkin: Equatable {
    let id: String
    let hair: Color
    let bold: Color
    let hairWidth: CGFloat
    let boldWidth: CGFloat
    let given: Color
    let selected: Color
    let sameNumber: Color
    let finish: BoardFinish
}

/// Surface treatment for the glyph itself. Every option remains an individual
/// numeral; this never substitutes a keycap, ball, machine, or prop for a digit.
enum NumberFinish: Equatable {
    case press, typewriter, graphite, woodType, stencil, neon, laser, flame

    var glowColor: Color? {
        switch self {
        case .neon: Color(hex: 0xE14B9A)
        case .laser: Color(hex: 0x59F5E8)
        case .flame: Color(hex: 0xFF7B2C)
        default: nil
        }
    }

    var isAnimated: Bool {
        switch self {
        case .neon, .laser, .flame: true
        default: false
        }
    }
}

struct NumberSkin: Equatable {
    let id: String
    let design: Font.Design
    let ink: Color
    let givenInk: Color
    let motion: NumberMotion
    let finish: NumberFinish
    /// Some faces sit heavier than the press, so each carries its own trim.
    let weightShift: Int

    func font(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: shifted(weight), design: design).monospacedDigit()
    }

    private func shifted(_ weight: Font.Weight) -> Font.Weight {
        let ladder: [Font.Weight] = [.light, .regular, .medium, .semibold, .bold, .heavy, .black]
        let at = ladder.firstIndex(of: weight) ?? 1
        return ladder[min(max(at + weightShift, 0), ladder.count - 1)]
    }
}

/// The physical way a numeral reaches and leaves the paper. It affects only
/// presentation transforms; the board, hit targets, and rules never change.
enum NumberMotion: Equatable {
    case press, typewriter, pencil, stencil, neon, handset, laser, flame

    var arrivalAnimation: Animation {
        switch self {
        case .press: .snappy(duration: 0.24, extraBounce: 0.08)
        case .typewriter: .easeOut(duration: 0.11)
        case .pencil: .easeOut(duration: 0.30)
        case .stencil: .easeIn(duration: 0.18)
        case .neon: .bouncy(duration: 0.34, extraBounce: 0.22)
        case .handset: .spring(response: 0.28, dampingFraction: 0.72)
        case .laser: .snappy(duration: 0.20, extraBounce: 0.04)
        case .flame: .bouncy(duration: 0.30, extraBounce: 0.14)
        }
    }

    var arrivalScale: CGFloat {
        switch self {
        case .press: 0.72
        case .typewriter: 1.12
        case .pencil: 0.92
        case .stencil: 1.04
        case .neon: 0.62
        case .handset: 0.76
        case .laser: 0.70
        case .flame: 0.66
        }
    }

    var arrivalOffset: CGFloat {
        switch self {
        case .press, .handset, .flame: 10
        case .typewriter: -7
        case .pencil: 5
        case .stencil, .neon, .laser: 0
        }
    }

    var returnScale: CGFloat {
        switch self {
        case .pencil: 0.68
        case .stencil: 0.48
        case .neon, .laser, .flame: 0.38
        default: 0.52
        }
    }

    var returnRotation: Double {
        switch self {
        case .typewriter: 0
        case .pencil: 12
        case .stencil: -4
        case .neon, .laser: 0
        case .flame: 6
        case .handset: -10
        case .press: -18
        }
    }

}

/// The three equipped page treatments, resolved once and read from the
/// environment by gameplay and every preview.
struct CosmeticTheme: Equatable {
    var paper: PaperSkin
    var board: BoardSkin
    var numbers: NumberSkin

    static let standard = CosmeticCatalog.theme(for: .starting)
}

extension EnvironmentValues {
    @Entry var cosmeticTheme: CosmeticTheme = .standard
}

// MARK: - The catalogue

enum CosmeticCatalog {

    static let items: [CosmeticItem] = [
        // Paper
        CosmeticItem(id: "pp_newsprint", category: .paper, name: "Newsprint", price: 0,
                     blurb: "What the Book is printed on."),
        CosmeticItem(id: "pp_white", category: .paper, name: "Fresh White", price: 35,
                     blurb: "A new sheet. Suspiciously uncreased."),
        CosmeticItem(id: "pp_ivory", category: .paper, name: "Ivory Laid", price: 40,
                     blurb: "Heavier stock. Takes ink well."),
        CosmeticItem(id: "pp_manila", category: .paper, name: "Manila", price: 60,
                     blurb: "Filed, not published."),
        CosmeticItem(id: "pp_ledger", category: .paper, name: "Ledger Blue", price: 85,
                     blurb: "Accountancy paper. It expects you to add up."),
        CosmeticItem(id: "pp_graph", category: .paper, name: "Graph", price: 55,
                     blurb: "Engineer’s stock. Every square is already squared."),
        CosmeticItem(id: "pp_onion", category: .paper, name: "Onion Skin", price: 70,
                     blurb: "Thin enough for yesterday’s puzzle to show through."),
        CosmeticItem(id: "pp_carbon", category: .paper, name: "Carbon", price: 80,
                     blurb: "A second impression, slightly out of register."),
        CosmeticItem(id: "pp_telegram", category: .paper, name: "Telegram", price: 95,
                     blurb: "Yellow tape from a machine that never sleeps."),
        CosmeticItem(id: "pp_garden", category: .paper, name: "Garden", price: 100,
                     blurb: "Ivy round the edges. The numbers still have nowhere to hide."),
        CosmeticItem(id: "pp_night_sky", category: .paper, name: "Night Sky", price: 100,
                     blurb: "A quiet sky. The grid is the constellation."),
        CosmeticItem(id: "pp_ocean", category: .paper, name: "Ocean", price: 100,
                     blurb: "Sea-glass paper and a tide that minds its own business."),
        CosmeticItem(id: "pp_utility_roll", category: .paper, name: "Utility Roll", price: 110,
                     blurb: "Two-ply optimism. Perforated between difficult decisions."),
        // Grid
        CosmeticItem(id: "bd_printed", category: .board, name: "Printed Rule", price: 0,
                     blurb: "Hairlines inside, heavy lines round the boxes."),
        CosmeticItem(id: "bd_fine", category: .board, name: "Fine Rule", price: 40,
                     blurb: "Thinner throughout. The numbers do the work."),
        CosmeticItem(id: "bd_heavy", category: .board, name: "Heavy Rule", price: 55,
                     blurb: "Struck hard. Every box is a box."),
        CosmeticItem(id: "bd_sage", category: .board, name: "Sage Rule", price: 75,
                     blurb: "Ruled in the club's own green."),
        CosmeticItem(id: "bd_blueprint", category: .board, name: "Blueprint", price: 80,
                     blurb: "Drafting dashes, measured twice."),
        CosmeticItem(id: "bd_gilt", category: .board, name: "Gilt Rule", price: 95,
                     blurb: "A brass line where plain ink would have done."),
        CosmeticItem(id: "bd_laser", category: .board, name: "Laser Grid", price: 120,
                     blurb: "Cyan light rules the page, then politely holds still."),
        // Numbers
        CosmeticItem(id: "nb_press", category: .numbers, name: "Press", price: 0,
                     blurb: "The face the Book is set in."),
        CosmeticItem(id: "nb_typewriter", category: .numbers, name: "Typewriter", price: 50,
                     blurb: "Struck one at a time, by something with keys."),
        CosmeticItem(id: "nb_schoolbook", category: .numbers, name: "Pencil", price: 50,
                     blurb: "Graphite, soft at the edge, almost erasable."),
        CosmeticItem(id: "nb_oldstyle", category: .numbers, name: "Handset", price: 70,
                     blurb: "Wood type, big and just a little uneven."),
        CosmeticItem(id: "nb_stencil", category: .numbers, name: "Stencil", price: 65,
                     blurb: "Cut out, then sprayed into the square."),
        CosmeticItem(id: "nb_neon", category: .numbers, name: "Neon Sign", price: 90,
                     blurb: "The one loud thing in an otherwise quiet room."),
        CosmeticItem(id: "nb_laser", category: .numbers, name: "Laser Cut", price: 120,
                     blurb: "A clean cyan edge, drawn through the digit itself."),
        CosmeticItem(id: "nb_flame", category: .numbers, name: "Hot Type", price: 135,
                     blurb: "Individual figures cast hot, with the embers left on."),
    ]

    static func items(in category: CosmeticCategory) -> [CosmeticItem] {
        items.filter { $0.category == category }
    }

    static func item(_ id: String) -> CosmeticItem? {
        items.first { $0.id == id }
    }

    static func defaultID(for category: CosmeticCategory) -> String {
        items(in: category).first { $0.isDefault }?.id ?? items(in: category)[0].id
    }

    /// Everything priced at nothing. Owned from the first launch so every
    /// active page slot always has a valid treatment.
    static let startingOwnedIDs: Set<String> = Set(items.filter(\.isDefault).map(\.id))

    // MARK: Resolving

    static func theme(for equipped: EquippedCosmetics) -> CosmeticTheme {
        let selectedPaper = paper(equipped.paperID)
        let selectedBoard = board(equipped.boardID)
        let selectedNumbers = numbers(equipped.numberID)
        return CosmeticTheme(paper: selectedPaper,
                             board: nightAdjusted(selectedBoard, on: selectedPaper),
                             numbers: nightAdjusted(selectedNumbers, on: selectedPaper))
    }

    /// Night Sky is the one dark stock. Keep the player's chosen rule weight
    /// and numeral face, but invert their inks so it stays a theme, not an
    /// accessibility regression.
    private static func nightAdjusted(_ skin: BoardSkin, on paper: PaperSkin) -> BoardSkin {
        guard paper.treatment == .nightSky else { return skin }
        return BoardSkin(id: skin.id,
                         hair: Color.white.opacity(0.42), bold: Color(hex: 0xE6C671),
                         hairWidth: skin.hairWidth, boldWidth: skin.boldWidth,
                         given: Color(hex: 0x294568), selected: Color(hex: 0x3D5F80),
                         sameNumber: Color(hex: 0x2E486D), finish: skin.finish)
    }

    private static func nightAdjusted(_ skin: NumberSkin, on paper: PaperSkin) -> NumberSkin {
        guard paper.treatment == .nightSky else { return skin }
        return NumberSkin(id: skin.id, design: skin.design, ink: Color(hex: 0xFFF9E7),
                          givenInk: Color(hex: 0xE6C671), motion: skin.motion,
                          finish: skin.finish, weightShift: skin.weightShift)
    }

    static func paper(_ id: String) -> PaperSkin {
        switch id {
        case "pp_white":
            return PaperSkin(id: id, page: Color(hex: 0xFCFBF6), warm: Color(hex: 0xF4F2EA),
                             edge: Color(hex: 0xE7E4DB), grain: 0.018, treatment: .freshWhite)
        case "pp_ivory":
            return PaperSkin(id: id, page: Color(hex: 0xF4EFE2), warm: Color(hex: 0xEDE7D6),
                             edge: Color(hex: 0xDED6C1), grain: 0.04, treatment: .plain)
        case "pp_manila":
            return PaperSkin(id: id, page: Color(hex: 0xE4D3AE), warm: Color(hex: 0xDCCAA3),
                             edge: Color(hex: 0xC9B78E), grain: 0.07, treatment: .plain)
        case "pp_ledger":
            return PaperSkin(id: id, page: Color(hex: 0xE2E6E2), warm: Color(hex: 0xD8DDDA),
                             edge: Color(hex: 0xC4CCC8), grain: 0.05, treatment: .ledger)
        case "pp_graph":
            return PaperSkin(id: id, page: Color(hex: 0xE5EDF0), warm: Color(hex: 0xD8E4E8),
                             edge: Color(hex: 0xC5D5DA), grain: 0.035, treatment: .graph)
        case "pp_onion":
            return PaperSkin(id: id, page: Color(hex: 0xF0E8D7), warm: Color(hex: 0xE7DCC5),
                             edge: Color(hex: 0xD9CDB5), grain: 0.025, treatment: .onionSkin)
        case "pp_carbon":
            return PaperSkin(id: id, page: Color(hex: 0xE5DFE8), warm: Color(hex: 0xDCD3E1),
                             edge: Color(hex: 0xC9BED0), grain: 0.06, treatment: .carbon)
        case "pp_telegram":
            return PaperSkin(id: id, page: Color(hex: 0xEFE0A7), warm: Color(hex: 0xE5D397),
                             edge: Color(hex: 0xCEBD7B), grain: 0.045, treatment: .telegram)
        case "pp_garden":
            return PaperSkin(id: id, page: Color(hex: 0xF3EBD5), warm: Color(hex: 0xE9DFC1),
                             edge: Color(hex: 0xB8A87D), grain: 0.048, treatment: .garden)
        case "pp_night_sky":
            return PaperSkin(id: id, page: Color(hex: 0x172B49), warm: Color(hex: 0x12233D),
                             edge: Color(hex: 0x927B44), grain: 0.038, treatment: .nightSky)
        case "pp_ocean":
            return PaperSkin(id: id, page: Color(hex: 0xD9EDF0), warm: Color(hex: 0xC7E3E8),
                             edge: Color(hex: 0x8DB9C4), grain: 0.035, treatment: .ocean)
        case "pp_utility_roll":
            return PaperSkin(id: id, page: Color(hex: 0xF3F0E6), warm: Color(hex: 0xE8E3D6),
                             edge: Color(hex: 0xD2CCBD), grain: 0.075, treatment: .utilityRoll)
        default:
            return PaperSkin(id: "pp_newsprint", page: Paper.page, warm: Paper.pageWarm,
                             edge: Paper.pageEdge, grain: 0.055, treatment: .plain)
        }
    }

    static func board(_ id: String) -> BoardSkin {
        switch id {
        case "bd_fine":
            return BoardSkin(id: id, hair: Paper.gridHair.opacity(0.7), bold: Paper.inkSoft,
                             hairWidth: 0.5, boldWidth: 1.4,
                             given: Paper.cellGiven, selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber, finish: .fine)
        case "bd_heavy":
            return BoardSkin(id: id, hair: Paper.gridHair, bold: Color(hex: 0x1F1D1A),
                             hairWidth: 1.0, boldWidth: 3.2,
                             given: Paper.cellGiven, selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber, finish: .heavy)
        case "bd_sage":
            return BoardSkin(id: id, hair: Paper.sage.opacity(0.55), bold: Paper.sageDeep,
                             hairWidth: 0.75, boldWidth: 2.2,
                             given: Color(hex: 0xDDE2D2), selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber, finish: .sage)
        case "bd_blueprint":
            return BoardSkin(id: id, hair: Color(hex: 0x5683A0).opacity(0.60),
                             bold: Color(hex: 0x315E7C), hairWidth: 0.7, boldWidth: 2.0,
                             given: Color(hex: 0xD9E7ED), selected: Color(hex: 0xC5DEE7),
                             sameNumber: Color(hex: 0xCEE4EA), finish: .blueprint)
        case "bd_gilt":
            return BoardSkin(id: id, hair: Color(hex: 0xA77B3D).opacity(0.66),
                             bold: Color(hex: 0x80602F), hairWidth: 0.8, boldWidth: 2.3,
                             given: Color(hex: 0xEEE4CD), selected: Color(hex: 0xE8D8B7),
                             sameNumber: Color(hex: 0xF0E2C5), finish: .gilt)
        case "bd_laser":
            return BoardSkin(id: id, hair: Color(hex: 0x4ADACF).opacity(0.78),
                             bold: Color(hex: 0x2AAFA8), hairWidth: 0.72, boldWidth: 2.15,
                             given: Color(hex: 0xD8F1ED), selected: Color(hex: 0xB8E8E3),
                             sameNumber: Color(hex: 0xC5EFEA), finish: .laser)
        default:
            return BoardSkin(id: "bd_printed", hair: Paper.gridHair, bold: Paper.gridBold,
                             hairWidth: 0.75, boldWidth: 2,
                             given: Paper.cellGiven, selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber, finish: .printed)
        }
    }

    static func numbers(_ id: String) -> NumberSkin {
        switch id {
        case "nb_typewriter":
            return NumberSkin(id: id, design: .monospaced, ink: Paper.ink,
                              givenInk: Paper.inkSoft, motion: .typewriter,
                              finish: .typewriter, weightShift: 0)
        case "nb_schoolbook":
            return NumberSkin(id: id, design: .rounded, ink: Paper.pencil,
                              givenInk: Paper.pencil.opacity(0.72), motion: .pencil,
                              finish: .graphite, weightShift: -1)
        case "nb_oldstyle":
            return NumberSkin(id: id, design: .serif, ink: Color(hex: 0x241F19),
                              givenInk: Paper.inkSoft, motion: .handset,
                              finish: .woodType, weightShift: -1)
        case "nb_stencil":
            return NumberSkin(id: id, design: .monospaced, ink: Color(hex: 0x313A31),
                              givenInk: Color(hex: 0x657063), motion: .stencil,
                              finish: .stencil, weightShift: 0)
        case "nb_neon":
            return NumberSkin(id: id, design: .rounded, ink: Color(hex: 0xB62F72),
                              givenInk: Color(hex: 0x81385E), motion: .neon,
                              finish: .neon, weightShift: 0)
        case "nb_laser":
            return NumberSkin(id: id, design: .monospaced, ink: Color(hex: 0x148D88),
                              givenInk: Color(hex: 0x23726F), motion: .laser,
                              finish: .laser, weightShift: 0)
        case "nb_flame":
            return NumberSkin(id: id, design: .serif, ink: Color(hex: 0xB63B20),
                              givenInk: Color(hex: 0x853323), motion: .flame,
                              finish: .flame, weightShift: 1)
        default:
            return NumberSkin(id: "nb_press", design: .default, ink: Paper.ink,
                              givenInk: Paper.inkSoft, motion: .press,
                              finish: .press, weightShift: 0)
        }
    }
}
