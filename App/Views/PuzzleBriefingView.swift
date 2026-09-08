import SwiftUI
import ProbablySudokuEngine

/// Printed decisions keep a readable measure on a tablet without resizing the
/// physical Book. Phone-sized page proposals pass through unchanged.
struct PuzzleBriefingLayout {
    let available: CGSize
    static let routeMaximumWidth: CGFloat = 560

    var contentSize: CGSize {
        CGSize(width: min(available.width, 560), height: min(available.height, 840))
    }

    /// Extra page space is a margin, never a stretched single-rule coupon.
    var clippingMaximumHeight: CGFloat { 280 }

    var routeHeight: CGFloat { RunRouteStrip.height(for: contentSize.width) }
    var sceneHeight: CGFloat { contentSize.height < 620 ? 72 : (contentSize.width > 500 ? 112 : 88) }
    /// These slots depend on the page, never on whether a receipt just arrived.
    /// A short page can scroll its content; it must not squash the Sudoku grids.
    var decisionHeight: CGFloat {
        min(clippingMaximumHeight, max(contentSize.height < 620 ? 176 : 190,
                                      contentSize.height - routeHeight - sceneHeight - 220))
    }
}

/// The one-page decision before a Puzzle starts. A Clipping is a physical
/// tear-off from the Book, not a second modal or a generic reward card.
struct PuzzleBriefingView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PageFlipper.self) private var flipper
    @Bindable var model: GameModel
    var canStartPresentation: @MainActor () -> Bool = { true }
    var isPresentationCovered = false
    @State private var isStartingPuzzle = false
    @State private var isAwaitingPreparation = false
    @State private var playTask: Task<Void, Never>?
    @State private var playRequestID: UUID?
    @State private var clippingClaim: GameModel.ClippingClaim?
    @State private var clippingTask: Task<Void, Never>?
    @State private var clippingRequestID: UUID?

    var body: some View {
        // The page owns its bounds. An encounter's artwork must fit that
        // proposal instead of making the Book grow into the desk's HUD.
        GeometryReader { proxy in
            let layout = PuzzleBriefingLayout(available: proxy.size)
            briefingContent(layout: layout)
                .frame(width: layout.contentSize.width, height: layout.contentSize.height, alignment: .top)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .task(id: preparationLifetime) {
            guard scenePhase == .active else {
                model.cancelPuzzlePreparation()
                return
            }
            _ = await model.prepareUpcomingPuzzle()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                cancelPendingPlay()
                cancelClippingTake()
                model.cancelPuzzlePreparation()
            }
        }
        .onChange(of: isPresentationCovered) { _, covered in
            if covered {
                cancelPendingPlay()
                cancelClippingTake()
            }
        }
        .onChange(of: flipper.isFlipping) { _, flipping in
            if flipping { cancelClippingTake() }
        }
        .onDisappear {
            model.cancelPuzzlePreparation()
            cancelClippingTake()
            // A committed flip owns its remaining animation independently of
            // the disappearing briefing. Other navigation cancels a cold wait.
            if model.page != .puzzle || !flipper.isFlipping { cancelPendingPlay() }
        }
    }

    private func briefingContent(layout: PuzzleBriefingLayout) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    briefingHeader
                        .fixedSize(horizontal: false, vertical: true)
                    RunRouteStrip(currentSlot: model.run.slot, boss: upcomingBoss,
                                  isMotionActive: !isPresentationCovered && !flipper.isFlipping)
                        .frame(height: layout.routeHeight)
                    BookLivingScene(book: model.run.book,
                                    isActive: !isPresentationCovered && !flipper.isFlipping)
                        .frame(height: layout.sceneHeight)
                    decisionArea
                        .frame(height: layout.decisionHeight)
                        .padding(.top, 6)
                        .padding(.bottom, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)

            // Always allocated: accepting a clipping changes ink, not geometry.
            Group {
                if let clipping = model.lastClipping {
                    ClippingReceipt(clipping: clipping)
                } else {
                    Text(model.run.slot == .boss ? "No shortcuts past this page."
                         : "Clippings are optional. Your Book, your call.")
                        .font(.system(size: 12, design: .serif).italic())
                        .foregroundStyle(theme.paper.softInk)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(height: 26, alignment: .center)
            PaperButton(title: isAwaitingPreparation ? "Preparing Puzzle…" : "Play Puzzle  →",
                        kind: .primary, isEnabled: !isStartingPuzzle && clippingClaim == nil) {
                startPreparedPuzzle()
            }
            PageNumber(level: model.run.level, slot: model.run.slot.rawValue)
        }
    }

    private var decisionArea: some View {
        ZStack {
            if let clipping = model.run.currentClipping {
                ClippingOfferTicket(clipping: clipping, remaining: model.run.skipsRemaining,
                                    arrived: true, clipBounced: false, stampVisible: true,
                                    isTaking: clippingClaim != nil, onTake: takeClipping)
                    .id(clipping)
                    .transition(.opacity)
            } else if let boss = upcomingBoss, model.run.slot == .boss {
                BossEncounterPreview(boss: boss)
                    .transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: model.run.currentClipping)
    }

    private var preparationLifetime: String {
        "\(model.puzzlePreparationRevision)-\(scenePhase == .active)"
    }

    private func startPreparedPuzzle() {
        guard !isStartingPuzzle, clippingClaim == nil, scenePhase == .active, !flipper.isFlipping,
              canStartPresentation() else { return }
        let requestID = UUID()
        playRequestID = requestID
        isStartingPuzzle = true
        isAwaitingPreparation = !model.hasPreparedPuzzle
        playTask = Task { @MainActor in
            defer {
                if playRequestID == requestID {
                    isStartingPuzzle = false
                    isAwaitingPreparation = false
                    playTask = nil
                    playRequestID = nil
                }
            }
            guard let prepared = await model.prepareUpcomingPuzzle(reportFailure: true),
                  !Task.isCancelled, playRequestID == requestID,
                  canStartPresentation(), model.page == .briefing else { return }
            isAwaitingPreparation = false
            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                guard playRequestID == requestID, canStartPresentation() else { return }
                model.beginPreparedPuzzle(prepared)
            }
        }
    }

    private func cancelPendingPlay() {
        playRequestID = nil
        playTask?.cancel()
        playTask = nil
        isStartingPuzzle = false
        isAwaitingPreparation = false
    }

    private func takeClipping() {
        guard !isStartingPuzzle, clippingClaim == nil, scenePhase == .active,
              !flipper.isFlipping, canStartPresentation(),
              let claim = model.currentClippingClaim else { return }
        clippingClaim = claim
        let requestID = UUID()
        clippingRequestID = requestID
        Haptics.pageTurn()
        clippingTask = Task { @MainActor in
            defer {
                if clippingRequestID == requestID {
                    clippingRequestID = nil
                    clippingClaim = nil
                    clippingTask = nil
                }
            }
            do {
                try await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 820))
            } catch { return }
            guard !Task.isCancelled, clippingRequestID == requestID,
                  clippingClaim == claim, scenePhase == .active,
                  !isPresentationCovered, !flipper.isFlipping, canStartPresentation() else { return }
            // The reward and route advance are one engine mutation. The
            // hanging paper is only presentation and can never pay twice.
            _ = model.takeClipping(ifCurrent: claim)
        }
    }

    private func cancelClippingTake() {
        clippingTask?.cancel()
        clippingTask = nil
        clippingRequestID = nil
        clippingClaim = nil
    }

    private var briefingHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Puzzle").pageHeading(30)
                    Text("Level \(model.run.level) · Run Plan")
                        .font(Print.caption(11)).tracking(1.35).textCase(.uppercase)
                        .foregroundStyle(theme.paper.softInk)
                }
                Spacer()
                RoundSeal(slot: model.run.slot)
            }
            Rectangle().fill(theme.paper.ruleInk).frame(height: 1)
        }
    }

    /// The engine commits the Boss when this briefing is entered. The UI only
    /// reads that stored decision; it never rolls a second candidate.
    private var upcomingBoss: BossModifier? {
        model.run.pendingBoss
    }
}

