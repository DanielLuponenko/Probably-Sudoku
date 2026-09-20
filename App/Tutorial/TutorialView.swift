import SwiftUI
import ProbablySudokuEngine

struct FirstTimeWelcomeView: View {
    let onExperienced: () -> Void
    let onLearn: () -> Void

    var body: some View {
        TutorialPaper {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 42, weight: .light))
                        .foregroundStyle(GameplaySurface.sage)
                        .accessibilityHidden(true)
                        .padding(22)
                        .background(Paper.pageWarm, in: .rect(cornerRadius: 14))
                        .padding(.top, 24)
                    Text("A little practice.\nA better first Book.")
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                    Text("Place a number. Build a combination. Beat the target.")
                        .font(.title3.weight(.medium))
                    Text("Six short chapters, using the real game. Your practice Book is separate from your saves, coins and achievements.")
                        .font(.body)
                        .foregroundStyle(Paper.inkSoft)
                    VStack(spacing: 12) {
                        TutorialButton(title: "Learn by playing", prominent: true, action: onLearn)
                        TutorialButton(title: "I've played before", action: onExperienced)
                    }
                    .padding(.top, 12)
                    Text("At your pace · Skip whenever you like")
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

enum TutorialPresentation {
    case firstRun, replay

    var exitTitle: String { self == .replay ? "Exit practice" : "Skip tutorial" }
    var completionTitle: String { self == .replay ? "Back to Settings" : "Choose my first Book" }
    var completionMessage: String {
        self == .replay
            ? "Your refresher is complete. Return to Settings, then carry on with your Book. None of this practice changes your saves, coins, scores or achievements."
            : "Pick a Book, reach its targets, and build useful combinations. Your real game starts fresh; none of this practice changes its progress or records."
    }
}

struct TutorialView: View {
    var presentation: TutorialPresentation = .firstRun
    let onFinish: (OnboardingStore.Resolution) -> Void
    @State private var session = TutorialSession()
    @State private var deliveredCompletion = false

    var body: some View {
        TutorialLessonPage(session: session, presentation: presentation)
            .task { await session.prepare() }
            .onChange(of: session.completion) { _, resolution in
                guard let resolution, !deliveredCompletion else { return }
                deliveredCompletion = true
                onFinish(resolution)
            }
            .onDisappear { session.stop() }
    }
}

/// The same interactive page is used for first-time learning and Settings replay.
/// Its session owns a separate engine Game; none of these controls write saves.
struct TutorialLessonPage: View {
    let session: TutorialSession
    let presentation: TutorialPresentation
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.gameReduceMotion) private var reduceMotion
    @AccessibilityFocusState private var focusedStep: TutorialSession.Step?

