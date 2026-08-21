import SwiftUI
import ProbablySudokuEngine

/// A Book built out of layers rather than photographed.
///
/// The layers matter for more than sharpness: a photographed Book is welded to
/// the desk it was shot on, so browsing the shelf can only slide the whole
/// picture. Built like this, the Book is an object that can be moved across a
/// desk that stays where it is — and its cover can be opened on a hinge.
///
/// It is cased, not stitched: two boards and a spine, with the text block
/// sitting inside them. The boards overhang the leaves on three edges, and
/// that overhang is the whole difference between a hardback and a stack of
/// paper.
struct LiveBook: View {
    var edition: BookEdition
    /// The desk's clock, in turns. One for the whole shelf, so nothing moves
    /// against anything else.
    var phase: Double = 0
    /// 0 shut, negative laid open. The front board swings on the joint.
    var openAngle: Double = 0
    /// The obstacle ribbons, when this is the Book in hand.
    var ribbons: RibbonStrip? = nil
    /// What is printed on the first page. Only ever seen while the board is
    /// swinging off it, so there is no point setting one on a shut Book.
    var epigraph: String? = nil

    /// The ribbons sewn into a Book, and what pulling on one does.
    struct RibbonStrip {
        var levels: [Obstacle]
        var selected: Obstacle
        var isUnlocked: (Obstacle) -> Bool
        var onPick: (Obstacle) -> Void
    }

    private var design: CoverDesign { edition.design }

    /// The Book is bound in the colour of the ribbon you are holding.
    private var cloth: Color {
        guard let ribbons, !design.isBare else { return design.cloth }
        return ObstacleRibbon.cloth(for: ribbons.selected)
    }

    /// The three layers are seen from slightly off to one side, so each one
    /// steps out from under the one above it. These are how far.
    private static let leafStep: CGFloat = 0.016
    private static let caseStep: CGFloat = 0.034
    /// How many bookmarks are bound in. The obstacle ladder is nine long; the
    /// rest of it is not written yet, and the empty slots are shown shut
    /// rather than left off.
    private static let slots = 9

    /// One radius for every layer, so the stepped corner reads as one rounded
    /// object seen in depth rather than as three sheets of paper piled up.
    private static let radius: CGFloat = 0.026

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = w * 1.4                    // a stout puzzle book, not a novel

