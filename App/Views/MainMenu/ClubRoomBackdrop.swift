import SwiftUI

/// The materials the room is made of. Named after the thing, the way the rest
/// of the game names colours — there is no `primaryBackground` here, because
/// there is no primary background: there is plaster, and there is walnut.
enum ClubRoomMaterial {
    static let plaster = Color(hex: 0xB49470)
    static let plasterLit = Color(hex: 0xDAC49B)
    static let plasterDeep = Color(hex: 0x6E5A42)

    /// Walnut, in the four values every wooden thing in the room is built from.
    static let walnutLit = Color(hex: 0x8A5C33)
    static let walnut = Color(hex: 0x5C3B20)
    static let walnutDeep = Color(hex: 0x38220F)

    static let lampEnamel = Color(hex: 0x2E3A28)
    static let lampEnamelLit = Color(hex: 0x5B6E4E)
    static let brass = Color(hex: 0x8A6429)
    static let brassLit = Color(hex: 0xC79B4C)
    static let bulb = Color(hex: 0xFFD889)
    static let bulbCore = Color(hex: 0xFFF0C2)
    static let tape = Color(hex: 0x899674)
    static let leaf = Color(hex: 0x3E5A38)
    static let leafLit = Color(hex: 0x789A5E)
    static let leafDeep = Color(hex: 0x22331F)
    static let stoneware = Color(hex: 0xBFB39A)
    static let rug = Color(hex: 0x6B5537)

    /// The one lighting colour the design adds. Everything warm in the room is
    /// this, at some opacity.
    static let lampWarm = Color(red: 0.96, green: 0.75, blue: 0.40)
}
/// Whether a piece of commissioned room art has been added to the catalogue.
/// Nothing uses it and nothing needs to: the room is drawn, the way the Book
/// is drawn, so it relights and rescales per device and weighs nothing.
@MainActor
enum RoomArt {
    private static var known: [String: Bool] = [:]

    static func has(_ name: String) -> Bool {
        if let answer = known[name] { return answer }
        let answer = UIImage(named: name) != nil
        known[name] = answer
        return answer
    }
}

// MARK: - Depth kit
//
// Three things make a drawn object read as a photographed one, and all three
// live here rather than being reinvented per prop: the tight dark ellipse
// where it meets the surface, the dark seam in every gap, and a bevel that is
// light on the lamp's side and dark on the other.

/// Where an object touches the thing it stands on. Tighter and darker than the
/// object's own drop shadow, and the single strongest cue that it is resting
/// on a surface rather than pasted over one.
struct ContactShadow: View {
    var width: CGFloat
    var depth: CGFloat
    var opacity: Double = 0.6
    /// The lamp is up and to the left, so the shadow falls right.
    var lean: CGFloat = 0.10

    var body: some View {
        Ellipse()
            .fill(RadialGradient(colors: [.black.opacity(opacity),
                                          .black.opacity(opacity * 0.35), .clear],
                                 center: .center, startRadius: 0, endRadius: width / 2))
            .frame(width: width, height: depth)
            .offset(x: width * lean)
            .blur(radius: max(2, depth * 0.32))
            .allowsHitTesting(false)
    }
}

/// The shadow an object standing on the desk puts on the desk.
///
/// Belongs to the *scene*, not to the object: a shadow drawn inside a board's
/// own stack knows where the board is but not where the desk is, so it lands
/// wherever the board's frame happens to end. Placed here, its top edge is the
/// contact plane itself, which is what stops a strip of wall showing between a
/// thing and the surface it is standing on.
///
/// Dark and tight where the object meets the wood, opening out and fading as
/// it leaves — and leaning down and to the right, because the lamp is up and
/// to the left, like everything else in this room.
struct DeskContactShadow: View {
    /// The object's footprint on the desk.
    var width: CGFloat
    var scale: CGFloat

    private var depth: CGFloat { max(4, width * 0.20) }

    var body: some View {
        ZStack(alignment: .top) {
            // The cast: broad, weak, and thrown away from the lamp.
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(0.34), .clear],
                                     center: .center, startRadius: 0,
                                     endRadius: width * 0.55))
                .frame(width: width * 1.22, height: depth * 1.9)
                .offset(x: depth * 0.55, y: -depth * 0.35)
                .blur(radius: max(2, depth * 0.30))

            // The seam: almost black, and no wider than the foot itself.
            Ellipse()
                .fill(RadialGradient(colors: [.black.opacity(0.86),
                                              .black.opacity(0.30), .clear],
                                     center: .center, startRadius: 0,
                                     endRadius: width * 0.42))
                .frame(width: width * 0.99, height: depth * 0.72)
                .offset(x: depth * 0.18, y: -depth * 0.30)
                .blur(radius: max(0.8, depth * 0.10))
        }
        .frame(width: width * 1.3, height: depth * 1.6, alignment: .top)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Where to put it: its top edge sits on the contact plane.
    static func height(for width: CGFloat) -> CGFloat { max(4, width * 0.20) * 1.6 }
}

extension View {
    /// A lit edge on the lamp's side and a dark one opposite. Every solid in
    /// the room wears this, which is what stops them reading as flat colour.
    func bevel<S: InsettableShape>(_ shape: S, width: CGFloat = 1.2,
                                   light: Double = 0.28, dark: Double = 0.38) -> some View {
        overlay {
            shape.strokeBorder(
                LinearGradient(colors: [.white.opacity(light), .clear, .black.opacity(dark)],
                               startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: width)
        }
    }
}

// MARK: - Layers 01 to 07

/// Everything behind the interface: wall, desk, cabinet, shelf and props. The
/// light the lamp *casts* is a separate layer, because it has to fall on the
/// plaque and the board, which are drawn above this.
struct ClubRoomBackdrop: View {
    var metrics: MainMenuSceneMetrics
    var reduceMotion: Bool

    private var scale: CGFloat { metrics.scale }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // 00 — the room with the light off.
            Paper.deskDark.ignoresSafeArea()

            // 01 — plaster.
            wall

