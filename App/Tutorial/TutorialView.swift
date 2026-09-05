import SwiftUI
import ProbablySudokuEngine

struct FirstTimeWelcomeView: View {
    let onExperienced: () -> Void
    let onLearn: () -> Void

    var body: some View {
        TutorialPaper {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "book.closed")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(Paper.sageDeep)
                        .accessibilityHidden(true)
                        .padding(.top, 36)
                    Text("Have you played Probably Sudoku before?")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("A familiar grid. A slightly different game.")
                        .font(.title3)
                    Text("The short version takes about 90 seconds. You can try a move, or let the page show you.")
                        .font(.body)
                        .foregroundStyle(Paper.inkSoft)
                    Text("no pressure. this page doesn't count.")
                        .font(.custom("Bradley Hand", size: 22, relativeTo: .title3))
                        .foregroundStyle(Paper.pencil)
                    VStack(spacing: 12) {
                        TutorialButton(title: "Yes, I've played", action: onExperienced)
                        TutorialButton(title: "No, show me how", prominent: true, action: onLearn)
                    }
                    .padding(.top, 12)
                    Text("Under 2 minutes · Skip whenever you like")
                        .font(.footnote)
                        .foregroundStyle(Paper.inkSoft)
                        .padding(.bottom, 24)
                }
                .frame(maxWidth: 440, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct TutorialView: View {
    let onFinish: (OnboardingStore.Resolution) -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var session = TutorialSession()
    @State private var deliveredCompletion = false
    @AccessibilityFocusState private var focusedStep: TutorialSession.Step?

    private struct PacingKey: Equatable {
        let step: TutorialSession.Step
        let revision: Int
        let isActive: Bool
        let voiceOver: Bool
        let isReady: Bool
    }

    private var pacingKey: PacingKey {
        PacingKey(step: session.step, revision: session.activityRevision,
                  isActive: scenePhase == .active, voiceOver: voiceOver,
                  isReady: session.snapshot != nil)
    }

    var body: some View {
        TutorialPaper {
            VStack(spacing: 0) {
                header
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            lessonHeading
                                .id("lesson-top")
                            if let snapshot = session.snapshot {
                                lesson(snapshot)
                            } else {
                                preparation
                            }
                            if let feedback = session.feedback {
                                Label(feedback, systemImage: "pencil.tip")
                                    .font(.body)
                                    .foregroundStyle(Paper.ink)
                            }
                        }
                        .frame(maxWidth: 440, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                    }
                    .onChange(of: session.step) { _, newStep in
                        proxy.scrollTo("lesson-top", anchor: .top)
                        if voiceOver { focusedStep = newStep }
                    }
                }
                footer
            }
        }
        .task { await session.prepare() }
        .task(id: pacingKey) {
            await session.advanceWhenIdle(enabled: scenePhase == .active && !voiceOver)
        }
        .onChange(of: session.completion) { _, resolution in
            guard let resolution, !deliveredCompletion else { return }
            deliveredCompletion = true
            onFinish(resolution)
        }
        .onDisappear { session.stop() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Practice \(session.step.rawValue + 1) of \(TutorialSession.Step.allCases.count)")
                .font(.caption)
                .foregroundStyle(Paper.inkSoft)
            Spacer(minLength: 0)
            Button("Skip tutorial", action: session.skip)
                .font(.body.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityIdentifier("tutorial-skip")
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Paper.rule).frame(height: 1) }
    }

