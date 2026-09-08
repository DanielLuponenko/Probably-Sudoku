import SwiftUI
import ProbablySudokuEngine

struct BookstoreOpeningView: View {
    var onOpenBook: (BookEdition, Obstacle) -> Void
    var onFirstFrame: (() -> Void)?
    var isSceneVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerProfileStore.self) private var profile
    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var phase: BookstoreScenePhase
    @State private var selectedIndex = 0
    @State private var turnSerial = 0
    @State private var focusSerial = 0
    @State private var returnFocusSerial = 0
    @State private var isFocusedBookPresented = false
    @State private var isReturningFocusedBook = false
    @State private var returnsToStoreAfterBook = false
    @State private var showingSettings = false
    @State private var isOpeningBook = false
    @State private var focusedEditionID: String?
    @State private var obstacle: Obstacle = .none
    @State private var obstacleInfo: Obstacle?
    @State private var shopCategory: CosmeticCategory
    @State private var shopItemIDs: [CosmeticCategory: String]
    @State private var shopSelectionFeedback = 0
    @State private var shopPurchaseFeedback = 0
    @State private var shopRefusalFeedback = 0
    @State private var shopMessage: String?
    @State private var shopMessageGeneration = 0
    @State private var shopDragOffset: CGFloat?
    @State private var counterYaw: Double
    @State private var counterForward: Double
    @State private var counterSide: Double
    @State private var cameraForward: Double
    @State private var cameraSide: Double

    private let debugDestination = BookstoreDebugDestination.current
    private var books: [BookEdition] { BookEdition.shelf }
    private var selectedBook: BookEdition { books[selectedIndex] }
    private var isCoveredByPaper: Bool { showingSettings || obstacleInfo != nil }
    private var sceneryIsVisible: Bool {
        BookstoreMotionPolicy.isSceneVisible(isVisible: isSceneVisible,
                                             sceneIsActive: scenePhase == .active,
                                             isCovered: showingSettings || obstacleInfo != nil)
    }
    private var sceneryMotionEnabled: Bool {
        BookstoreMotionPolicy.animatesScenery(isSceneVisible: sceneryIsVisible,
                                              preference: ambientMotion,
                                              reduceMotion: reduceMotion, lowPower: lowPower)
    }
    private var shopCategories: [CosmeticCategory] {
        CosmeticCategory.allCases
    }
    private var shopItems: [CosmeticItem] {
        CosmeticCatalog.items(in: shopCategory)
    }
    private var selectedShopItem: CosmeticItem? {
        guard let requested = shopItemIDs[shopCategory] else { return shopItems.first }
        return shopItems.first(where: { $0.id == requested }) ?? shopItems.first
    }
    private var selectedShopIndex: Int {
        guard let selectedShopItem else { return 0 }
        return shopItems.firstIndex(of: selectedShopItem) ?? 0
    }
    private var shopPresentation: BookstoreShopPresentation {
        let item = selectedShopItem
        return BookstoreShopPresentation(
            currentIndex: selectedShopIndex,
            itemCount: shopItems.count,
            stampBalance: profile.currency,
            owned: item.map(profile.owns) ?? false,
            equipped: item.map(profile.isEquipped) ?? false,
            affordable: item.map { profile.currency >= $0.price } ?? false,
            message: shopMessage
        )
    }

    init(onOpenBook: @escaping (BookEdition, Obstacle) -> Void,
         onFirstFrame: (() -> Void)? = nil, isSceneVisible: Bool = true) {
        self.onOpenBook = onOpenBook
        self.onFirstFrame = onFirstFrame
        self.isSceneVisible = isSceneVisible
        // Approved, fixed Club Shop framing. These are source defaults rather
        // than per-simulator preferences so every player sees the same stand.
        _counterYaw = State(initialValue: -0.988)
        _counterForward = State(initialValue: 0)
        _counterSide = State(initialValue: 0)
        _cameraForward = State(initialValue: 2.96)
        _cameraSide = State(initialValue: 5.19)
        var initialCategory: CosmeticCategory = .paper
        var initialSelections: [CosmeticCategory: String] = [:]
        #if DEBUG && targetEnvironment(simulator)
        let arguments = ProcessInfo.processInfo.arguments
        if let at = arguments.firstIndex(of: "-shopCategory"), at + 1 < arguments.count,
           let requested = CosmeticCategory(rawValue: arguments[at + 1]) {
            initialCategory = requested
        }
        if let at = arguments.firstIndex(of: "-shopItem"), at + 1 < arguments.count,
           let requested = CosmeticCatalog.item(arguments[at + 1]) {
            initialCategory = requested.category
            initialSelections[requested.category] = requested.id
        }
        #endif
        _shopCategory = State(initialValue: initialCategory)
        _shopItemIDs = State(initialValue: initialSelections)
        switch BookstoreDebugDestination.current {
        case .normal: _phase = State(initialValue: .store)
        case .halfwayToStand: _phase = State(initialValue: .transitioningToStand)
        case .stand: _phase = State(initialValue: .choosingBook)
        case .halfwayToShop: _phase = State(initialValue: .transitioningToShop)
        case .shop: _phase = State(initialValue: .shopping)
        }
    }

    var body: some View {
        ZStack {
            // SceneKit needs a short first-frame compile on a cold launch.
            // Keep a native, in-world colour field behind its transparent
            // drawable so the player never sees an unrelated black screen.
            BookstoreRoomFallback()
                .ignoresSafeArea()

            GeometryReader { proxy in
                BookstoreSceneView(
                    phase: phase,
                    editions: books,
                    selectedEditionID: selectedBook.id,
                    selectedObstacle: obstacle,
                    unlockedObstaclesByBookID: progressUnlockedObstaclesByBookID,
                    turnCommand: BookstoreTurnCommand(serial: turnSerial, selectedIndex: selectedIndex),
                    focusCommand: BookstoreFocusCommand(serial: focusSerial, editionID: selectedBook.id),
                    returnFocusCommand: BookstoreReturnFocusCommand(serial: returnFocusSerial),
                    isLiveBookPresented: isFocusedBookPresented,
                    shopCategory: shopCategory,
                    shopItem: selectedShopItem,
                    shopPresentation: shopPresentation,
                    shopDragOffset: shopDragOffset,
                    counterYaw: counterYaw,
                    counterForward: counterForward,
                    counterSide: counterSide,
                    cameraForward: cameraForward,
                    cameraSide: cameraSide,
                    reduceMotion: reduceMotion,
                    ambientMotionEnabled: sceneryMotionEnabled,
                    debugCameraPosition: debugCameraPosition,
                    onSelectEdition: selectEdition,
                    onRequestBookFocus: requestBookFocus,
                    onSelectObstacle: selectObstacle,
                    onShowObstacleInfo: { obstacleInfo = $0 },
                    onSelectShopCategory: selectShopCategory,
                    onStepShopItem: stepShopItem,
                    onBuyOrEquipShopItem: {
                        if let selectedShopItem { buyOrEquip(selectedShopItem) }
                    },
                    onBookFocusChanged: bookFocusChanged,
                    onTransitionFinished: transitionFinished,
                    onFirstFrame: onFirstFrame,
                    isSceneVisible: sceneryIsVisible
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
                .allowsHitTesting(!isReturningFocusedBook)
            }
            .ignoresSafeArea()

            if phase.showsSelectionControls, focusedEditionID == selectedBook.id, !isCoveredByPaper {
                // This is intentionally a real button. The undimmed room is
                // the one-tap target for returning to the spinning stand;
                // it no longer depends on hit testing through LiveBook.
                Button(action: returnFocusedBookToShelf) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Return book to shelf")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Returns the selected book to the spinning book shelf")
                .disabled(isReturningFocusedBook || isOpeningBook)
                .accessibilityHidden(isReturningFocusedBook || isCoveredByPaper)
                .zIndex(4)
            }

            // Reuse the original shelf Book for the focused state. It carries
            // the actual page block and sewn-in bookmark strip, rather than
            // attempting to redraw those physical details in SceneKit.
            if phase.showsSelectionControls, focusedEditionID == selectedBook.id,
               isFocusedBookPresented {
                focusedLiveBook
                    .ignoresSafeArea()
                    .allowsHitTesting(!isReturningFocusedBook)
                    // GeometryReader does not establish an AX container. Drop
                    // its explicit child nodes while a modal paper covers it.
                    .accessibilityElement(children: isCoveredByPaper ? .ignore : .contain)
                    .accessibilityHidden(isReturningFocusedBook || isCoveredByPaper)
                    .transition(.identity)
                    .zIndex(5)
            }

            if phase.showsHomeControls {
                homeControls
                    .ignoresSafeArea()
                    .accessibilityElement(children: isCoveredByPaper ? .ignore : .contain)
                    .accessibilityHidden(isCoveredByPaper)
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }

            if phase.showsSelectionControls {
                selectionControls
                    .ignoresSafeArea()
                    .disabled(isReturningFocusedBook)
                    .accessibilityElement(children: isCoveredByPaper ? .ignore : .contain)
                    .accessibilityHidden(isCoveredByPaper)
                    .transition(.opacity)
                    .zIndex(10)
            }

            if phase.showsShopControls, let selectedShopItem {
                ClubShopOverlay(
                    categories: shopCategories,
                    selectedCategory: shopCategory,
                    selectedItem: selectedShopItem,
                    currentIndex: selectedShopIndex,
                    itemCount: shopItems.count,
                    stampBalance: profile.currency,
                    owned: profile.owns(selectedShopItem),
                    equipped: profile.isEquipped(selectedShopItem),
                    affordable: profile.currency >= selectedShopItem.price,
                    message: shopMessage,
                    onBack: returnFromShop,
                    onSelectCategory: selectShopCategory,
                    onBuyOrEquip: { buyOrEquip(selectedShopItem) },
                    onStepItem: stepShopItem,
                    onDragItem: { shopDragOffset = $0 },
                )
                .ignoresSafeArea()
                .transition(.opacity)
                .zIndex(12)
            }

            if let obstacleInfo {
                ObstacleInfoPopup(obstacle: obstacleInfo,
                                  isLocked: ObstacleInfoPopup.lockedState(
                                      obstacle: obstacleInfo, unlockedThrough: unlockedObstacleRawValue)) {
                    withAnimation(.snappy(duration: 0.2)) { self.obstacleInfo = nil }
                }
                .zIndex(30)
            }

            if showingSettings {
                Color.black.opacity(0.38).ignoresSafeArea()
                    .transition(.opacity)
                AppSettingsSlip {
                    showingSettings = false
                }
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        .background(Color(red: 0.035, green: 0.031, blue: 0.027))
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            let updated = ProcessInfo.processInfo.isLowPowerModeEnabled
            if lowPower != updated { lowPower = updated }
        }
        .animation(.easeOut(duration: reduceMotion ? 0.08 : 0.32), value: phase)
        .animation(.snappy(duration: 0.22), value: showingSettings)
        .sensoryFeedback(.selection, trigger: shopSelectionFeedback)
        .sensoryFeedback(.success, trigger: shopPurchaseFeedback)
        .sensoryFeedback(.warning, trigger: shopRefusalFeedback)
        .task {
            #if DEBUG && targetEnvironment(simulator)
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-menuSettings") {
                try? await Task.sleep(for: .milliseconds(500))
                showingSettings = true
            } else if arguments.contains("-tapPlay"), phase == .store {
                try? await Task.sleep(for: .milliseconds(700))
                walkToStand()
            }
            if arguments.contains("-focusBook"), phase == .choosingBook {
                try? await Task.sleep(for: .milliseconds(450))
                focusSelectedBook()
            }
            if arguments.contains("-tapOpenBook"), phase == .choosingBook {
                try? await Task.sleep(for: .milliseconds(850))
                openSelectedBook()
            }
            #endif
        }
    }

    private var homeControls: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        Haptics.menuOpen()
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(BookstoreInk.paper)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(.black.opacity(0.64)))
                            .overlay(Circle().stroke(BookstoreInk.brass.opacity(0.75), lineWidth: 1))
                            .shadow(color: .black.opacity(0.5), radius: 7, y: 4)
                    }
                    .buttonStyle(BookstorePressedStyle())
                    .accessibilityLabel("Settings")
                    .accessibilityHint("Open game settings")
                }
                .padding(.horizontal, 22)
                .padding(.top, 20)

                BookstoreIdentity()
                    .padding(.top, 24)

                Spacer()

                VStack(spacing: 18) {
                    Button(action: walkToStand) {
                        VStack(spacing: 4) {
                            Label("PLAY", systemImage: "play.fill")
                                .font(Print.subheading(22))
                                .tracking(2)
                            Text("Walk over to the book stand")
                                .font(Print.handwritten(13))
                                .foregroundStyle(BookstoreInk.paper.opacity(0.88))
                        }
                        .foregroundStyle(BookstoreInk.paper)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .buttonStyle(.plain)
                    .frame(width: proxy.size.width * 0.60, height: 73)
                    .background(BookstoreInk.green)
                    .clipShape(Rectangle())
                    .overlay(Rectangle().stroke(BookstoreInk.brass.opacity(0.85), lineWidth: 1))
                    .shadow(color: .black.opacity(0.7), radius: 17, y: 10)
                    .accessibilityHint("Move to the rotating book stand")

                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 34)
            }
        }
    }

    private var selectionControls: some View {
        GeometryReader { proxy in
            let layout = BookstoreSelectionLayout(viewport: proxy.size)
            let bookTheme = BookPresentationTheme(book: selectedBook.rule)
            ZStack(alignment: .topLeading) {
                HStack {
                    Button(action: returnToStore) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .black))
                            .foregroundStyle(BookstoreInk.paper)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(.black.opacity(0.72)))
                            .overlay(Circle().stroke(BookstoreInk.brass, lineWidth: 1.5))
                            .shadow(color: .black.opacity(0.6), radius: 8, y: 5)
                    }
                    .buttonStyle(BookstorePressedStyle())
                    .accessibilityLabel("Back to bookstore")
                    .accessibilityHint("Return to the wide aisle view")
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                    if focusedEditionID == selectedBook.id {
                        Button(action: openSelectedBook) {
                            Text(isOpeningBook
                                 ? "OPENING…"
                                 : "OPEN THE BOOK")
                            .font(Print.subheading(18))
                            .tracking(0.8)
                            .frame(maxWidth: .infinity, minHeight: BookstoreSelectionLayout.openButtonHeight)
                            .foregroundStyle(bookTheme.buttonForeground)
                        }
                        .buttonStyle(RaisedBookOpenStyle(fill: bookTheme.buttonFill))
                        .disabled(isOpeningBook || !isFocusedBookPresented)
                        .opacity(isFocusedBookPresented ? 1 : 0)
                        .frame(width: layout.openButtonFrame.width,
                               height: layout.openButtonFrame.height)
                        .position(x: layout.openButtonFrame.midX, y: layout.openButtonFrame.midY)
                        .accessibilityHint("Open or resume this Book")
                        .accessibilityIdentifier("bookstore.openBook")

                        // The sign itself is rendered by SceneKit. Expose its
                        // complete rule natively without adding a second banner.
                        Color.clear
                            .frame(width: proxy.size.width * 0.64, height: 72)
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel("Book benefit: \(selectedBook.benefit.title). \(selectedBook.benefit.detail)")
                            .accessibilityIdentifier("bookstore.benefitSign")
                            .accessibilityHidden(!isFocusedBookPresented || isReturningFocusedBook)
                            .accessibilitySortPriority(2)
                            .position(x: proxy.size.width * 0.5, y: layout.headerClearance * 0.58)
                            .allowsHitTesting(false)
                    } else {
                        BookstoreShelfSelector(
                            editions: books, selectedEdition: selectedBook,
                            canBrowse: phase == .choosingBook && focusedEditionID == nil
                                && !isFocusedBookPresented && !isReturningFocusedBook && !isOpeningBook,
                            onSelect: focusSelectedBook, onBrowse: browseShelf
                        )
                        .frame(width: max(0, proxy.size.width - 32), height: 40)
                        .position(x: proxy.size.width * 0.5,
                                  y: proxy.size.height - layout.openButtonBottomPadding - 20)
                    }
            }

        }
    }

    private var focusedLiveBook: some View {
        GeometryReader { proxy in
            let layout = BookstoreSelectionLayout(viewport: proxy.size)

            ZStack {
                LiveBook(
                    edition: selectedBook,
                    ribbons: LiveBook.RibbonStrip(
                        levels: Obstacle.allCases,
                        selected: obstacle,
                        isUnlocked: { $0.rawValue <= unlockedObstacleRawValue },
                        onPick: selectObstacle,
                        onShowInfo: { obstacleInfo = $0 }
                    )
                )
                // These dimensions and the ribbon construction are the former
                // shelf implementation that established the approved look.
                .frame(width: layout.bookWidth)
                // LiveBook's tab strip reaches beyond the fore-edge. Keep the
                // hit region tightly around that actual Book, not the whole
                // screen, so the dimmed room behind it remains a reliable return
                // target.
                .frame(
                    width: layout.canvasSize.width,
                    height: layout.canvasSize.height,
                    alignment: .topLeading
                )
                // SceneKit brings this exact printed face to this measured
                // rectangle before handing interaction to LiveBook.
                .position(layout.coverCenter)

            }
        }
    }

    private func walkToStand() {
        guard phase == .store else { return }
        resetFocusedBookPresentation()
        Haptics.menuOpen()
        phase = .transitioningToStand
    }

    private func walkToShop() {
        guard phase == .store else { return }
        Haptics.menuOpen()
        phase = .transitioningToShop
    }

    private func returnToStore() {
        guard phase == .choosingBook, !isReturningFocusedBook, !isOpeningBook else { return }
        if focusedEditionID != nil {
            returnsToStoreAfterBook = true
            returnFocusedBookToShelf()
            return
        }
        Haptics.menuOpen()
        phase = .transitioningToStore
    }

    private func returnFromShop() {
        guard phase == .shopping else { return }
        shopDragOffset = nil
        Haptics.menuOpen()
        phase = .transitioningShopToStore
    }

    private func transitionFinished(_ destination: BookstoreScenePhase) {
        guard phase == .transitioningToStand
                || phase == .transitioningToStore
                || phase == .transitioningToShop
                || phase == .transitioningShopToStore
        else { return }
        phase = destination
    }

    private var debugCameraPosition: BookstoreDebugCameraPosition? {
        switch debugDestination {
        case .halfwayToStand: .stand(progress: 0.5)
        case .halfwayToShop: .shop(progress: 0.5)
        default: nil
        }
    }

    private func selectShopCategory(_ category: CosmeticCategory) {
        guard shopCategory != category else { return }
        shopDragOffset = nil
        shopCategory = category
        if shopItemIDs[category] == nil {
            shopItemIDs[category] = CosmeticCatalog.items(in: category).first?.id
        }
        if haptics { shopSelectionFeedback += 1 }
        shopMessage = nil
    }

    private func stepShopItem(_ direction: Int) {
        guard !shopItems.isEmpty else { return }
        shopDragOffset = nil
        let next = (selectedShopIndex + direction + shopItems.count) % shopItems.count
        shopItemIDs[shopCategory] = shopItems[next].id
        if haptics { shopSelectionFeedback += 1 }
        shopMessage = nil
    }

    private func buyOrEquip(_ item: CosmeticItem) {
        if profile.isEquipped(item) { return }

        if profile.owns(item) {
            profile.equip(item)
            if haptics { shopPurchaseFeedback += 1 }
            showShopMessage("SET ON YOUR DESK")
            return
        }

        do {
            try profile.purchase(item)
            profile.equip(item)
            if haptics { shopPurchaseFeedback += 1 }
            showShopMessage("WRAPPED AND READY")
        } catch {
            if haptics { shopRefusalFeedback += 1 }
            showShopMessage("NOT ENOUGH STAMPS")
        }
    }

    private func showShopMessage(_ message: String) {
        shopMessageGeneration += 1
        let generation = shopMessageGeneration
        shopMessage = message
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.45))
            if shopMessageGeneration == generation { shopMessage = nil }
        }
    }

    private func selectEdition(_ id: String) {
        guard let index = books.firstIndex(where: { $0.id == id }) else { return }
        selectedIndex = index
        obstacle = selectedBook.availableObstacle(
            obstacle, progressByBookID: progressUnlockedObstaclesByBookID
        )
    }

    private func focusSelectedBook() {
        requestBookFocus(selectedBook.id)
    }

    private func browseShelf(to editionID: String) {
        guard phase == .choosingBook, focusedEditionID == nil,
              !isFocusedBookPresented, !isReturningFocusedBook, !isOpeningBook,
              editionID != selectedBook.id, books.contains(where: { $0.id == editionID }) else { return }
        selectEdition(editionID)
        turnSerial += 1
    }

    private func requestBookFocus(_ id: String) {
        guard phase == .choosingBook, focusedEditionID == nil,
              let index = books.firstIndex(where: { $0.id == id }) else { return }
        selectEdition(books[index].id)
        // Resolve the binding before SceneKit starts moving. Its update applies
        // these print textures before processing focusSerial, including when
        // Reduce Motion skips extraction and goes straight to presentation.
        if let saved = RunStore.displayedRun(), saved.run.book == selectedBook.rule {
            obstacle = saved.run.obstacle
        }
        Haptics.menuPress()
        focusSerial += 1
    }

    private func bookFocusChanged(_ focus: BookstoreBookFocus) {
        guard phase == .choosingBook else { return }
        // A queued extraction callback cannot undo a return already requested
        // while the plaque is fading at its stationary screen position.
        if isReturningFocusedBook {
            switch focus {
            case .extracting, .presented: return
            case .returning, .shelf: break
            }
        }
        if focus == .shelf {
            let returnToAisle = returnsToStoreAfterBook
            resetFocusedBookPresentation()
            if returnToAisle {
                Haptics.menuOpen()
                phase = .transitioningToStore
            }
            return
        }
        focusedEditionID = focus.editionID
        isFocusedBookPresented = focus.isPresented
        if case .returning = focus { isReturningFocusedBook = true }
    }

    private func returnFocusedBookToShelf() {
        guard focusedEditionID != nil, !isReturningFocusedBook, !isOpeningBook else { return }
        Haptics.menuPress()
        isReturningFocusedBook = true
        // The stationary sign changes its print independently. Keep LiveBook
        // mounted until SceneKit reports its physical twin GPU-ready.
        returnFocusSerial += 1
    }

    private func resetFocusedBookPresentation() {
        isFocusedBookPresented = false
        isReturningFocusedBook = false
        returnsToStoreAfterBook = false
        focusedEditionID = nil
    }

    private var unlockedObstacleRawValue: Int {
        selectedBook.unlockedObstacleRawValue(progressByBookID: progressUnlockedObstaclesByBookID)
    }

    private var progressUnlockedObstaclesByBookID: [String: Int] {
        BookEdition.obstacleUnlocks(for: profile.profile.achievementProgress,
                                   arguments: ProcessInfo.processInfo.arguments)
    }

    private func selectObstacle(_ selected: Obstacle) {
        guard selected.rawValue <= unlockedObstacleRawValue else {
            obstacleInfo = selected
            return
        }
        guard obstacle != selected else { return }
        Haptics.pageTurn()
        obstacle = selected
    }

    private func openSelectedBook() {
        guard phase == .choosingBook, isFocusedBookPresented,
              selectedBook.isUnlocked, !isOpeningBook else { return }
        isOpeningBook = true
        let book = selectedBook
        Haptics.menuOpen()
        // Let the pressed state commit before ContentView replaces the entire
        // bookstore. This also gives a visible response on slower devices.
        Task { @MainActor in
            await Task.yield()
            onOpenBook(book, obstacle)
            try? await Task.sleep(for: .milliseconds(600))
            if phase == .choosingBook { isOpeningBook = false }
        }
    }

}