            // 03 — the wall taking the lamp's light. Broad and shapeless: this
            // is bounce, not the beam.
            RadialGradient(
                stops: [
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.46), location: 0),
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.22), location: 0.24),
                    .init(color: ClubRoomMaterial.lampWarm.opacity(0.06), location: 0.60),
                    .init(color: .clear, location: 1),
                ],
                center: UnitPoint(x: metrics.bulbCentre.x / metrics.width,
                                  y: metrics.bulbCentre.y / metrics.height),
                startRadius: 4, endRadius: metrics.width * 1.05
            )
            .blendMode(.plusLighter)
            .ignoresSafeArea()

            // The key. One gradient over wall, desk and props alike, so the
            // room is lit as one place rather than as a stack of correctly
            // shaded objects.
            LinearGradient(stops: [
                .init(color: .white.opacity(0.12), location: 0),
                .init(color: .clear, location: 0.40),
                .init(color: .black.opacity(0.10), location: 0.74),
                .init(color: .black.opacity(0.26), location: 1),
            ], startPoint: .topLeading, endPoint: .bottomTrailing)
            .blendMode(.overlay)
            .ignoresSafeArea()

            // 02 — the desk, then the things standing on it. In that order,
            // because that is the order they exist in: nothing on a desk is
            // behind the desk.
            deskAndCabinet

            // 07 — the shelf corner and the books, with their feet on the
            // same plane as everything else.
            rightProps

            // 04 — the fixture itself. Its own sheen does not move: what the
            // eye reads as the lamp breathing is the halo above it, which is
            // drawn by `BulbGlow` and is animatable.
            SwayingLampFixture(
                ceilingDrop: max(0, metrics.lampFrame.minY - metrics.wallPlane.minY),
                isEnabled: !reduceMotion)
                .frame(width: metrics.lampFrame.width, height: metrics.lampFrame.height)
                .position(x: metrics.lampFrame.midX, y: metrics.lampFrame.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var wall: some View {
        ZStack {
            LinearGradient(
                colors: [ClubRoomMaterial.plasterLit, ClubRoomMaterial.plaster,
                         ClubRoomMaterial.plasterDeep],
                startPoint: .topLeading, endPoint: .bottom
            )
            PlasterSurface()

            // Everything away from the lamp falls off. Without this the wall
            // is evenly lit, which is the one thing a single bulb cannot do.
            LinearGradient(colors: [.clear, .black.opacity(0.16), .black.opacity(0.38)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            // The wall meets the desk in shadow, not in a line.
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [.clear, .black.opacity(0.34)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 30 * scale)
            }
        }
        .frame(height: metrics.cabinetTop + 4)
        .frame(maxWidth: .infinity, alignment: .top)
        .ignoresSafeArea(edges: .top)
    }

    private var deskAndCabinet: some View {
        DeskAndDrawers(metrics: metrics)
            .ignoresSafeArea()
    }

    @ViewBuilder
    private var rightProps: some View {
        let rect = metrics.rightPropsFrame
        RightShelf(scale: scale, reduceMotion: reduceMotion,
                   showBooks: !metrics.isVeryCompact)
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
    }
}

// MARK: - Layers 16 to 18

/// What the room puts in front of the interface: a leaf too close to be in
/// focus, the rug, the shade at the corners, and the grain that ties the whole
/// picture together. All of it is depth, and none of it can be touched.
struct ClubRoomForeground: View {
    var metrics: MainMenuSceneMetrics
    var reduceMotion: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if !metrics.isVeryCompact {
                ForegroundLeaf()
                    .frame(width: metrics.width * 0.48, height: metrics.width * 0.40)
                    .offset(x: -metrics.width * 0.12,
                            y: metrics.height - metrics.width * 0.34)
                    // Nearest the camera, so it travels furthest — and still
                    // only by two and a half points.
            }

            RugEdge()
                .frame(height: max(18, metrics.height * 0.055))
                .frame(maxHeight: .infinity, alignment: .bottom)

            vignette

            // One grain over everything, at the end. A photograph has a single
            // grain structure; a picture whose parts each have their own reads
            // as a collage, which is exactly what a drawn room must not.
            FilmGrain()
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// Shade at the edges, so the eye is left in the middle of the room.
    private var vignette: some View {
        RadialGradient(
            stops: [
                .init(color: .clear, location: 0.34),
                .init(color: .black.opacity(0.18), location: 0.72),
                .init(color: .black.opacity(0.52), location: 1),
            ],
            center: .init(x: 0.46, y: 0.42),
            startRadius: metrics.width * 0.18, endRadius: metrics.height * 0.76
        )
        .blendMode(.multiply)
    }
}

/// Film grain, drawn once and left there. Deterministic, so it never crawls.
private struct FilmGrain: View {
    var body: some View {
        Canvas { context, size in
            var state: UInt64 = 424243
            func unit() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }
            let width = Double(size.width)
            let height = Double(size.height)
            let count = Int(width * height / 420)
            for _ in 0..<count {
                let x: Double = unit() * width
                let y: Double = unit() * height
                let r: Double = 0.5 + unit() * 1.1
                let dark = unit() < 0.55
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                    with: .color(dark ? .black.opacity(0.30) : .white.opacity(0.22)))
            }
        }
        .opacity(0.5)
        .blendMode(.overlay)
        .allowsHitTesting(false)
    }
}

// MARK: - Plaster

