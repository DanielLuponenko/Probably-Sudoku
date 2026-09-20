import SwiftUI
import ProbablySudokuEngine

struct ContentView: View {
    @State private var model: GameModel?
    // @State retains its value, but its initial-value expression still runs
    // whenever SwiftUI constructs this view. Dealing a debug Puzzle there
    // writes profile state and can cause another construction/deal cycle.
    @State private var didInitializeDebugLaunch = false
    /// The obstacle level chosen with the Book.
    @State private var chosenObstacle: Obstacle = .none
    /// A saved run that should resume after the selected cover opens. A new
    /// Book leaves this nil and is dealt with `chosenObstacle` instead.
    @State private var openingSavedRun: Game?
    /// A newly accepted Book is already durable while its cover opens.
    @State private var openingModel: GameModel?
    /// The Book being opened, while its clip plays. `-playOpening` starts on
    /// it, so the transition can be recorded without tapping through the shelf.
    @State private var opening: BookEdition? = ContentView.debugOpening()
    @State private var openingToken = UUID()
    /// Held over the swap from the opening clip to the first Puzzle, so the
    /// two never show a hard cut between them.
    @State private var veil: Double = 0
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(PlayerProfileStore.self) private var profileStore
    @State private var onboardingStore = OnboardingStore()
    @State private var onboardingStage: OnboardingStage?
    @State private var frontDoor: FrontDoorRoute = FrontDoorRoute.launchRoute()
    /// A different Book was selected while an unfinished run is still safe.
    /// Nothing is cleared until the player explicitly starts the replacement.
    @State private var pendingBookReplacement: BookReplacement?
    @State private var closingBook: BookEdition?
    @State private var closingPageSnapshot: UIImage?
    @State private var closingToken = UUID()
    @State private var completionSummary: GameModel.BookCompletionSummary?
    @State private var completedBookSelection: CompletedBookSelection?
    @State private var storageError: String?
    @State private var menuReturn = MenuReturnTransition()
    @State private var introSceneReady = false

    private enum OnboardingStage { case welcome, practice }

    /// `-skipStartScreen` drops straight into a Puzzle, so iterating on the
    /// board does not mean tapping through the cover every launch. Add
    /// `-seed <value>` to land on the same Book every time.
    private static func debugModel() -> GameModel? {
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-skipStartScreen") else { return nil }
        var seed = GameModel.randomSeed()
        if let index = arguments.firstIndex(of: "-seed"), index + 1 < arguments.count {
            seed = arguments[index + 1]
        }
        // A visual/debug launch must not replace the player's normal Book.
        // Persistence QA opts in explicitly and uses its own simulator.
        let model = GameModel(resuming: Game(seed: seed),
                              savesProgress: arguments.contains("-persistQA"))
        // The rescue fixture deals/exhausts in GameView's one-shot task so
        // its presentation follows the mounted game's normal lifecycle.
        if arguments.contains("-rewardedRescue") { return model }
        // Direct visual QA for the in-run catalogue page. This is Debug-only
        // and still opens a real ShopState through the normal game action.
        if arguments.contains("-shop") {
            model.beginPuzzle()
            model.qaMeetTarget()
            model.cashOut()
            model.openShop()
            return model
        }
        // The normal route deliberately pauses at the briefing page so a
        // player can choose whether to skip for a Buff. This debug route is
        // normally for a live grid, while `-briefing` preserves that choice
        // for visual and interaction QA of the between-stage page itself.
        if !arguments.contains("-briefing") {
            model.beginPuzzle()
        }
        // Screenshot route for the boss briefing: take the two real Buff
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
        #if DEBUG && targetEnvironment(simulator)
        return ProcessInfo.processInfo.arguments.contains("-playOpening") ? .first : nil
        #else
        return nil
        #endif
    }