private enum BookstoreInk {
    static let paper = Color(red: 0.94, green: 0.90, blue: 0.82)
    static let brass = Color(red: 0.74, green: 0.49, blue: 0.18)
    static let green = Color(red: 0.486, green: 0.549, blue: 0.451)
    static let sage = Color(red: 0.63, green: 0.70, blue: 0.58)
    static let charcoal = Color(red: 0.09, green: 0.09, blue: 0.085)
}

/// The printed result of a Book's own benefit. Keeping this adjacent to the
/// selection UI makes the shelf explain gameplay in the same place the player
/// chooses a Book.
struct SelectedBookBenefitPlaque: View {
    let edition: BookEdition
    let obstacle: Obstacle
    var scrollHeight: CGFloat? = nil
    var onContentHeightChange: ((CGFloat) -> Void)? = nil

    @Environment(\.cosmeticTheme) private var theme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var benefit: BookBenefit { edition.benefit }
    private var showsObstacle: Bool { obstacle != .none }
    @ScaledMetric(relativeTo: .body) private var illustrationSize: CGFloat = 36
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var detailSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var obstacleTitleSize: CGFloat = 9.5
    @ScaledMetric(relativeTo: .body) private var obstacleDetailSize: CGFloat = 10
    private var bookTheme: BookPresentationTheme { BookPresentationTheme(book: edition.rule) }
    private var accent: Color { bookTheme.accent }
    private var strongInk: Color { bookTheme.buttonFill }