/// Fine surface variation and a few settled cracks. Drawn once into a Canvas:
/// the wall never changes, so this costs one pass and then nothing.
private struct PlasterSurface: View {
    var body: some View {
        Canvas { context, size in
            var state: UInt64 = 20260821
            func unit() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }
            let width = Double(size.width)
            let height = Double(size.height)

            // Trowel mottling: broad, soft, almost invisible one patch at a
            // time, and the whole reason plaster does not look like a gradient.
            for _ in 0..<140 {
                let x: Double = unit() * width
                let y: Double = unit() * height
                let r: Double = 20 + unit() * 90
                let dark = unit() < 0.5
                context.fill(
                    Path(ellipseIn: CGRect(x: x - r, y: y - r * 0.55,
                                           width: r * 2, height: r * 1.1)),
                    with: .color(dark ? .black.opacity(0.030) : .white.opacity(0.034)))
            }

            // Three cracks. A wall with a crack in it is a room; a wall with
            // twenty is a disaster area. Each is drawn twice — a dark line and
            // a bright one a hair below it — because a crack in plaster is a
            // groove with a lit lower lip, not a pen stroke.
            for index in 0..<3 {
                var path = Path()
                var x: Double = width * (0.18 + Double(index) * 0.31)
                var y: Double = -6
                path.move(to: CGPoint(x: x, y: y))
                let length: Double = height * (0.20 + unit() * 0.28)
                while y < length {
                    y += 12 + unit() * 22
                    x += (unit() - 0.5) * 16
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                context.stroke(path, with: .color(.black.opacity(0.16)),
                               lineWidth: 0.7 + unit() * 0.6)
                context.translateBy(x: 0.8, y: 0.8)
                context.stroke(path, with: .color(.white.opacity(0.07)), lineWidth: 0.6)
                context.translateBy(x: -0.8, y: -0.8)
            }

            // Grit.
            let flecks = Int(width * height / 2400)
            for _ in 0..<flecks {
                let x: Double = unit() * width
                let y: Double = unit() * height
                let r: Double = 0.5 + unit() * 1.2
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(unit() < 0.5 ? .black.opacity(0.11)
                                                       : .white.opacity(0.11)))
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Walnut

/// A wooden face. Grain runs the long way, darkens away from the lamp, and
/// carries the pores that stop stained walnut reading as brown paper.
struct WoodFace: View {
    var light: Color = ClubRoomMaterial.walnutLit
    var mid: Color = ClubRoomMaterial.walnut
    var dark: Color = ClubRoomMaterial.walnutDeep
    var vertical: Bool = false
    var seed: UInt64 = 11
    /// Grain lines bunching up towards the far edge, for a surface seen at an
    /// angle rather than head on.
    var recede: Bool = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [light, mid, dark],
                           startPoint: vertical ? .top : .topLeading,
                           endPoint: vertical ? .bottom : .bottomTrailing)
            Grain(vertical: vertical, seed: seed, recede: recede)
            // Varnish: a broad, weak sheen from the lamp's quarter.
            LinearGradient(colors: [.white.opacity(0.10), .clear, .clear],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .blendMode(.plusLighter)
        }
    }

    private struct Grain: View {
        var vertical: Bool
        var seed: UInt64
        var recede: Bool

        var body: some View {
            Canvas { context, size in
                var state = seed &* 2654435761 &+ 17
                func unit() -> Double {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    return Double(state >> 11) / Double(UInt64(1) << 53)
                }
                let width = Double(size.width)
                let height = Double(size.height)
                let span: Double = vertical ? width : height
                let run: Double = vertical ? height : width

                var offset: Double = 0
                while offset < span {
                    var path = Path()
                    var cursor: Double = offset
                    var along: Double = -20
                    path.move(to: point(along, cursor))
                    while along < run + 20 {
                        along += 40
                        cursor += (unit() - 0.5) * 4.4
                        path.addLine(to: point(along, cursor))
                    }
                    let shade: Double = 0.06 + unit() * (recede ? 0.22 : 0.16)
                    context.stroke(path, with: .color(.black.opacity(shade)),
                                   lineWidth: 0.5 + unit() * 1.8)
                    // A lit lip under the deeper lines: that is what a pore is.
                    if unit() < 0.3 {
                        context.translateBy(x: 0, y: 0.7)
                        context.stroke(path, with: .color(.white.opacity(0.05)), lineWidth: 0.5)
                        context.translateBy(x: 0, y: -0.7)
                    }
                    // Head on, the lines are evenly spaced. Seen at an angle,
                    // they crowd towards the far edge.
                    let openness: Double = recede ? 0.25 + (offset / span) * 1.6 : 1
                    offset += (3 + unit() * 11) * openness
                }
            }
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }

        private func point(_ along: Double, _ across: Double) -> CGPoint {
            vertical ? CGPoint(x: across, y: along) : CGPoint(x: along, y: across)
        }
    }
}

/// The desk top, its near edge, and the bank of drawers below it.
///
/// The top surface is the piece the screen was missing: without a plane for
/// things to stand on, every object on the desk is a sticker on a wall. It is
/// a separate face from the drawers, lit differently, with its grain crowding
/// towards the back and a bullnose edge catching the lamp along the front.
private struct DeskAndDrawers: View {
    var metrics: MainMenuSceneMetrics

    private var scale: CGFloat { metrics.scale }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // The carcass, from under the bullnose to the floor.
            ZStack {
                WoodFace(light: Color(hex: 0x5C3D25), mid: Color(hex: 0x3D2714),
                         dark: Color(hex: 0x23150A), seed: 71)
                LinearGradient(colors: [.clear, .black.opacity(0.48)],
                               startPoint: .center, endPoint: .bottom)
            }
            .frame(height: max(0, metrics.height + metrics.safeArea.bottom - metrics.drawerTop))
            .offset(y: metrics.drawerTop)

            // The drawers, each in the rect the controls are mounted to. One
            // source of geometry: the drawer a panel sits on and the panel
            // itself cannot disagree about where it is.
            drawer(metrics.drawerOneRect)
            drawer(metrics.drawerTwoRect)

            // The top, seen at a shallow angle. Drawn over the carcass so its
            // near edge overhangs the drawers, the way a worktop does.
            deskTop
                .frame(height: metrics.deskSurfaceHeight)
                .offset(y: metrics.deskBackY)

            bullnose
                .frame(height: metrics.deskEdgeHeight)
                .offset(y: metrics.deskEdgeY)
        }
        .frame(width: metrics.width, height: metrics.height, alignment: .topLeading)
    }

    private func drawer(_ rect: CGRect) -> some View {
        DrawerFront(scale: scale)
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
    }

    private var deskTop: some View {
        ZStack {
            WoodFace(light: Color(hex: 0x9A6B3D), mid: Color(hex: 0x6D4726),
                     dark: Color(hex: 0x452B16), vertical: false, seed: 83,
                     recede: true)
            // Dark where it meets the wall, then opening out into the light as
            // it comes towards the reader. This band is the only horizontal
            // plane on the screen, so it is the one thing telling the eye
            // where the floor of the picture is.
            LinearGradient(stops: [
                .init(color: .black.opacity(0.62), location: 0),
                .init(color: .black.opacity(0.06), location: 0.34),
                .init(color: .clear, location: 0.60),
                .init(color: ClubRoomMaterial.lampWarm.opacity(0.16), location: 1),
            ], startPoint: .top, endPoint: .bottom)
            // The lamp is off to the left, so the near left corner of the desk
            // is the brightest wood in the room.
            RadialGradient(colors: [ClubRoomMaterial.lampWarm.opacity(0.22), .clear],
                           center: .init(x: 0.18, y: 0.9),
                           startRadius: 2, endRadius: 260)
                .blendMode(.plusLighter)
        }
    }

    /// The rounded front edge: a lit top and the face turning under it.
    private var bullnose: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Color(hex: 0xA9764A), Color(hex: 0x7A5230)],
                           startPoint: .top, endPoint: .bottom)
                .frame(maxHeight: .infinity)
            LinearGradient(colors: [Color(hex: 0x60401F), Color(hex: 0x3A2411)],
                           startPoint: .top, endPoint: .bottom)
                .frame(maxHeight: .infinity)
        }
        .overlay(alignment: .bottom) {
            // Where the overhang meets the drawers below it.
            LinearGradient(colors: [.black.opacity(0.62), .clear],
                           startPoint: .bottom, endPoint: .top)
                .frame(height: metrics.deskEdgeHeight * 0.5)
        }
    }
}