/// A short receipt at the destination of the tear-off. It confirms the exact
/// run-scoped effect without interrupting the player with a system alert.
private struct ClippingReceipt: View {
    @Environment(\.cosmeticTheme) private var theme
    var clipping: Clipping

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.redPencil)
            Text("\(clipping.name): \(clipping.detail)")
                .font(Print.body(12))
                .lineLimit(2).minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.paper.softInk)
        .padding(.horizontal, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clipping secured: \(clipping.name). \(clipping.detail)")
    }
}

// MARK: - Route

struct RunRouteStrip: View {
    var currentSlot: PuzzleSlot
    var boss: BossModifier?
    var isMotionActive = true

    static func boardSide(for width: CGFloat) -> CGFloat {
        max(0, (min(width, PuzzleBriefingLayout.routeMaximumWidth) - 36) / 3)
    }

    static func height(for width: CGFloat) -> CGFloat { boardSide(for: width) + 80 }

    static func title(for slot: PuzzleSlot) -> String {
        switch slot {
        case .easy: "Easy"
        case .medium: "Easy but hard"
        case .boss: "Boss"
        }
    }

    var accessibilitySummary: String {
        let route = "Run plan: Easy, Easy but hard, then Boss. Current stop: \(Self.title(for: currentSlot))."
        guard let boss else { return "\(route) Adversary not yet known." }
        return "\(route) \(boss.name). Power: \(boss.text). Miniature grids illustrate the route."
    }

