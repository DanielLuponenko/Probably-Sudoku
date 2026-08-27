import SwiftUI

/// The club's own display board: nine numbered tiles standing in a walnut
/// frame on a plinth, on the desk. The one thing on this screen that is
/// allowed to move enough to be noticed.
///
/// It borrows its thinking from `SolvingBoxes` — one deterministic phase, no
/// runtime randomness, movement driven by an animatable value rather than by a
/// timer — but not its behaviour. The shelf's boxes solve themselves over and
/// over because they are wallpaper. This one fills once and then stays filled:
/// a menu that keeps wiping its own numbers away reads as a loading screen,
/// and the complete one-to-nine square is the picture the room is built around.
///
/// Built the way the Book is built: separate pieces at separate depths — a
/// back panel, rails standing proud of it, tiles standing proud of those, and
/// a plinth the whole thing rests on — rather than one rectangle with a
/// gradient. That stack *is* the thickness.
struct NumberTileBoard: View {
    /// The room's clock, 0 to 1 over eighteen seconds.
    var phase: Double
    /// 0 at the moment the menu appears, 1 once all nine have landed.
    var entrance: Double
    var reduceMotion: Bool

    var body: some View {
        GeometryReader { proxy in
            let board = BoardGeometry(size: proxy.size)
            let size = proxy.size

            // The shadow this board puts on the desk is drawn by the scene,
            // against the desk's own contact plane — see `DeskContactShadow`.
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    ZStack(alignment: .topLeading) {
                        // The panel the tiles are set into: end grain, darker
                        // than the rails in front of it.
                        WoodFace(light: Color(hex: 0x3E2814), mid: Color(hex: 0x2A1A0C),
                                 dark: Color(hex: 0x180E06), vertical: true, seed: 37)
                            .overlay {
                                // The frame closes light out towards its edges.
                                RadialGradient(colors: [.clear, .black.opacity(0.55)],
                                               center: .init(x: 0.4, y: 0.35),
                                               startRadius: size.width * 0.1,
                                               endRadius: size.width * 0.8)
                            }

                        ForEach(0..<9, id: \.self) { index in
                            // One centre for the pocket and the tile that
                            // stands in it. Two calculations here is how they
                            // drift apart.
                            let centre = board.centre(of: index)

                            slot(side: board.tile, pocket: board.slot).position(centre)

                            PlayfulNumberTile(number: index + 1, side: board.tile,
                                              tilt: Self.tilt(of: index),
                                              reduceMotion: reduceMotion)
                                .modifier(TileMotion(phase: phase, entrance: entrance,
                                                     index: index, side: board.tile,
                                                     reduceMotion: reduceMotion))
                                .position(centre)
                        }

                        // The rails: four pieces of wood standing in front of
                        // the panel, each with its own lit inner edge. In
                        // front is correct — they are in front — which is why
                        // the field has to be sized to fit *between* them.
                        rails(board)
                    }
                    .frame(height: board.caseHeight)
                    .overlay {
                        BoardPulse(entrance: entrance, corner: size.width * 0.03,
                                   reduceMotion: reduceMotion)
                    }

                    plinthBoard(width: size.width, height: board.plinth)
                }
                // Two shadows, not one: a tight seam where the frame's own
                // parts meet, and a much weaker cast away from the lamp. One
                // broad soft shadow implies a large gap behind the object,
                // which is exactly what makes a drawn thing look like a card.
                .shadow(color: .black.opacity(0.55), radius: size.width * 0.006,
                        x: size.width * 0.004, y: size.width * 0.006)
                .shadow(color: .black.opacity(0.22), radius: size.width * 0.020,
                        x: size.width * 0.012, y: size.width * 0.018)
            }
        }
    }

    // MARK: The object

    /// Left, right, top and bottom rails, mitred at the corners the way a
    /// frame is. Each is lit along the edge that faces the lamp and dark along
    /// the one that faces the tiles, which is what makes the field read as
    /// sunk rather than painted on.
    private func rails(_ board: BoardGeometry) -> some View {
        ZStack {
            // Top and bottom.
            VStack(spacing: 0) {
                railFace(vertical: false)
                    .frame(height: board.topRail)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.black.opacity(0.55)).frame(height: 1.2)
                    }
                Spacer(minLength: 0)
                railFace(vertical: false)
                    .frame(height: board.bottomRail)
                    .overlay(alignment: .top) {
                        Rectangle().fill(.black.opacity(0.45)).frame(height: 1)
                    }
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(.white.opacity(0.14)).frame(height: 1)
                    }
            }

            // Left and right.
            HStack(spacing: 0) {
                railFace(vertical: true)
                    .frame(width: board.rail)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(.black.opacity(0.55)).frame(width: 1.2)
                    }
                Spacer(minLength: 0)
                railFace(vertical: true)
                    .frame(width: board.rail)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(.black.opacity(0.55)).frame(width: 1.2)
                    }
            }
        }
        .frame(width: board.size.width, height: board.caseHeight)
        .allowsHitTesting(false)
    }

    private func railFace(vertical: Bool) -> some View {
        ZStack {
            WoodFace(light: Color(hex: 0x7A5230), mid: Color(hex: 0x4C3018),
                     dark: Color(hex: 0x2A1A0E), vertical: !vertical, seed: 43)
            // The lamp is up and to the left of the whole room.
            LinearGradient(colors: [ClubRoomMaterial.lampWarm.opacity(0.18), .clear,
                                    .black.opacity(0.30)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// The foot: a board wider and deeper than the frame, so the frame stands
    /// *on* something. Its top catches the lamp and its front face does not.
    private func plinthBoard(width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            // The top of the plinth, seen at the desk's own shallow angle.
            ZStack {
                WoodFace(light: Color(hex: 0x8A5C33), mid: Color(hex: 0x5C3B20),
                         dark: Color(hex: 0x3A2411), vertical: false, seed: 67,
                         recede: true)
                LinearGradient(colors: [.black.opacity(0.65), .clear],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(height: height * 0.34)

            // Its front face.
            ZStack {
                WoodFace(light: Color(hex: 0x6E4A2A), mid: Color(hex: 0x452B15),
                         dark: Color(hex: 0x241709), seed: 61)
                LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.35)],
                               startPoint: .top, endPoint: .bottom)
            }
            .frame(height: height * 0.66)
        }
        .frame(width: width * 1.04)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: height * 0.05,
                                          bottomLeadingRadius: height * 0.18,
                                          bottomTrailingRadius: height * 0.18,
                                          topTrailingRadius: height * 0.05))
    }

    /// The recess a tile sits in: a dark hole with a lit lower lip, because
    /// that is what a routed pocket looks like under a lamp.
    private func slot(side: CGFloat, pocket: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
            .fill(Color(hex: 0x1B1109))
            .overlay {
                RoundedRectangle(cornerRadius: side * 0.10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: [.black.opacity(0.75), .clear,
                                                .white.opacity(0.12)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: max(0.8, side * 0.05))
            }
            .frame(width: pocket, height: pocket)
    }

    /// A third of a degree either way, decided by the tile rather than rolled.
    private static func tilt(of index: Int) -> Double {
        var state = UInt64(index &* 2654435761 &+ 17)
        state = state &* 6364136223846793005 &+ 1442695040888963407
        let unit = Double(state >> 11) / Double(UInt64(1) << 53)
        return -0.35 + unit * 0.7
    }
}