/// One drawer: a panel set back into the carcass, so the gap round it is a
/// shadow and the panel itself has a lit top edge and a dark bottom one.
private struct DrawerFront: View {
    var scale: CGFloat

    var body: some View {
        let corner = max(1, 3 * scale)
        let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

        ZStack {
            WoodFace(light: Color(hex: 0x704C2C), mid: Color(hex: 0x4A2F18),
                     dark: Color(hex: 0x2A190C), seed: 97)
                .clipShape(shape)
                .bevel(shape, width: max(0.8, 1.6 * scale), light: 0.20, dark: 0.50)

            // The gap the drawer sits in, seen along the top.
            VStack {
                LinearGradient(colors: [.black.opacity(0.60), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: max(2, 7 * scale))
                Spacer(minLength: 0)
            }
            .clipShape(shape)

            HStack {
                DrawerPull(scale: scale)
                Spacer()
                DrawerPull(scale: scale)
            }
            .padding(.horizontal, max(6, 26 * scale))
        }
        // A drawer sits in a hole. The seam round it is tight and dark; there
        // is no gap behind it for a soft shadow to come from.
        .shadow(color: .black.opacity(0.62), radius: max(0.6, 1.4 * scale),
                x: max(0.4, 0.8 * scale), y: max(0.6, 1.2 * scale))
        .shadow(color: .black.opacity(0.20), radius: max(1.5, 4 * scale),
                x: max(1, 2.5 * scale), y: max(1.2, 3.5 * scale))
    }
}

private struct DrawerPull: View {
    var scale: CGFloat

    var body: some View {
        Capsule()
            .fill(LinearGradient(colors: [ClubRoomMaterial.brassLit,
                                          ClubRoomMaterial.brass,
                                          Color(hex: 0x4A3413)],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: max(16, 58 * scale), height: max(6, 20 * scale))
            .overlay {
                // Brass is polished: one bright line along the top of it.
                Capsule()
                    .fill(LinearGradient(colors: [.white.opacity(0.55), .clear],
                                         startPoint: .top, endPoint: .center))
                    .padding(max(0.5, 1.5 * scale))
            }
            .overlay(Capsule().strokeBorder(.black.opacity(0.45), lineWidth: 0.7))
            .shadow(color: .black.opacity(0.6), radius: max(1, 3 * scale), y: max(1, 2 * scale))
    }
}

// MARK: - The right-hand corner

/// Shelf, spines and the plant that trails off it. Props: nothing here is a
/// Book you could open, and none of the spines says anything.
private struct RightShelf: View {
    var scale: CGFloat
    var reduceMotion: Bool
    var showBooks: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .topLeading) {
                // The shelf: an open box on the wall, seen from below, so its
                // underside is in shadow and its front rail catches the lamp.
                ShelfBox(scale: scale)
                    .frame(width: size.width * 0.88, height: size.height * 0.17)
                    .offset(x: size.width * 0.16, y: size.height * 0.26)

                // The pot standing on it, and what hangs off it. Drawn after
                // the box so the plant is in front of its own shelf.
                PothosSpray(leaves: 14, seed: 3, hang: true)
                    .frame(width: size.width * 0.92, height: size.height * 0.34)
                    .offset(x: size.width * 0.10, y: -size.height * 0.02)

                if showBooks {
                    BookRow(scale: scale)
                        .frame(width: size.width * 1.02, height: size.height * 0.46)
                        .offset(x: -size.width * 0.02, y: size.height * 0.54)
                }
            }
        }
    }
}