    var body: some View {
        TutorialPaper {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                lessonHeading.id("lesson-top")
                                if let snapshot = session.snapshot {
                                    lesson(snapshot, boardSize: boardSize(in: geometry.size))
                                } else {
                                    preparation
                                }
                            }
                            .frame(maxWidth: 480, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: session.step) { _, newStep in
                            proxy.scrollTo("lesson-top", anchor: .top)
                            if voiceOver { focusedStep = newStep }
                        }
                        .onChange(of: session.completedActions.count) { old, new in
                            if new > old { Haptics.menuOpen() }
                        }
                    }
                    if !dynamicType.isAccessibilitySize || hasPinnedAction {
                        footer
                    }
                }
            }
        }
    }

    private func boardSize(in size: CGSize) -> CGFloat {
        // Keep the real Hand below the board and above the task footer on a
        // compact phone. Enlarged reading content keeps its normal scroll path.
        let reserve: CGFloat = hasPinnedAction ? 470 : (session.successMessage == nil ? 430 : 460)
        return min(360, max(190, size.height - reserve), max(190, size.width - 40))
    }

    private var header: some View {
        VStack(spacing: 2) {
          HStack(alignment: .center, spacing: 12) {
            if dynamicType.isAccessibilitySize {
                Text("\(session.step.chapter.rawValue + 1)/\(TutorialSession.Chapter.allCases.count)")
                    .font(.caption2)
                    .accessibilityLabel("Chapter \(session.step.chapter.rawValue + 1) of 6. \(session.step.chapter.title). \(session.completedActions.count) of \(TutorialSession.actionCount) practice actions completed.")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter).font(.caption.weight(.semibold))
                    Text("\(session.completedActions.count) of \(TutorialSession.actionCount) actions tried")
                        .font(.caption2).foregroundStyle(Paper.inkSoft)
                        .accessibilityIdentifier("tutorial-action-progress")
                }
            }
            Spacer(minLength: 0)
            Button(dynamicType.isAccessibilitySize ? "Exit" : presentation.exitTitle, action: session.skip)
                .font(.callout.weight(.semibold))
                .foregroundStyle(Paper.ink)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel(presentation.exitTitle)
                .accessibilityIdentifier("tutorial-skip")
          }
          if !dynamicType.isAccessibilitySize {
              HStack(spacing: 5) {
                  ForEach(TutorialSession.Chapter.allCases, id: \.rawValue) { chapter in
                      Capsule().fill(chapter.rawValue <= session.step.chapter.rawValue
                          ? GameplaySurface.sage : Paper.rule.opacity(0.35))
                          .frame(height: 3)
                  }
              }
              .padding(.bottom, 5)
              .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: session.step.chapter)
              .accessibilityHidden(true)
          }
        }
        .padding(.horizontal, 20).padding(.vertical, 4)
        .overlay(alignment: .bottom) { Rectangle().fill(Paper.rule).frame(height: 1) }
    }

    private var lessonHeading: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(copy.title)
                .font(.system(.title2, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($focusedStep, equals: session.step)
                .accessibilityIdentifier("tutorial-heading")
            Text(copy.body)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(Paper.inkSoft)
            if let feedback = session.feedback {
                Label(feedback, systemImage: "arrow.turn.up.left")
                    .font(.callout)
                    .foregroundStyle(Paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tutorial-feedback")
            } else if let message = session.successMessage {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(GameplaySurface.sage)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("tutorial-success")
            }
        }
    }

    @ViewBuilder
    private func lesson(_ snapshot: TutorialPracticeSnapshot, boardSize: CGFloat) -> some View {
        switch session.step {
        case .goal, .select, .place, .bank, .banked,
             .markerPlacement, .comboSelect, .comboPlace, .comboScore,
            .buffed, .comboBank, .won:
            TutorialScore(snapshot: snapshot)
            TutorialPracticeBoard(cells: snapshot.cells, target: session.targetSquare,
                highlightsTarget: boardIsInteractive, isInteractive: boardIsInteractive,
                markedSquares: snapshot.markedSquares, place: boardAction)
                .frame(width: boardSize, height: boardSize)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(voiceOver)
            if !snapshot.hand.isEmpty {
                TutorialHand(cards: snapshot.hand, targetID: showsHand ? session.targetCardID : nil,
                             selectedID: session.selectedCardID,
                             isInteractive: session.step == .select || session.step == .comboSelect,
                             select: session.selectCard)
            }
            if voiceOver && boardIsInteractive, let square = session.targetSquare {
                TutorialButton(title: session.step == .markerPlacement
                    ? "Mark row \(square.row + 1), column \(square.col + 1)"
                    : "Place \(session.targetDigit?.rawValue ?? 1) in row \(square.row + 1), column \(square.col + 1)",
                    prominent: true) { _ = boardAction(square) }
                    .accessibilityIdentifier("tutorial-accessible-place")
            }
            if session.step == .markerPlacement {
                TutorialNote(title: "Golden Marker · +100 points",
                    detail: "It stays on this square for the Book. A printed starting number makes it dormant for that puzzle.")
            }
            if !snapshot.bookmarks.isEmpty { inventorySummary(snapshot) }
        case .shop:
            coinBalance(snapshot)
            TutorialNote(title: "A practice budget",
                detail: "30 supplied coins and a spare Overtime Buff. In a real Book, your puzzle payout funds the Shop.")
            ForEach(snapshot.offers) { offer in
                HStack {
                    Image(systemName: ItemIcon.symbol(for: offer.defID)).accessibilityHidden(true)
                    Text(offer.name).font(.callout.weight(.semibold))
                    Spacer()
                    Text("\(offer.price) coins").font(.callout)
                }
                .accessibilityElement(children: .combine)
            }
        case .buyBookmark, .buyMultiplier, .buyMarker, .buyBuff:
            coinBalance(snapshot)
            if let offer = snapshot.offers.first(where: { $0.slot == session.targetOfferSlot }) {
                TutorialItemCard(defID: offer.defID, name: offer.name, detail: offer.detail,
                    caption: "Shop price · \(offer.price) coins", actionTitle: "Buy \(offer.name) · \(offer.price) coins",
                    actionID: "tutorial-buy-\(offer.slot)") { _ = session.buyOffer(offer.slot) }
            }
            inventorySummary(snapshot)
        case .useBuff:
            TutorialScore(snapshot: snapshot)
            if let item = snapshot.buffs.first(where: { $0.index == session.targetBuffIndex }) {
                TutorialItemCard(defID: item.defID, name: item.name, detail: item.detail,
                    caption: "In your Buff slots · one use", actionTitle: "Use \(item.name)",
                    actionID: "tutorial-use-\(item.index)") { _ = session.useBuff(item.index) }
            }
        case .sellBookmark, .sellBuff:
            coinBalance(snapshot)
            let items = session.step == .sellBookmark ? snapshot.bookmarks : snapshot.buffs
            if let item = items.first(where: { $0.index == session.targetSaleIndex }),
               let kind = session.targetSaleKind {
                TutorialItemCard(defID: item.defID, name: item.name, detail: item.detail,
                    caption: "Paid \(item.pricePaid) · sell for \(item.sellPrice) coins",
                    actionTitle: "Sell \(item.name) · +\(item.sellPrice) coins",
                    actionID: "tutorial-sell-\(kind.rawValue)-\(item.index)") {
                    _ = session.sellItem(kind: kind, index: item.index)
                }
            }
            inventorySummary(snapshot)
        case .payout:
            coinBalance(snapshot)
            TutorialNote(title: "Coins for your next Shop",
                detail: "\(snapshot.payout?.total ?? 0) coins collected. Spend them in the next Shop, or save for interest.")
            inventorySummary(snapshot)
        case .books:
            TutorialNote(title: "Probably Sudoku", detail: Book.probably.benefit.detail)
            TutorialNote(title: "Play or skip an ordinary puzzle",
                detail: "The next-puzzle page shows your target and a specific skip Buff. Skip as often as you like. If your Buff slots are full, replace one or cancel first.")
        case .boss:
            TutorialNote(title: BossModifier.deadline.name, detail: BossModifier.deadline.text)
            TutorialNote(title: "Read before you play",
                detail: "Boss puzzles are mandatory. Read the rule, then play around it. Beat the final Boss to complete the Book; there is no final Shop.")
        case .ready:
            TutorialNote(title: "You tried it yourself",
                detail: "\(session.completedActions.count) real practice actions completed. Place, buy, mark, use, sell, bank and Cash Out—your next Book is yours to build.")
        }
    }

    private func coinBalance(_ snapshot: TutorialPracticeSnapshot) -> some View {
        Label("\(snapshot.coins) practice coins", systemImage: "circle.circle")
            .font(.title3.weight(.semibold)).monospacedDigit()
            .accessibilityIdentifier("tutorial-coins")
    }

    private func inventorySummary(_ snapshot: TutorialPracticeSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Your practice items").font(.subheadline.weight(.semibold))
            Text("Bookmarks: \(snapshot.bookmarks.map(\.name).joined(separator: ", ").nilIfEmpty ?? "none")")
            Text("Markers: \(snapshot.markers.map(\.name).joined(separator: ", ").nilIfEmpty ?? "none")")
            Text("Buffs: \(snapshot.buffs.map(\.name).joined(separator: ", ").nilIfEmpty ?? "none")")
        }
        .font(.footnote).foregroundStyle(Paper.inkSoft)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tutorial-inventory")
    }

    private var preparation: some View {
        VStack(alignment: .leading, spacing: 14) {
            if session.preparationFailed {
                Text("The practice page couldn't open. Try again, or skip to the Books.")
                TutorialButton(title: "Try again") { Task { await session.prepare() } }
            } else {
                ProgressView("Opening a fresh practice page…").tint(Paper.sageDeep)
            }
        }.padding(.vertical, 30)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            if session.snapshot != nil {
                switch session.step {
                case .bank, .comboBank:
                    TutorialButton(title: "End Turn", prominent: true) { _ = session.bankTurn() }
                        .accessibilityIdentifier("tutorial-end-turn")
                case .won:
                    TutorialButton(title: "Cash Out", prominent: true) { _ = session.cashOut() }
                        .accessibilityIdentifier("tutorial-cash-out")
                case .select, .comboSelect, .place, .comboPlace, .markerPlacement,
                     .buyBookmark, .buyMultiplier, .buyMarker, .buyBuff, .useBuff,
                     .sellBookmark, .sellBuff:
                    Label(actionHint, systemImage: "hand.tap")
                        .font(.footnote.weight(.semibold))
                        .frame(minHeight: 32)
                        .accessibilityIdentifier("tutorial-action-hint")
                default:
                    TutorialButton(title: session.step == .ready ? presentation.completionTitle : "Continue", prominent: true,
                                   action: session.continueLesson)
                        .accessibilityIdentifier("tutorial-continue")
                }
            }
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 20).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Paper.pageWarm)
        .overlay(alignment: .top) { Rectangle().fill(Paper.rule).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("tutorial-footer")
    }

    private var hasPinnedAction: Bool {
        !session.step.requiresInteraction || [.bank, .comboBank, .won].contains(session.step)
    }

    private var showsHand: Bool {
        [.select, .place, .comboSelect, .comboPlace].contains(session.step)
    }
    private var boardIsInteractive: Bool {
        [.place, .comboPlace, .markerPlacement].contains(session.step)
    }
    private func boardAction(_ square: Square) -> Bool {
        session.step == .markerPlacement ? session.claimMarker(at: square) : session.place(at: square)
    }
    private var chapter: String {
        "\(session.step.chapter.rawValue + 1) of 6 · \(session.step.chapter.title)"
    }
    private var actionHint: String {
        switch session.step {
        case .select, .comboSelect: "Tap the outlined number in your Hand"
        case .place, .comboPlace: "Tap the outlined square"
        case .markerPlacement: "Choose the outlined Marker square"
        case .useBuff: "Tap Use on the Buff above"
        case .sellBookmark, .sellBuff: "Tap Sell on the item above"
        default: "Tap Buy on the item above"
        }
    }
    private var copy: (title: String, body: String) {
        let digit = session.targetDigit?.rawValue ?? 1
        switch session.step {
        case .goal: return ("Score points. Leave blanks.", "Reach the target before your Turns run out. You can win with empty squares. Let's play one Turn.")
        case .select: return ("Start with a number.", "Tap the outlined \(digit) below the board. Rows, columns and 3×3 boxes use 1–9 without repeats.")
        case .place: return ("Give it a square.", "Tap the outlined empty square. Your \(digit) fits here. Wrong practice taps cost nothing.")
        case .bank: return ("Bank your first Turn.", "Tap End Turn to add the live points to your score and refill your Hand. In a real Turn, you can place more numbers first.")
        case .banked: return ("Points in the bank.", "Your score rose, your Hand refilled, and one Turn was spent. Next: items that make every placement worth more.")
        case .shop: return ("Try a practice Shop.", "A real Shop opens after Cash Out. This supplied shelf lets you try all three item types.")
        case .buyBookmark: return ("Buy a Bookmark.", "Buy Local Gossip below. It adds points to every correct placement automatically.")
        case .buyMultiplier: return ("Give your score a multiplier.", "Buy Front Page Splash. It adds 1 Mult per Bookmark, including itself. Your two Bookmarks make ×3.")
        case .buyMarker: return ("A bonus on one square.", "Buy Golden Marker. Your next lesson puts its +100 placement Points on a square you choose.")
        case .buyBuff: return ("Keep a trick for later.", "Buy Fresh Ink. Use this consumable once for +2 Mult through the rest of the puzzle.")
        case .markerPlacement: return ("Put your Marker to work.", "Tap the outlined blank to mark it. This prepared row and box share their last missing number.")
        case .comboSelect: return ("Set up a Line Clear.", "Tap the outlined \(digit) in your Hand. Your Bookmarks are already working.")
        case .comboPlace: return ("Make the pieces work together.", "Place \(digit) on the Golden square. Complete the row and box, then let your items add their bonuses.")
        case .comboScore: return ("See your combination.", "Golden Marker and Local Gossip added Points. The row and box added two Line Clears; Front Page Splash made ×3.")
        case .useBuff: return ("Use Fresh Ink.", "Tap Use. This copy is spent, and its +2 Mult also boosts the Points already earned this Turn.")
        case .buffed: return ("Same Points. More Mult.", "Base 1 + Fresh Ink 2 + Front Page Splash 2 = 5 Mult. Your live total grew; the Buff left its slot.")
        case .sellBookmark: return ("Sell a Bookmark.", "Sell Local Gossip below. Earned Points stay. In your Book, use the item's details or drag it to Sell.")
        case .sellBuff: return ("Unused Buffs can be sold too.", "Sell the spare Overtime. A sale returns half the price paid, rounded down, with a minimum of one coin.")
        case .comboBank: return ("Bank the combination.", "Tap End Turn to bank your multiplied Points and reach the practice target.")
        case .won: return ("Target reached.", "Tap Cash Out for your payout. In your Book, Keep Filling can earn extra coins while Turns and blanks remain.")
        case .payout: return ("Your next Shop is funded.", "Your coins and remaining items carry into the next puzzle of the Book.")
        case .books: return ("Choose your Book's benefit.", "Probably Sudoku starts with an extra number in your Hand. Each Book brings its own benefit.")
        case .boss: return ("Read the Boss first.", "Bosses change the rules. Read the announced effect before playing.")
        case .ready: return ("You're ready. Probably.", presentation.completionMessage)
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private struct TutorialNote: View {
    let title: String
    let detail: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(.headline, design: .serif))
            Text(detail).font(.callout).foregroundStyle(Paper.inkSoft)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(14).frame(maxWidth: .infinity, alignment: .leading)
        .background(Paper.pageWarm, in: .rect(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(Paper.rule.opacity(0.65), lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }
}

private struct TutorialItemCard: View {
    let defID: String
    let name: String
    let detail: String
    let caption: String
    let actionTitle: String
    let actionID: String
    let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ItemArtwork(id: defID, size: 32, style: .glyph)
                    .foregroundStyle(isBuff ? Paper.pageWarm : GameplaySurface.sage)
                    .frame(width: 50, height: 54)
                    .background(isBuff ? Paper.ink : Paper.page, in: .rect(cornerRadius: 7))
                    .overlay(alignment: .top) {
                        if isBuff { Capsule().fill(Paper.coin).frame(height: 3).padding(.horizontal, 3) }
                    }
                    .accessibilityHidden(true)
                Text(name)
                    .font(.system(.title3, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.body).fixedSize(horizontal: false, vertical: true)
            Text(caption).font(.callout).foregroundStyle(Paper.inkSoft)
            TutorialButton(title: actionTitle, prominent: true, action: action)
                .accessibilityIdentifier(actionID)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Paper.pageWarm, in: .rect(cornerRadius: 9))
        .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(Paper.sageDeep.opacity(0.6), lineWidth: 1) }
        .shadow(color: Paper.ink.opacity(0.08), radius: 4, y: 3)
    }

    private var isBuff: Bool { Catalog.item(defID)?.kind == .buff }
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
        .buttonStyle(PressedPaperStyle())
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
    }
}