    var body: some View {
        ZStack {
            Group {
                if let closingBook {
                    LiveBookClosing(edition: closingBook, obstacle: model?.run.obstacle ?? chosenObstacle,
                                    reduceMotion: reduceMotion,
                                    outgoingPage: closingPageSnapshot) { [token = closingToken, owner = model] in
                        finishBookClosing(token: token, owner: owner)
                    }
                } else if let model, !model.wantsMenu {
                    GameView(model: model, reduceMotion: reduceMotion,
                             onBookCompletion: beginBookClosing, onAbandon: abandonGame)
                } else if let book = opening {
                    LiveBookOpening(edition: book,
                                    obstacle: openingSavedRun?.run.obstacle ?? chosenObstacle,
                                    reduceMotion: reduceMotion) { [token = openingToken] in
                        begin(book, token: token)
                    }
                } else {
                    switch frontDoor {
                case .studioIntro, .mainMenu:
                    ZStack {
                        // Prepare the book scene beneath the logo, preserving its identity
                        // across the handoff instead of constructing it on the white frame.
                        MainMenuView(
                            onBookSelected: { book, obstacle in
                                openBookOrAskToReplace(book, obstacle: obstacle)
                            },
                            onContinueBook: continueSavedRun,
                            onFirstFrame: { [token = menuReturn.token] in
                                introSceneReady = true
                                if let token { revealMenu(token: token) }
                            },
                            isSceneVisible: frontDoor == .mainMenu && onboardingStage == nil,
                            completedBookSelection: completedBookSelection
                        )
                        .allowsHitTesting(frontDoor == .mainMenu && onboardingStage == nil)
                        .accessibilityHidden(frontDoor == .studioIntro || onboardingStage != nil)

                        if frontDoor == .studioIntro {
                            StudioSplashView(reduceMotion: reduceMotion, isReadyToAnimate: introSceneReady) {
                                withAnimation(.easeOut(duration: 0.12)) { frontDoor = .mainMenu }
                            }
                            .transition(.opacity)
                            .zIndex(1)
                        }
                    }
                    .transition(.opacity)

                case .bookShelf:
                    StartBookView(
                        onStart: { book, obstacle in
                            openBookOrAskToReplace(book, obstacle: obstacle)
                        },
                        onContinue: continueSavedRun,
                        onBack: {
                            withAnimation(.easeInOut(duration: 0.28)) { frontDoor = .mainMenu }
                        },
                        initialIndex: completionSummary.map { summary in
                            // The next Obstacle belongs to this Book, so put
                            // the reader back at the volume they just finished.
                            BookEdition.shelf.firstIndex(of: summary.edition) ?? 0
                        }
                    )
                    .transition(.opacity)

                    }
                }

                // Paper, held opaque across the swap and then lifted off the board.
                Paper.page
                    .opacity(veil)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

            }
            .allowsHitTesting(!isShowingRunDecision && !menuReturn.isActive && onboardingStage == nil)
            .accessibilityHidden(isShowingRunDecision || menuReturn.isActive
                                || (onboardingStage != nil && frontDoor != .studioIntro))

            if let onboardingStage, frontDoor != .studioIntro {
                switch onboardingStage {
                case .welcome:
                    FirstTimeWelcomeView(
                        onExperienced: { finishOnboarding(.experienced) },
                        onLearn: {
                            withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.2)) {
                                self.onboardingStage = .practice
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(80)
                case .practice:
                    TutorialView(onFinish: finishOnboarding)
                        .transition(.opacity)
                        .zIndex(80)
                }
            }

            if let replacement = pendingBookReplacement {
                Color.black.opacity(0.48)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture { dismissBookReplacement() }

                BookReplacementSlip(
                    savedRunLabel: replacement.savedRunLabel,
                    savedRunCompleted: replacement.savedRun.run.outcome == .bookCompleted,
                    newBookLabel: "\(replacement.book.shelfLabel) · \(replacement.obstacle.name)",
                    onContinueSaved: continueSavedRun,
                    onStartNew: { startReplacement(from: replacement) },
                    onCancel: dismissBookReplacement
                )
                .environment(\.bookPresentation, BookPresentationTheme(book: replacement.savedRun.run.book))
                .transition(.opacity)
                .zIndex(40)
            }

            if let snapshot = menuReturn.snapshot {
                GeometryReader { proxy in
                    Image(uiImage: snapshot)
                        .resizable()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .ignoresSafeArea()
                .opacity(menuReturn.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .zIndex(100)
            }
        }
        .inventoryDragHost()
        .paperPanel(isPresented: Binding(get: { storageError != nil }, set: {
            if !$0 { storageError = nil }
        })) {
            PaperSlip(title: "Book not changed", subtitle: storageError,
                      onClose: { storageError = nil }) {
                EmptyView()
            }
        }
        .paperPanelHost()
        .task {
            guard !Task.isCancelled, !didInitializeDebugLaunch else { return }
            // Set the latch before the factory's profile/persistence writes.
            // A reappearance must not replace an existing or abandoned run.
            didInitializeDebugLaunch = true
            model = Self.debugModel()
            if OnboardingEligibility.shouldOffer(
                hasResolved: onboardingStore.isResolved, hasSavedRun: RunStore.hasRun,
                profile: profileStore.profile,
                isPreviewLaunch: model != nil || opening != nil || frontDoor != .studioIntro
            ) {
                onboardingStage = .welcome
            }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.08 : 0.22), value: isShowingRunDecision)
        .background { GameMusicObserver(model: model, isClosingBook: closingBook != nil) }
        .onDisappear { menuReturn.cancel() }
    }

    private func finishOnboarding(_ resolution: OnboardingStore.Resolution) {
        onboardingStore.resolve(as: resolution)
        withAnimation(.easeOut(duration: reduceMotion ? 0 : 0.2)) {
            onboardingStage = nil
            frontDoor = .mainMenu
        }
    }

    private var isShowingRunDecision: Bool {
        pendingBookReplacement != nil
    }

    private func abandonGame(_ model: GameModel) {
        guard self.model === model, !model.wantsMenu else { return }
        // Capture before removing the slip/game. The abandoned model can exit
        // immediately; its frozen pixels cover the scene's cold first render.
        let snapshot = MenuReturnTransition.captureCurrentScreen()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            guard model.abandonRun() else {
                storageError = "This Book could not be removed. It is still open and can be continued. Try again."
                return
            }
            menuReturn.begin(snapshot: snapshot)
            completedBookSelection = nil
            // The return transition owns pixels, not the departed run.
            self.model = nil
            frontDoor = .mainMenu
        }
    }

    private func revealMenu(token: UUID) {
        guard menuReturn.token == token, menuReturn.opacity == 1 else { return }
        withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.22),
                      completionCriteria: .removed) {
            _ = menuReturn.destinationDidRender(token: token)
        } completion: {
            menuReturn.finish(token: token)
        }
    }

    /// Opens a saved route or a durably saved first briefing behind the veil.
    private func begin(_ book: BookEdition, token: UUID) {
        // A renderer may finish after another route has already taken over.
        guard openingToken == token, opening == book,
              model == nil || model?.wantsMenu == true else { return }
        veil = 1
        if let prepared = openingModel {
            model = prepared
            openingModel = nil
        } else if let saved = openingSavedRun {
            model = GameModel(resuming: saved)
            openingSavedRun = nil
        } else {
            guard let started = GameModel.startingBook(book: book.rule, obstacle: chosenObstacle) else {
                opening = nil
                veil = 0
                storageError = "The new Book could not be saved. Free some space, then try again."
                return
            }
            model = started
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
        guard self.model === model, !model.wantsMenu,
              closingBook == nil, let summary = model.bookCompletionSummary else { return }
        completionSummary = summary
        closingPageSnapshot = MenuReturnTransition.captureCurrentScreen()
        closingToken = UUID()
        closingBook = summary.edition
    }

    private func finishBookClosing(token: UUID, owner: GameModel?) {
        guard closingToken == token, let owner, model === owner, closingBook != nil else { return }
        let snapshot = MenuReturnTransition.captureCurrentScreen()
        guard owner.abandonRun() else {
            closingBook = nil
            closingPageSnapshot = nil
            storageError = "The final page could not be closed safely. Your completion has been kept. Try again."
            return
        }
        // Change the route and remove the closed cover together. An animated
        // intermediate render can otherwise expose the old studio-intro route.
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            menuReturn.begin(snapshot: snapshot)
            completedBookSelection = CompletedBookSelection(
                book: owner.run.book, completedObstacle: owner.run.obstacle,
                progressByBookID: profileStore.profile.achievementProgress.unlockedObstaclesByBookID)
            model = nil
            frontDoor = .mainMenu
            closingBook = nil
            closingPageSnapshot = nil
        }
    }

    private func openBookOrAskToReplace(_ book: BookEdition, obstacle: Obstacle) {
        guard opening == nil, model == nil || model?.wantsMenu == true,
              !isShowingRunDecision else { return }

        if let displayed = RunStore.displayedRun() {
            // Even the same cover needs an explicit resume decision. Otherwise
            // "Open" silently jumps past the ordinary puzzle's skip briefing.
            pendingBookReplacement = BookReplacement(
                book: book, obstacle: obstacle, savedRun: displayed
            )
            return
        }

        chosenObstacle = obstacle
        guard let prepared = GameModel.startingBook(book: book.rule, obstacle: obstacle) else {
            // A cloud-only current Book may arrive between drawing the shelf
            // and the guarded durable start. Ask before replacing that Book.
            if let saved = RunStore.displayedRun() {
                pendingBookReplacement = BookReplacement(book: book, obstacle: obstacle, savedRun: saved)
                return
            }
            storageError = "The new Book could not be saved. Free some space, then try again."
            return
        }
        openingModel = prepared
        openingSavedRun = nil
        openingToken = UUID()
        opening = book
    }

    private func continueSavedRun() {
        guard opening == nil, model == nil || model?.wantsMenu == true else { return }
        // Re-read the single authoritative run at acceptance. Home and the
        // replacement decision both resume its exact saved page and inventory.
        guard let saved = RunStore.resumeRun() else {
            storageError = "This Book could not be opened safely. Your saved copies have been kept. Try again."
            return
        }
        pendingBookReplacement = nil
        openingModel = nil
        openingSavedRun = saved
        openingToken = UUID()
        opening = BookEdition.edition(for: saved.run.book)
    }

    private func startReplacement(from replacement: BookReplacement) {
        guard pendingBookReplacement?.id == replacement.id, opening == nil else { return }
        // A remote-only save can change without creating a two-copy conflict.
        // Never delete a different Book than the one named on this decision.
        guard let current = RunStore.displayedRun() else {
            pendingBookReplacement = nil
            storageError = "The saved Book changed while this page was open. Choose a Book again."
            return
        }
        guard RunStore.conflict(local: replacement.savedRun, remote: current) == nil else {
            pendingBookReplacement = BookReplacement(book: replacement.book,
                obstacle: replacement.obstacle, savedRun: current)
            return
        }
        if replacement.savedRun.run.outcome == .bookCompleted {
            // A legacy receipt may not yet have recorded its per-Book win.
            // Settle that idempotent resume before acknowledging the receipt.
            _ = GameModel(resuming: replacement.savedRun)
            guard RunStore.recordBookCompleted(replacement.savedRun.run.book,
                                               obstacle: replacement.savedRun.run.obstacle) else {
                storageError = "The completed Book's unlock could not be saved. Its final page has been kept. Try again."
                return
            }
        }
        // Replace the saved bytes in one write before the opening animation.
        // A failed new save must leave the previous Book resumable.
        guard let prepared = GameModel.startingBook(book: replacement.book.rule,
                                                    obstacle: replacement.obstacle,
                                                    saveInitial: {
            RunStore.replace(expected: replacement.savedRun, with: $0)
        }) else {
            storageError = "The new Book could not be saved. The previous Book has been kept; try again."
            return
        }
        pendingBookReplacement = nil
        chosenObstacle = replacement.obstacle
        openingModel = prepared
        openingSavedRun = nil
        openingToken = UUID()
        opening = replacement.book
    }

    private func dismissBookReplacement() {
        pendingBookReplacement = nil
    }

    private struct BookReplacement {
        let id = UUID()
        let book: BookEdition
        let obstacle: Obstacle
        let savedRun: Game

        var savedRunLabel: String {
            SavedBookSummary(game: savedRun)?.decisionLabel ?? "Current Book"
        }
    }
}

