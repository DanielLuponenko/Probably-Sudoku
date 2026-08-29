import SwiftUI
import ProbablySudokuEngine

struct BookstoreOpeningView: View {
    var onOpenBook: (BookEdition, Obstacle) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(PlayerProfileStore.self) private var profile
    @AppStorage(AppPreferences.Key.haptics) private var haptics = true
    @State private var phase: BookstoreScenePhase
    @State private var selectedIndex = 0
    @State private var turnSerial = 0
    @State private var focusSerial = 0
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
    private let pocketSlots: [[Int?]] = [
        [0, 4, 8],
        [1, 5, nil],
        [2, 6, nil],
        [3, 7, nil]
    ]
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

    init(onOpenBook: @escaping (BookEdition, Obstacle) -> Void) {
        self.onOpenBook = onOpenBook
        let storedYaw = UserDefaults.standard.object(forKey: "clubShopCounterYawV2") as? Double
        _counterYaw = State(initialValue: storedYaw ?? 0.20)
        _counterForward = State(initialValue: UserDefaults.standard.object(forKey: "clubShopCounterForwardV2") as? Double ?? 0)
        _counterSide = State(initialValue: UserDefaults.standard.object(forKey: "clubShopCounterSideV2") as? Double ?? 0)
        _cameraForward = State(initialValue: UserDefaults.standard.object(forKey: "clubShopCameraForwardV2") as? Double ?? 0)
        _cameraSide = State(initialValue: UserDefaults.standard.object(forKey: "clubShopCameraSideV2") as? Double ?? 0)
        var initialCategory: CosmeticCategory = .paper
        var initialSelections: [CosmeticCategory: String] = [:]
        #if DEBUG
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
                    unlockedObstacleRawValue: unlockedObstacleRawValue,
                    turnCommand: BookstoreTurnCommand(serial: turnSerial, selectedIndex: selectedIndex),
                    focusCommand: BookstoreFocusCommand(serial: focusSerial, editionID: selectedBook.id),
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
                    onSelectObstacle: selectObstacle,
                    onShowObstacleInfo: { obstacleInfo = $0 },
                    onSelectShopCategory: selectShopCategory,
                    onStepShopItem: stepShopItem,
                    onBuyOrEquipShopItem: {
                        if let selectedShopItem { buyOrEquip(selectedShopItem) }
                    },
                    onBookFocusChanged: bookFocusChanged,
                    onTransitionFinished: transitionFinished
                )
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
            .ignoresSafeArea()

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
                AppSettingsSlip(onOpenShop: {
                    showingSettings = false
                    walkToShop()
                }) {
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
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-menuSettings") {
                try? await Task.sleep(for: .milliseconds(500))
                showingSettings = true
            } else if arguments.contains("-tapPlay"), phase == .store {
                try? await Task.sleep(for: .milliseconds(700))
                walkToStand()
            } else if arguments.contains("-tapShop") {
                try? await Task.sleep(for: .milliseconds(600))
                walkToShop()
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
                    BookstoreCurrencyBadge(amount: profile.currency)
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
                        .frame(width: proxy.size.width * 0.60, height: 73)
                        .foregroundStyle(BookstoreInk.paper)
                        .background(BookstoreInk.green)
                        .overlay(Rectangle().stroke(BookstoreInk.paper.opacity(0.72), lineWidth: 1))
                        .overlay(Rectangle().stroke(BookstoreInk.brass.opacity(0.7), lineWidth: 1).padding(4))
                        .shadow(color: .black.opacity(0.7), radius: 17, y: 10)
                    }
                    .buttonStyle(BookstorePressedStyle())
                    .accessibilityHint("Move to the rotating book stand")

