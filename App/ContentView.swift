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

    var body: some View {
        DeskView {
            VStack(spacing: 8) {
                LoadoutRow(model: model) { model.useBuff(at: $0) }
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                BookView(flipper: flipper) { pageContent }
                    .padding(.leading, 8)
                    .padding(.trailing, 10)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .center) { wonOverlay }
            .overlay(alignment: .bottom) { toast }
            .overlay(alignment: .top) {
                IslandBar(coins: model.coins, controls: controls)
                    .ignoresSafeArea(edges: .top)
            }
            .task {
                #if DEBUG
                guard ProcessInfo.processInfo.arguments.contains("-autoEndTurn") else { return }
                try? await Task.sleep(for: .seconds(1))
                await flipper.flip(reduceMotion: false) { model.endTurn() }
                #endif
            }
        }
        .environment(flipper)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: Pages

    @ViewBuilder
    private var pageContent: some View {
        switch model.page {
        case .puzzle:
            if let puzzle = model.puzzle {
                PuzzlePageView(model: model, puzzle: puzzle)
            }
        case .results:
            ResultsPageView(model: model)
        case .shop:
            if let shop = model.shop {
                ShopPageView(model: model, shop: shop)
            }
        }
    }

    // MARK: Chrome

    /// Only the two things that are true on every page. Clue moved onto the
    /// Puzzle page and Reroll onto the Shop page, because both act on a page.
    private var controls: [StripControl] {
        [
            StripControl(systemImage: "questionmark", label: "How to play") {},
            StripControl(systemImage: "gearshape", label: "Settings") {},
        ]
    }

    @ViewBuilder
    private var wonOverlay: some View {
        if model.page == .puzzle, let puzzle = model.puzzle, puzzle.phase == .won {
            Color.black.opacity(0.45).ignoresSafeArea()
                .transition(.opacity)
            WonOverlay(model: model, puzzle: puzzle)
                .transition(.scale(scale: 0.94).combined(with: .opacity))
        }
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