/// The only choice when opening another Book: keep the current attempt or
/// explicitly abandon it. Cancelling leaves its exact saved state intact.
struct BookReplacementSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 14
    var savedRunLabel: String
    var savedRunCompleted = false
    var newBookLabel: String
    var onContinueSaved: () -> Void
    var onStartNew: () -> Void
    var onCancel: () -> Void

    var body: some View {
        PaperSlip(title: savedRunCompleted ? "Another Book?" : "A Book is already open",
                  subtitle: nil,
                  closeLabel: "Back to the shelf",
                  dismissesOnBackground: false,
                  dimsBackground: false,
                  maximumWidth: 390,
                  onClose: onCancel) {
            VStack(alignment: .leading, spacing: 12) {
                Text(savedRunLabel)
                    .font(Print.subheading(bodySize))
                    .foregroundStyle(theme.paper.ink)
                    .fixedSize(horizontal: false, vertical: true)

                PaperButton(title: savedRunCompleted ? "View final page" : "Continue current Book",
                            subtitle: savedRunCompleted ? nil : "Keep your current puzzle and items",
                            kind: .primary, action: onContinueSaved)
                    .accessibilityIdentifier("book-replacement.continue")

                Text(savedRunCompleted
                     ? "Your earned progress stays saved when you begin another Book."
                     : "You can play one Book at a time. Starting another abandons this attempt. Your achievements and unlocks stay saved.")
                    .font(Print.body(bodySize))
                    .foregroundStyle(theme.paper.softInk)
                    .fixedSize(horizontal: false, vertical: true)

                PaperButton(title: savedRunCompleted ? "Start new Book" : "Abandon & start new",
                            subtitle: newBookLabel,
                            kind: savedRunCompleted ? .quiet : .danger,
                            action: onStartNew)
                    .accessibilityIdentifier("book-replacement.replace")
                    .accessibilityHint(savedRunCompleted
                        ? "Begins the selected Book"
                        : "Permanently abandons the current attempt and opens the selected Book")
            }
        }
    }
}

