import SwiftUI
import ProbablySudokuEngine

/// The one-page decision before a Puzzle starts. A Clipping is a physical
/// tear-off from the Book, not a second modal or a generic reward card.
struct PuzzleBriefingView: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var model: GameModel
    @State private var ticketArrived = false
    @State private var clipBounced = false
    @State private var stampVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            briefingHeader
            RunRouteStrip(currentSlot: model.run.slot, boss: upcomingBoss)

            if let clipping = model.lastClipping {
                ClippingReceipt(clipping: clipping)
            }

            if let clipping = model.run.currentClipping {
                BookNarration(slot: model.run.slot)
                ClippingOfferTicket(clipping: clipping,
                                    remaining: model.run.skipsRemaining,
                                    arrived: ticketArrived,
                                    clipBounced: clipBounced,
                                    stampVisible: stampVisible) {
                    model.skipCurrentPuzzle()
                }
            } else if model.run.slot == .boss {
                if let boss = upcomingBoss {
                    BookNarration(text: "The Book insists you face \(boss.name).")
                    BossEncounterPreview(boss: boss)
                }
            }

            Spacer(minLength: 0)

            PaperButton(title: "Play Puzzle  →", kind: .primary) {
                model.beginPuzzle()
            }
            PageNumber(level: model.run.level, slot: model.run.slot.rawValue)
        }
        .task(id: "\(model.run.level)-\(model.run.slot.rawValue)") {
            ticketArrived = false
            clipBounced = false
            stampVisible = false
            guard model.run.currentClipping != nil else { return }
            guard !reduceMotion else {
                ticketArrived = true
                stampVisible = true
                return
            }
            withAnimation(.spring(response: 0.32, dampingFraction: 0.76)) { ticketArrived = true }
            try? await Task.sleep(for: .milliseconds(170))
            withAnimation(.bouncy(duration: 0.22, extraBounce: 0.18)) { clipBounced = true }
            try? await Task.sleep(for: .milliseconds(160))
            withAnimation(.easeOut(duration: 0.12)) { clipBounced = false }
            try? await Task.sleep(for: .milliseconds(90))
            withAnimation(.snappy(duration: 0.18)) { stampVisible = true }
        }
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
        HStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Paper.redPencil)
            Text("Clipping secured")
                .font(Print.caption(10)).tracking(0.8).textCase(.uppercase)
            Text("·")
                .foregroundStyle(theme.paper.softInk)
            Text(clipping.detail)
                .font(Print.body(12.5))
            Spacer(minLength: 0)
        }
        .foregroundStyle(theme.paper.softInk)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(theme.paper.edge.opacity(0.58))
        .overlay(alignment: .leading) {
            Rectangle().fill(Paper.redPencil).frame(width: 2)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Clipping secured: \(clipping.name). \(clipping.detail)")
    }
}

// MARK: - Route

struct RunRouteStrip: View {
    var currentSlot: PuzzleSlot
    var boss: BossModifier?

    var body: some View {
        HStack(spacing: 5) {
            RouteCard(slot: .easy, currentSlot: currentSlot, boss: boss)
            RouteArrow()
            RouteCard(slot: .medium, currentSlot: currentSlot, boss: boss)
            RouteArrow()
            RouteCard(slot: .boss, currentSlot: currentSlot, boss: boss)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Run plan: Puzzle 1, Puzzle 2, then Boss")
    }
}

private struct RouteCard: View {
    @Environment(\.cosmeticTheme) private var theme
    var slot: PuzzleSlot
    var currentSlot: PuzzleSlot
    var boss: BossModifier?