/// A shelf: a board, the rail across its front, and the shadow the whole box
/// throws down the wall behind it. Seen from below, which is why the underside
/// is the darkest part of it.
private struct ShelfBox: View {
    var scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            VStack(spacing: 0) {
                // The top of the board, mostly hidden by whatever stands on it.
                ZStack {
                    WoodFace(light: Color(hex: 0x8A5C33), mid: Color(hex: 0x5C3B20),
                             dark: Color(hex: 0x3A2411), vertical: false, seed: 29,
                             recede: true)
                    LinearGradient(colors: [.black.opacity(0.55), .clear],
                                   startPoint: .top, endPoint: .bottom)
                }
                .frame(height: size.height * 0.30)

                // The front rail.
                ZStack {
                    WoodFace(light: Color(hex: 0x9A6B3D), mid: Color(hex: 0x6D4726),
                             dark: Color(hex: 0x3E2716), seed: 31)
                    LinearGradient(colors: [.white.opacity(0.20), .clear, .black.opacity(0.42)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .frame(height: size.height * 0.34)

                // Underneath, where no light reaches.
                LinearGradient(colors: [.black.opacity(0.72), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: size.height * 0.36)
            }
            .shadow(color: .black.opacity(0.6), radius: 10 * scale, x: -2, y: 8 * scale)
        }
    }
}

/// A row of books standing on the desk. Blank, banded, and muted — they are
/// wallpaper with depth, and a legible title on one would turn it into
/// something to tap.
private struct BookRow: View {
    var scale: CGFloat

    private static let cloth: [Color] = [
        Color(hex: 0x3B4F33), Color(hex: 0x25302A), Color(hex: 0x5A4526),
        Color(hex: 0x44523B), Color(hex: 0x6A5730), Color(hex: 0x2C3A2E),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack(alignment: .bottom) {
                HStack(alignment: .bottom, spacing: max(0.5, 1.2 * scale)) {
                    ForEach(0..<5, id: \.self) { index in
                        Spine(scale: scale, index: index,
                              cloth: Self.cloth[index % Self.cloth.count],
                              width: size.width * (0.15 + Self.roll(index).0 * 0.055),
                              height: size.height * (0.64 + Self.roll(index).1 * 0.36))
                    }
                }
                .frame(width: size.width, height: size.height, alignment: .bottom)

                // Where the whole row meets the desk.
                ContactShadow(width: size.width * 0.92, depth: max(5, 16 * scale),
                              opacity: 0.7)
                    .offset(y: max(2, 5 * scale))
            }
        }
    }

    private static func roll(_ index: Int) -> (Double, Double) {
        var state = UInt64(index &* 97 &+ 13) &* 2654435761 &+ 5
        func unit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        return (unit(), unit())
    }

    /// One book, seen spine-on: cloth, a lit left edge, the head of the block
    /// showing above it, and the shade its neighbour throws across it.
    private struct Spine: View {
        var scale: CGFloat
        var index: Int
        var cloth: Color
        var width: CGFloat
        var height: CGFloat

        var body: some View {
            let corner = max(0.5, 2 * scale)
            let lean: Double = index == 4 ? 9 : (index == 3 ? 3.5 : 0)

            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(
                        colors: [cloth.mixed(with: .white, by: 0.16), cloth,
                                 cloth.mixed(with: .black, by: 0.55)],
                        startPoint: .leading, endPoint: .trailing))
                    // Cloth is not flat: it takes the light in a band and then
                    // turns away from it.
                    .overlay {
                        LinearGradient(colors: [.white.opacity(0.10), .clear, .clear,
                                                .black.opacity(0.35)],
                                       startPoint: .leading, endPoint: .trailing)
                            .clipShape(RoundedRectangle(cornerRadius: corner))
                    }
                    // The head of the text block, showing above the boards.
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(LinearGradient(colors: [Paper.pageEdge.opacity(0.80),
                                                          Paper.pageStack.opacity(0.40)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(height: max(1.5, 5 * scale))
                            .padding(.horizontal, max(0.4, 1.2 * scale))
                    }
                    // And the fore-edge down the side away from the spine —
                    // the leaves of the block, in shadow at the bottom.
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(LinearGradient(colors: [Paper.pageStack.opacity(0.55),
                                                          Color(hex: 0x6B6350).opacity(0.5)],
                                                 startPoint: .top, endPoint: .bottom))
                            .frame(width: max(1, 3.5 * scale))
                            .padding(.vertical, max(1, 3 * scale))
                    }

                // Blind-stamped bands, which is what a spine reads as from four
                // feet away.
                VStack(spacing: max(1, 5 * scale)) {
                    Rectangle().fill(ClubRoomMaterial.brass.opacity(0.50))
                        .frame(height: max(0.5, 1.8 * scale))
                    Rectangle().fill(ClubRoomMaterial.brass.opacity(0.32))
                        .frame(height: max(0.5, 1.0 * scale))
                }
                .padding(.horizontal, max(1, 3 * scale))
                .padding(.top, height * 0.16)
            }
            .frame(width: width, height: height)
            .rotationEffect(.degrees(lean), anchor: .bottomLeading)
            .shadow(color: .black.opacity(0.55), radius: max(2, 6 * scale),
                    x: -max(1, 2 * scale), y: 0)
        }
    }
}

// MARK: - Green things

/// A pothos: heart-shaped leaves on their own stems, each lit from the lamp's
/// quarter and carrying a vein down the middle.
///
/// One `Canvas` for the whole plant, drawn in passes — stems, then every
/// leaf's shadow, then every leaf — because a plant is a stack of overlapping
/// leaves and the shadows have to fall *under* all of them, not between them.
struct PothosSpray: View {
    var leaves: Int
    var seed: UInt64
    /// Hanging off a shelf rather than standing in a pot.
    var hang: Bool = false
    var tint: Color = ClubRoomMaterial.leaf
    var highlight: Color = ClubRoomMaterial.leafLit

