import SwiftUI
import ProbablySudokuEngine

struct ContentView: View {
    @State private var model: GameModel? = ContentView.debugModel()
    /// The obstacle level chosen with the Book.
    @State private var chosenObstacle: Obstacle = .none
    /// A saved run that should resume after the selected cover opens. A new
    /// Book leaves this nil and is dealt with `chosenObstacle` instead.
    @State private var openingSavedRun: Game?
    /// The Book being opened, while its clip plays. `-playOpening` starts on
    /// it, so the transition can be recorded without tapping through the shelf.
    @State private var opening: BookEdition? = ContentView.debugOpening()
    /// Held over the swap from the opening clip to the first Puzzle, so the
    /// two never show a hard cut between them.
    @State private var veil: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(GameCenterService.self) private var gameCenter
    @State private var frontDoor: FrontDoorRoute = FrontDoorRoute.launchRoute()
    @State private var pendingRunConflict: RunStore.Conflict?
    @State private var showingRunConflict = false
    /// A different Book was selected while an unfinished run is still safe.
    /// Nothing is cleared until the player explicitly starts the replacement.
    @State private var pendingBookReplacement: BookReplacement?
    @State private var closingBook: BookEdition?
    @State private var completionSummary: GameModel.BookCompletionSummary?

    /// `-skipStartScreen` drops straight into a Puzzle, so iterating on the
    /// board does not mean tapping through the cover every launch. Add
    /// `-seed <value>` to land on the same Book every time.
    private static func debugModel() -> GameModel? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-skipStartScreen") else { return nil }
        var seed = GameModel.randomSeed()
        if let index = arguments.firstIndex(of: "-seed"), index + 1 < arguments.count {
            seed = arguments[index + 1]
        }
        let model = GameModel(seed: seed, startingBoard: .scholar)
        // The normal route deliberately pauses at the briefing page so a
        // player can choose whether to spend a Clipping. This debug route is
        // normally for a live grid, while `-briefing` preserves that choice
        // for visual and interaction QA of the between-stage page itself.
        if !arguments.contains("-briefing") {
            model.beginPuzzle()
        }
        // Screenshot route for the boss briefing: take the two real clipping
        // skips so the view receives the exact state a player reaches.
        if arguments.contains("-briefingBoss") {
            model.skipCurrentPuzzle()
            model.skipCurrentPuzzle()
        }
        if let index = arguments.firstIndex(of: "-selectHand"), index + 1 < arguments.count,
           let handIndex = Int(arguments[index + 1]) {
            model.selectedHandIndex = handIndex
        }
        // Reproduces "pick a number, then tap a filled square" — the order the
        // highlight has to respect.
        if let index = arguments.firstIndex(of: "-thenTapSquare"), index + 1 < arguments.count,
           let square = Int(arguments[index + 1]), (0..<81).contains(square) {
            model.tapSquare(Square(square))
        }
        return model
        #else
        return nil
        #endif
    }

    private static func debugOpening() -> BookEdition? {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-playOpening") ? .first : nil
        #else
        return nil
        #endif
    }

    var body: some View {
        ZStack {
            Group {
                if let closingBook {
                    LiveBookClosing(edition: closingBook, reduceMotion: reduceMotion,
                                    onFinish: finishBookClosing)
                } else if let model, !model.wantsMenu {
                    GameView(model: model, reduceMotion: reduceMotion,
                             onBookCompletion: beginBookClosing)
                } else if let book = opening {
                    LiveBookOpening(edition: book, reduceMotion: reduceMotion) {
                        begin(book)
                    }
                } else {
                    switch frontDoor {
                case .studioIntro:
                    StudioSplashView(reduceMotion: reduceMotion) {
                        withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .mainMenu }
                    }
                    .transition(.opacity)

                case .mainMenu:
                    MainMenuView(
                        onBookSelected: { book, obstacle in
                            openBookOrAskAboutConflict(book, obstacle: obstacle)
                        }
                    )
                    .transition(.opacity)

                case .bookShelf:
                    StartBookView(
                        onStart: { book, obstacle in
                            openBookOrAskAboutConflict(book, obstacle: obstacle)
                        },
                        onContinue: {
                            if let saved = RunStore.resumeRun() {
                                model = GameModel(resuming: saved)
                            }
                        },
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .mainMenu }
                        },
                        initialIndex: completionSummary?.nextBook.map { edition in
                            BookEdition.shelf.firstIndex(of: edition) ?? 0
                        }
                    )
                    .transition(.opacity)

                case .cosmeticShop:
                    ClubShopView {
                        withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .mainMenu }
                    }
                    .transition(.opacity)
                    }
                }

                // Paper, held opaque across the swap and then lifted off the board.
                Paper.page
                    .opacity(veil)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                if let completionSummary {
                    BookCompletionView(summary: completionSummary) {
                        withAnimation(.easeInOut(duration: 0.22)) { self.completionSummary = nil }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .allowsHitTesting(!isShowingRunDecision)
            .accessibilityHidden(isShowingRunDecision)

            if showingRunConflict, let conflict = pendingRunConflict {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissRunConflict() }

                RunConflictSlip(
                    localLabel: conflict.label(for: .local),
                    remoteLabel: conflict.label(for: .remote),
                    onChooseLocal: { resume(.local, from: conflict) },
                    onChooseRemote: { resume(.remote, from: conflict) },
                    onCancel: dismissRunConflict
                )
                .transition(.opacity.combined(with: .scale(scale: 0.965)))
                .zIndex(40)
            }

            if let replacement = pendingBookReplacement {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissBookReplacement() }

                BookReplacementSlip(
                    savedRunLabel: replacement.savedRunLabel,
                    newBookLabel: replacement.book.shelfLabel,
                    onContinueSaved: continueSavedRun,
                    onStartNew: { startReplacement(from: replacement) },
                    onCancel: dismissBookReplacement
                )
                .transition(.opacity.combined(with: .scale(scale: 0.965)))
                .zIndex(40)
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.08 : 0.22), value: isShowingRunDecision)
        .onChange(of: isShowingBook, initial: true) { _, isShowingBook in
            gameCenter.setAccessPointVisible(!isShowingBook)
        }
    }

    /// Game Center belongs to the club room and shelf, never on an open Book.
    private var isShowingBook: Bool {
        guard let model else { return false }
        return !model.wantsMenu
    }

    private var isShowingRunDecision: Bool {
        showingRunConflict || pendingBookReplacement != nil
    }

    /// Deals the first Puzzle behind the veil, then lifts it.
    private func begin(_ book: BookEdition) {
        veil = 1
        if let saved = openingSavedRun {
            model = GameModel(resuming: saved)
            openingSavedRun = nil
        } else {
            model = GameModel(book: book.rule, startingBoard: book.bonus, obstacle: chosenObstacle)
        }
        opening = nil
        Task {
            // One frame flat first: animating a value in the same update that
            // sets it leaves the animation nothing to travel from.
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.easeOut(duration: 0.65)) { veil = 0 }
        }
    }

    private func beginBookClosing(_ model: GameModel) {
        guard let summary = model.bookCompletionSummary else { return }
        completionSummary = summary
        closingBook = summary.edition
    }

    private func finishBookClosing() {
        closingBook = nil
        model?.abandonRun()
        withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .bookShelf }
    }

    private func openBookOrAskAboutConflict(_ book: BookEdition, obstacle: Obstacle) {
        if let conflict = RunStore.conflict() {
            pendingRunConflict = conflict
            showingRunConflict = true
            return
        }

        if let displayed = RunStore.displayedRun() {
            if displayed.run.book == book.rule, let saved = RunStore.resumeRun() {
                openingSavedRun = saved
                opening = book
            } else {
                pendingBookReplacement = BookReplacement(
                    book: book,
                    obstacle: obstacle,
                    savedRun: displayed
                )
            }
            return
        }

        chosenObstacle = obstacle
        openingSavedRun = nil
        opening = book
    }

    private func continueSavedRun() {
        pendingBookReplacement = nil
        guard let saved = RunStore.resumeRun() else { return }
        openingSavedRun = saved
        opening = BookEdition.edition(for: saved.run.book)
    }

    private func startReplacement(from replacement: BookReplacement) {
        pendingBookReplacement = nil
        // This is the only replacement path that clears the unfinished run,
        // and it is reached solely from the explicit "Start new Book" action.
        RunStore.clearRun()
        chosenObstacle = replacement.obstacle
        openingSavedRun = nil
        opening = replacement.book
    }

    private func dismissBookReplacement() {
        pendingBookReplacement = nil
    }

    private struct BookReplacement {
        let book: BookEdition
        let obstacle: Obstacle
        let savedRun: Game

        var savedRunLabel: String {
            "Book \(savedRun.run.book.volume), Level \(savedRun.run.level), Puzzle \(savedRun.run.slot.rawValue + 1)"
        }
    }

    private func resume(_ choice: RunStore.Conflict.Choice, from conflict: RunStore.Conflict) {
        let chosen = RunStore.choose(choice, from: conflict)
        pendingRunConflict = nil
        showingRunConflict = false
        openingSavedRun = chosen
        opening = BookEdition.edition(for: chosen.run.book)
    }

    private func dismissRunConflict() {
        showingRunConflict = false
        pendingRunConflict = nil
    }
}