            ZStack(alignment: .topLeading) {
                // Seen from above and slightly off to one side, so the case
                // steps out from under the front board along two edges: cloth,
                // then leaves, then cloth. That step is the thickness.
                backBoard(w: w, h: h)
                textBlock(w: w, h: h)
                frontBoard(w: w, h: h)
            }
            .frame(width: w, height: h)
            .frame(maxHeight: .infinity, alignment: .center)
            // One shadow for the whole book, and it moves with the tilt.
            .modifier(Idle(phase: phase))
        }
    }

    // MARK: The case

    /// The back board, lying deepest and furthest out.
    private func backBoard(w: CGFloat, h: CGFloat) -> some View {
        Case(radius: w * Self.radius, spine: w * 0.068)
            .fill(
                LinearGradient(colors: [cloth.mixed(with: .black, by: 0.35),
                                        cloth.mixed(with: .black, by: 0.62)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .frame(width: w, height: h)
            .offset(x: w * Self.caseStep, y: w * Self.caseStep * 1.25)
    }

    /// The leaves, between the boards and smaller than them.
    private func textBlock(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Leaves(radius: w * Self.radius)
                .frame(width: w, height: h)
                .overlay(alignment: .top) {
                    if let epigraph {
                        Epigraph(text: epigraph, width: w)
                            .padding(.top, h * 0.30)
                    }
                }

            // Ribbons are sewn to the block, not glued to the cover, so they
            // stay where they are when the Book is opened.
            if let ribbons {
                ribbonStrip(ribbons, w: w, h: h)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        // Between the boards: what shows along the fore-edge and the tail is a
        // band of leaves with cloth on either side of it, and that band is the
        // whole difference between a hardback and a stack of paper.
        .offset(x: w * Self.leafStep, y: w * Self.leafStep * 1.25)
    }

    /// The front board on its joint, and everything printed or stuck on it.
    private func frontBoard(w: CGFloat, h: CGFloat) -> some View {
        Hinge(angle: openAngle) {
            ZStack(alignment: .topLeading) {
                board(w: w, h: h) {
                    CoverFace(design: design)
                        // The turn-in, where the cover wraps the board — wider
                        // at the joint, because the spine is there.
                        .padding(EdgeInsets(top: w * 0.032, leading: w * 0.085,
                                            bottom: w * 0.032, trailing: w * 0.032))
                }
                if !design.isBare {
                    notes(w: w, h: h)
                }
            }
            .frame(width: w, height: h, alignment: .topLeading)
        } inside: {
            board(w: w, h: h) {
                Endpaper(colour: design.accent)
                    .padding(EdgeInsets(top: w * 0.032, leading: w * 0.085,
                                        bottom: w * 0.032, trailing: w * 0.032))
            }
            .frame(width: w, height: h, alignment: .topLeading)
        }
    }

    /// A rigid board: cloth, a bevelled edge, and the spine standing proud
    /// along the joint.
    private func board<Face: View>(w: CGFloat, h: CGFloat,
                                   @ViewBuilder face: () -> Face) -> some View {
        ZStack(alignment: .leading) {
            Case(radius: w * Self.radius, spine: w * 0.068)
                .fill(cloth)
                .overlay { face() }
                // The lamp is up and to the left, here as everywhere else.
                .overlay {
                    Case(radius: w * Self.radius, spine: w * 0.068)
                        .strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.30), .black.opacity(0.30)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 1.2)
                }

            SpineCurl(colour: cloth)
                .frame(width: w * 0.075)
        }
        .frame(width: w, height: h)
        .clipShape(Case(radius: w * Self.radius, spine: w * 0.068))
    }

    // MARK: Furniture

    private func ribbonStrip(_ strip: RibbonStrip, w: CGFloat, h: CGFloat) -> some View {
        VStack(spacing: h * 0.012) {
            ForEach(1...Self.slots, id: \.self) { slot in
                // A slot with no obstacle behind it yet is still shown, and
                // still shut. The ladder is nine long whether or not it has
                // been written, and a strip that grew a bookmark at a time
                // would never look like the edge of a book.
                let level = strip.levels.first { $0.rawValue == slot }
                let unlocked = level.map(strip.isUnlocked) ?? false
                let picked = level != nil && level == strip.selected

                Bookmark(numeral: "\(slot)",
                         // The one you are on is bound in with the Book.
                         colour: picked
                             ? ObstacleRibbon.colour(for: strip.selected)
                             : ObstacleRibbon.colour(forSlot: slot),
                         unlocked: unlocked,
                         picked: picked,
                         width: w,
                         height: h * 0.088)
                    // Only a sliver of a bookmark is outside the boards, and a
                    // sliver is not something you can hit. The touch box runs
                    // on past the fore-edge into the bare desk beside it.
                    .frame(width: w * 0.20, height: h * 0.088, alignment: .leading)
                    .contentShape(Rectangle())
                    // Out a little further when it is the one you are on.
                    .offset(x: w * 0.155 + (picked ? w * 0.030 : 0))
                    .onTapGesture {
                        guard let level, unlocked, !picked else { return }
                        Haptics.pageTurn()
                        withAnimation(.snappy(duration: 0.28)) { strip.onPick(level) }
                    }
                    .accessibilityLabel(label(slot: slot, level: level, unlocked: unlocked))
                    .accessibilityAddTraits(picked ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(width: w, height: h, alignment: .trailing)
    }

    private func label(slot: Int, level: Obstacle?, unlocked: Bool) -> String {
        guard let level else { return "Obstacle \(slot). Not written yet." }
        return unlocked ? "\(level.name). \(level.text)" : "\(level.name). Locked."
    }

    private func notes(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(design.notes.enumerated()), id: \.offset) { position, note in
                StickyNote(note: note,
                           width: w * width(of: note.corner),
                           phase: phase + Double(position) * 0.31)
                    .offset(x: w * spot(of: note.corner).x,
                            y: h * spot(of: note.corner).y)
            }
        }
        .frame(width: w, height: h, alignment: .topLeading)
        // Notes can overhang the boards, so nothing here may be clipped to
        // them — and none of them takes a touch.
        .allowsHitTesting(false)
    }

    /// Where a note's top-left corner sits, as a fraction of the Book.
    ///
    /// Placed rather than padded. Padding a note inside a frame the size of
    /// the Book only moves it half as far as the number says, because the
    /// frame then centres what has grown — which is why every one of these
    /// used to land somewhere other than where it was put.
    private func spot(of corner: CoverDesign.Note.Corner) -> (x: CGFloat, y: CGFloat) {
        switch corner {
        case .headLeft:
            // Top-left of the printed cover, clear of the sun.
            return (0.035, 0.035)
        case .fore:
            // The band above the title, right of the sun. Not out past the
            // fore-edge: that is where the bookmarks live.
            return (0.690, 0.055)
        case .underTheFlourish:
            // Beside the mug, under the tail of "Probably", stopping short of
            // the fore-edge and the bookmarks.
            return (0.673, 0.577)
        }
    }

    /// The one at the head is smaller: it is the first thing read and there is
    /// least room for it.
    private func width(of corner: CoverDesign.Note.Corner) -> CGFloat {
        corner == .fore ? 0.26 : 0.27
    }

}
// MARK: - The joint

/// The front board's hinge.
///
/// `Animatable` rather than a plain `rotation3DEffect`, because the board has
/// two faces: past ninety degrees you are looking at the inside of it, and
/// SwiftUI only re-reads the body — and so only makes that swap — if the angle
/// is the thing being animated.
private struct Hinge<Front: View, Inside: View>: View, Animatable {
    var angle: Double
    @ViewBuilder var front: Front
    @ViewBuilder var inside: Inside

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        Group {
            if angle > -90 {
                front
            } else {
                // The far side of a board, seen through it.
                inside.scaleEffect(x: -1, anchor: .center)
            }
        }
        .rotation3DEffect(.degrees(angle), axis: (x: 0, y: 1, z: 0),
                          anchor: .leading, perspective: 0.55)
        // A cover coming up off the desk throws the page below it into shade,
        // and catches the lamp itself as it turns.
        .brightness(-abs(sin(angle * .pi / 180)) * 0.18)
    }
}

// MARK: - Surfaces

/// The text block: the first page, and the leaves under it seen along the
/// fore-edge and the tail.
///
/// Only the outer band is hatched. The middle is the page you are about to
/// read — when the front board swings off, this is what is underneath it, and
/// a book that opens onto its own fore-edge is not a book.
private struct Leaves: View {
    var radius: CGFloat

    var body: some View {
        Canvas { context, size in
            let body = Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius)
            context.fill(body, with: .color(Color(hex: 0xEFE9D8)))
            context.clip(to: body)

            var state: UInt64 = 8123
            func jitter() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }

            // The fore-edge, no deeper than the boards overhang.
            let foreEdge = max(6, size.width * 0.045)
            var x = size.width - 1
            while x > size.width - foreEdge {
                var line = Path()
                let bow = (jitter() - 0.5) * 1.4
                line.move(to: CGPoint(x: x, y: 2 + bow))
                line.addLine(to: CGPoint(x: x + bow * 0.4, y: size.height - 2))
                context.stroke(line, with: .color(.black.opacity(0.08 + jitter() * 0.24)),
                               lineWidth: 0.9)
                x -= 1.1 + jitter() * 0.5
            }

            // The tail.
            let tail = max(5, size.height * 0.026)
            var y = size.height - 1
            while y > size.height - tail {
                var line = Path()
                line.move(to: CGPoint(x: 2, y: y))
                line.addLine(to: CGPoint(x: size.width - 2, y: y + (jitter() - 0.5) * 1.1))
                context.stroke(line, with: .color(.black.opacity(0.07 + jitter() * 0.22)),
                               lineWidth: 0.9)
                y -= 1.1 + jitter() * 0.5
            }

            // Where the boards close over them.
            context.fill(body, with: .linearGradient(
                Gradient(colors: [.black.opacity(0.30), .clear]),
                startPoint: .zero, endPoint: CGPoint(x: size.width * 0.16, y: 0)))
        }
        // Thousands of strokes; drawn once and then treated as a picture.
        .drawingGroup()
        .overlay { PaperGrain(opacity: 0.06).allowsHitTesting(false) }
    }
}