    var body: some View {
        Canvas { context, size in
            let width = Double(size.width)
            let height = Double(size.height)
            let origin: CGPoint = hang
                ? CGPoint(x: width * 0.68, y: height * 0.06)
                : CGPoint(x: width * 0.5, y: height * 0.97)

            let placed = Self.arrange(leaves: leaves, seed: seed, hang: hang,
                                      width: width, height: height, origin: origin)

            for leaf in placed {
                let midX: Double = (Double(origin.x) + Double(leaf.base.x)) / 2 + leaf.bend
                let midY: Double = (Double(origin.y) + Double(leaf.base.y)) / 2
                var stem = Path()
                stem.move(to: origin)
                stem.addQuadCurve(to: leaf.base, control: CGPoint(x: midX, y: midY))
                context.stroke(stem, with: .color(ClubRoomMaterial.leafDeep.opacity(0.9)),
                               lineWidth: 1.0 + leaf.size * 0.012)
            }

            for leaf in placed {
                context.translateBy(x: 3, y: 4)
                context.fill(Self.leafPath(leaf), with: .color(.black.opacity(0.28)))
                context.translateBy(x: -3, y: -4)
            }

            for leaf in placed {
                let path = Self.leafPath(leaf)
                let face = leaf.lit ? highlight : tint.mixed(with: highlight, by: 0.25)
                context.fill(path, with: .linearGradient(
                    Gradient(colors: [face, tint, ClubRoomMaterial.leafDeep]),
                    startPoint: CGPoint(x: leaf.base.x - leaf.size * 0.4,
                                        y: leaf.base.y - leaf.size * 0.5),
                    endPoint: CGPoint(x: leaf.tip.x + leaf.size * 0.3,
                                      y: leaf.tip.y + leaf.size * 0.4)))

                // The vein down the middle, and the edge catching the light.
                var vein = Path()
                vein.move(to: leaf.base)
                vein.addLine(to: leaf.tip)
                context.stroke(vein, with: .color(highlight.opacity(0.45)), lineWidth: 0.9)
                context.stroke(path, with: .color(.black.opacity(0.30)), lineWidth: 0.7)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: Where the leaves are

    fileprivate struct Leaf {
        var base: CGPoint
        var tip: CGPoint
        var size: Double
        var angle: Double
        var bend: Double
        var lit: Bool
    }

    private static func arrange(leaves: Int, seed: UInt64, hang: Bool,
                                width: Double, height: Double,
                                origin: CGPoint) -> [Leaf] {
        var state = seed &* 6364136223846793005 &+ 99
        func unit() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }

        var placed: [Leaf] = []
        for index in 0..<leaves {
            let along: Double = Double(index) / Double(max(1, leaves - 1))
            let reach: Double = hang
                ? height * (0.20 + along * 0.72)
                : height * (0.30 + unit() * 0.55)
            let angle: Double = hang
                ? Double.pi / 2 + (unit() - 0.5) * 1.7 + (along - 0.5) * 0.5
                : -Double.pi / 2 + (unit() - 0.5) * 2.0
            let baseX: Double = Double(origin.x) + cos(angle) * reach * 0.72
            let baseY: Double = Double(origin.y) + sin(angle) * reach * 0.72
            let size: Double = min(width, height) * (0.16 + unit() * 0.11)
            let tipX: Double = baseX + cos(angle) * size
            let tipY: Double = baseY + sin(angle) * size
            placed.append(Leaf(base: CGPoint(x: baseX, y: baseY),
                               tip: CGPoint(x: tipX, y: tipY),
                               size: size, angle: angle,
                               bend: (unit() - 0.5) * 26,
                               lit: unit() < 0.40))
        }
        return placed
    }

    /// A heart: two lobes at the stem end, a point at the far one. Drawn as
    /// two curves round the leaf's own axis, so it works at any angle.
    private static func leafPath(_ leaf: Leaf) -> Path {
        let normal: Double = leaf.angle + Double.pi / 2
        let half: Double = leaf.size * 0.42
        let baseX = Double(leaf.base.x)
        let baseY = Double(leaf.base.y)
        let tipX = Double(leaf.tip.x)
        let tipY = Double(leaf.tip.y)

        func offset(_ x: Double, _ y: Double, along: Double, across: Double) -> CGPoint {
            CGPoint(x: x + cos(leaf.angle) * along + cos(normal) * across,
                    y: y + sin(leaf.angle) * along + sin(normal) * across)
        }

        // The notch between the two lobes, at the stem.
        let notch = offset(baseX, baseY, along: leaf.size * 0.10, across: 0)
        let tip = CGPoint(x: tipX, y: tipY)

        var path = Path()
        path.move(to: notch)
        path.addCurve(to: tip,
                      control1: offset(baseX, baseY, along: -leaf.size * 0.10, across: -half),
                      control2: offset(tipX, tipY, along: -leaf.size * 0.34, across: -half * 0.8))
        path.addCurve(to: notch,
                      control1: offset(tipX, tipY, along: -leaf.size * 0.34, across: half * 0.8),
                      control2: offset(baseX, baseY, along: -leaf.size * 0.10, across: half))
        path.closeSubpath()
        return path
    }
}

/// The leaf that is nearest the camera, and therefore the only thing in the
/// room allowed to be out of focus.
private struct ForegroundLeaf: View {
    var body: some View {
        PothosSpray(leaves: 5, seed: 41,
                    tint: ClubRoomMaterial.leaf.mixed(with: .black, by: 0.30),
                    highlight: ClubRoomMaterial.leafLit.mixed(with: .black, by: 0.25))
            .blur(radius: 7)
            .opacity(0.88)
            // Small, static and grouped: the blur is rasterised once instead of
            // being recomputed behind every frame of the room.
            .drawingGroup()
    }
}

/// A pot of pencils and a succulent, at the left edge of the desk.
struct LeftDeskProps: View {
    var scale: CGFloat
    var showPencils: Bool

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .bottom) {
                if showPencils {
                    PencilCup(scale: scale)
                        .frame(width: size.width * 0.60, height: size.height * 0.82)
                        .offset(x: -size.width * 0.18)
                }

                Succulent(scale: scale)
                    .frame(width: size.width * 0.56, height: size.height * 0.50)
                    .offset(x: size.width * 0.22)
            }
            .frame(width: size.width, height: size.height, alignment: .bottom)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Glazed stoneware with pencils in it. The rim is an ellipse and the inside
/// of it is dark, which is the difference between a pot and a coloured
/// rectangle.
private struct PencilCup: View {
    var scale: CGFloat

    private static let leads: [Color] = [
        Color(hex: 0x46543E), Color(hex: 0x8E6B3F), Color(hex: 0x6B7A62),
        Color(hex: 0x7A5A42), Color(hex: 0x3A4237),
    ]

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let potHeight = size.height * 0.44
            let rim = potHeight * 0.30

            ZStack(alignment: .bottom) {
                ContactShadow(width: size.width * 1.15, depth: max(4, 14 * scale))
                    .offset(y: max(1, 3 * scale))

                // Pencils, standing at slightly different angles inside it.
                ForEach(0..<5, id: \.self) { index in
                    Pencil(colour: Self.leads[index])
                        .frame(width: max(3, 12 * scale), height: size.height * 0.74)
                        .rotationEffect(.degrees(Double(index - 2) * 6), anchor: .bottom)
                        // Sink the barrel well below the lip.  It must read as
                        // held by the cup, not balanced on its rim.
                        .offset(x: CGFloat(index - 2) * size.width * 0.11,
                                y: -potHeight * 0.20)
                }

                // The pot.
                ZStack(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: rim * 0.2,
                                           bottomLeadingRadius: potHeight * 0.28,
                                           bottomTrailingRadius: potHeight * 0.28,
                                           topTrailingRadius: rim * 0.2)
                        .fill(LinearGradient(colors: [Color(hex: 0x6C7A5A),
                                                      Color(hex: 0x44503A),
                                                      Color(hex: 0x1E241A)],
                                             startPoint: .topLeading,
                                             endPoint: .bottomTrailing))
                        // Glaze: a hard highlight down the lamp's side.
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(LinearGradient(colors: [.white.opacity(0.30), .clear],
                                                     startPoint: .top, endPoint: .bottom))
                                .frame(width: max(1.5, 5 * scale))
                                .padding(.vertical, potHeight * 0.16)
                                .padding(.leading, max(2, 7 * scale))
                                .blur(radius: max(0.5, 1.5 * scale))
                        }

                    // The opening, and the shadow inside it.
                    Ellipse()
                        .fill(RadialGradient(colors: [.black, Color(hex: 0x20261B)],
                                             center: .init(x: 0.5, y: 0.9),
                                             startRadius: 0, endRadius: rim))
                        .frame(height: rim)
                        .overlay {
                            Ellipse().strokeBorder(
                                LinearGradient(colors: [.white.opacity(0.35), .clear],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: max(0.6, 1.6 * scale))
                        }
                        .offset(y: -rim * 0.42)
                }
                .frame(height: potHeight)
                .shadow(color: .black.opacity(0.55), radius: max(2, 7 * scale),
                        x: max(1, 2 * scale), y: max(1, 4 * scale))
            }
            // Pinned to the floor of the reader. Without this the stack sizes
            // itself to its own content and floats at the top of the frame,
            // however carefully the frame's bottom was placed on the desk.
            .frame(width: size.width, height: size.height, alignment: .bottom)
        }
    }
}

/// Hexagonal, sharpened, and never quite vertical.
private struct Pencil: View {
    var colour: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let tip = size.height * 0.10

