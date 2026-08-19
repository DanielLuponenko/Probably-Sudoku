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

    var body: some View {
        DeskView {
            VStack(spacing: 8) {
                topStrip

                LoadoutRow(model: model) { model.useBuff(at: $0) }
                    .padding(.horizontal, 12)

                BookPageView { pageContent }
                    .padding(.horizontal, 12)
            }
            .padding(.vertical, 8)
            .overlay(alignment: .center) { wonOverlay }
            .overlay(alignment: .bottom) { toast }
        }
        .animation(.snappy(duration: 0.35), value: model.page)
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
                    .pageTurnTransition(forward: false, reduceMotion: reduceMotion)
            }
        case .results:
            ResultsPageView(model: model)
                .pageTurnTransition(forward: true, reduceMotion: reduceMotion)
        case .shop:
            if let shop = model.shop {
                ShopPageView(model: model, shop: shop)
                    .pageTurnTransition(forward: true, reduceMotion: reduceMotion)
            }
        }
    }

    // MARK: Chrome

    private var topStrip: some View {
        TopStripView(
            coins: model.coins,
            levelLabel: "Level \(model.run.level)",
            slotIndex: model.run.slot.rawValue,
            slotCount: 3,
            trailing: controls
        )
        .padding(.horizontal, 14)
    }

    /// Refresh belongs to the Shop page only; the Puzzle page carries Clue.
    private var controls: [StripControl] {
        switch model.page {
        case .shop:
            return [
                StripControl(systemImage: "arrow.triangle.2.circlepath",
                             label: "Reroll the shop",
                             badge: model.shop.map { "\($0.rerollCost)" },
                             isEnabled: model.coins >= (model.shop?.rerollCost ?? .max)) {
                    model.reroll()
                },
                StripControl(systemImage: "questionmark", label: "How to play") {},
                StripControl(systemImage: "gearshape", label: "Settings") {},
            ]
        default:
            let clues = model.puzzle?.cluesRemaining ?? 0
            return [
                StripControl(systemImage: "magnifyingglass",
                             label: "Use a Clue",
                             badge: clues > 0 ? "\(clues)" : nil,
                             isEnabled: model.puzzle?.canUseClue == true
                                        && model.selectedSquare != nil) {
                    if let square = model.selectedSquare { model.useClue(at: square) }
                },
                StripControl(systemImage: "questionmark", label: "How to play") {},
                StripControl(systemImage: "gearshape", label: "Settings") {},
            ]
        }
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
}

#Preview("Start") {
    StartBookView { _ in }
}