/// The outline of a cased book seen from above.
///
/// The spine side is rounded off far harder than the fore-edge, because it is
/// a curved back rather than a cut corner. Square corners there are what makes
/// a drawn book read as a rectangle of card.
struct Case: InsettableShape {
    var radius: CGFloat
    var spine: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(topLeadingRadius: spine * 0.55,
                               bottomLeadingRadius: spine * 0.55,
                               bottomTrailingRadius: radius,
                               topTrailingRadius: radius)
            .path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> Case {
        var shape = self
        shape.inset += amount
        return shape
    }
}

/// The curl: the rounded back of the case, turning away from the lamp on the
/// outside and turning into the groove on the inside.
private struct SpineCurl: View {
    var colour: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            ZStack(alignment: .trailing) {
                // Across the curl. The bright band is where the round of the
                // spine faces the lamp; it falls away on both sides of that.
                LinearGradient(
                    stops: [
                        .init(color: colour.mixed(with: .black, by: 0.55), location: 0),
                        .init(color: colour.mixed(with: .black, by: 0.22), location: 0.16),
                        .init(color: colour.mixed(with: .white, by: 0.26), location: 0.38),
                        .init(color: colour, location: 0.66),
                        .init(color: colour.mixed(with: .black, by: 0.30), location: 0.88),
                        .init(color: colour.mixed(with: .black, by: 0.58), location: 1),
                    ],
                    startPoint: .leading, endPoint: .trailing)

                // Along it: the case is pinched in at the head and the tail.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.42), location: 0),
                        .init(color: .clear, location: 0.10),
                        .init(color: .clear, location: 0.90),
                        .init(color: .black.opacity(0.42), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom)

                // The groove the board hinges in.
                Rectangle()
                    .fill(.black.opacity(0.42))
                    .frame(width: max(1, w * 0.11))
                    .blur(radius: 0.7)
            }
        }
    }
}