    static func height(width: CGFloat, showsObstacle: Bool) -> CGFloat {
        BookstoreSelectionLayout.plaqueHeight(width: width, showsObstacle: showsObstacle)
    }

    var body: some View {
        Group {
            if let scrollHeight {
                ScrollView(.vertical, showsIndicators: false) {
                    plaqueContent
                }
                .frame(height: scrollHeight)
            } else {
                plaqueContent
            }
        }
        .paperSurface(kind: .label)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    private var plaqueContent: some View {
        VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 10) {
                    // Each Book has its own little stationery illustration:
                    // a seventh card, a lamp, an eraser, a biscuit, and so on.
                    // Removing the generic circle also gives the drawing air.
                    BookBenefitIllustration(book: edition.rule)
                        .frame(width: min(illustrationSize, 48), height: min(illustrationSize, 48))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(benefit.title)
                            .font(Print.subheading(titleSize))
                            .foregroundStyle(strongInk)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(detail)
                            .font(Print.body(detailSize))
                            .foregroundStyle(theme.paper.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)

                if showsObstacle {
                    let ruleLayout = dynamicTypeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                        : AnyLayout(HStackLayout(spacing: 7))
                    ruleLayout {
                        Text(obstacle.name)
                            .font(Print.caption(obstacleTitleSize))
                            .foregroundStyle(ObstacleRibbon.colour(for: obstacle).mixed(with: .black, by: 0.45))
                            .fixedSize()
                        Text(obstacle.text)
                            .font(Print.body(obstacleDetailSize))
                            .foregroundStyle(theme.paper.softInk)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .overlay(alignment: .top) {
                        Rectangle().fill(accent.opacity(0.32)).frame(height: 0.65)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 7)
                    .padding(.bottom, 10)
                }
            }
            .padding(.vertical, showsObstacle ? 3 : 10)
            .frame(maxWidth: .infinity,
                   minHeight: BookstoreSelectionLayout.plaqueHeight(width: 0,
                                                                      showsObstacle: showsObstacle),
                   alignment: .center)
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.height.rounded(.up)
            } action: { height in
                // This is the intrinsic child height even when the outer
                // plaque becomes a capped ScrollView, so the parent can grow
                // and shrink the measured target without moving the Book.
                if height > 0 { onContentHeightChange?(height) }
            }
    }