private struct GameView: View {
    @Environment(PlayerProfileStore.self) private var profile
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.paperPanelPresenter) private var panelPresenter
    @Bindable var model: GameModel
    var reduceMotion: Bool
    var onBookCompletion: (GameModel) -> Void
    var onAbandon: (GameModel) -> Void
    @State private var flipper = PageFlipper()
    @State private var showingSettings = false
    @State private var showingRunInfo = false
    /// The Buff being spent, while its slip is open.
    @State private var usingBuff: Int?
    @State private var claimingMarker: Int?
    @State private var isClosingSlip = false
    @State private var isInspectingShopOffer = false

    var body: some View {
        GeometryReader { viewport in
        ZStack {
            GameplaySurfaceBackground()
            .ignoresSafeArea()

            // One host survives every route. The outgoing snapshot includes
            // the actual controls, inventory, and content in one coordinate space.
            RunPageSurface(model: model, flipper: flipper, controls: controls,
                           safeAreaInsets: viewport.safeAreaInsets, onTapBuff: { usingBuff = $0 }) {
                page(of: model)
            }
            .ignoresSafeArea()
            .overlay(alignment: .bottom) { toast }
            .onChange(of: model.puzzle?.phase) { _, _ in
                // Reaching the target or running out of Turns finishes the
                // page, so the book turns to the result the same way it turns
                // to anything else.
                reconcileFinishedPuzzle()
            }
            .onChange(of: model.isPresentingScore) { _, presenting in
                if !presenting { reconcileFinishedPuzzle() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { reconcileFinishedPuzzle() }
            }
            .onChange(of: flipper.isFlipping) { _, turning in
                if !turning { reconcileFinishedPuzzle() }
            }
            .onChange(of: isPresentingSlip) { _, covered in
                if covered { model.cancelClueTargeting() }
                if !covered { reconcileFinishedPuzzle() }
            }
            .allowsHitTesting(!isPresentingSlip && !flipper.isFlipping && !model.hasRewardedRescueInFlight)
            // A paper slip covers the whole desk. Keep its obscured controls
            // out of VoiceOver navigation until the slip is closed.
            .accessibilityHidden(isPresentingSlip || flipper.isFlipping || model.hasRewardedRescueInFlight)
            .overlay {
                // In-world, on the desk — not a system sheet sliding up over it.
                ZStack {
                    if showingSettings {
                        SettingsSlip(model: model, onAbandon: { onAbandon(model) }) {
                            closeSlip { showingSettings = false }
                        }
                    }
                    if showingRunInfo {
                        RunInfoSlip(model: model) {
                            closeSlip { showingRunInfo = false }
                        }
                    }
                    if let index = usingBuff {
                        BuffSlip(model: model, index: index) {
                            closeSlip { usingBuff = nil }
                        }
                    }
                    if let index = claimingMarker {
                        MarkerPlacementSlip(model: model, markerIndex: index) {
                            closeSlip { claimingMarker = nil }
                        }
                    }
                    if model.requestedCatalogueReading != nil, model.pendingItemDecision == nil,
                       usingBuff == nil, !showingSettings, !showingRunInfo, claimingMarker == nil {
                        CatalogueReadingsSlip(run: model.run) { model.dismissCatalogueReading() }
                    }
                    if let decision = model.pendingItemDecision, !flipper.isFlipping,
                       usingBuff == nil, !showingSettings, !showingRunInfo, claimingMarker == nil {
                        ItemDecisionSlip(model: model, decision: decision)
                            .id(decision.id)
                    }
                }
                // Only the slip animates. A Buff can change the Hand and
                // board in this update too; those retain their own motions.
                .allowsHitTesting(!isClosingSlip)
                .accessibilityHidden(isClosingSlip)
                .animation(slipAnimation, value: showingSettings)
                .animation(slipAnimation, value: showingRunInfo)
                .animation(slipAnimation, value: usingBuff)
                .animation(slipAnimation, value: claimingMarker)
            }
            .onChange(of: model.pendingItemDecision?.id) { _, id in
                if id != nil { usingBuff = nil }
            }
            .task {
                #if DEBUG && targetEnvironment(simulator)
                if ProcessInfo.processInfo.arguments.contains("-rewardedRescue") {
                    // Real exhaustion and real Google demo ads. No synthetic
                    // reward callback, and never present on physical phones.
                    guard model.puzzle == nil else { return }
                    model.beginPuzzle()
                    while model.puzzle?.phase == .playing { model.endTurn() }
                    return
                }
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
                    // Exercise the real outgoing puzzle, not a score change
                    // in the same layout pass that first creates its board.
                    try? await Task.sleep(for: .seconds(1))
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
                if let index = arguments.firstIndex(of: "-gameplayFixture"), index + 1 < arguments.count {
                    model.qaGameplayFixture(arguments[index + 1])
                    if let bossIndex = arguments.firstIndex(of: "-qaBoss"), bossIndex + 1 < arguments.count,
                       let boss = BossModifier(rawValue: arguments[bossIndex + 1]) {
                        model.qaSetBoss(boss)
                    }
                    return
                }
                if arguments.contains("-autoPlayPuzzle") {
                    // Repeatable, hands-free recording of the real briefing
                    // action, after the ticket has finished arriving.
                    try? await Task.sleep(for: .seconds(1))
                    await flipper.flip(from: model, reduceMotion: reduceMotion) {
                        model.beginPuzzle()
                    }
                    return
                }
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
                    // Let the page's initial labels finish appearing before
                    // capturing the same settled state a reader would turn.
                    try? await Task.sleep(for: .seconds(1))
                    // This is an ordinary completed-Puzzle result, not the
                    // final Book state. “Book Complete” remains exclusive to
                    // the Level 9 Boss path.
                    flipper.hold(from: model, at: value) { model.showResults() }
                    return
                }
                guard ProcessInfo.processInfo.arguments.contains("-autoEndTurn") else { return }
                try? await Task.sleep(for: .seconds(1))
                model.beginPuzzle()
                await flipper.flip(from: model, reduceMotion: false) { model.endTurn() }
                #endif
            }
        }
        }
        .environment(flipper)
        .environment(\.cosmeticTheme, runTheme)
        .environment(\.bookPresentation, BookPresentationTheme(book: model.run.book))
        .environment(\.bossMotionIsActive, !isPresentingSlip && !isInspectingShopOffer
                     && !flipper.isFlipping && !model.hasRewardedRescueInFlight)
        .environment(\.bossEntranceIsDeferred, flipper.isFlipping && !isPresentingSlip
                     && !isInspectingShopOffer && !model.hasRewardedRescueInFlight)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var runTheme: CosmeticTheme {
        var theme = profile.theme
        theme.paper = CosmeticTheme.standard.paper
        return theme
    }

    private var isPresentingSlip: Bool {
        showingSettings || showingRunInfo || usingBuff != nil || claimingMarker != nil || isClosingSlip
            || panelPresenter?.isPresenting == true || model.pendingItemDecision != nil || model.requestedCatalogueReading != nil
    }

    private var slipAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.22)
    }

    private func closeSlip(_ dismiss: () -> Void) {
        guard !isClosingSlip else { return }
        isClosingSlip = true
        withAnimation(slipAnimation, completionCriteria: .removed) {
            dismiss()
        } completion: {
            // The window snapshot must not bake a still-fading slip into the
            // next leaf. Keep input/clock paused until its pixels are gone.
            isClosingSlip = false
        }
    }

    private func reconcileFinishedPuzzle() {
        // A suspended/cancelled turn may never present its first frame. A
        // terminal puzzle still needs its result page when the app returns.
        guard scenePhase == .active, !model.isPresentingScore, !isPresentingSlip, !flipper.isFlipping, model.page == .puzzle,
              model.puzzle?.phase == .won || model.puzzle?.phase == .failed
                || model.puzzle?.phase == .outOfTurns else { return }
        Task { @MainActor in
            guard scenePhase == .active, !model.isPresentingScore, !isPresentingSlip, model.page == .puzzle,
                  model.puzzle?.phase == .won || model.puzzle?.phase == .failed
                    || model.puzzle?.phase == .outOfTurns else { return }
            await flipper.flip(from: model, reduceMotion: reduceMotion) {
                model.showResults()
            }
        }
    }

    // MARK: Pages

    @ViewBuilder
    private func page(of source: GameModel) -> some View {
        switch source.page {
        case .briefing:
            PuzzleBriefingView(model: source,
                               canStartPresentation: { scenePhase == .active && !isPresentingSlip },
                               isPresentationCovered: isPresentingSlip)
        case .puzzle:
            if let puzzle = source.puzzle {
                PuzzlePageView(model: source, puzzle: puzzle,
                               isClockRunning: scenePhase == .active && !isPresentingSlip
                                && !flipper.isFlipping && !source.hasRewardedRescueInFlight)
                    .environment(\.levelPalette,
                                 .forDisplay(slot: puzzle.slot).resolved(for: runTheme.paper))
            }
        case .results:
            ResultsPageView(model: source,
                            onBookCompletion: { onBookCompletion(source) },
                            onAbandon: { onAbandon(source) })
        case .shop:
            if let shop = source.shop {
                ShopPageView(model: source, shop: shop, onClaimMarker: { index in
                    guard source.page == .shop, source.run.markers.indices.contains(index),
                          source.run.markers[index].pendingSquares(atLevel: source.run.level) > 0 else { return }
                    claimingMarker = index
                }, onOfferPresentationChange: { isInspectingShopOffer = $0 },
                   isPresentationCovered: isPresentingSlip,
                   canStartPresentation: { scenePhase == .active && !isPresentingSlip })
            }
        case .achievements:
            AchievementsPageView {
                Task {
                    await flipper.flip(from: source, reduceMotion: reduceMotion) {
                        source.closeAchievements()
                    }
                }
            }
        }
    }

    // MARK: Chrome

    /// Only the two things that are true on every page. Clue moved onto the
    /// Puzzle page and Reroll onto the Shop page, because both act on a page.
    private var controls: [StripControl] {
        [
            StripControl(systemImage: "questionmark", label: "Run information") {
                showingRunInfo = true
            },
            StripControl(systemImage: "gearshape", label: "Settings") {
                showingSettings = true
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
                .task(id: message) {
                    try? await Task.sleep(for: .seconds(2.2))
                    guard !Task.isCancelled, model.message == message else { return }
                    model.clearMessage()
                }
        }
    }
}

#Preview("Puzzle") {
    GameView(model: GameModel(seed: "preview", book: .noPressure), reduceMotion: false,
             onBookCompletion: { _ in }, onAbandon: { $0.abandonRun() })
        .environment(PageFlipper())
}

#Preview("Start") {
    StartBookView(onStart: { _, _ in }, onContinue: {})
        .environment(PlayerProfileStore(profile: PlayerProfile()))
}