    private var isCurrent: Bool { slot == currentSlot }
    private var isBoss: Bool { slot == .boss }
    private var title: String { isBoss ? "Boss" : "Puzzle \(slot.rawValue + 1)" }
    private var status: String { isBoss ? "Must play" : (isCurrent ? "Choose now" : "Up next") }
    /// A current route is printed with club ink, not the page's semantic ink.
    /// Night Sky reverses semantic page ink to cream, so using it as a fill
    /// would turn the active card into a bright tile.
    private var currentForeground: Color {
        theme.paper.isDark ? theme.paper.ink : theme.paper.page
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(Print.caption(9.5)).tracking(0.55).textCase(.uppercase)
            if isBoss {
                Text(boss?.name ?? "Unknown adversary")
                    .font(Print.caption(7.5)).tracking(0.3).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.55)
                Text("Power: \(boss?.briefPower ?? "Unknown")")
                    .font(Print.caption(7.2)).tracking(0.25).textCase(.uppercase)
                    .lineLimit(1).minimumScaleFactor(0.48)
                    .foregroundStyle(Paper.redPencil)
            } else {
                Spacer(minLength: 0)
            }
            Text(status).font(Print.caption(8.5)).tracking(0.45).textCase(.uppercase)
                .foregroundStyle(isCurrent && !isBoss ? currentForeground.opacity(0.76) : theme.paper.softInk)
        }
        .foregroundStyle(isCurrent && !isBoss ? currentForeground : theme.paper.ink)
        .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
        .padding(.horizontal, 7).padding(.vertical, 7)
        .background { RoundedRectangle(cornerRadius: 3).fill(isCurrent && !isBoss ? Paper.ink : theme.paper.warm) }
        .overlay(alignment: .top) {
            Rectangle().fill(isBoss ? Paper.redPencil : (isCurrent ? Paper.coinRim : .clear))
                .frame(height: 2).padding(.horizontal, 2)
        }
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(isBoss ? Paper.redPencil.opacity(0.8) : theme.paper.ruleInk, lineWidth: isBoss ? 1.25 : 1) }
        .overlay(alignment: .bottomTrailing) {
            if isBoss {
                LinearGradient(colors: [.clear, Paper.redPencil.opacity(0.14)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .offset(y: isCurrent && !isBoss ? -3 : 0)
        .shadow(color: .black.opacity(isCurrent && !isBoss ? 0.26 : 0.10), radius: isCurrent && !isBoss ? 3 : 1, x: 0, y: isCurrent && !isBoss ? 3 : 1)
    }
}

private struct RouteArrow: View {
    @Environment(\.cosmeticTheme) private var theme
    var body: some View {
        Image(systemName: "arrow.right").font(.system(size: 10, weight: .medium))
            .foregroundStyle(theme.paper.faintInk).frame(width: 11).accessibilityHidden(true)
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

/// A small living proof of what is about to change. The board stays a board;
/// the boss only disturbs its numbers, so the encounter reads before play.
private struct BossEncounterPreview: View {
    @Environment(\.cosmeticTheme) private var theme
    var boss: BossModifier

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                BossMark(boss: boss)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Boss encounter")
                        .font(Print.caption(9.5)).tracking(1.2).textCase(.uppercase)
                        .foregroundStyle(Paper.redPencil)
                    Text(boss.name)
                        .font(Print.subheading(21)).textCase(.uppercase).tracking(0.45)
                        .foregroundStyle(theme.paper.ink)
                        .lineLimit(2).minimumScaleFactor(0.72)
                    Text(boss.text)
                        .font(Print.body(12.5)).foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            BossFleeingBoard(boss: boss)
                .frame(maxWidth: .infinity)
                .frame(height: 315)

        }
        .padding(15)
        .background(theme.paper.warm.opacity(0.88))
        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(Paper.redPencil.opacity(0.72), lineWidth: 1) }
        .overlay(alignment: .top) { Rectangle().fill(Paper.redPencil).frame(height: 2).padding(.horizontal, 3) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Boss encounter: \(boss.name). \(boss.text)")
    }
}

private struct BossMark: View {
    @Environment(\.cosmeticTheme) private var theme
    var boss: BossModifier

    var body: some View {
        Image(systemName: boss.previewSymbol)
            .font(.system(size: 22, weight: .semibold))
            .foregroundStyle(Paper.redPencil)
            .frame(width: 48, height: 48)
            .background(Circle().fill(theme.paper.page.opacity(0.45)))
            .overlay { Circle().strokeBorder(Paper.redPencil.opacity(0.8), lineWidth: 1.2) }
            .overlay { Circle().inset(by: 4).strokeBorder(theme.paper.ruleInk.opacity(0.65), style: StrokeStyle(lineWidth: 0.8, dash: [2, 2])) }
            .accessibilityHidden(true)
    }
}

private struct BossFleeingBoard: View {
    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var boss: BossModifier

    /// A real solved Sudoku. The preview may be disrupted by the Boss, but
    /// its resting state must still read as a legitimate board.
    private let solvedBoard = [
        5, 3, 4, 6, 7, 8, 9, 1, 2,
        6, 7, 2, 1, 9, 5, 3, 4, 8,
        1, 9, 8, 3, 4, 2, 5, 6, 7,
        8, 5, 9, 7, 6, 1, 4, 2, 3,
        4, 2, 6, 8, 5, 3, 7, 9, 1,
        7, 1, 3, 9, 2, 4, 8, 5, 6,
        9, 6, 1, 5, 3, 7, 2, 8, 4,
        2, 8, 7, 4, 1, 9, 6, 3, 5,
        3, 4, 5, 2, 8, 6, 1, 7, 9,
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let progress = animationProgress(at: timeline.date)
            GeometryReader { proxy in
                let side = min(proxy.size.width, proxy.size.height)
                let cell = side / 9
                ZStack {
                    RoundedRectangle(cornerRadius: 2).fill(theme.paper.page.opacity(theme.paper.isDark ? 0.18 : 0.42))
                    RoundedRectangle(cornerRadius: 2).strokeBorder(theme.paper.ruleInk.opacity(0.72), lineWidth: 1)
                    ForEach(1..<9, id: \.self) { line in
                        let isBoxRule = line.isMultiple(of: 3)
                        Rectangle().fill(theme.paper.ruleInk.opacity(isBoxRule ? 0.78 : 0.42))
                            .frame(width: isBoxRule ? 1.5 : 0.6, height: side)
                            .offset(x: CGFloat(line) * cell - side / 2)
                        Rectangle().fill(theme.paper.ruleInk.opacity(isBoxRule ? 0.78 : 0.42))
                            .frame(width: side, height: isBoxRule ? 1.5 : 0.6)
                            .offset(y: CGFloat(line) * cell - side / 2)
                    }
                    ForEach(0..<81, id: \.self) { index in
                        Text("\(solvedBoard[index])").font(Print.numeral(cell * 0.52, weight: .bold))
                            .foregroundStyle(index == 40 ? Paper.redPencil : theme.paper.ink)
                            .position(x: cell * (CGFloat(index % 9) + 0.5), y: cell * (CGFloat(index / 9) + 0.5))
                            .offset(numberOffset(for: index, progress: progress))
                            .opacity(numberOpacity(for: index, progress: progress))
                            .rotationEffect(numberRotation(for: index, progress: progress))
                            .scaleEffect(numberScale(for: index, progress: progress))
                    }
                    Image(systemName: boss.previewSymbol)
                        .font(.system(size: side * 0.18, weight: .bold))
                        .foregroundStyle(Paper.redPencil.opacity(0.88))
                        .padding(10)
                        .background(Circle().fill(theme.paper.warm.opacity(0.92)))
                        .overlay { Circle().strokeBorder(Paper.redPencil.opacity(0.72), lineWidth: 1.2) }
                        .scaleEffect(boss.isPulsingPreview ? 1 + 0.13 * progress : 1)
                }
                .frame(width: side, height: side)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func numberOffset(for index: Int, progress: CGFloat) -> CGSize {
        let direction = direction(for: index)
        let distance = boss.previewEscapeDistance
        switch boss {
        case .fog: return index == 40 ? .zero : .init(width: direction.width * 8 * progress, height: direction.height * 8 * progress)
        case .mirror: return .init(width: -direction.width * distance * 0.45 * progress, height: direction.height * 5 * progress)
        case .editor, .handyDandy: return index % 9 >= 7 ? .init(width: distance * progress, height: 0) : .zero
        case .grayTheGarry: return index / 9 == 4 ? .init(width: distance * 0.6 * progress, height: 0) : .zero
        case .garryTheGray: return (3...5).contains(index / 9) && (3...5).contains(index % 9)
            ? .init(width: 0, height: distance * 0.55 * progress) : .zero
        default: return .init(width: direction.width * distance * progress, height: direction.height * distance * progress)
        }
    }

    private func numberOpacity(for index: Int, progress: CGFloat) -> Double {
        switch boss {
        case .censor: return index == 40 ? 1 - 0.88 * progress : 1
        case .fog: return index == 40 ? 1 : 1 - 0.66 * progress
        case .paywall, .buffborger: return index == 40 ? 1 : 1 - 0.42 * progress
        default: return 1 - 0.18 * progress
        }
    }

    private func numberRotation(for index: Int, progress: CGFloat) -> Angle {
        switch boss {
        case .deadline, .tikTak: return .degrees((index.isMultiple(of: 2) ? 12 : -12) * progress)
        case .sashimi: return .degrees((index.isMultiple(of: 2) ? 20 : -20) * progress)
        default: return .zero
        }
    }

    private func numberScale(for index: Int, progress: CGFloat) -> CGFloat {
        switch boss {
        case .heavyLifter: return index == 40 ? 1 + 0.45 * progress : 1 - 0.16 * progress
        case .mirror: return index.isMultiple(of: 2) ? 1 - 0.28 * progress : 1 + 0.08 * progress
        case .censor: return index == 40 ? 1 - 0.6 * progress : 1
        default: return 1 - 0.06 * progress
        }
    }

    private func animationProgress(at date: Date) -> CGFloat {
        guard !reduceMotion else { return 0 }
        let cycle = sin(date.timeIntervalSinceReferenceDate * (2 * .pi / boss.previewDuration))
        return CGFloat((cycle + 1) / 2)
    }

    private func direction(for index: Int) -> CGSize {
        let column = CGFloat(index % 9) - 4
        let row = CGFloat(index / 9) - 4
        return .init(width: column / 4, height: row / 4)
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
        case .unluckyLucky: "Bookmark sleeps"
        case .buffborger: "Buffs disabled"
        case .sashimi: "Multipliers halved"
        case .overPusher: "Squares foul"
        case .accountant: "Placements cost"
        case .tikTak: "3 minute clock"
        case .handyDandy: "Two digits barred"
        case .grayTheGarry: "A row locked"
        case .garryTheGray: "A box locked"
        }
    }

    var previewSymbol: String {
        switch self {
        case .censor: "eye.slash"
        case .editor: "pencil.line"
        case .deadline, .tikTak: "timer"
        case .fog: "cloud.fog"
        case .critic: "exclamationmark.bubble"
        case .mirror: "rectangle.on.rectangle"
        case .paywall: "lock"
        case .erratum: "arrow.uturn.backward"
        case .collector, .accountant: "banknote"
        case .heavyLifter: "dumbbell"
        case .unluckyLucky: "bookmark.slash"
        case .buffborger: "shield.slash"
        case .sashimi: "scissors"
        case .overPusher: "arrow.right"
        case .handyDandy: "hand.raised.slash"
        case .grayTheGarry, .garryTheGray: "square.grid.3x3"
        }
    }

    var previewEscapeDistance: CGFloat {
        switch self {
        case .overPusher, .heavyLifter: 24
        case .deadline, .tikTak: 18
        default: 13
        }
    }

    var previewDuration: Double {
        switch self {
        case .deadline, .tikTak: 0.72
        case .overPusher: 0.9
        default: 1.55
        }
    }

    var isPulsingPreview: Bool {
        switch self {
        case .deadline, .tikTak, .critic, .heavyLifter, .overPusher: true
        default: false
        }
    }
}

struct ClippingOfferTicket: View {
    @Environment(\.cosmeticTheme) private var theme
    var clipping: Clipping
    var remaining: Int
    var arrived: Bool
    var clipBounced: Bool
    var stampVisible: Bool
    var onTake: () -> Void

    var body: some View {
        ticket
            .background {
                Rectangle().fill(theme.paper.edge.opacity(0.82))
                    .overlay { Rectangle().strokeBorder(theme.paper.ruleInk.opacity(0.35), lineWidth: 0.8) }
                    .offset(x: 4, y: 6)
            }
            .rotationEffect(.degrees(arrived ? -1 : 6)).offset(x: arrived ? 0 : 30).opacity(arrived ? 1 : 0)
            .shadow(color: .black.opacity(0.18), radius: 5, x: 1, y: 4)
            .accessibilityElement(children: .contain)
    }

    private var ticket: some View {
        VStack(spacing: 0) {
            ticketTop
            Divider().overlay(theme.paper.ruleInk.opacity(0.65))
            HStack(spacing: 15) {
                TicketSeal()
                VStack(alignment: .leading, spacing: 4) {
                    Text(clipping.name)
                        .font(.system(size: 27, weight: .medium, design: .serif))
                        .foregroundStyle(theme.paper.ink)
                    Text(clipping.detail).font(Print.body(14)).foregroundStyle(theme.paper.softInk).fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 17).padding(.vertical, 24)
            DashedPerforation(color: theme.paper.ruleInk)
            Button(action: onTake) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Tear off to take").font(Print.caption(9.5)).tracking(1).textCase(.uppercase).foregroundStyle(Paper.redPencil)
                        Text("Skip + reward").font(Print.subheading(17)).tracking(0.75).textCase(.uppercase)
                    }
                    Spacer()
                    Image(systemName: "arrow.right").font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(theme.paper.ink).padding(.horizontal, 17).padding(.vertical, 14).contentShape(Rectangle())
            }
            .buttonStyle(PressedPaperStyle()).accessibilityLabel("Skip Puzzle and take \(clipping.name)")
        }
        .background(theme.paper.warm)
        .overlay { Rectangle().strokeBorder(theme.paper.ruleInk.opacity(0.7), lineWidth: 0.9) }
        .overlay(alignment: .topTrailing) {
            Image(systemName: "paperclip").font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.paper.ink.opacity(0.75)).rotationEffect(.degrees(17))
                .scaleEffect(clipBounced ? 1.13 : 1).offset(x: -18, y: -11).accessibilityHidden(true)
        }
    }

    private var ticketTop: some View {
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
        .padding(.horizontal, 17).padding(.vertical, 13)
    }
}

private struct TicketSeal: View {
    @Environment(\.cosmeticTheme) private var theme
    var body: some View {
        Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 25, weight: .medium))
            .foregroundStyle(theme.paper.ink).frame(width: 60, height: 60)
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