/// The destructive counterpart to `RunConflictSlip`: the saved Book remains
/// untouched unless the red replacement action is pressed explicitly.
private struct BookReplacementSlip: View {
    var savedRunLabel: String
    var newBookLabel: String
    var onContinueSaved: () -> Void
    var onStartNew: () -> Void
    var onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("UNFINISHED BOOK")
                            .font(Print.caption(10))
                            .tracking(1.8)
                            .foregroundStyle(Paper.redPencil)

                        Text("Start a different Book?")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)

                        Text("Your current run stays safe unless you replace it.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Paper.inkSoft)
                    }

                    Spacer(minLength: 8)

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Paper.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Paper.pageEdge.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Keep current Book")
                }
                .padding(.horizontal, 20)
                .padding(.top, 19)
                .padding(.bottom, 15)

                Rectangle()
                    .fill(Paper.redPencil.opacity(0.48))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                VStack(spacing: 11) {
                    decisionButton(
                        eyebrow: "CONTINUE CURRENT",
                        label: savedRunLabel,
                        symbol: "bookmark",
                        tint: Paper.sage,
                        action: onContinueSaved
                    )

                    decisionButton(
                        eyebrow: "REPLACE CURRENT RUN",
                        label: "Start \(newBookLabel)",
                        symbol: "book.closed",
                        tint: Paper.redPencil,
                        action: onStartNew
                    )

                    Button("KEEP CURRENT BOOK", action: onCancel)
                        .font(Print.caption(10))
                        .tracking(1.5)
                        .foregroundStyle(Paper.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .buttonStyle(.plain)
                }
                .padding(16)
            }
            .frame(width: min(proxy.size.width - 30, 390))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Paper.page)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Paper.pageEdge, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Paper.redPencil)
                    .frame(width: 3)
                    .padding(.vertical, 18)
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
    }

    private func decisionButton(
        eyebrow: String,
        label: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(tint.opacity(0.65), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(Print.caption(9))
                        .tracking(1.4)
                        .foregroundStyle(tint)
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Paper.inkSoft)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Paper.pageEdge, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(eyebrow), \(label)")
    }
}