/// The face of one menu tile. Each tap uses the next stable entry in the
/// sequence, so it feels playful without making tests or accessibility output
/// depend on runtime randomness.
private struct PlayfulNumberTile: View {
    private static let glyphs = ["9×9", "✓", "×", "□", "↔", "?", "3×3", "#1", "!"]
    private static let descriptions = [
        "nine by nine", "correct", "not allowed", "a Sudoku box",
        "swap", "a missing clue", "three by three", "number one", "surprise"
    ]

    var number: Int
    var side: CGFloat
    var tilt: Double
    var reduceMotion: Bool

    @State private var glyphIndex = 0
    @State private var isShowingGlyph = false
    @State private var resetTask: Task<Void, Never>?

    private var glyph: String { Self.glyphs[glyphIndex] }
    private var glyphDescription: String { Self.descriptions[glyphIndex] }

    var body: some View {
        Button(action: reveal) {
            ZStack {
                PhysicalNumberTile(number: number, side: side, glyph: nil, tilt: tilt)
                    .opacity(isShowingGlyph ? 0 : 1)
                    .rotation3DEffect(.degrees(isShowingGlyph ? 90 : 0),
                                      axis: (x: 0, y: 1, z: 0), perspective: 0.65)

                PhysicalNumberTile(number: number, side: side, glyph: glyph, tilt: tilt)
                    .opacity(isShowingGlyph ? 1 : 0)
                    .rotation3DEffect(.degrees(isShowingGlyph ? 0 : -90),
                                      axis: (x: 0, y: 1, z: 0), perspective: 0.65)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Number \(number)")
        .accessibilityValue(isShowingGlyph ? glyphDescription : "\(number)")
        .accessibilityHint("Double tap to reveal a Sudoku surprise")
        .onDisappear { resetTask?.cancel() }
    }

    private func reveal() {
        resetTask?.cancel()
        glyphIndex = (glyphIndex + number) % Self.glyphs.count

        withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.28)) {
            isShowingGlyph = true
        }

        resetTask = Task {
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.5 : 1.45))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(reduceMotion ? .linear(duration: 0.01) : .snappy(duration: 0.24)) {
                    isShowingGlyph = false
                }
            }
        }
    }
}
/// Every measurement of the board, worked out once from its frame.
///
/// This type exists because of a specific bug. The tile field used to be sized
/// from the board's *width* alone, while the rails framing it were sized from
/// their own constants — and three tiles of width-derived height do not fit
/// between a top rail and a bottom rail. The bottom row ran underneath the
/// bottom rail, and since the rails are drawn in front of the field (correctly:
/// they are in front of it), seven, eight and nine were clipped.
///
/// The field and the rails now come out of the same arithmetic, so they cannot
/// disagree again. The rule the whole type enforces: the cell is the smaller of
/// what the width allows and what the height allows, and the height is what is
/// left after both rails and a little clearance have taken their share.
private struct BoardGeometry {
    let size: CGSize
    /// The foot the frame stands on.
    let plinth: CGFloat
    /// The framed part, above the plinth.
    let caseHeight: CGFloat
    /// The side rails' width, and the top and bottom rails' thicknesses.
    let rail: CGFloat
    let topRail: CGFloat
    let bottomRail: CGFloat
    /// The gap left between the field and the rails, so the tiles read as
    /// sitting inside a frame rather than jammed against it.
    let clearance: CGFloat
    let cell: CGFloat
    let tile: CGFloat
    /// The routed pocket, always a little larger than the tile in it.
    let slot: CGFloat
    let originX: CGFloat
    let originY: CGFloat