/// One obstacle, as a tab cut into the fore-edge.
///
/// Small, solid and square-ended, like the index tabs it replaces. Nine of
/// them have to fit down one edge and still be told apart at a glance, which
/// rules out anything with a shape to it: the colour is the whole signal, and
/// the numeral is there to confirm it.
private struct Bookmark: View {
    var numeral: String
    var colour: Color
    var unlocked: Bool
    var picked: Bool
    var width: CGFloat
    var height: CGFloat

    var body: some View {
        Group {
            if unlocked {
                Text(numeral)
                    .font(.system(size: width * 0.040, weight: .bold))
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: width * 0.032))
            }
        }
            .foregroundStyle(.white.opacity(unlocked ? 0.95 : 0.5))
            .lineLimit(1)
            .fixedSize()
            // Toward the outer end: the inner half of a bookmark is inside the
            // Book, and a figure printed there cannot be read.
            .frame(width: width * 0.088, height: height, alignment: .trailing)
            .padding(.trailing, width * 0.018)
            .background {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: width * 0.014,
                                       topTrailingRadius: width * 0.014)
                    .fill(unlocked ? colour : colour.mixed(with: Color(hex: 0x2A2622), by: 0.76))
                    .overlay {
                        UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                               bottomTrailingRadius: width * 0.014,
                                               topTrailingRadius: width * 0.014)
                            .fill(LinearGradient(colors: [.white.opacity(0.22), .clear],
                                                 startPoint: .top, endPoint: .bottom))
                    }
            }
            // The one you are on is the only one that stands off the page.
            .shadow(color: .black.opacity(picked ? 0.45 : 0.22),
                    radius: picked ? 3.5 : 1.5, x: 1, y: 1)
            .overlay(alignment: .leading) {
                // A hairline where it is glued to the leaf, so it reads as
                // stuck on rather than as part of the edge.
                Rectangle()
                    .fill(.black.opacity(0.18))
                    .frame(width: 0.7)
            }
    }
}