private struct GameView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Bindable var model: GameModel
    var reduceMotion: Bool
    var onBookCompletion: (GameModel) -> Void
    @State private var flipper = PageFlipper()
    @State private var showingSettings = false
    @State private var showingRunInfo = false
    /// The Buff being spent, while its slip is open.
    @State private var usingBuff: Int?

    var body: some View {
        DeskView {
            VStack(spacing: 0) {
                BookmarkRow(model: model) { index in
                    withAnimation(.snappy(duration: 0.2)) { usingBuff = index }
                }
                .padding(.horizontal, 26)
                .padding(.top, 4)
                // Bookmarks sit behind the page block: their lower tails are
                // swallowed by the book rather than floating over the paper.
                .zIndex(0)

                BookView(
                    flipper: flipper,
                    outgoing: flipper.outgoing.map { AnyView(page(of: $0)) }
                ) {
                    page(of: model)
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                // The tabs must remain above the book rather than covering
                // the puzzle heading. Their lower tails still tuck into the
                // page block, but the readable part keeps its own band.
                .padding(.top, -(BookmarkRow.tuck - 4))
                .zIndex(1)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { toast }
            .onChange(of: model.puzzle?.phase) { _, phase in
                // Reaching the target or running out of Turns finishes the
                // page, so the book turns to the result the same way it turns
                // to anything else.
                guard model.page == .puzzle,
                      phase == .won || phase == .failed else { return }
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) {
                        model.showResults()
                    }
                }
            }
            .overlay(alignment: .top) {
                IslandBar(coins: model.coins, controls: controls)
                    .ignoresSafeArea(edges: .top)
            }
            // A paper slip covers the whole desk. Keep its obscured controls
            // out of VoiceOver navigation until the slip is closed.
            .accessibilityHidden(isPresentingSlip)
            .overlay {
                // In-world, on the desk — not a system sheet sliding up over it.
                if showingSettings {
                    SettingsSlip(model: model) {
                        withAnimation(.snappy(duration: 0.2)) { showingSettings = false }
                    }
                }
                if showingRunInfo {
                    RunInfoSlip(model: model) {
                        withAnimation(.snappy(duration: 0.2)) { showingRunInfo = false }
                    }
                }
                if let index = usingBuff {
                    BuffSlip(model: model, index: index) {
                        withAnimation(.snappy(duration: 0.2)) { usingBuff = nil }
                    }
                }
            }
            .animation(.snappy(duration: 0.22), value: showingSettings)
            .animation(.snappy(duration: 0.22), value: showingRunInfo)
            .animation(.snappy(duration: 0.22), value: usingBuff)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-qa") { showingSettings = true }
                if ProcessInfo.processInfo.arguments.contains("-runInfo") { showingRunInfo = true }
                if ProcessInfo.processInfo.arguments.contains("-achievements") {
                    model.openAchievements()
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-loadout") {
                    model.qaFillLoadout()
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-buffSlip") {
                    model.qaGrantBuff(Buffs.paperCrane)
                    try? await Task.sleep(for: .milliseconds(300))
                    usingBuff = 0
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-clearLine") {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.beginPuzzle()
                    model.qaCompleteARow()
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-winNow") {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.beginPuzzle()
                    model.qaMeetTarget()
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-completeBookNow") {
                    try? await Task.sleep(for: .milliseconds(400))
                    await flipper.flip(from: model, reduceMotion: reduceMotion) {
                        model.qaCompleteBook()
                    }
                    return
                }
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-qaBoss"), index + 1 < arguments.count,
                   let boss = BossModifier(rawValue: arguments[index + 1]) {
                    // This debug route is used by launch-time screenshot QA.  It must
                    // configure the board in the first rendered state instead of
                    // leaving a timing window that exposes the briefing page.
                    model.beginPuzzle()
                    model.qaSetBoss(boss)
                    return
                }
                if let index = arguments.firstIndex(of: "-failBookAtLevel"), index + 1 < arguments.count,
                   let level = Int(arguments[index + 1]) {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.beginPuzzle()
                    model.qaFailBook(atLevel: level)
                    return
                }
                if let index = arguments.firstIndex(of: "-curlHold"), index + 1 < arguments.count,
                   let value = Double(arguments[index + 1]) {
                    try? await Task.sleep(for: .milliseconds(400))
                    // A new Game opens on its briefing page. Use the existing
                    // deterministic completion shortcut so this QA route
                    // always freezes a real outgoing/incoming page pair,
                    // rather than a curl over an unchanged briefing.
                    flipper.hold(from: model, at: value) { model.qaCompleteBook() }
                    return
                }
                guard ProcessInfo.processInfo.arguments.contains("-autoEndTurn") else { return }
                try? await Task.sleep(for: .seconds(1))
                model.beginPuzzle()
                await flipper.flip(from: model, reduceMotion: false) { model.endTurn() }
                #endif
            }
        }
        .environment(flipper)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var isPresentingSlip: Bool {
        showingSettings || showingRunInfo || usingBuff != nil
    }

    // MARK: Pages

    @ViewBuilder
    private func page(of source: GameModel) -> some View {
        switch source.page {
        case .briefing:
            PuzzleBriefingView(model: source)
        case .puzzle:
            if let puzzle = source.puzzle {
                PuzzlePageView(model: source, puzzle: puzzle)
                    .environment(\.levelPalette,
                                 .forDisplay(slot: puzzle.slot).resolved(for: profile.theme.paper))
            }
        case .results:
            ResultsPageView(model: source) { onBookCompletion(model) }
        case .shop:
            if let shop = source.shop {
                ShopPageView(model: source, shop: shop)
            }
        case .achievements:
            AchievementsPageView { source.closeAchievements() }
        }
    }

    // MARK: Chrome

    /// Only the two things that are true on every page. Clue moved onto the
    /// Puzzle page and Reroll onto the Shop page, because both act on a page.
    private var controls: [StripControl] {
        [
            StripControl(systemImage: "rosette", label: "Achievements") {
                Task {
                    await flipper.flip(from: model, reduceMotion: reduceMotion) {
                        model.openAchievements()
                    }
                }
            },
            StripControl(systemImage: "questionmark", label: "Run information") {
                withAnimation(.snappy(duration: 0.22)) { showingRunInfo = true }
            },
            StripControl(systemImage: "gearshape", label: "Settings") {
                withAnimation(.snappy(duration: 0.22)) { showingSettings = true }
            },
        ]
    }


    @ViewBuilder
    private var toast: some View {
        if let message = model.message {
            Text(message)
                .font(Print.caption(13))
                .foregroundStyle(Paper.page)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Capsule().fill(Paper.ink.opacity(0.92)))
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(2.2))
                    model.clearMessage()
                }
        }
    }
}

#Preview("Puzzle") {
    GameView(model: GameModel(seed: "preview", startingBoard: .oracle), reduceMotion: false,
             onBookCompletion: { _ in })
        .environment(PageFlipper())
}

#Preview("Start") {
    StartBookView(onStart: { _, _ in }, onContinue: {})
}