            VStack(spacing: 0) {
                // The sharpened end: bare wood, with the lead at the point.
                Triangle()
                    .fill(LinearGradient(colors: [Color(hex: 0xE0CBA4), Color(hex: 0xA98D63)],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(height: tip)
                    .overlay(alignment: .top) {
                        Triangle()
                            .fill(Color(hex: 0x2A2723))
                            .frame(width: size.width * 0.34, height: tip * 0.34)
                    }

                // The barrel, with the facets a hexagonal pencil shows.
                Rectangle()
                    .fill(LinearGradient(colors: [colour.mixed(with: .white, by: 0.28),
                                                  colour,
                                                  colour.mixed(with: .black, by: 0.45)],
                                         startPoint: .leading, endPoint: .trailing))
                    .overlay {
                        HStack(spacing: 0) {
                            Rectangle().fill(.white.opacity(0.10))
                            Rectangle().fill(.clear)
                            Rectangle().fill(.black.opacity(0.16))
                        }
                    }
            }
        }
    }
}

private struct Succulent: View {
    var scale: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let potHeight = size.height * 0.46

            ZStack(alignment: .bottom) {
                ContactShadow(width: size.width * 1.1, depth: max(4, 12 * scale))
                    .offset(y: max(1, 3 * scale))

                DeskPlant()
                    .frame(width: size.width * 0.62, height: size.height * 0.62)
                    // The plant's root extends below the rim and is covered by
                    // the soil overlay, so there is no daylight gap above pot.
                    .offset(x: size.width * 0.01, y: -potHeight * 0.80)

                // A pot of unglazed stoneware, speckled.
                UnevenRoundedRectangle(topLeadingRadius: 2 * scale,
                                       bottomLeadingRadius: potHeight * 0.22,
                                       bottomTrailingRadius: potHeight * 0.22,
                                       topTrailingRadius: 2 * scale)
                    .fill(LinearGradient(colors: [ClubRoomMaterial.stoneware
                                                    .mixed(with: .white, by: 0.18),
                                                  ClubRoomMaterial.stoneware,
                                                  ClubRoomMaterial.stoneware
                                                    .mixed(with: .black, by: 0.55)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay {
                        PaperGrain(opacity: 0.14, seed: 22)
                            .clipShape(RoundedRectangle(cornerRadius: potHeight * 0.22))
                    }
                    .overlay(alignment: .top) {
                        // The soil, in the shade of its own rim.
                        Ellipse()
                            .fill(Color(hex: 0x241C13))
                            .frame(height: max(3, 10 * scale))
                            .padding(.horizontal, max(1, 4 * scale))
                            .offset(y: -max(1.5, 5 * scale))
                    }
                    .frame(height: potHeight)
                    .shadow(color: .black.opacity(0.5), radius: max(2, 6 * scale),
                            x: max(1, 2 * scale), y: max(1, 3 * scale))
            }
            .frame(width: size.width, height: size.height, alignment: .bottom)
        }
    }

    /// One living, stemmed desk plant. Its leaves grow in pairs directly from
    /// the stalk, so its silhouette remains legible at phone scale.
    private struct DeskPlant: View {
        var body: some View {
            Canvas { context, size in
                let root = CGPoint(x: size.width * 0.48, y: size.height * 0.96)
                let crown = CGPoint(x: size.width * 0.56, y: size.height * 0.16)

                var stem = Path()
                stem.move(to: root)
                stem.addCurve(to: crown,
                              control1: CGPoint(x: size.width * 0.43, y: size.height * 0.68),
                              control2: CGPoint(x: size.width * 0.68, y: size.height * 0.37))
                context.stroke(stem, with: .color(.black.opacity(0.42)), lineWidth: 5.2)
                context.stroke(stem, with: .color(Color(hex: 0x456238)), lineWidth: 3.2)
                context.stroke(stem, with: .color(Color(hex: 0x91AD6C).opacity(0.72)), lineWidth: 0.9)

                let leaves: [(CGPoint, Angle, CGFloat, Color)] = [
                    (CGPoint(x: size.width * 0.47, y: size.height * 0.73), .radians(3.65), size.width * 0.30, Color(hex: 0x587645)),
                    (CGPoint(x: size.width * 0.49, y: size.height * 0.66), .radians(-0.36), size.width * 0.27, Color(hex: 0x709054)),
                    (CGPoint(x: size.width * 0.50, y: size.height * 0.53), .radians(3.57), size.width * 0.32, Color(hex: 0x648348)),
                    (CGPoint(x: size.width * 0.54, y: size.height * 0.46), .radians(-0.48), size.width * 0.30, Color(hex: 0x789A5B)),
                    (CGPoint(x: size.width * 0.55, y: size.height * 0.34), .radians(3.72), size.width * 0.26, Color(hex: 0x6B8A50)),
                    (CGPoint(x: size.width * 0.57, y: size.height * 0.27), .radians(-0.62), size.width * 0.23, Color(hex: 0x8DA968)),
                    (crown, .radians(4.46), size.width * 0.21, Color(hex: 0x91AD6C)),
                    (crown, .radians(-1.02), size.width * 0.21, Color(hex: 0x9BB778))
                ]

                for (anchor, angle, length, color) in leaves {
                    context.drawLayer { layer in
                        layer.translateBy(x: anchor.x, y: anchor.y)
                        layer.rotate(by: angle)

                        var leaf = Path()
                        leaf.move(to: .zero)
                        leaf.addCurve(to: CGPoint(x: length, y: 0),
                                      control1: CGPoint(x: length * 0.31, y: -length * 0.27),
                                      control2: CGPoint(x: length * 0.80, y: -length * 0.25))
                        leaf.addCurve(to: .zero,
                                      control1: CGPoint(x: length * 0.80, y: length * 0.25),
                                      control2: CGPoint(x: length * 0.31, y: length * 0.27))
                        leaf.closeSubpath()

                        layer.fill(leaf, with: .linearGradient(
                            Gradient(colors: [Color(hex: 0xB0C98A), color, Color(hex: 0x31472B)]),
                            startPoint: .zero,
                            endPoint: CGPoint(x: length, y: 0)))
                        layer.stroke(leaf, with: .color(.black.opacity(0.30)), lineWidth: 0.7)

                        var vein = Path()
                        vein.move(to: .zero)
                        vein.addLine(to: CGPoint(x: length * 0.84, y: 0))
                        layer.stroke(vein, with: .color(.black.opacity(0.18)), lineWidth: 0.5)
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// The very bottom of the frame: the edge of a woven rug, mostly in shadow.
private struct RugEdge: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [ClubRoomMaterial.rug.mixed(with: .black, by: 0.42),
                                    Color(hex: 0x1E160C)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { context, size in
                var state: UInt64 = 6151
                func unit() -> Double {
                    state = state &* 6364136223846793005 &+ 1442695040888963407
                    return Double(state >> 11) / Double(UInt64(1) << 53)
                }
                let width = Double(size.width)
                let height = Double(size.height)
                var x: Double = 0
                while x < width {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x + (unit() - 0.5) * 4, y: height))
                    context.stroke(path, with: .color(.black.opacity(0.22 + unit() * 0.28)),
                                   lineWidth: 0.8 + unit() * 1.8)
                    x += 2 + unit() * 4
                }
            }
        }
        .overlay(alignment: .top) {
            // The rug is under the cabinet, so the cabinet shades it.
            LinearGradient(colors: [.black.opacity(0.75), .clear],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 10)
        }
    }
}

// MARK: - The lamp as an object

/// Enamel shade, cord, and a bulb. No glow: the light is a separate layer, so
/// it can fall on the plaque and the tiles rather than sit inside the fixture.
struct LampFixture: View {
    /// The lamp's own two per cent, applied to the enamel's sheen only.
    var glow: Double = 1
    /// The lamp is composed below the top of a tall screen; its flex must
    /// still begin at the actual ceiling rather than at the fixture's frame.
    var ceilingDrop: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let shadeWidth = size.width * 0.94
            // Leave enough visible flex to read as a ceiling lamp.  The
            // previous shallow drop made the cable look like it stopped in
            // mid-air just above the shade.
            let shadeHeight = size.height * 0.44
            let top = size.height * 0.42

            ZStack(alignment: .top) {
                // A ceiling rose anchors the flex at the room's top edge. The
                // cord then has one continuous curve to the shade's collar.
                Capsule()
                    .fill(Color(hex: 0x15180F))
                    .frame(width: max(5, size.width * 0.11), height: max(2, size.height * 0.018))
                    .position(x: size.width * 0.30, y: max(1, size.height * 0.009))
                    .offset(y: -ceilingDrop)

                Cord(ceilingDrop: ceilingDrop)
                    .stroke(Color(hex: 0x15180F),
                            style: StrokeStyle(lineWidth: max(2, size.width * 0.022),
                                               lineCap: .round))
                    .frame(width: size.width, height: top + max(2, size.height * 0.018))

                // Shade.
                ZStack {
                    Dome()
                        .fill(LinearGradient(
                            colors: [ClubRoomMaterial.lampEnamelLit,
                                     ClubRoomMaterial.lampEnamel,
                                     Color(hex: 0x10140E)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))

                    // Enamel is glossy: one hard, narrow highlight down the
                    // lamp's left shoulder, and a weaker one opposite.
                    Dome()
                        .fill(LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.06),
                                .init(color: .white.opacity(0.42 * glow), location: 0.16),
                                .init(color: .clear, location: 0.30),
                                .init(color: .clear, location: 0.80),
                                .init(color: .white.opacity(0.10), location: 0.92),
                            ],
                            startPoint: .leading, endPoint: .trailing))
                        .blur(radius: 1.5)

                    Dome().stroke(.black.opacity(0.5), lineWidth: 1)
                }
                .frame(width: shadeWidth, height: shadeHeight)
                .offset(y: top)
                .shadow(color: .black.opacity(0.6), radius: 12, x: 6, y: 8)

                // The rim the shade turns out to, lit from inside.
                Ellipse()
                    .strokeBorder(LinearGradient(
                        colors: [ClubRoomMaterial.bulbCore.opacity(0.75 * glow),
                                 ClubRoomMaterial.brass.opacity(0.5)],
                        startPoint: .top, endPoint: .bottom),
                        lineWidth: max(1, size.width * 0.018))
                    .frame(width: shadeWidth * 0.99, height: shadeHeight * 0.26)
                    .offset(y: top + shadeHeight * 0.80)

                // Under the shade: the lit inside of the enamel. This is the
                // part that says the lamp is on.
                Ellipse()
                    .fill(RadialGradient(
                        colors: [ClubRoomMaterial.bulbCore.opacity(0.85 * glow),
                                 ClubRoomMaterial.bulb.opacity(0.5 * glow),
                                 Color(hex: 0x6B5A34).opacity(0.6)],
                        center: .init(x: 0.5, y: 0.2), startRadius: 1,
                        endRadius: shadeWidth * 0.55))
                    .frame(width: shadeWidth * 0.94, height: shadeHeight * 0.30)
                    .offset(y: top + shadeHeight * 0.84)

                // The bulb hanging in it.
                Circle()
                    .fill(RadialGradient(colors: [.white, ClubRoomMaterial.bulbCore,
                                                  ClubRoomMaterial.bulb],
                                         center: .init(x: 0.4, y: 0.35),
                                         startRadius: 0, endRadius: shadeWidth * 0.16))
                    .frame(width: shadeWidth * 0.30, height: shadeWidth * 0.30)
                    .offset(y: top + shadeHeight * 0.98)
                    .blur(radius: 0.6)
            }
            .frame(width: size.width, height: size.height, alignment: .top)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// A hanging flex is not a plumb line: it leaves the ceiling at an angle
    /// and comes into the fitting straight.
    private struct Cord: Shape {
        var ceilingDrop: CGFloat

        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.30, y: rect.minY - ceilingDrop))
            path.addCurve(to: CGPoint(x: rect.width * 0.50, y: rect.maxY),
                          control1: CGPoint(x: rect.width * 0.29,
                                             y: rect.minY - ceilingDrop * 0.42),
                          control2: CGPoint(x: rect.width * 0.40, y: rect.height * 0.86))
            return path
        }
    }

    /// A pressed-metal shade: straight sides falling away from a small collar,
    /// and a rim that turns out at the bottom.
    private struct Dome: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let collar = rect.width * 0.22
            path.move(to: CGPoint(x: rect.midX - collar / 2, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - rect.height * 0.12),
                control: CGPoint(x: rect.minX + rect.width * 0.06, y: rect.midY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.12),
                control: CGPoint(x: rect.midX, y: rect.maxY + rect.height * 0.22))
            path.addQuadCurve(
                to: CGPoint(x: rect.midX + collar / 2, y: rect.minY),
                control: CGPoint(x: rect.maxX - rect.width * 0.06, y: rect.midY))
            path.closeSubpath()
            return path
        }
    }
}