    var body: some View {
        // The grid, not a tall card behind it, owns each stop's footprint.
        HStack(alignment: .routeGridCenter, spacing: 3) {
            RouteCard(slot: .easy, currentSlot: currentSlot, boss: boss, isMotionActive: isMotionActive)
            RouteArrow()
            RouteCard(slot: .medium, currentSlot: currentSlot, boss: boss, isMotionActive: isMotionActive)
            RouteArrow()
            RouteCard(slot: .boss, currentSlot: currentSlot, boss: boss, isMotionActive: isMotionActive)
        }
        .frame(maxWidth: PuzzleBriefingLayout.routeMaximumWidth)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }
}

private struct RouteCard: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.bookPresentation) private var bookTheme
    var slot: PuzzleSlot
    var currentSlot: PuzzleSlot
    var boss: BossModifier?
    var isMotionActive: Bool

    private var isCurrent: Bool { slot == currentSlot }
    private var isBoss: Bool { slot == .boss }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                if isBoss, let boss {
                    BossSignatureBadge(boss: boss, isActive: isMotionActive, side: 22)
                }
                Text(RunRouteStrip.title(for: slot))
                    .font(Print.caption(11)).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.75)
            }
            .frame(height: 22)
            Group {
                if isBoss, let boss {
                    BossRouteArtwork(boss: boss, isActive: isMotionActive)
                } else {
                    RouteBoardPreview(slot: slot, isCurrent: isCurrent, book: bookTheme.book)
                        .overlay { Rectangle().stroke(isCurrent ? Paper.coinRim : theme.paper.ruleInk, lineWidth: isCurrent ? 1.4 : 0.7) }
                        .shadow(color: .black.opacity(0.13), radius: 2, y: 2)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            VStack(spacing: 3) {
                if isBoss {
                    Text(boss?.name ?? "Unknown adversary")
                        .font(Print.caption(10)).textCase(.uppercase)
                        .lineLimit(2).minimumScaleFactor(0.8)
                    Text(boss?.briefPower ?? "Power unknown")
                        .font(Print.body(10)).foregroundStyle(theme.paper.isDark ? Color(hex: 0xF2A39B) : Paper.redPencil)
                        .lineLimit(2).minimumScaleFactor(0.8)
                } else {
                    Capsule().fill(isCurrent ? Paper.coinRim : .clear)
                        .frame(width: 22, height: 2)
                    if slot.rawValue < currentSlot.rawValue {
                        Text("Passed").font(Print.caption(8.5)).foregroundStyle(theme.paper.softInk)
                    }
                }
            }
            .frame(height: 46, alignment: .top)
            .multilineTextAlignment(.center)
        }
        .foregroundStyle(theme.paper.ink)
        .frame(maxWidth: .infinity)
        .alignmentGuide(.routeGridCenter) { dimensions in 28 + dimensions.width / 2 }
    }
}