    /// Concise print copy for the plaque; the accessibility label retains the
    /// complete engine-authored rule, including its exact scope.
    var detail: String {
        switch benefit {
        case .extraNumber: return "\(benefit.after) numbers in your hand"
        case .openingFloat: return "\(benefit.after) coins to begin"
        case .marginClue: return "\(benefit.after) clue per puzzle"
        case .oneMoreTurn: return "\(benefit.after) turns per puzzle"
        case .extraToss: return "\(benefit.after) numbers per puzzle"
        case .boxCoin: return "For each box you complete"
        case .firstMistakeFree: return "One penalty waived per puzzle"
        case .placementBonus: return "For each correct placement"
        case .unitBonus: return "For each row, column or box clear"
        case .interestCap: return "Up to \(benefit.after) interest coins"
        case .freeReroll: return "First reroll in every Shop"
        case .puzzleCoin: return "\(benefit.after) base coins per puzzle"
        }
    }

    var accessibilitySummary: String {
        var summary = "Book benefit: \(benefit.title). \(benefit.detail)"
        if showsObstacle {
            summary += " \(obstacle.name). \(obstacle.text)"
        }
        return summary
    }
}

private struct BookstoreCurrencyBadge: View {
    var amount: Int

    var body: some View {
        HStack(spacing: 8) {
            Text("N")
                .font(Print.subheading(20))
                .foregroundStyle(Color(red: 0.16, green: 0.12, blue: 0.06))
                .frame(width: 40, height: 40)
                .background(Circle().fill(LinearGradient(
                    colors: [Color(red: 0.94, green: 0.78, blue: 0.28), Color(red: 0.61, green: 0.39, blue: 0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )))
                .overlay(Circle().stroke(Color(red: 0.45, green: 0.29, blue: 0.04), lineWidth: 2))
            Text("\(amount)")
                .font(Print.numeral(24, weight: .bold))
                .foregroundStyle(BookstoreInk.paper)
        }
        .shadow(color: .black.opacity(0.6), radius: 6, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(amount) Number Club coins")
    }
}

private struct BookstoreIdentity: View {
    var body: some View {
        VStack(spacing: 5) {
            Text("PROBABLY SUDOKU")
                .font(.system(size: 19, weight: .semibold, design: .serif))
                .tracking(3.0)
            Text("THE NUMBER CLUB · EST. RECENTLY")
                .font(Print.caption(8.5))
                .tracking(1.9)
                .foregroundStyle(BookstoreInk.sage)
        }
        .foregroundStyle(BookstoreInk.paper)
        .frame(maxWidth: 286)
        .padding(.vertical, 12)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.76), .clear], startPoint: .leading, endPoint: .trailing))
        .overlay(alignment: .top) { Rectangle().fill(BookstoreInk.brass.opacity(0.75)).frame(height: 1) }
        .overlay(alignment: .bottom) { Rectangle().fill(BookstoreInk.brass.opacity(0.75)).frame(height: 1) }
        .shadow(color: .black.opacity(0.65), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
    }
}