                    Button(action: walkToShop) {
                        HStack(spacing: 12) {
                            Rectangle().fill(BookstoreInk.brass.opacity(0.5)).frame(width: 42, height: 1)
                            Text("SHOP").font(Print.caption(11)).tracking(2.8)
                            Rectangle().fill(BookstoreInk.brass.opacity(0.5)).frame(width: 42, height: 1)
                        }
                        .foregroundStyle(BookstoreInk.paper.opacity(0.9))
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(BookstorePressedStyle())
                    .accessibilityHint("Turn toward the permanent Club Shop counter")
                    .offset(y: 10)
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

                HStack {
                    turnButton(systemName: "chevron.left", label: "Previous book", delta: -1)
                    Spacer()
                    turnButton(systemName: "chevron.right", label: "Next book", delta: 1)
                }
                .padding(.horizontal, 14)
                // The turn buttons sit over the lower rack tier, close to the
                // selected Book rather than halfway up the stand.
                .padding(.bottom, 47)

                VStack(spacing: 8) {
                    Text(selectedBook.title)
                        .font(.system(size: 17, design: .serif).italic())
                        .foregroundStyle(BookstoreInk.paper)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("\(selectedBook.shelfLabel) · \(selectorStatus)")
                        .font(Print.caption(9.5))
                        .tracking(1.15)
                        .textCase(.uppercase)
                        .foregroundStyle(BookstoreInk.paper.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    if focusedEditionID == selectedBook.id {
                        Button(action: openSelectedBook) {
                            Text(isOpeningBook
                                 ? "OPENING…"
                                 : (selectedBook.isUnlocked ? "OPEN THE BOOK" : "FINISH THE PREVIOUS BOOK"))
                            .font(Print.subheading(19))
                            .tracking(1)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .foregroundStyle(BookstoreInk.paper)
                            .background(selectedBook.isUnlocked ? BookstoreInk.green : BookstoreInk.charcoal.opacity(0.9))
                            .contentShape(Rectangle())
                            .overlay(Rectangle().stroke(BookstoreInk.paper.opacity(0.62), lineWidth: 1))
                            .clipped()
                        }
                        .buttonStyle(BookstorePressedStyle())
                        .disabled(!selectedBook.isUnlocked || isOpeningBook)
                        .opacity(selectedBook.isUnlocked ? 1 : 0.66)
                        .padding(.top, 5)
                        .accessibilityHint(selectedBook.isUnlocked ? "Open or resume this Book" : "This volume is locked")
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

    private func turnButton(systemName: String, label: String, delta: Int) -> some View {
        Button {
            Haptics.menuPress()
            turnToAdjacentFace(delta)
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(BookstoreInk.paper)
                .frame(width: 42, height: 42)
                .background(Circle().fill(.black.opacity(0.72)))
                .overlay(Circle().stroke(BookstoreInk.paper.opacity(0.38), lineWidth: 1))
                .shadow(color: .black.opacity(0.6), radius: 8, y: 5)
        }
        .buttonStyle(BookstorePressedStyle())
        .accessibilityLabel(label)
    }

    private func walkToStand() {
        guard phase == .store else { return }
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
    }

    private func focusSelectedBook() {
        guard phase == .choosingBook, focusedEditionID == nil else { return }
        Haptics.menuPress()
        focusSerial += 1
    }

    private func bookFocusChanged(_ id: String?) {
        guard focusedEditionID != id else { return }
        focusedEditionID = id
        guard let id,
              let book = books.first(where: { $0.id == id }),
              let saved = RunStore.displayedRun(), saved.run.book == book.rule
        else { return }
        obstacle = saved.run.obstacle
    }

    private var unlockedObstacleRawValue: Int {
        #if DEBUG
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
        guard phase == .choosingBook, selectedBook.isUnlocked, !isOpeningBook else { return }
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

    private func turnToAdjacentFace(_ delta: Int) {
        let currentFace = pocketSlots.firstIndex { $0.contains { $0 == selectedIndex } } ?? 0
        let nextFace = (currentFace + delta + pocketSlots.count) % pocketSlots.count
        guard let index = pocketSlots[nextFace].compactMap({ $0 }).first(where: { $0 < books.count }) else { return }
        selectedIndex = index
        turnSerial += 1
    }

    private var selectorStatus: String {
        if selectedBook.id == BookEdition.first.id { return "Hand size 7" }
        return selectedBook.isUnlocked ? "Unlocked" : "Locked"
    }
}

private enum BookstoreInk {
    static let paper = Color(red: 0.94, green: 0.90, blue: 0.82)
    static let brass = Color(red: 0.74, green: 0.49, blue: 0.18)
    static let green = Color(red: 0.486, green: 0.549, blue: 0.451)
    static let sage = Color(red: 0.63, green: 0.70, blue: 0.58)
    static let charcoal = Color(red: 0.09, green: 0.09, blue: 0.085)
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