/// Reuses the book's paper fibres at a restrained strength. The texture is
/// sized by its parent, so it never contributes an intrinsic image size.
private struct BriefingPaperTexture: View {
    var opacity: Double

    var body: some View {
        GeometryReader { proxy in
            Image("BetweenPuzzlesPaper")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .opacity(opacity)
        .blendMode(.multiply)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ClippingPaperEdge: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 1.5))
        let teeth = max(1, Int(rect.width / 5))
        let pitch = rect.width / CGFloat(teeth)
        for tooth in 0..<teeth {
            let x = rect.maxX - CGFloat(tooth) * pitch
            path.addQuadCurve(
                to: CGPoint(x: x - pitch, y: rect.maxY - 1.5),
                control: CGPoint(x: x - pitch * 0.5, y: rect.maxY - (tooth.isMultiple(of: 3) ? 3 : 2))
            )
        }
        path.closeSubpath()
        return path
    }
}

/// Static, legal miniature proofs. They communicate density, not tomorrow's deal.
private struct RouteBoardPreview: View {
    var slot: PuzzleSlot
    var isCurrent: Bool
    var book: Book = .probably

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let cell = side / 9
            let paper = isCurrent ? Color(hex: 0x2A2622) : Color(hex: 0xE9E3D3)
            let ink = isCurrent ? Color(hex: 0xF3E7C7) : Paper.inkSoft
            let rule = isCurrent ? Color(hex: 0xB69B63).opacity(0.65) : Paper.rule.opacity(0.65)
            context.fill(Path(CGRect(x: 0, y: 0, width: side, height: side)), with: .color(paper))
            for line in 0...9 {
                var path = Path()
                path.move(to: CGPoint(x: CGFloat(line) * cell, y: 0))
                path.addLine(to: CGPoint(x: CGFloat(line) * cell, y: side))
                path.move(to: CGPoint(x: 0, y: CGFloat(line) * cell))
                path.addLine(to: CGPoint(x: side, y: CGFloat(line) * cell))
                context.stroke(path, with: .color(rule), lineWidth: line.isMultiple(of: 3) ? 0.9 : 0.4)
            }
            for (index, digit) in RoutePreviewGrid.digits(for: slot, book: book).enumerated() {
                guard let digit else { continue }
                context.draw(Text(String(digit)).font(Print.numeral(cell * 0.65, weight: .medium)).foregroundStyle(ink),
                             at: CGPoint(x: (CGFloat(index % 9) + 0.5) * cell,
                                         y: (CGFloat(index / 9) + 0.5) * cell))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct RouteArrow: View {
    @Environment(\.cosmeticTheme) private var theme
    var body: some View {
        Image(systemName: "arrow.right").font(.system(size: 14, weight: .medium))
            .foregroundStyle(theme.paper.faintInk).frame(width: 12).accessibilityHidden(true)
    }
}

private struct RoundSeal: View {
    @Environment(\.cosmeticTheme) private var theme
    var slot: PuzzleSlot
    var body: some View {
        VStack(spacing: -1) {
            Text("Round").font(Print.caption(7.5)).tracking(0.8).textCase(.uppercase)
            Text("\(slot.rawValue + 1) / 3").font(Print.handwritten(13))
        }
        .foregroundStyle(theme.paper.softInk).frame(width: 43, height: 43)
        .overlay { Circle().strokeBorder(theme.paper.ruleInk, lineWidth: 0.8) }
        .overlay { Circle().inset(by: 3).strokeBorder(theme.paper.ruleInk.opacity(0.65), lineWidth: 0.55) }
        .rotationEffect(.degrees(-8)).accessibilityLabel("Round \(slot.rawValue + 1) of 3")
    }
}

// MARK: - Clipping

private struct BookNarration: View {
    @Environment(\.cosmeticTheme) private var theme
    var text: String

    init(slot: PuzzleSlot) { text = "The Book offers one way around Puzzle \(slot.rawValue + 1)." }
    init(text: String) { self.text = text }

    var body: some View {
        Text(text).font(.system(size: 12, weight: .regular, design: .serif).italic())
            .foregroundStyle(theme.paper.softInk).frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7).padding(.leading, 10).background(theme.paper.warm.opacity(0.78))
            .overlay(alignment: .leading) { Rectangle().fill(Paper.redPencil).frame(width: 2) }
    }
}

// MARK: - Boss encounter

/// A full, readable rule in the coupon's existing slot. The only Boss board
/// stays in the route; a second grid here used to force that route to shrink.
private struct BossEncounterPreview: View {
    @Environment(\.cosmeticTheme) private var theme
    var boss: BossModifier

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Spacer(minLength: 0)
            HStack(alignment: .top, spacing: 12) {
                BossSignatureBadge(boss: boss, side: 44)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Boss encounter")
                        .font(Print.caption(9.5)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(Paper.redPencil)
                    Text(boss.text)
                        .font(Print.body(17)).foregroundStyle(theme.paper.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("No clipping gets you past this one.")
                .font(.system(size: 15, design: .serif).italic())
                .foregroundStyle(theme.paper.softInk)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boss encounter: \(boss.name). \(boss.text)")
    }
}

private struct BossMark: View {
    @Environment(\.cosmeticTheme) private var theme
    var boss: BossModifier

    var body: some View {
        Image(systemName: BossBoardDesign(boss: boss).symbol)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Paper.redPencil)
            .frame(width: 48, height: 48)
            .background(Circle().fill(theme.paper.page.opacity(0.45)))
            .overlay { Circle().strokeBorder(Paper.redPencil.opacity(0.8), lineWidth: 1.2) }
            .overlay { Circle().inset(by: 4).strokeBorder(theme.paper.ruleInk.opacity(0.65), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2])) }
            .accessibilityHidden(true)
    }
}


