import SwiftUI

// MARK: - Skins
//
// A skin is a set of materials, never a set of rules. Nothing here can change
// what a square is worth, hide a Given, or make a wrong placement look right —
// every skin has to keep the four things the board says: what was printed,
// what you wrote, what is selected, and what is wrong.

struct DeskSkin: Equatable {
    let id: String
    let dark: Color
    let mid: Color
    let light: Color

    var surface: some ShapeStyle {
        RadialGradient(colors: [light, dark],
                       center: .init(x: 0.35, y: 0.1),
                       startRadius: 40, endRadius: 900)
    }
}

struct PaperSkin: Equatable {
    let id: String
    let page: Color
    let warm: Color
    let edge: Color
    let grain: Double
    let treatment: PaperTreatment
}

/// A material treatment, not a gameplay state. It is shared by the live page
/// and shop preview so a purchased sheet never promises something it cannot do.
enum PaperTreatment: Equatable {
    case plain, graph, ledger, onionSkin, carbon, telegram
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
}

struct NumberSkin: Equatable {
    let id: String
    let design: Font.Design
    let ink: Color
    let givenInk: Color
    let motion: NumberMotion
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
    case press, typewriter, pencil, stencil, neon, handset

    var arrivalAnimation: Animation {
        switch self {
        case .press: .snappy(duration: 0.24, extraBounce: 0.08)
        case .typewriter: .easeOut(duration: 0.11)
        case .pencil: .easeOut(duration: 0.30)
        case .stencil: .easeIn(duration: 0.18)
        case .neon: .bouncy(duration: 0.34, extraBounce: 0.22)
        case .handset: .spring(response: 0.28, dampingFraction: 0.72)
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
        }
    }

    var arrivalOffset: CGFloat {
        switch self {
        case .press, .handset: 10
        case .typewriter: -7
        case .pencil: 5
        case .stencil: 0
        case .neon: 0
        }
    }

    var returnScale: CGFloat {
        switch self {
        case .pencil: 0.68
        case .stencil: 0.48
        case .neon: 0.38
        default: 0.52
        }
    }

    var returnRotation: Double {
        switch self {
        case .typewriter: 0
        case .pencil: 12
        case .stencil: -4
        case .neon: 0
        case .handset: -10
        case .press: -18
        }
    }

    var glow: Color? {
        self == .neon ? Color(hex: 0xD14E8C) : nil
    }
}

struct MarkerSkin: Equatable {
    let id: String
    /// The lead. What the margin notes and anything hand-written are in.
    let tint: Color
}

/// The five worn at once, resolved from ids exactly once and then read from
/// the environment.
struct CosmeticTheme: Equatable {
    var desk: DeskSkin
    var paper: PaperSkin
    var board: BoardSkin
    var numbers: NumberSkin
    var marker: MarkerSkin

    static let standard = CosmeticCatalog.theme(for: .starting)
}

extension EnvironmentValues {
    @Entry var cosmeticTheme: CosmeticTheme = .standard
}

// MARK: - The catalogue

enum CosmeticCatalog {

