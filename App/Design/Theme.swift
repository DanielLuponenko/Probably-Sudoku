import SwiftUI
import UIKit
import ProbablySudokuEngine

/// The whole game is one physical object: a sudoku book lying open on a desk.
/// Every colour here is a real material — stained wood, cream paper, printing
/// ink, a pencil, a brass token — and nothing is a UI colour. If a new value
/// does not name a material, the object is probably wrong.
enum Paper {

    // MARK: Desk

    static let deskDark = Color(hex: 0x261A13)
    static let deskMid = Color(hex: 0x3E2C20)
    static let deskLight = Color(hex: 0x4C3627)

    static var desk: some ShapeStyle {
        RadialGradient(colors: [deskLight, deskDark],
                       center: .init(x: 0.35, y: 0.1),
                       startRadius: 40, endRadius: 900)
    }

    // MARK: Page

    /// The printed page. Warm, slightly yellowed, never white.
    static let page = Color(hex: 0xEDE8DB)
    static let pageWarm = Color(hex: 0xE6E0D0)
    static let pageEdge = Color(hex: 0xD8D0BC)
    static let pageStack = Color(hex: 0xCFC6B0)
    static let coverBoard = Color(hex: 0x2B2724)

    // MARK: Ink

    static let ink = Color(hex: 0x2E2C28)
    static let inkSoft = Color(hex: 0x5E594F)
    static let inkFaint = Color(hex: 0x8E8879)
    static let rule = Color(hex: 0xB6AE9C)

    // MARK: Grid

    static let gridHair = Color(hex: 0x9E9788)
    static let gridBold = Color(hex: 0x393630)
    /// The soft olive wash the mockups use for a Given.
    static let cellGiven = Color(hex: 0xE0DCC4)
    static let cellSelected = Color(hex: 0xD3D9C2)
    /// Every copy of the number you are holding. This has to read instantly
    /// against the Givens wash, so it is a distinctly cooler green rather than
    /// another shade of olive.
    static let cellSameNumber = Color(hex: 0xB9CEAE)
    static let cellWrong = Color(hex: 0xE4C4B8)
    static let cellCleared = Color(hex: 0xCFDBC2)

    // MARK: Accents

    /// The sage of the CONTINUE button and the pencil.
    static let sage = Color(hex: 0x7C8C73)
    static let sageDeep = Color(hex: 0x66765E)
    static let coin = Color(hex: 0xE0B33C)
    static let coinRim = Color(hex: 0xA9801E)
    static let redPencil = Color(hex: 0xB4544A)
    /// Editorial blue stays a named ink rather than becoming an anonymous
    /// literal in a board treatment.
    static let editorBlue = Color(hex: 0x53688C)
    /// Graphite, for anything written by hand rather than printed.
    static let pencil = Color(hex: 0x5A5750)
    /// The first Book's accents: soft green and a warm orange.
    static let bookGreen = Color(hex: 0x7C8C73)
    static let bookOrange = Color(hex: 0xC8853F)

    /// The chapter tabs down the right edge of the book.
    static let tabs: [Color] = [
        Color(hex: 0xDCD98A), Color(hex: 0xB9C99A), Color(hex: 0xE8B45C),
        Color(hex: 0x8FC5DE), Color(hex: 0xE3A9A4),
    ]

    /// The twelve Marker colours (§11). Each is an ink, so each stays legible
    /// with the page behind it and with a number printed on top.
    static func markerColor(_ defID: String) -> Color {
        switch defID {
        case "mk_crimson": return Color(hex: 0xB4544A)
        case "mk_golden": return Color(hex: 0xD9A93C)
        case "mk_azure": return Color(hex: 0x6F9EC4)
        case "mk_ivory": return Color(hex: 0xDCD3BB)
        case "mk_emerald": return Color(hex: 0x6E9A6B)
        case "mk_onyx": return Color(hex: 0x59544D)
        case "mk_silver": return Color(hex: 0xAFAFA6)
        case "mk_sapphire": return Color(hex: 0x5A7BA8)
        case "mk_rose": return Color(hex: 0xC98F92)
        case "mk_copper": return Color(hex: 0xB07A4E)
        case "mk_violet": return Color(hex: 0x8E7BA8)
        case "mk_jade": return Color(hex: 0x77A08D)
        default: return inkFaint
        }
    }
}

// MARK: - Level palettes

/// Semantic inks for a Puzzle slot. Cosmetic themes choose the physical paper,
/// desk, typeface, and rule furniture; this palette is the Level's temperature
/// on top of those materials. The values are immutable so a page only updates
/// when it moves to another slot.
struct LevelPalette: Equatable {
    let id: String
    let paper: Color
    let ink: Color
    let rule: Color
    let accent: Color
    let danger: Color
    let given: Color
    let placed: Color
    let marked: Color
    let target: Color

    static let easy = LevelPalette(id: "easy",
                                   paper: Paper.page,
                                   ink: Paper.ink,
                                   rule: Paper.rule,
                                   accent: Paper.sageDeep,
                                   danger: Paper.redPencil,
                                   given: Paper.cellGiven,
                                   placed: Paper.ink,
                                   marked: Paper.sage,
                                   target: Paper.sage)
    static let medium = LevelPalette(id: "medium",
                                     paper: Color(hex: 0xE7DDC9),
                                     ink: Color(hex: 0x332A25),
                                     rule: Color(hex: 0xA99B85),
                                     accent: Color(hex: 0x87613B),
                                     danger: Paper.redPencil,
                                     given: Color(hex: 0xDDD0B4),
                                     placed: Color(hex: 0x332A25),
                                     marked: Color(hex: 0xA56B3A),
                                     target: Color(hex: 0x785538))
    static let boss = LevelPalette(id: "boss",
                                   paper: Color(hex: 0xE7E1D4),
                                   ink: Color(hex: 0x29302C),
                                   rule: Color(hex: 0x938B7C),
                                   accent: Color(hex: 0x65765D),
                                   danger: Paper.redPencil,
                                   given: Color(hex: 0xD7D5B8),
                                   placed: Color(hex: 0x29302C),
                                   marked: Color(hex: 0x6E825F),
                                   target: Color(hex: 0x5A6B52))