    init(size: CGSize) {
        self.size = size
        plinth = size.height * 0.13
        caseHeight = size.height - plinth
        rail = size.width * 0.062
        topRail = rail * 0.85
        bottomRail = rail * 0.70
        clearance = rail * 0.10

        let usableWidth = max(0, size.width - rail * 2)
        let usableHeight = max(0, caseHeight - topRail - bottomRail - clearance * 2)
        cell = min(usableWidth / 3, usableHeight / 3)
        tile = cell * 0.90
        slot = tile * 1.06

        let field = cell * 3
        originX = (size.width - field) / 2
        // Centred in whatever the rails left, so a board that is wider than it
        // is tall does not push its field to the top.
        originY = topRail + clearance + max(0, (usableHeight - field) / 2)
    }

    /// Where tile `index` stands. The pocket uses this too.
    func centre(of index: Int) -> CGPoint {
        CGPoint(x: originX + (CGFloat(index % 3) + 0.5) * cell,
                y: originY + (CGFloat(index / 3) + 0.5) * cell)
    }
}

/// The board's one flourish: a soft warm line round it as the ninth tile
/// lands, and then nothing for as long as the menu is open.
private struct BoardPulse: View, Animatable {
    var entrance: Double
    var corner: CGFloat
    var reduceMotion: Bool

    var animatableData: Double {
        get { entrance }
        set { entrance = newValue }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: corner, style: .continuous)
            .stroke(ClubRoomMaterial.lampWarm.opacity(0.55 * strength), lineWidth: 2)
            .blur(radius: 3)
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    /// At 0.68 seconds — after the ninth tile is down and before anything else
    /// on the screen asks for attention.
    private var strength: Double {
        guard !reduceMotion else { return 0 }
        let seconds = entrance * TileMotion.span
        let through = (seconds - 0.62) / 0.30
        guard through > 0, through < 1 else { return 0 }
        return sin(through * .pi)
    }
}