/// One native action surface for the physical rack. SceneKit stays decorative
/// to assistive technology; these actions turn and select its actual editions.
struct BookstoreShelfSelector: View {
    let editions: [BookEdition]
    let selectedEdition: BookEdition
    let canBrowse: Bool
    let onSelect: () -> Void
    let onBrowse: (String) -> Void

    var accessibilityValue: String {
        let volume = (editions.firstIndex(where: { $0.id == selectedEdition.id }) ?? 0) + 1
        return "Volume \(volume) of \(editions.count). \(selectedEdition.title)"
    }

    var body: some View {
        Button(action: selectCurrentBook) {
            Text("TAP A COVER TO SELECT IT")
                .font(Print.caption(9.5))
                .tracking(1.4)
                .foregroundStyle(BookstoreInk.paper.opacity(0.62))
                .frame(maxWidth: .infinity, minHeight: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(BookstorePressedStyle())
        .disabled(!canBrowse)
        .accessibilityIdentifier("bookstore.shelfSelector")
        .accessibilityLabel("Select \(selectedEdition.title)")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Adjust to browse Books. Activate to bring this Book forward and show its obstacle bookmarks.")
        .accessibilityAdjustableAction(browse)
        .accessibilityAction(named: "Next Book") { browse(.increment) }
        .accessibilityAction(named: "Previous Book") { browse(.decrement) }
    }

    func selectCurrentBook() {
        guard canBrowse else { return }
        onSelect()
    }

    func browse(_ direction: AccessibilityAdjustmentDirection) {
        guard canBrowse, !editions.isEmpty,
              let index = editions.firstIndex(where: { $0.id == selectedEdition.id }) else { return }
        let step: Int
        switch direction {
        case .increment: step = 1
        case .decrement: step = -1
        @unknown default: return
        }
        let nextIndex = (index + step + editions.count) % editions.count
        onBrowse(editions[nextIndex].id)
    }
}

private struct BookstorePressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
    }
}

/// A small cloth-faced paper stack, using the same Book ink and stock. Its
/// depth is static; only an intentional press compresses the raised face.
private struct RaisedBookOpenStyle: ButtonStyle {
    let fill: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [fill.mixed(with: .white, by: 0.06), fill],
                                         startPoint: .top, endPoint: .bottom))
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(BookstoreInk.paper.opacity(0.38), lineWidth: 1)
                    }
            }
            .offset(y: configuration.isPressed ? 3 : 0)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fill.mixed(with: .black, by: 0.36))
                    .offset(y: 4)
                    .shadow(color: .black.opacity(configuration.isPressed ? 0.18 : 0.32),
                            radius: configuration.isPressed ? 2 : 5,
                            y: configuration.isPressed ? 3 : 7)
            }
            .contentShape(RoundedRectangle(cornerRadius: 4))
            .animation(.easeOut(duration: reduceMotion ? 0 : 0.10), value: configuration.isPressed)
    }
}

private struct BookstoreRoomFallback: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: 0x34382B),
                    Color(hex: 0x3A2419),
                    Color(hex: 0x15131A)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            LinearGradient(
                colors: [.clear, Color(hex: 0x0D2D28).opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: 120)
        }
        .accessibilityHidden(true)
    }
}