private struct TutorialScore: View {
    let snapshot: TutorialPracticeSnapshot
    @Environment(\.dynamicTypeSize) private var dynamicType
    @Environment(\.gameReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    bankedScore.fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 8)
                    turn
                }
                VStack(alignment: .leading, spacing: 3) {
                    bankedScore.fixedSize(horizontal: false, vertical: true)
                    turn
                }
            }
            if dynamicType.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 3) { turnTotal; calculation }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    turnTotal
                    Spacer(minLength: 0)
                    calculation
                }
            }
        }
        .monospacedDigit()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("tutorial-live-score")
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var bankedScore: some View {
        Text("\(snapshot.score.formatted()) / \(snapshot.target.formatted()) points")
            .font(.system(.title3, design: .serif).weight(.semibold))
    }

    private var turn: some View {
        Text("Turn \(snapshot.turn)/\(snapshot.turns)")
            .font(.caption).foregroundStyle(Paper.inkSoft)
            .fixedSize(horizontal: true, vertical: false)
    }

    private var turnTotal: some View {
        Text("+\(snapshot.queued.formatted()) this Turn")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(GameplaySurface.sage)
            .contentTransition(.numericText())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: snapshot.queued)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var calculation: some View {
        Text("\(snapshot.queuedBase.formatted()) Points × \(ScorePerformance.number(snapshot.multiplier)) Mult")
            .font(.caption)
            .foregroundStyle(Paper.inkSoft)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct TutorialPracticeBoard: View {
    let cells: [TutorialCell]
    let target: Square?
    let highlightsTarget: Bool
    let isInteractive: Bool
    let markedSquares: [Square]
    let place: (Square) -> Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
      GeometryReader { geometry in
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(cells) { cell in
                Button { _ = place(cell.square) } label: {
                    Text(cell.digit.map { String($0.rawValue) } ?? " ")
                        .font(.system(size: min(22, geometry.size.width / 9 * 0.58), weight: cell.isGiven ? .regular : .semibold))
                        .foregroundStyle(Paper.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(highlightsTarget && cell.square == target ? Paper.cellSelected :
                                        (markedSquares.contains(cell.square) ? Paper.coin.opacity(0.22) : Paper.pageWarm))
                        .overlay(alignment: .top) {
                            Rectangle().fill(.white.opacity(0.7)).frame(height: 1)
                        }
                        .overlay {
                            if highlightsTarget && cell.square == target {
                                Rectangle().strokeBorder(Paper.sageDeep, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(PressedPaperStyle())
                .disabled(!isInteractive || cell.digit != nil)
                .accessibilityIdentifier("tutorial-cell-\(cell.square.index)")
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
                    context.stroke(path, with: .color(line.isMultiple(of: 3) ? GameplaySurface.sage : .white.opacity(0.85)),
                                   lineWidth: line.isMultiple(of: 3) ? 3.5 : 1)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .overlay { Rectangle().strokeBorder(GameplaySurface.sage, lineWidth: 3.5) }
        .background {
            Rectangle().fill(Paper.pageWarm)
                .shadow(color: Paper.ink.opacity(0.16), radius: 3, y: 3)
        }
      }
        .dynamicTypeSize(.large) // Fixed grid geometry; VO gets a full-size placement button.
    }
}

private struct TutorialHand: View {
    let cards: [TutorialHandCard]
    let targetID: Int?
    let selectedID: Int?
    let isInteractive: Bool
    let select: (Int) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Hand").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 46), spacing: 2)], spacing: 7) {
                ForEach(cards) { card in
                    Button { _ = select(card.id) } label: {
                        Text("\(card.digit.rawValue)")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background {
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(card.id == targetID || card.id == selectedID ? Paper.cellSelected : Paper.pageWarm)
                                    .shadow(color: Paper.ink.opacity(0.16), radius: 1, y: 2)
                            }
                            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(card.id == targetID || card.id == selectedID ? Paper.sageDeep : .white.opacity(0.9), lineWidth: card.id == targetID || card.id == selectedID ? 2 : 1) }
                    }
                    .buttonStyle(PressedPaperStyle())
                    .disabled(!isInteractive)
                    .accessibilityLabel("Number \(card.digit.rawValue)\(card.id == targetID ? ", outlined practice number" : "")")
                    .accessibilityIdentifier("tutorial-hand-\(card.id)")
                    .accessibilityAddTraits(card.id == selectedID ? .isSelected : [])
                }
            }
        }
    }
}
