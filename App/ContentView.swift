import SwiftUI
import NumberClubEngine

struct ContentView: View {
    @State private var model: GameModel? = ContentView.debugModel()
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

    var body: some View {
        if let model {
            GameView(model: model, reduceMotion: reduceMotion)
        } else {
            StartBookView { board in
                model = GameModel(startingBoard: board)
            }
            .transition(.opacity)
        }
    }
}

private struct GameView: View {
    @Bindable var model: GameModel
    var reduceMotion: Bool
    @State private var flipper = PageFlipper()
    @State private var showingSettings = false
    @State private var showingHelp = false

    var body: some View {
        DeskView {
            VStack(spacing: 8) {
                LoadoutRow(model: model) { model.useBuff(at: $0) }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                BookView(
                    flipper: flipper,
                    outgoing: flipper.outgoing.map { AnyView(page(of: $0)) }
                ) {
                    page(of: model)
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
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
                    } onShowHelp: {
                        withAnimation(.snappy(duration: 0.2)) {
                            showingSettings = false
                            showingHelp = true
                        }
                    }
                }
                if showingHelp {
                    HelpSlip {
                        withAnimation(.snappy(duration: 0.2)) { showingHelp = false }
                    }
                }
            }
            .animation(.snappy(duration: 0.22), value: showingSettings)
            .animation(.snappy(duration: 0.22), value: showingHelp)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("-qa") { showingSettings = true }
                if ProcessInfo.processInfo.arguments.contains("-help") { showingHelp = true }
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
            StripControl(systemImage: "questionmark", label: "How to play") {
                withAnimation(.snappy(duration: 0.22)) { showingHelp = true }
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
    StartBookView { _ in }
}
