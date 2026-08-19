import SwiftUI
import NumberClubEngine

struct ContentView: View {
    @State private var model = GameModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        DeskView {
            VStack(spacing: 12) {
                topStrip

                BookPageView(tabIndex: min(model.run.level - 1, 4),
                             tabLabels: tabLabels) {
                    pageContent
                }
                .padding(.horizontal, 14)
                .padding(.trailing, 22)          // room for the fore-edge tabs

                if model.page == .puzzle {
                    OwnedPanelView(model: model) { model.useBuff(at: $0) }
                        .padding(.horizontal, 14)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
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

    private var tabLabels: [String] {
        // Five tabs, windowed onto the nine Levels so the active one is visible.
        let start = max(0, min(model.run.level - 1, 4))
        _ = start
        return (1...5).map { "L\($0 + max(0, model.run.level - 5))" }
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

#Preview {
    ContentView()
}