    private var lessonHeading: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(copy.title)
                .font(.system(.title, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedStep, equals: session.step)
            Text(copy.body)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Paper.inkSoft)
        }
    }

    @ViewBuilder
    private func lesson(_ snapshot: TutorialPracticeSnapshot) -> some View {
        if session.step.showsBoard {
            TutorialScore(snapshot: snapshot)
            TutorialPracticeBoard(cells: snapshot.cells, target: session.targetSquare,
                                  highlightsTarget: session.step == .place,
                                  isInteractive: session.step == .place,
                                  place: session.place)
                .frame(maxWidth: 340)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(voiceOver)
            if session.step == .select || session.step == .place {
                TutorialHand(cards: snapshot.hand, targetID: session.targetCardID,
                             selectedID: session.selectedCardID, select: session.selectCard)
            }
            if voiceOver, session.step == .place, let square = session.targetSquare,
               let digit = session.targetDigit {
                TutorialButton(title: "Place \(digit.rawValue) in row \(square.row + 1), column \(square.col + 1)",
                               prominent: true) { session.place(at: square) }
            }
        } else {
            TutorialExamples(step: session.step)
        }
    }

    private var preparation: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.preparationFailed {
                Text("The practice page couldn't open. Try again, or skip to the Books.")
                TutorialButton(title: "Try again") { Task { await session.prepare() } }
            } else {
                ProgressView("Opening a fresh practice page…")
                    .tint(Paper.sageDeep)
            }
        }
        .padding(.vertical, 30)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            TutorialButton(title: actionTitle, prominent: true,
                           isEnabled: session.snapshot != nil) {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.15)) {
                    session.continueLesson()
                }
            }
            .accessibilityIdentifier("tutorial-continue")
            Text(voiceOver ? "Take your time. Use the button to continue." : "Try it yourself, or let the guide continue.")
                .font(.footnote)
                .foregroundStyle(Paper.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 440)
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(Paper.pageWarm)
    }

    private var actionTitle: String {
        switch session.step {
        case .select, .place: "Show me"
        case .bank: "End Turn"
        case .ready: "Choose my first Book"
        default: "Continue"
        }
    }

    private var copy: (title: String, body: String) {
        let digit = session.targetDigit?.rawValue ?? 1
        switch session.step {
        case .goal:
            return ("Score points. Leave blanks.", "Reach the score target before your Turns run out. You do not have to finish the Sudoku. This practice page cannot touch your real Book.")
        case .select:
            return ("Start with a number.", "Your Hand holds the numbers you can play. Tap the outlined \(digit). Each row, column and 3-by-3 box uses 1 to 9 without repeats.")
        case .place:
            return ("Give it a square.", "Tap the outlined space. It can take \(digit) without a repeat in its row, column or box. Wrong practice taps cost nothing.")
        case .bank:
            return ("Bank your points.", "Correct placements queue points. End Turn banks them together, refills your Hand and spends one Turn. Try it now.")
        case .banked:
            return ("\(session.snapshot?.score ?? 0) points in the bank.", "That's one Turn. This puzzle gives you 10 Turns to reach 1,000 points. Completing rows, columns and boxes earns extra points.")
        case .books:
            return ("Your Book brings a benefit.", "Each Book has a different ability. Its benefit lasts for that Book. Pick the one that suits how you want to play.")
        case .bookmarks:
            return ("Build a good combination.", "Bookmarks stay with you for the current Book, adding points or multipliers. Their effects can work together. Sell one when you need room for another.")
        case .tools:
            return ("Mark a square. Save a trick.", "Markers attach bonuses to grid squares for the Book. Buffs are different: each copy is spent once. Use one when its effect will help.")
        case .shop:
            return ("Coins have a job.", "After a win, your payout buys items in the Shop. Spend thoughtfully, or save for interest. The price is shown before you buy; rerolls also cost coins.")
        case .boss:
            return ("Read the Boss first.", "Every Level ends with a Boss and a known power. Read the preview before you play and plan around it. Beat the final Boss to finish the Book—no final Shop.")
        case .ready:
            return ("You're ready. Probably.", "Pick a Book, reach its targets, and build useful combinations. Your real game starts fresh; none of this practice changes its progress or records.")
        }
    }
}

private struct TutorialPaper<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .foregroundStyle(Paper.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Paper.page
                    .overlay {
                        Image(decorative: "BetweenPuzzlesPaper")
                            .resizable().scaledToFill().opacity(0.07).clipped()
                    }
                    .ignoresSafeArea()
            }
    }
}

