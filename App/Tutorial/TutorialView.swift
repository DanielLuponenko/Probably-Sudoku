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
                    Text("Learn by playing: place numbers, build a multiplier, buy useful items and try selling one. Everything happens in a separate practice Book.")
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
    @AccessibilityFocusState private var focusedStep: TutorialSession.Step?

    var body: some View {
        TutorialPaper {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    header
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                lessonHeading.id("lesson-top")
                                if let snapshot = session.snapshot {
                                    lesson(snapshot, boardSize: boardSize(in: geometry.size))
                                } else {
                                    preparation
                                }
                                if let feedback = session.feedback {
                                    Label(feedback, systemImage: "pencil.tip")
                                        .font(.callout)
                                        .foregroundStyle(Paper.ink)
                                        .accessibilityIdentifier("tutorial-feedback")
                                }
                            }
                            .frame(maxWidth: 480, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .frame(maxWidth: .infinity)
                        }
                        .onChange(of: session.step) { _, newStep in
                            proxy.scrollTo("lesson-top", anchor: .top)
                            if voiceOver { focusedStep = newStep }
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
        min(300, max(190, size.height * 0.36), max(190, size.width - 40))
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            if dynamicType.isAccessibilitySize {
                Text("\(session.step.rawValue + 1)/\(TutorialSession.Step.allCases.count)")
                    .font(.caption2)
                    .accessibilityLabel("\(chapter), practice \(session.step.rawValue + 1) of \(TutorialSession.Step.allCases.count)")
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(chapter).font(.caption.weight(.semibold))
                    Text("Practice \(session.step.rawValue + 1) of \(TutorialSession.Step.allCases.count)")
                        .font(.caption2).foregroundStyle(Paper.inkSoft)
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
        }
    }

    @ViewBuilder
    private func lesson(_ snapshot: TutorialPracticeSnapshot, boardSize: CGFloat) -> some View {
        switch session.step {
        case .goal, .select, .place, .bank, .banked,
             .markerPlacement, .comboSelect, .comboPlace, .comboScore,
             .buffed, .comboBank, .won:
            if showsHand {
                TutorialHand(cards: snapshot.hand, targetID: session.targetCardID,
                             selectedID: session.selectedCardID,
                             isInteractive: session.step == .select || session.step == .comboSelect,
                             select: session.selectCard)
            }
            TutorialScore(snapshot: snapshot)
            if session.step == .comboScore || session.step == .buffed || session.step == .comboBank {
                TutorialNote(title: snapshot.completedUnits > 0 ? "Line clear + your items" : "Your scoring combination",
                    detail: "\(snapshot.queuedBase.formatted()) queued base × \(snapshot.multiplier.formatted(.number.precision(.fractionLength(0...2)))) mult = \(snapshot.queued.formatted()) points to bank.")
            }
            TutorialPracticeBoard(cells: snapshot.cells, target: session.targetSquare,
                highlightsTarget: boardIsInteractive, isInteractive: boardIsInteractive,
                markedSquares: snapshot.markedSquares, place: boardAction)
                .frame(width: boardSize, height: boardSize)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(voiceOver)
            if voiceOver && boardIsInteractive, let square = session.targetSquare {
                TutorialButton(title: session.step == .markerPlacement
                    ? "Mark row \(square.row + 1), column \(square.col + 1)"
                    : "Place \(session.targetDigit?.rawValue ?? 1) in row \(square.row + 1), column \(square.col + 1)",
                    prominent: true) { _ = boardAction(square) }
                    .accessibilityIdentifier("tutorial-accessible-place")
            }
            if session.step == .markerPlacement {
                TutorialNote(title: "Golden Marker · +100 points",
                    detail: "Choose the outlined square. In a real Book you choose its position. It stays there for the Book; a printed starting number makes it dormant for that puzzle.")
            }
            if !snapshot.bookmarks.isEmpty { inventorySummary(snapshot) }
        case .shop:
            coinBalance(snapshot)
            TutorialNote(title: "A practice budget",
                detail: "We supplied 30 practice coins and one spare Overtime Buff. Real Shop coins come from puzzle payouts. Prices and refunds are shown before you act.")
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
                detail: "Cash Out has paid this practice puzzle once. Your earned coins stay with the Book. Spend them on combinations, or save for interest.")
            inventorySummary(snapshot)
        case .books:
            TutorialNote(title: "Probably Sudoku", detail: Book.probably.benefit.detail)
            TutorialNote(title: "One build, a whole Book",
                detail: "Keep your Bookmarks and Markers between puzzles. Buffs are spent when used. Each Book has its own benefit and progress.")
        case .boss:
            TutorialNote(title: BossModifier.deadline.name, detail: BossModifier.deadline.text)
            TutorialNote(title: "Read before you play",
                detail: "Every Level ends with a Boss. Its announced rule may change your plan. Beat the final Boss to complete the Book; there is no final Shop.")
        case .ready:
            TutorialNote(title: "You tried it yourself",
                detail: "Place → build a multiplier → use a Buff → bank points → Cash Out. Buy Bookmarks and Markers for the Book; sell Bookmarks or unused Buffs when you need coins or space.")
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
                        .font(.callout.weight(.semibold))
                        .accessibilityIdentifier("tutorial-action-hint")
                default:
                    TutorialButton(title: session.step == .ready ? presentation.completionTitle : "Continue", prominent: true,
                                   action: session.continueLesson)
                        .accessibilityIdentifier("tutorial-continue")
                }
            }
            if !dynamicType.isAccessibilitySize {
                Text("At your pace · Practice never changes your saved Book")
                    .font(.caption).foregroundStyle(Paper.inkSoft)
                    .multilineTextAlignment(.center)
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
        switch session.step {
        case .goal, .select, .place, .bank, .banked: "1 · Play a Turn"
        case .shop, .buyBookmark, .buyMultiplier, .buyMarker, .buyBuff: "2 · Build your Book"
        case .markerPlacement, .comboSelect, .comboPlace, .comboScore, .useBuff, .buffed: "3 · Make a combination"
        case .sellBookmark, .sellBuff: "4 · Sell and make room"
        case .comboBank, .won, .payout: "5 · Reach the target"
        case .books, .boss, .ready: "6 · Your next Book"
        }
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
        case .goal: return ("Score points. Leave blanks.", "Reach the target before your Turns run out. You do not need to finish the Sudoku. Let's play one Turn together.")
        case .select: return ("Start with a number.", "Tap the outlined \(digit) in your Hand. Each row, column and 3-by-3 box uses 1 to 9 without repeats.")
        case .place: return ("Give it a square.", "Now tap the outlined empty square. The \(digit) fits its row, column and box. Wrong practice taps cost nothing.")
        case .bank: return ("Your points are queued.", "In a real Turn, play as many numbers from your Hand as fit before banking. We'll end this practice Turn now: End Turn banks your points, refills your Hand and spends one Turn.")
        case .banked: return ("Points in the bank.", "The queued score moved into your total. The Hand refilled and the Turn counter advanced. Next, try the items that make your points grow.")
        case .shop: return ("Try a practice Shop.", "In a real Book, the Shop opens after you Cash Out a puzzle. We'll jump to a stocked practice shelf so you can try each kind of item.")
        case .buyBookmark: return ("Buy a Bookmark.", "Local Gossip adds points to every correct placement. Bookmarks work automatically while you own them; you do not need a Use button.")
        case .buyMultiplier: return ("Give your score a multiplier.", "Local Gossip is yours. Now buy Op-Ed Column: its +1 mult adds to the starting ×1, making ×2. Additive bonuses add together: two +1 bonuses would make ×3.")
        case .buyMarker: return ("A bonus on one square.", "Golden Marker adds 100 placement points at its marked square. Buy it, then you'll choose a position on the practice board.")
        case .buyBuff: return ("Keep a trick for later.", "Fresh Ink adds +2 mult for the rest of this puzzle when used. Buy it now; unlike a Bookmark, each Buff copy is spent once.")
        case .markerPlacement: return ("Put your Marker to work.", "This next practice board has a nearly finished row. Tap the outlined square to attach Golden Marker there. Markers stay for the Book and cannot be sold.")
        case .comboSelect: return ("Set up a Line Clear.", "Tap the outlined \(digit). It is the missing number in the prepared row. Your passive Bookmarks are already equipped.")
        case .comboPlace: return ("Make the pieces work together.", "Place \(digit) on the Golden square. You'll earn placement points, a Line Clear, Local Gossip's bonus and Op-Ed's multiplier through the real scoring rules.")
        case .comboScore: return ("See your combination.", "The Marker boosted this placement, the completed row added a Line Clear, and Op-Ed raised your mult. These points are still queued until End Turn.")
        case .useBuff: return ("Use Fresh Ink.", "Tap Use to spend this copy. Its +2 mult lasts for this puzzle and also boosts the points already queued this Turn.")
        case .buffed: return ("More mult. Same queued base.", "Fresh Ink left your Buff slots and the multiplier rose. Op-Ed's +1 and Fresh Ink's +2 add to the starting ×1, giving ×4. Try selling an item next.")
        case .sellBookmark: return ("Sell a Bookmark.", "Open an owned item's details in the game to find Sell. Try Local Gossip here: selling removes it and returns coins. Points already earned stay queued.")
        case .sellBuff: return ("Unused Buffs can be sold too.", "Local Gossip has left your inventory and its refund is in your balance. Sell the spare Overtime Buff next. Refunds are half the price paid, rounded down, with a minimum of one coin.")
        case .comboBank: return ("Bank the combination.", "The spare Buff is sold, leaving room for a new one. Now tap End Turn to bank your multiplied points and reach this prepared practice target.")
        case .won: return ("Target reached.", "In the game, Keep Filling lets you continue for extra coins when Turns and empty squares remain. For this lesson, tap Cash Out to collect your payout.")
        case .payout: return ("Your next Shop is funded.", "The payout increased your practice coins. A real Book carries those coins and your remaining items into the next puzzle.")
        case .books: return ("Choose your Book's benefit.", "Each Book changes how you play. Probably Sudoku starts with one extra number in your Hand. Read the benefit before opening a Book.")
        case .boss: return ("Read the Boss first.", "Items are only part of your plan. A Boss brings an announced rule; read it before starting and choose your moves around it.")
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
        .background(Paper.pageWarm, in: .rect(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.rule, lineWidth: 1) }
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
            Label(name, systemImage: ItemIcon.symbol(for: defID))
                .font(.system(.title3, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(detail).font(.body).fixedSize(horizontal: false, vertical: true)
            Text(caption).font(.callout).foregroundStyle(Paper.inkSoft)
            TutorialButton(title: actionTitle, prominent: true, action: action)
                .accessibilityIdentifier(actionID)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(Paper.pageWarm, in: .rect(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(Paper.sageDeep, lineWidth: 1.5) }
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
    let markedSquares: [Square]
    let place: (Square) -> Bool
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 9)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(cells) { cell in
                Button { _ = place(cell.square) } label: {
                    Text(cell.digit.map { String($0.rawValue) } ?? " ")
                        .font(.system(size: 20, weight: cell.isGiven ? .regular : .bold, design: .serif))
                        .foregroundStyle(cell.isGiven ? Paper.inkSoft : Paper.ink)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .aspectRatio(1, contentMode: .fit)
                        .background(highlightsTarget && cell.square == target ? Paper.cellSelected :
                                        (markedSquares.contains(cell.square) ? Color.yellow.opacity(0.24) : (cell.isGiven ? Paper.cellGiven : Paper.page)))
                        .overlay {
                            if highlightsTarget && cell.square == target {
                                Rectangle().strokeBorder(Paper.sageDeep, lineWidth: 3)
                            }
                        }
                }
                .buttonStyle(.plain)
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
    let isInteractive: Bool
    let select: (Int) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your Hand").font(.headline)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 4)], spacing: 7) {
                ForEach(cards) { card in
                    Button { _ = select(card.id) } label: {
                        Text("\(card.digit.rawValue)")
                            .font(.system(.title2, design: .serif).weight(.semibold))
                            .foregroundStyle(Paper.ink)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(card.id == targetID ? Paper.cellSelected : Paper.pageWarm,
                                        in: .rect(cornerRadius: 3))
                            .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(card.id == targetID ? Paper.sageDeep : Paper.rule, lineWidth: card.id == targetID ? 2 : 0.7) }
                    }
                    .buttonStyle(.plain)
                    .disabled(!isInteractive)
                    .accessibilityLabel("Number \(card.digit.rawValue)\(card.id == targetID ? ", outlined practice number" : "")")
                    .accessibilityIdentifier("tutorial-hand-\(card.id)")
                    .accessibilityAddTraits(card.id == selectedID ? .isSelected : [])
                }
            }
        }
    }
}