// MARK: - The desk's clock


/// A Book at rest is still a Book on a desk someone is sitting at. One slow
/// turn of the light across it, and nothing else.
struct Idle: ViewModifier, Animatable {
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    func body(content: Content) -> some View {
        let turn = phase * 2 * .pi
        let tilt = sin(turn)
        // Offset in the angle, not in the frequency: half a cycle would not
        // land back where it started when the clock wraps.
        let lift = sin(turn + 1.1)

        content
            .rotation3DEffect(.degrees(tilt * 0.7), axis: (x: 0.4, y: 1, z: 0),
                              anchor: .center, perspective: 0.25)
            .scaleEffect(1 + lift * 0.003)
            .compositingGroup()
            .shadow(color: .black.opacity(0.55), radius: 24, x: 14 + tilt * 2.5, y: 22)
    }
}

/// The line printed on the first page.
///
/// Set like a printer's epigraph — small, centred, with a rule above and
/// below — and light enough that it reads as part of the paper. Anything
/// darker would be an announcement, and it is not one.
private struct Epigraph: View {
    var text: String
    var width: CGFloat

    var body: some View {
        VStack(spacing: width * 0.030) {
            rule
            Text(text)
                .font(MarginNote.font(width * 0.052))
                .foregroundStyle(Paper.pencil.opacity(0.34))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, width * 0.16)
            rule
        }
        .frame(width: width)
    }

    private var rule: some View {
        Rectangle()
            .fill(Paper.pencil.opacity(0.16))
            .frame(width: width * 0.30, height: 0.6)
    }
}

/// The paste-down inside the front board.
private struct Endpaper: View {
    var colour: Color

    var body: some View {
        Rectangle()
            .fill(Color(hex: 0xE7E0CC))
            .overlay { PaperGrain(opacity: 0.06) }
            .overlay {
                Rectangle()
                    .fill(colour.opacity(0.10))
            }
            .overlay {
                // Shade running out of the joint.
                LinearGradient(colors: [.black.opacity(0.30), .clear],
                               startPoint: .trailing, endPoint: .center)
            }
    }
}

// MARK: - The cover face

/// Everything printed on the front. Set rather than photographed, so it stays
/// sharp at any size and every volume can say its own name.
private struct CoverFace: View {
    var design: CoverDesign

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height

            ZStack {
                if design.isBare {
                    bareCover(w: w, h: h)
                } else {
                    Rectangle()
                        .fill(design.stock)
                        .overlay { PaperGrain(opacity: 0.05) }
                    printedCover(w: w, h: h)
                }

                LinearGradient(colors: [.white.opacity(0.15), .clear,
                                        .black.opacity(0.10)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .blendMode(.overlay)
            }
        }
    }

    private func bareCover(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // Book cloth, not a dark rectangle: a weave, and light raking
            // across it.
            Cloth(colour: design.stock)

            // The blind rules a binder stamps before anything is printed.
            Rectangle()
                .strokeBorder(design.accent.opacity(0.55), lineWidth: 1)
                .padding(w * 0.03)
            Rectangle()
                .strokeBorder(design.accent.opacity(0.28), lineWidth: 0.5)
                .padding(w * 0.05)

            VStack(spacing: h * 0.014) {
                Spacer(minLength: 0)

                VStack(spacing: -h * 0.004) {
                    ForEach(design.titleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: w * 0.115, weight: .heavy))
                            // Blocked in foil, so it catches the lamp.
                            .foregroundStyle(
                                LinearGradient(colors: [design.accent.opacity(0.95),
                                                        design.accent.opacity(0.55)],
                                               startPoint: .topLeading,
                                               endPoint: .bottomTrailing))
                    }
                }
                .multilineTextAlignment(.center)
                .padding(.horizontal, w * 0.10)

                Rectangle()
                    .fill(design.accent.opacity(0.45))
                    .frame(width: w * 0.22, height: 1)
                    .padding(.vertical, h * 0.008)