private extension BossModifier {
    var briefPower: String {
        switch self {
        case .censor: "One digit scores 0"
        case .editor: "Hand size −1"
        case .deadline: "8 turns"
        case .fog: "Markers hidden"
        case .critic: "Wrong penalty ×2"
        case .mirror: "Lines score 0"
        case .paywall: "Clues disabled"
        case .erratum: "No tosses"
        case .collector: "No interest"
        case .heavyLifter: "Target ×4"
        case .unluckyLucky: "Triggered Bookmark sleeps"
        case .buffborger: "Buffs disabled"
        case .sashimi: "Multipliers halved"
        case .overPusher: "Squares foul"
        case .accountant: "Placements cost"
        case .tikTak: "4 minute clock"
        case .handyDandy: "Up to 2 cards barred"
        case .grayTheGarry: "A row locked"
        case .garryTheGray: "A box locked"
        }
    }

}

struct ClippingOfferTicket: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var clipping: Clipping
    var remaining: Int
    var arrived: Bool
    var clipBounced: Bool
    var stampVisible: Bool
    var isTaking = false
    var onTake: () -> Void

    var body: some View {
        Button(action: onTake) {
            GeometryReader { proxy in
                ticket(compact: proxy.size.height < 225)
                    .frame(width: proxy.size.width, height: proxy.size.height)
            }
                .background {
                    ClippingPaperEdge().fill(theme.paper.edge.opacity(0.70))
                        .offset(x: 2, y: 3)
                }
                .modifier(ClippingDepartureModifier(isTaking: isTaking, reduceMotion: reduceMotion))
                .contentShape(Rectangle())
        }
            .buttonStyle(PressedPaperStyle())
            .disabled(isTaking)
            // The clip stays attached to the page while the paper slips free.
            .overlay(alignment: .topTrailing) {
                Image(systemName: "paperclip").font(.system(size: 28, weight: .light))
                    .foregroundStyle(theme.paper.ink.opacity(0.75)).rotationEffect(.degrees(17))
                    .scaleEffect(clipBounced ? 1.13 : 1).offset(x: -18, y: -11)
                    .allowsHitTesting(false).accessibilityHidden(true)
            }
            .rotationEffect(.degrees(arrived ? 0 : 6)).offset(x: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
            .shadow(color: .black.opacity(0.14), radius: 3, x: 1, y: 3)
            .accessibilityLabel("Take \(clipping.name). \(clipping.detail). Skip Puzzle and take reward.")
            .accessibilityHint("Uses one of your \(remaining) remaining skips. You will not play this Puzzle.")
            .accessibilityIdentifier("briefing.clipping")
    }

    private func ticket(compact: Bool) -> some View {
        VStack(spacing: 0) {
            ticketTop(compact: compact)
            Divider().overlay(theme.paper.ruleInk.opacity(0.65))
            HStack(spacing: 15) {
                TicketSeal(side: compact ? 44 : 60)
                VStack(alignment: .leading, spacing: 4) {
                    Text(clipping.name)
                        .font(.system(size: compact ? 22 : 27, weight: .medium, design: .serif))
                        .foregroundStyle(theme.paper.ink)
                    Text(clipping.detail).font(Print.body(compact ? 12.5 : 14)).foregroundStyle(theme.paper.softInk).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17).padding(.vertical, compact ? 10 : 24)
            .frame(maxHeight: .infinity)
            DashedPerforation(color: theme.paper.ruleInk)
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tear off to take").font(Print.caption(9.5)).tracking(1).textCase(.uppercase).foregroundStyle(Paper.redPencil)
                        Text("Skip + reward").font(Print.subheading(17)).tracking(0.75).textCase(.uppercase)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(theme.paper.ink).padding(.horizontal, 17).padding(.vertical, compact ? 12 : 20).contentShape(Rectangle())
        }
        .background {
            theme.paper.warm
                .overlay { BriefingPaperTexture(opacity: 0.26) }
        }
        .clipShape(ClippingPaperEdge())
        .overlay { ClippingPaperEdge().stroke(theme.paper.ruleInk.opacity(0.55), lineWidth: 0.6) }
    }

    private func ticketTop(compact: Bool) -> some View {
        HStack {
            Text("Clipping on offer").font(Print.caption(9.5)).tracking(1.05).textCase(.uppercase)
                .foregroundStyle(Paper.redPencil).padding(.horizontal, 8).padding(.vertical, 5)
                .overlay { Rectangle().strokeBorder(Paper.redPencil.opacity(0.75), lineWidth: 1) }
                .scaleEffect(stampVisible ? 1 : 1.28).opacity(stampVisible ? 1 : 0)
            Spacer()
            HStack(spacing: 3) {
                ForEach(0..<min(2, remaining), id: \.self) { _ in Circle().fill(Paper.coinRim).frame(width: 6, height: 6) }
                Text("\(remaining) left").font(Print.caption(10)).tracking(0.55).textCase(.uppercase).foregroundStyle(theme.paper.softInk)
            }
            .padding(.trailing, 31)
        }
        .padding(.horizontal, 17).padding(.vertical, compact ? 8 : 13)
    }
}

private struct TicketSeal: View {
    @Environment(\.cosmeticTheme) private var theme
    var side: CGFloat = 60
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: side * 0.42, weight: .medium))
            .foregroundStyle(theme.paper.ink).frame(width: side, height: side)
            .overlay { Circle().strokeBorder(theme.paper.ink.opacity(0.75), lineWidth: 1.3) }
            .overlay { Circle().inset(by: 5).strokeBorder(theme.paper.ruleInk, style: StrokeStyle(lineWidth: 0.8, dash: [2, 2])) }
    }
}

private struct DashedPerforation: View {
    var color: Color
    var body: some View {
        Rectangle().strokeBorder(color.opacity(0.75), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1).padding(.horizontal, 10)
    }
}
