import SwiftUI
import ProbablySudokuEngine

struct ContentView: View {
    @State private var model: GameModel? = ContentView.debugModel()
    /// The obstacle level chosen with the Book.
    @State private var chosenObstacle: Obstacle = .none
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
        // specifically for exercising a live grid, so it must make that
        // choice before applying its selection fixtures.
        model.beginPuzzle()
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
                    StudioIntroView {
                        withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .mainMenu }
                    }
                    .transition(.opacity)

                case .mainMenu:
                    MainMenuView(
                        onPlay: {
                            showBookShelfOrAskAboutConflict()
                        },
                        onShop: {
                            withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .cosmeticShop }
                        }
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))

                case .bookShelf:
                    StartBookView(
                        onStart: { book, obstacle in
                            chosenObstacle = obstacle
                            RunStore.clearRun()
                            opening = book
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
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))

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
        .confirmationDialog("Two unfinished Books", isPresented: $showingRunConflict) {
            if let conflict = pendingRunConflict {
                Button("Use this device’s \(conflict.label(for: .local))") {
                    resume(.local, from: conflict)
                }
                Button("Use the other device’s \(conflict.label(for: .remote))") {
                    resume(.remote, from: conflict)
                }
            }
            Button("Decide later", role: .cancel) {}
        } message: {
            if let conflict = pendingRunConflict {
                Text("This device has \(conflict.label(for: .local)). The other device has \(conflict.label(for: .remote)). Both are kept until you choose one.")
            }
        }
        .onChange(of: showingRunConflict) { wasShowing, isShowing in
            // The club-room Play animation has already finished by this point.
            // If the player defers, land them on the shelf rather than leaving
            // an invisible, disabled main-menu button behind the dialog.
            guard wasShowing, !isShowing, pendingRunConflict != nil else { return }
            withAnimation(.easeInOut(duration: 0.35)) { frontDoor = .bookShelf }
        }
        .onChange(of: isShowingBook, initial: true) { _, isShowingBook in
            gameCenter.setAccessPointVisible(!isShowingBook)
        }
    }

    /// Game Center belongs to the club room and shelf, never on an open Book.
    private var isShowingBook: Bool {
        guard let model else { return false }
        return !model.wantsMenu
    }

    /// Deals the first Puzzle behind the veil, then lifts it.
    private func begin(_ book: BookEdition) {
        veil = 1
        model = GameModel(book: book.rule, startingBoard: book.bonus, obstacle: chosenObstacle)
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

    private func showBookShelfOrAskAboutConflict() {
        if let conflict = RunStore.conflict() {
            pendingRunConflict = conflict
            showingRunConflict = true
        } else {
            withAnimation(.easeInOut(duration: 0.35)) { frontDoor = .bookShelf }
        }
    }

    private func resume(_ choice: RunStore.Conflict.Choice, from conflict: RunStore.Conflict) {
        _ = RunStore.choose(choice, from: conflict)
        pendingRunConflict = nil
        showingRunConflict = false
        withAnimation(.easeInOut(duration: 0.35)) { frontDoor = .bookShelf }
    }
}

private struct GameView: View {
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
                .zIndex(0)

                BookView(
                    flipper: flipper,
                    outgoing: flipper.outgoing.map { AnyView(page(of: $0)) }
                ) {
                    page(of: model)
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                // Pulls the book up over the bookmarks' tails, so they read as
                // slipped into the pages rather than resting on them.
                .padding(.top, -BookmarkRow.tuck)
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
                    .environment(\.levelPalette, .forDisplay(slot: puzzle.slot))
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