                Text(design.volume)
                    .font(.system(size: w * 0.042, weight: .semibold))
                    .tracking(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(design.ink.opacity(0.42))

                Spacer(minLength: 0)

                Image(systemName: "lock.fill")
                    .font(.system(size: w * 0.055))
                    .foregroundStyle(design.ink.opacity(0.28))
                    .padding(.bottom, h * 0.055)
            }
            .frame(width: w, height: h)
        }
    }

    private func printedCover(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            // A blind-stamped rule, the way a cover is finished.
            Rectangle()
                .strokeBorder(design.ink.opacity(0.28), lineWidth: 1)
                .padding(w * 0.035)

            VStack(spacing: 0) {
                SunDoodle(colour: design.secondAccent, accent: design.accent)
                    .frame(width: w * 0.34, height: h * 0.085)
                    .padding(.top, h * 0.10)

                VStack(spacing: -h * 0.008) {
                    ForEach(design.titleLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: w * 0.175, weight: .black))
                            .tracking(-w * 0.004)
                            .foregroundStyle(design.ink)
                    }
                }
                .padding(.top, h * 0.012)

                Text(design.flourish)
                    .font(.custom("MarkerFelt-Wide", size: w * 0.20))
                    .foregroundStyle(design.accent)
                    .rotationEffect(.degrees(-3))
                    .padding(.top, -h * 0.012)

                Underline(colour: design.secondAccent)
                    .frame(width: w * 0.58, height: h * 0.016)
                    .padding(.top, h * 0.004)

                MugDoodle(ink: design.ink, accent: design.accent)
                    .frame(width: w * 0.30, height: h * 0.115)
                    .padding(.top, h * 0.02)

                Banner(text: design.banner, colour: design.accent, ink: design.stock)
                    .frame(width: w * 0.66, height: h * 0.048)
                    .padding(.top, h * 0.018)

                Text("— \(design.strapline) —")
                    .font(.system(size: w * 0.043, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(design.secondAccent)
                    .padding(.top, h * 0.016)

                Text(design.volume)
                    .font(.system(size: w * 0.045, weight: .bold))
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(design.ink.opacity(0.8))
                    .padding(.top, h * 0.008)

                Image(systemName: "heart.fill")
                    .font(.system(size: w * 0.036))
                    .foregroundStyle(design.secondAccent)
                    .padding(.top, h * 0.010)

                Spacer(minLength: 0)

                Imprint(text: design.imprint, colour: design.cloth, ink: design.stock)
                    .frame(width: w * 0.44, height: h * 0.042)
                    .padding(.bottom, h * 0.06)
            }
            .frame(width: w, height: h)
        }
    }
}

// MARK: - Drawn furniture

/// A square of paper stuck on the cover with one strip of tape.
///
/// The paper moves and the tape does not. That is the whole trick: the tape is
/// drawn over the top and never rotated, so what you see is a sheet lifting
/// out from under something that is still stuck down — rather than a rectangle
/// being tilted, tape and all, which is what it looked like before.
///
/// `Animatable` on the phase so the curl is interpolated per frame; a plain
/// `Double` would jump.
private struct StickyNote: View, Animatable {
    var note: CoverDesign.Note
    var width: CGFloat
    var phase: Double

    var animatableData: Double {
        get { phase }
        set { phase = newValue }
    }

    /// Barely anything: the corner is never quite flat against the cover and
    /// the amount it is off by drifts.
    ///
    /// There was a version of this that lifted the whole sheet to give back the
    /// words underneath, and it was wrong — a rectangle rotating on a hinge is
    /// not wind. Doing it properly means bending the sheet, which needs a mesh
    /// rather than a rotation, and a lift that does not convince is worse than
    /// no lift at all.
    private var curl: Double {
        (sin(phase * 2 * .pi) * 0.5 + 0.5) * 0.16
    }