private struct TutorialButton: View {
    let title: String
    var prominent = false
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Paper.ink)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(prominent ? Paper.cellSelected : Paper.pageWarm,
                            in: .rect(cornerRadius: 5))
                .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.sageDeep, lineWidth: prominent ? 1.5 : 0.7) }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct TutorialScore: View {
    let snapshot: TutorialPracticeSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(snapshot.score.formatted()) / \(snapshot.target.formatted()) points")
                .font(.system(.title3, design: .serif).weight(.semibold))
                .monospacedDigit()
            Text("Turn \(snapshot.turn) of \(snapshot.turns) · \(snapshot.queued) points queued")
                .font(.footnote)
                .foregroundStyle(Paper.inkSoft)
        }
        .accessibilityElement(children: .combine)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TutorialPracticeBoard: View {
    let cells: [TutorialCell]
    let target: Square?
    let highlightsTarget: Bool
    let isInteractive: Bool
    let place: (Square) -> Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(cells) { cell in
                Button { _ = place(cell.square) } label: {
                    Text(cell.digit.map { String($0.rawValue) } ?? " ")
                        .font(.system(size: 20, weight: cell.isGiven ? .regular : .bold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(highlightsTarget && cell.square == target ? Paper.cellSelected :
                                        (cell.isGiven ? Paper.cellGiven : Paper.page))
                        .overlay {
                            if highlightsTarget && cell.square == target {
                                Rectangle().strokeBorder(Paper.sageDeep, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
                .disabled(!isInteractive || cell.isGiven)
                .accessibilityLabel("Row \(cell.square.row + 1), column \(cell.square.col + 1), \(cell.digit.map { String($0.rawValue) } ?? "empty")")
                .accessibilityHidden(cell.square != target || !isInteractive)
            }
        }
        .overlay {
            Canvas { context, size in
                for line in 0...9 {
                    var path = Path()
                    let x = size.width * CGFloat(line) / 9
                    let y = size.height * CGFloat(line) / 9
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(Paper.gridBold.opacity(line.isMultiple(of: 3) ? 1 : 0.4)),
                                   lineWidth: line.isMultiple(of: 3) ? 1.8 : 0.5)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .dynamicTypeSize(.large) // Fixed grid geometry; VO gets a full-size placement button.
    }
}

private struct TutorialHand: View {
    let cards: [TutorialHandCard]
    let targetID: Int?
    let selectedID: Int?
    let select: (Int) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Hand").font(.headline)
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(cards) { card in
                            Button { _ = select(card.id) } label: {
                                Text("\(card.digit.rawValue)")
                                    .font(.system(.title2, design: .serif).weight(.semibold))
                                    .foregroundStyle(Paper.ink)
                                    .frame(minWidth: 46, minHeight: 54)
                                    .background(card.id == targetID ? Paper.cellSelected : Paper.pageWarm,
                                                in: .rect(cornerRadius: 3))
                                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(card.id == targetID ? Paper.sageDeep : Paper.rule, lineWidth: card.id == targetID ? 2 : 0.7) }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Number \(card.digit.rawValue)\(card.id == targetID ? ", outlined practice number" : "")")
                            .accessibilityAddTraits(card.id == selectedID ? .isSelected : [])
                            .id(card.id)
                        }
                    }
                    .padding(.vertical, 3)
                }
                .onAppear {
                    if let targetID { proxy.scrollTo(targetID, anchor: .center) }
                }
            }
        }
    }
}

private struct TutorialExamples: View {
    let step: TutorialSession.Step

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            switch step {
            case .books:
                example(symbol: "book.closed", title: "Probably Sudoku",
                        detail: Book.probably.benefit.detail)
            case .bookmarks:
                item("bm_local_gossip", symbol: "bookmark")
                Text("One good idea. Every placement.")
                    .font(.custom("Bradley Hand", size: 23, relativeTo: .title3))
            case .tools:
                item("mk_golden", symbol: "square.and.pencil")
                item("bf_overtime", symbol: "clock.badge.plus")
            case .shop:
                example(symbol: "basket", title: "One budget for the Book",
                        detail: "Items can help you earn more points. You don't have to buy everything.")
                Text("save some. future you likes coins.")
                    .font(.custom("Bradley Hand", size: 23, relativeTo: .title3))
            case .boss:
                example(symbol: "exclamationmark.shield", title: BossModifier.deadline.name,
                        detail: BossModifier.deadline.text)
            case .ready:
                example(symbol: "checkmark.seal", title: "Practice complete",
                        detail: "This page stays out of your saves, scores, coins and achievements.")
            default: EmptyView()
            }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func item(_ id: String, symbol: String) -> some View {
        if let item = Catalog.item(id) {
            example(symbol: symbol, title: item.name, detail: item.text)
        }
    }

    private func example(symbol: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Paper.sageDeep)
                .accessibilityHidden(true)
            Text(title).font(.system(.title2, design: .serif).weight(.semibold))
            Text(detail).font(.body).fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
