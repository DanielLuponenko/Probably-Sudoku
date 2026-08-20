import SwiftUI
import NumberClubEngine

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
            if let model, !model.wantsMenu {
                GameView(model: model, reduceMotion: reduceMotion)
            } else if let book = opening, let url = openingClip(for: book) {
                BookOpening(url: url, poster: book.cover, reduceMotion: reduceMotion) {
                    begin(book)
                }
            } else {
                StartBookView { book, obstacle in
                    chosenObstacle = obstacle
                    if openingClip(for: book) == nil {
                        begin(book)          // no clip: straight in
                    } else {
                        opening = book
                    }
                }
                .transition(.opacity)
            }

            // Paper, held opaque across the swap and then lifted off the board.
            Paper.page
                .opacity(veil)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private func openingClip(for book: BookEdition) -> URL? {
        guard let opening = book.opening else { return nil }
        return Bundle.main.url(forResource: opening, withExtension: "mp4")
    }

    /// Deals the first Puzzle behind the veil, then lifts it.
    private func begin(_ book: BookEdition) {
        veil = 1
        model = GameModel(startingBoard: book.bonus, obstacle: chosenObstacle)
        opening = nil
        Task {
            // One frame flat first: animating a value in the same update that
            // sets it leaves the animation nothing to travel from.
            try? await Task.sleep(for: .milliseconds(16))
            withAnimation(.easeOut(duration: 0.65)) { veil = 0 }
        }
    }
}

private struct GameView: View {
    @Bindable var model: GameModel
    var reduceMotion: Bool
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
                    model.qaCompleteARow()
                    return
                }
                if ProcessInfo.processInfo.arguments.contains("-winNow") {
                    try? await Task.sleep(for: .milliseconds(400))
                    model.qaMeetTarget()
                    return
                }
                let arguments = ProcessInfo.processInfo.arguments
                if let index = arguments.firstIndex(of: "-curlHold"), index + 1 < arguments.count,
                   let value = Double(arguments[index + 1]) {
                    try? await Task.sleep(for: .milliseconds(400))
                    flipper.hold(from: model, at: value) { model.endTurn() }
                    return
                }
                guard ProcessInfo.processInfo.arguments.contains("-autoEndTurn") else { return }
                try? await Task.sleep(for: .seconds(1))
                await flipper.flip(from: model, reduceMotion: false) { model.endTurn() }
                #endif
            }
        }
        .environment(flipper)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: Pages

    @ViewBuilder
    private func page(of source: GameModel) -> some View {
        switch source.page {
        case .puzzle:
            if let puzzle = source.puzzle {
                PuzzlePageView(model: source, puzzle: puzzle)
            }
        case .results:
            ResultsPageView(model: source)
        case .shop:
            if let shop = source.shop {
                ShopPageView(model: source, shop: shop)
            }
        }
    }

    // MARK: Chrome

    /// Only the two things that are true on every page. Clue moved onto the
    /// Puzzle page and Reroll onto the Shop page, because both act on a page.
    private var controls: [StripControl] {
        [
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
    GameView(model: GameModel(seed: "preview", startingBoard: .oracle), reduceMotion: false)
        .environment(PageFlipper())
}

#Preview("Start") {
    StartBookView { _, _ in }
}