    var body: some View {
        ZStack(alignment: .top) {
            paper
                // Hinged along the taped edge, and only just.
                .rotation3DEffect(.degrees(curl * 7),
                                  axis: (x: 1, y: 0.30, z: 0),
                                  anchor: .top, perspective: 0.72)
                .rotationEffect(.degrees(note.tilt), anchor: .top)

            tape
                .rotationEffect(.degrees(note.tilt), anchor: .top)
        }
        .frame(width: width, alignment: .top)
    }

    // MARK: The sheet

    private var paper: some View {
        VStack(alignment: .leading, spacing: width * 0.035) {
            ForEach(note.lines, id: \.self) { line in
                HStack(spacing: width * 0.03) {
                    if note.ticked {
                        Image(systemName: "checkmark.square")
                            .font(.system(size: width * 0.085))
                            .foregroundStyle(Paper.pencil)
                    }
                    Text(line)
                        .font(MarginNote.font(width * 0.105))
                        .foregroundStyle(Paper.pencil)
                }
            }
        }
        .padding(width * 0.10)
        .frame(width: width, alignment: .leading)
        .background { stock }
        .overlay { bend }
        .clipShape(TornSquare())
        // Sits on the cover when it is down and stands off it when it is up.
        .shadow(color: .black.opacity(0.20 + curl * 0.28),
                radius: 2 + curl * 9,
                x: 1 + curl * 2,
                y: 2 + curl * 10)
    }

    /// Paper, not a fill: sticky notes are dyed pulp, lighter where the light
    /// falls on them and never perfectly even.
    private var stock: some View {
        Rectangle()
            .fill(note.colour)
            .overlay {
                LinearGradient(colors: [.white.opacity(0.16), .clear,
                                        .black.opacity(0.06)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay { PaperGrain(opacity: 0.12) }
    }

    /// What sells the bend. A flat sheet lit evenly reads as card however far
    /// it is rotated; a sheet that darkens along the crease and catches the
    /// light at the free edge reads as paper.
    private var bend: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.20 * curl), location: 0),
                .init(color: .black.opacity(0.06 * curl), location: 0.28),
                .init(color: .clear, location: 0.62),
                .init(color: .white.opacity(0.30 * curl), location: 1),
            ],
            startPoint: .top, endPoint: .bottom
        )
        .allowsHitTesting(false)
    }

    /// A strip of tape. Never moves — it is what the paper is lifting away
    /// from.
    private var tape: some View {
        Rectangle()
            .fill(.white.opacity(0.32))
            .overlay {
                LinearGradient(colors: [.white.opacity(0.35), .clear],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .frame(width: width * 0.34, height: width * 0.13)
            .rotationEffect(.degrees(-6))
            .offset(y: -width * 0.055)
            .shadow(color: .black.opacity(0.14), radius: 1, y: 1)
    }
}

/// A square of paper, cut by a machine but not perfectly: the corners are a
/// touch soft and the foot has the faintest bow in it. Straight edges are the
/// other half of why a note reads as an asset rather than as a thing.
private struct TornSquare: Shape {
    func path(in rect: CGRect) -> Path {
        let r = rect.width * 0.012
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r),
                          control: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r * 1.6))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - r * 1.6, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        // The bow along the foot.
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.maxY - r * 0.5),
                          control: CGPoint(x: rect.midX, y: rect.maxY + r * 0.9))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - r * 2),
                          control: CGPoint(x: rect.minX, y: rect.maxY - r * 0.5))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        path.addQuadCurve(to: CGPoint(x: rect.minX + r, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// Book cloth: a fine weave, close-woven enough that at this size it reads as
/// texture rather than as a pattern.
private struct Cloth: View {
    var colour: Color

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(colour))

            var state: UInt64 = 4471
            func jitter() -> Double {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return Double(state >> 11) / Double(UInt64(1) << 53)
            }
            var y: CGFloat = 0
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(.white.opacity(0.012 + jitter() * 0.022)),
                               lineWidth: 0.7)
                y += 2.2
            }
            var x: CGFloat = 0
            while x < size.width {
                var line = Path()
                line.move(to: CGPoint(x: x, y: 0))
                line.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(line, with: .color(.black.opacity(0.05 + jitter() * 0.05)),
                               lineWidth: 0.7)
                x += 2.2
            }
        }
        .drawingGroup()
    }
}