    static let items: [CosmeticItem] = [
        // Desk
        CosmeticItem(id: "dk_walnut", category: .desk, name: "Walnut", price: 0,
                     blurb: "The club's own desk. Dark, and older than you."),
        CosmeticItem(id: "dk_oak", category: .desk, name: "Pale Oak", price: 45,
                     blurb: "Lighter wood. The room reads as morning."),
        CosmeticItem(id: "dk_ebony", category: .desk, name: "Ebony", price: 70,
                     blurb: "Nearly black. Nothing on it argues with the page."),
        CosmeticItem(id: "dk_baize", category: .desk, name: "Green Baize", price: 90,
                     blurb: "Card-table felt. Slightly too pleased with itself."),
        // Paper
        CosmeticItem(id: "pp_newsprint", category: .paper, name: "Newsprint", price: 0,
                     blurb: "What the Book is printed on."),
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
        // Grid
        CosmeticItem(id: "bd_printed", category: .board, name: "Printed Rule", price: 0,
                     blurb: "Hairlines inside, heavy lines round the boxes."),
        CosmeticItem(id: "bd_fine", category: .board, name: "Fine Rule", price: 40,
                     blurb: "Thinner throughout. The numbers do the work."),
        CosmeticItem(id: "bd_heavy", category: .board, name: "Heavy Rule", price: 55,
                     blurb: "Struck hard. Every box is a box."),
        CosmeticItem(id: "bd_sage", category: .board, name: "Sage Rule", price: 75,
                     blurb: "Ruled in the club's own green."),
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
        // Pencil
        CosmeticItem(id: "pc_graphite", category: .marker, name: "Graphite", price: 0,
                     blurb: "A pencil. It has been sharpened twice."),
        CosmeticItem(id: "pc_red", category: .marker, name: "Red Pencil", price: 35,
                     blurb: "For marking other people's work."),
        CosmeticItem(id: "pc_blue", category: .marker, name: "Blue Pencil", price: 35,
                     blurb: "Editorial. Cuts things."),
        CosmeticItem(id: "pc_brass", category: .marker, name: "Brass Nib", price: 80,
                     blurb: "Ink, and no way to rub it out."),
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

    /// Everything priced at nothing. Owned from the first launch, because the
    /// desk cannot be bare while you save up for one.
    static let startingOwnedIDs: Set<String> = Set(items.filter(\.isDefault).map(\.id))

    // MARK: Resolving

    static func theme(for equipped: EquippedCosmetics) -> CosmeticTheme {
        CosmeticTheme(desk: desk(equipped.deskID),
                      paper: paper(equipped.paperID),
                      board: board(equipped.boardID),
                      numbers: numbers(equipped.numberID),
                      marker: marker(equipped.markerID))
    }

    static func desk(_ id: String) -> DeskSkin {
        switch id {
        case "dk_oak":
            return DeskSkin(id: id, dark: Color(hex: 0x4A3623), mid: Color(hex: 0x6B4F33),
                            light: Color(hex: 0x8A6941))
        case "dk_ebony":
            return DeskSkin(id: id, dark: Color(hex: 0x120F0D), mid: Color(hex: 0x201B18),
                            light: Color(hex: 0x2C2521))
        case "dk_baize":
            return DeskSkin(id: id, dark: Color(hex: 0x1B2A1E), mid: Color(hex: 0x2A3F2C),
                            light: Color(hex: 0x3A5539))
        default:
            return DeskSkin(id: "dk_walnut", dark: Paper.deskDark, mid: Paper.deskMid,
                            light: Paper.deskLight)
        }
    }

    static func paper(_ id: String) -> PaperSkin {
        switch id {
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
                             sameNumber: Paper.cellSameNumber)
        case "bd_heavy":
            return BoardSkin(id: id, hair: Paper.gridHair, bold: Color(hex: 0x1F1D1A),
                             hairWidth: 1.0, boldWidth: 3.2,
                             given: Paper.cellGiven, selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber)
        case "bd_sage":
            return BoardSkin(id: id, hair: Paper.sage.opacity(0.55), bold: Paper.sageDeep,
                             hairWidth: 0.75, boldWidth: 2.2,
                             given: Color(hex: 0xDDE2D2), selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber)
        default:
            return BoardSkin(id: "bd_printed", hair: Paper.gridHair, bold: Paper.gridBold,
                             hairWidth: 0.75, boldWidth: 2,
                             given: Paper.cellGiven, selected: Paper.cellSelected,
                             sameNumber: Paper.cellSameNumber)
        }
    }

    static func numbers(_ id: String) -> NumberSkin {
        switch id {
        case "nb_typewriter":
            return NumberSkin(id: id, design: .monospaced, ink: Paper.ink,
                              givenInk: Paper.inkSoft, motion: .typewriter, weightShift: 0)
        case "nb_schoolbook":
            return NumberSkin(id: id, design: .rounded, ink: Paper.pencil,
                              givenInk: Paper.pencil.opacity(0.72), motion: .pencil, weightShift: -1)
        case "nb_oldstyle":
            return NumberSkin(id: id, design: .serif, ink: Color(hex: 0x241F19),
                              givenInk: Paper.inkSoft, motion: .handset, weightShift: -1)
        case "nb_stencil":
            return NumberSkin(id: id, design: .monospaced, ink: Color(hex: 0x313A31),
                              givenInk: Color(hex: 0x657063), motion: .stencil, weightShift: 0)
        case "nb_neon":
            return NumberSkin(id: id, design: .rounded, ink: Color(hex: 0xB62F72),
                              givenInk: Color(hex: 0x81385E), motion: .neon, weightShift: 0)
        default:
            return NumberSkin(id: "nb_press", design: .default, ink: Paper.ink,
                              givenInk: Paper.inkSoft, motion: .press, weightShift: 0)
        }
    }

    static func marker(_ id: String) -> MarkerSkin {
        switch id {
        case "pc_red": return MarkerSkin(id: id, tint: Paper.redPencil)
        case "pc_blue": return MarkerSkin(id: id, tint: Color(hex: 0x53688C))
        case "pc_brass": return MarkerSkin(id: id, tint: Color(hex: 0x6E5324))
        default: return MarkerSkin(id: "pc_graphite", tint: Paper.pencil)
        }
    }
}
