import SwiftUI

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
    static let cellPeer = Color(hex: 0xE7E3D3)
    static let cellSameNumber = Color(hex: 0xDCDCC0)
    static let cellWrong = Color(hex: 0xE4C4B8)
    static let cellCleared = Color(hex: 0xCFDBC2)

    // MARK: Accents

    /// The sage of the CONTINUE button and the pencil.
    static let sage = Color(hex: 0x7C8C73)
    static let sageDeep = Color(hex: 0x66765E)
    static let coin = Color(hex: 0xE0B33C)
    static let coinRim = Color(hex: 0xA9801E)
    static let redPencil = Color(hex: 0xB4544A)

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
}

extension View {
    /// Uppercase, heavy, tightly tracked — the mockups' section headings.
    func pageHeading(_ size: CGFloat = 34) -> some View {
        self.font(Print.heading(size))
            .tracking(-0.5)
            .foregroundStyle(Paper.ink)
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