private struct SunDoodle: View {
    var colour: Color
    var accent: Color

    var body: some View {
        GeometryReader { proxy in
            let s = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle()
                    .strokeBorder(colour, lineWidth: s * 0.05)
                    .frame(width: s * 0.62, height: s * 0.62)
                ForEach(0..<8, id: \.self) { i in
                    Capsule()
                        .fill(colour)
                        .frame(width: s * 0.045, height: s * 0.16)
                        .offset(y: -s * 0.46)
                        .rotationEffect(.degrees(Double(i) / 8 * 360))
                }
                HStack(spacing: s * 0.12) {
                    Circle().fill(colour).frame(width: s * 0.05, height: s * 0.05)
                    Circle().fill(colour).frame(width: s * 0.05, height: s * 0.05)
                }
                .offset(y: -s * 0.06)
                Arc()
                    .stroke(colour, style: StrokeStyle(lineWidth: s * 0.045, lineCap: .round))
                    .frame(width: s * 0.24, height: s * 0.14)
                    .offset(y: s * 0.10)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

private struct Arc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY),
                          control: CGPoint(x: rect.midX, y: rect.maxY * 1.6))
        return path
    }
}

private struct Underline: Shape {
    var colour: Color
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.midY * 0.7),
                      control1: CGPoint(x: rect.width * 0.3, y: rect.maxY),
                      control2: CGPoint(x: rect.width * 0.7, y: rect.minY))
        return path
    }
}

extension Underline: View {
    var body: some View {
        GeometryReader { proxy in
            self.path(in: CGRect(origin: .zero, size: proxy.size))
                .stroke(colour, style: StrokeStyle(lineWidth: proxy.size.height * 0.55,
                                                   lineCap: .round))
        }
    }
}

private struct MugDoodle: View {
    var ink: Color
    var accent: Color

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: w * 0.06)
                    .strokeBorder(ink.opacity(0.75), lineWidth: w * 0.035)
                    .frame(width: w * 0.62, height: h * 0.66)
                    .offset(x: -w * 0.05)
                Circle()
                    .strokeBorder(ink.opacity(0.75), lineWidth: w * 0.035)
                    .frame(width: w * 0.26, height: w * 0.26)
                    .offset(x: w * 0.30, y: -h * 0.02)
                Image(systemName: "heart.fill")
                    .font(.system(size: w * 0.16))
                    .foregroundStyle(accent)
                    .offset(x: -w * 0.05, y: -h * 0.02)
                Ellipse()
                    .fill(ink.opacity(0.10))
                    .frame(width: w * 0.72, height: h * 0.09)
                    .offset(x: -w * 0.05, y: h * 0.40)
            }
            .frame(width: w, height: h)
        }
    }
}

private struct Banner: View {
    var text: String
    var colour: Color
    var ink: Color

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            Text(text)
                .font(.system(size: h * 0.52, weight: .semibold))
                .tracking(h * 0.06)
                .textCase(.uppercase)
                .foregroundStyle(ink)
                .frame(width: proxy.size.width, height: h)
                .background { BannerShape().fill(colour) }
        }
    }
}

private struct BannerShape: Shape {
    func path(in rect: CGRect) -> Path {
        let notch = rect.height * 0.42
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - notch, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + notch, y: rect.midY))
        path.closeSubpath()
        return path
    }
}

/// The publisher's plate, blocked into the cloth at the foot.
private struct Imprint: View {
    var text: String
    var colour: Color
    var ink: Color

    var body: some View {
        GeometryReader { proxy in
            let h = proxy.size.height
            VStack(spacing: h * 0.06) {
                Text(text)
                    .font(.system(size: h * 0.34, weight: .semibold))
                    .tracking(h * 0.05)
                    .textCase(.uppercase)
                Text("— ✦ —")
                    .font(.system(size: h * 0.24))
            }
            .foregroundStyle(ink.opacity(0.9))
            .frame(width: proxy.size.width, height: h)
            .background { RoundedRectangle(cornerRadius: 2).fill(colour) }
        }
    }
}
