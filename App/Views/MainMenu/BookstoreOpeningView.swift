import SwiftUI
import ProbablySudokuEngine

struct BookstoreOpeningView: View {
    var onOpenBook: (BookEdition, Obstacle) -> Void
    var onFirstFrame: (() -> Void)?
    var isSceneVisible: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlayerProfileStore.self) private var profile
    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @State private var phase: BookstoreScenePhase
    @State private var selectedIndex = 0
    @State private var turnSerial = 0
    @State private var focusSerial = 0
    @State private var returnFocusSerial = 0
    @State private var isFocusedBookPresented = false
    @State private var isBenefitPlaqueVisible = false
    @State private var focusPresentationSerial = 0
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
                    unlockedObstacleRawValue: progressUnlockedObstacleRawValue,
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
                    isSceneVisible: isSceneVisible
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()

            if phase.showsSelectionControls, focusedEditionID == selectedBook.id {
                Color.black.opacity(isFocusedBookPresented ? 0.30 : 0)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
                    .zIndex(4)
                    .animation(.easeOut(duration: 0.2), value: isFocusedBookPresented)

                // This is intentionally a real button.  The dimmed room is
                // the one-tap target for returning to the spinning stand;
                // it no longer depends on hit testing through LiveBook.
                Button(action: returnFocusedBookToShelf) {
                    Color.clear.contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .ignoresSafeArea()
                .accessibilityLabel("Return book to shelf")
                .accessibilityHint("Returns the selected book to the spinning book shelf")
                .zIndex(4)
            }

            // Reuse the original shelf Book for the focused state. It carries
            // the actual page block and sewn-in bookmark strip, rather than
            // attempting to redraw those physical details in SceneKit.
            if phase.showsSelectionControls, focusedEditionID == selectedBook.id,
               isFocusedBookPresented {
                focusedLiveBook
                    .ignoresSafeArea()
                    .transition(.identity)
                    .zIndex(5)
            }

            if phase.showsHomeControls {
                homeControls
                    .ignoresSafeArea()
                    .transition(.opacity.combined(with: .scale(scale: 0.985)))
            }

            if phase.showsSelectionControls {
                selectionControls
                    .ignoresSafeArea()
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
                ObstacleInfoPopup(obstacle: obstacleInfo) {
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
        ZStack {
            VStack(spacing: 0) {
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

                Spacer()

                VStack(spacing: 8) {
                    if focusedEditionID == selectedBook.id {
                        Button(action: openSelectedBook) {
                            Text(isOpeningBook
                                 ? "OPENING…"
                                 : "OPEN THE BOOK")
                            .font(Print.subheading(19))
                            .tracking(1)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(BookstoreInk.paper)
                            .background(BookstoreInk.green)
                            .contentShape(Rectangle())
                            .overlay(Rectangle().stroke(BookstoreInk.paper.opacity(0.62), lineWidth: 1))
                            .clipped()
                        }
                        .buttonStyle(BookstorePressedStyle())
                        .disabled(isOpeningBook || !isFocusedBookPresented)
                        .opacity(isFocusedBookPresented ? 1 : 0)
                        .padding(.top, 5)
                        .accessibilityHint("Open or resume this Book")
                    } else {
                        Button(action: focusSelectedBook) {
                            Text("TAP A COVER TO SELECT IT")
                                .font(Print.caption(9.5))
                                .tracking(1.4)
                                .foregroundStyle(BookstoreInk.paper.opacity(0.62))
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(BookstorePressedStyle())
                        .padding(.top, 5)
                        .accessibilityLabel("Select \(selectedBook.title)")
                        .accessibilityHint("Bring this Book forward and show its obstacle bookmarks")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }

        }
    }

    private var focusedLiveBook: some View {
        GeometryReader { proxy in
            let layout = BookstoreSelectionLayout(viewport: proxy.size)
            let benefitHeight: CGFloat = obstacle == .none ? 84 : 122
            let plaqueFrame = layout.plaqueFrame(height: benefitHeight)

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

                // The Book's actual starting-board rule belongs beside the
                // focused cover, with the selected obstacle shown only when it
                // changes the run.
                SelectedBookBenefitPlaque(benefit: selectedBook.benefit, obstacle: obstacle)
                    // The plaque is a screen-level reading aid, not part of
                    // the Book's physical frame. Keep its measured right
                    // gutter (2% of the current screen width) and mirror it
                    // exactly on the left at every device size.
                    .frame(width: plaqueFrame.width, height: plaqueFrame.height)
                    .position(x: plaqueFrame.midX, y: plaqueFrame.midY)
                    .opacity(isBenefitPlaqueVisible ? 1 : 0)
                    .allowsHitTesting(false)
            }
        }
        .task(id: focusPresentationSerial) {
            let serial = focusPresentationSerial
            await Task.yield()
            guard !Task.isCancelled, serial == focusPresentationSerial,
                  isFocusedBookPresented else { return }
            withAnimation(.easeOut(duration: reduceMotion ? 0.08 : 0.24)) {
                isBenefitPlaqueVisible = true
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
        guard phase == .choosingBook else { return }
        // Clear the SwiftUI focus synchronously. The old path waited for the
        // SceneKit camera transition to report back, which let a selected
        // LiveBook survive the title screen and reappear on the next Play.
        if focusedEditionID != nil {
            resetFocusedBookPresentation()
            returnFocusSerial += 1
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
            obstacle, progressUnlockedThrough: progressUnlockedObstacleRawValue
        )
    }

    private func focusSelectedBook() {
        requestBookFocus(selectedBook.id)
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
        focusedEditionID = focus.editionID
        isFocusedBookPresented = focus.isPresented
        isBenefitPlaqueVisible = false
        focusPresentationSerial += 1
    }

    private func returnFocusedBookToShelf() {
        guard focusedEditionID != nil else { return }
        Haptics.menuPress()
        // Do not wait for the SceneKit return callback to remove LiveBook.
        // The callback can arrive after the physical node is already back in
        // its wire pocket, which leaves a second, zoomed book on top of it.
        resetFocusedBookPresentation()
        returnFocusSerial += 1
    }

    private func resetFocusedBookPresentation() {
        focusPresentationSerial += 1
        isFocusedBookPresented = false
        isBenefitPlaqueVisible = false
        focusedEditionID = nil
    }

    private var unlockedObstacleRawValue: Int {
        selectedBook.unlockedObstacleRawValue(progressUnlockedThrough: progressUnlockedObstacleRawValue)
    }

    /// Send the progress ceiling to the rack, not the selected Book's sampler
    /// override. Each shelf cover resolves its own effective access.
    private var progressUnlockedObstacleRawValue: Int {
        #if DEBUG && targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("-unlockAll") {
            return Obstacle.allCases.count
        }
        #endif
        return RunStore.unlockedObstacle.rawValue
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
private struct SelectedBookBenefitPlaque: View {
    let benefit: BookBenefit
    let obstacle: Obstacle

    private var showsObstacle: Bool { obstacle != .none }

    var body: some View {
        VStack(spacing: showsObstacle ? 7 : 0) {
            HStack(spacing: 11) {
                benefitMark
                    .frame(width: 54, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(benefit.title)
                        .font(Print.subheading(15))
                        .foregroundStyle(BookstoreInk.charcoal)
                    Text(benefit.detail)
                        .font(.system(size: 10.5, weight: .medium, design: .serif))
                        .foregroundStyle(BookstoreInk.charcoal.opacity(0.74))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 3)

                HStack(spacing: 3) {
                    Text("\(benefit.before)")
                    Text("→")
                        .foregroundStyle(BookstoreInk.brass)
                    Text("\(benefit.after)")
                }
                .font(Print.numeral(16, weight: .bold))
                .foregroundStyle(BookstoreInk.charcoal)
                .fixedSize()
                .frame(width: 54, alignment: .trailing)
            }

            if showsObstacle {
                HStack(spacing: 7) {
                    Text(obstacle.name.uppercased())
                        .font(Print.caption(8.5))
                        .tracking(0.8)
                        .foregroundStyle(BookstoreInk.paper)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ObstacleRibbon.colour(for: obstacle).mixed(with: .black, by: 0.30))

                    Text(obstacle.text)
                        .font(.system(size: 9.5, weight: .medium, design: .serif))
                        .foregroundStyle(BookstoreInk.charcoal.opacity(0.78))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 0)
                }
                .padding(.top, 6)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(BookstoreInk.brass.opacity(0.35))
                        .frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, showsObstacle ? 10 : 9)
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.97, green: 0.93, blue: 0.83),
                    Color(red: 0.86, green: 0.80, blue: 0.67)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(BookstoreInk.charcoal.opacity(0.52), lineWidth: 2)
                .padding(1)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .stroke(BookstoreInk.brass.opacity(0.58), lineWidth: 1)
                .padding(5)
        }
        .shadow(color: .black.opacity(0.52), radius: 8, y: 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilitySummary)
    }

    @ViewBuilder
    private var benefitMark: some View {
        switch benefit {
        case .extraNumber:
            ZStack {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(BookstoreInk.paper)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(BookstoreInk.charcoal.opacity(0.48), lineWidth: 0.8)
                        )
                        .frame(width: 16, height: 22)
                        .rotationEffect(.degrees(Double(index - 2) * 7))
                        .offset(x: CGFloat(index - 2) * 7)
                        .overlay {
                            Text("\(index + 3)")
                                .font(Print.caption(7))
                                .foregroundStyle(BookstoreInk.charcoal)
                                .offset(x: CGFloat(index - 2) * 7)
                        }
                }
            }
        case .openingFloat:
            HStack(spacing: -5) {
                ForEach(0..<3, id: \.self) { _ in
                    Text("N")
                        .font(Print.caption(9))
                        .foregroundStyle(BookstoreInk.charcoal)
                        .frame(width: 19, height: 19)
                        .background(Circle().fill(Color(red: 0.92, green: 0.68, blue: 0.22)))
                        .overlay(Circle().stroke(BookstoreInk.brass, lineWidth: 1))
                }
            }
        case .marginClue:
            ZStack {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(BookstoreInk.paper)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(BookstoreInk.charcoal.opacity(0.5), lineWidth: 1)
                    )
                VStack(spacing: 2) {
                    HStack(spacing: 2) { clueSquares; clueSquares; clueSquares }
                    HStack(spacing: 2) { clueSquares; clueSquares; clueSquares }
                    HStack(spacing: 2) { clueSquares; clueSquares; clueSquares }
                }
                .padding(5)
            }
            .frame(width: 31, height: 31)
        case .oneMoreTurn:
            ZStack {
                Circle()
                    .fill(BookstoreInk.paper)
                    .overlay(Circle().stroke(BookstoreInk.charcoal.opacity(0.5), lineWidth: 1))
                Text("+1")
                    .font(Print.numeral(12, weight: .bold))
                    .foregroundStyle(BookstoreInk.brass)
            }
            .frame(width: 30, height: 30)
        case .extraToss, .boxCoin, .firstMistakeFree, .placementBonus,
             .unitBonus, .interestCap, .freeReroll, .puzzleCoin:
            Image(systemName: benefitSymbol)
                .font(.system(size: 27, weight: .regular))
                .foregroundStyle(BookstoreInk.charcoal)
        }
    }

    private var benefitSymbol: String {
        switch benefit {
        case .extraNumber: return "rectangle.stack"
        case .openingFloat: return "dollarsign.circle"
        case .marginClue: return "lightbulb"
        case .oneMoreTurn: return "clock.arrow.circlepath"
        case .extraToss: return "arrow.triangle.2.circlepath"
        case .boxCoin: return "square.grid.3x3"
        case .firstMistakeFree: return "eraser"
        case .placementBonus: return "pencil.and.outline"
        case .unitBonus: return "checkmark.rectangle.stack"
        case .interestCap: return "chart.line.uptrend.xyaxis"
        case .freeReroll: return "arrow.clockwise"
        case .puzzleCoin: return "checkmark.seal"
        }
    }

    private var clueSquares: some View {
        Rectangle()
            .fill(BookstoreInk.charcoal.opacity(0.42))
            .frame(width: 4, height: 4)
    }

    private var accessibilitySummary: String {
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

private struct BookstorePressedStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.07 : 0)
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