    static func forSlot(_ slot: PuzzleSlot) -> LevelPalette {
        switch slot {
        case .easy: return .easy
        case .medium: return .medium
        case .boss: return .boss
        }
    }

    /// A Level palette supplies the puzzle's temperature; the selected stock
    /// supplies contrast. The Night Sky paper is dark, so every semantic ink
    /// needs to invert together rather than fixing only the grid numerals.
    func resolved(for paper: PaperSkin) -> LevelPalette {
        guard paper.isDark else { return self }
        return LevelPalette(id: id,
                            paper: paper.ink,
                            ink: paper.ink,
                            rule: paper.ruleInk,
                            accent: paper.accentInk,
                            danger: Color(hex: 0xF2A39B),
                            given: Color(hex: 0x294568),
                            placed: paper.ink,
                            marked: Color(hex: 0xA6CFA4),
                            target: Paper.sage)
    }

    /// Lets the local screenshot harness compare the three Level treatments on
    /// the same puzzle. Only Debug simulator builds accept the override.
    static func forDisplay(slot: PuzzleSlot) -> LevelPalette {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let index = arguments.firstIndex(of: "-qaPalette"), index + 1 < arguments.count {
            switch arguments[index + 1] {
            case "easy": return .easy
            case "medium": return .medium
            case "boss": return .boss
            default: break
            }
        }
        #endif
        return forSlot(slot)
    }
}

extension EnvironmentValues {
    @Entry var levelPalette: LevelPalette = .easy
}

// MARK: - Type

/// Printed, not rendered: headings are letterpress-heavy and tightly set, body
/// text is quiet, and numbers are wide enough to read at a glance in a grid.
enum Print {
    static func heading(_ size: CGFloat) -> Font { .system(size: size, weight: .black) }
    static func subheading(_ size: CGFloat) -> Font { .system(size: size, weight: .bold) }
    static func body(_ size: CGFloat) -> Font { .system(size: size, weight: .regular) }
    static func caption(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
    /// Numbers on the board and in the Hand.
    static func numeral(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
    static func handwritten(_ size: CGFloat) -> Font { .custom("Bradley Hand", size: size) }
}

extension Print {
    static func clubTitle(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .serif).width(.condensed)
    }

    static func menuAction(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy).width(.condensed)
    }
}

extension View {
    /// Uppercase, heavy, tightly tracked — the mockups' section headings.
    func pageHeading(_ size: CGFloat = 34) -> some View {
        modifier(ThemedPageHeading(size: size))
    }
}

private struct ThemedPageHeading: ViewModifier {
    @Environment(\.cosmeticTheme) private var theme
    var size: CGFloat

    func body(content: Content) -> some View {
        content.font(Print.heading(size))
            .tracking(-0.5)
            .foregroundStyle(theme.paper.ink)
            .textCase(.uppercase)
    }
}

// MARK: - Materials

extension View {
    /// The soft inner shadow a page picks up towards the spine.
    func pageShading(spineOnLeft: Bool = true) -> some View {
        overlay {
            LinearGradient(
                colors: [Color.black.opacity(0.16), .clear, .clear, Color.black.opacity(0.05)],
                startPoint: spineOnLeft ? .leading : .trailing,
                endPoint: spineOnLeft ? .trailing : .leading
            )
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
    }
}

/// Deterministic paper grain. Drawn once into an image and reused, because a
/// fresh Canvas per frame is the sort of thing that quietly costs 8ms.
struct PaperGrain: View {
    var opacity: Double = 0.055
    var seed: UInt64 = 7

    var body: some View {
        Canvas { context, size in
            var state = seed &* 6364136223846793005 &+ 1442695040888963407
            func nextUnit() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }
            let fleckCount = Int(size.width * size.height / 900)
            for _ in 0..<fleckCount {
                let x = nextUnit() * size.width
                let y = nextUnit() * size.height
                let r = 0.4 + nextUnit() * 1.5
                let dark = nextUnit() < 0.55
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(dark ? .black.opacity(0.5) : .white.opacity(0.7))
                )
            }
        }
        .opacity(opacity)
        .blendMode(.plusDarker)
        .allowsHitTesting(false)
    }
}

// MARK: - Colour helper

extension Color {
    /// `Color.mix(with:by:)` is newer than the app's iOS 17 target.
    func mixed(with other: Color, by amount: Double) -> Color {
        let t = min(max(amount, 0), 1)
        let a = UIColor(self).rgba, b = UIColor(other).rgba
        return Color(.sRGB,
                     red: a.r + (b.r - a.r) * t,
                     green: a.g + (b.g - a.g) * t,
                     blue: a.b + (b.b - a.b) * t,
                     opacity: a.a + (b.a - a.a) * t)
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

private extension UIColor {
    var rgba: (r: Double, g: Double, b: Double, a: Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b), Double(a))
    }
}
