import SwiftUI
import UIKit
import ProbablySudokuEngine

/// Shared materials for the live puzzle. Book covers keep their own theme.
enum GameplaySurface {
    static let ivory = Color(hex: 0xF3EBDD)
    static let ink = Color(hex: 0x1E241F)
    static let sage = Color(hex: 0x4F6E64)
    static let softInk = Color(hex: 0x5F625B)
    static let frame = Color(hex: 0x5D8176)
}

struct GameplaySurfaceBackground: View {
    var body: some View {
        GameplaySurface.ivory
            .overlay { Rectangle().fill(ImagePaint(image: GameplayLinen.image)).opacity(0.5) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

private enum GameplayLinen {
    // Rasterize one small, seamless weave once. Repeated screen redraws reuse
    // the same texture instead of drawing thousands of individual threads.
    static let image: Image = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let tile = UIGraphicsImageRenderer(size: CGSize(width: 72, height: 72), format: format).image { _ in
            for row in 0..<24 {
                for column in 0..<24 {
                    let seed = (row &* 73_856_093) ^ (column &* 19_349_663)
                    let variation = CGFloat(abs(seed % 7)) / 7
                    let horizontal = (row + column) % 2 == 0
                    let thread = CGRect(x: CGFloat(column) * 3, y: CGFloat(row) * 3,
                                        width: horizontal ? 2.6 : 0.8,
                                        height: horizontal ? 0.8 : 2.6)
                    UIColor(red: 0.62, green: 0.55, blue: 0.43,
                            alpha: 0.055 + 0.035 * variation).setFill()
                    UIRectFill(thread.offsetBy(dx: 0.7, dy: 0.7))
                    UIColor.white.withAlphaComponent(0.24 + 0.16 * variation).setFill()
                    UIRectFill(thread)
                }
            }
        }
        return Image(uiImage: tile)
    }()
}

/// Every in-run route shares the same fullscreen capture and inventory host.
/// The Book's physical covers belong to opening/closing, never these pages.
struct RunPageSurface<Content: View>: View {
    var model: GameModel
    var flipper: PageFlipper
    var controls: [StripControl]
    var safeAreaInsets = EdgeInsets()
    var onTapBuff: (Int) -> Void
    @ViewBuilder var content: Content

    var body: some View {
        BookView(flipper: flipper, showsChrome: false) {
            GameplayShell(model: model, controls: controls, onTapBuff: onTapBuff) { content }
                .padding(safeAreaInsets)
        }
    }
}

/// This is shared by the app and layout tests, so tests exercise the live HUD
/// allocation rather than reconstructing the retired book margins.
struct GameplayShell<Content: View>: View {
    @Bindable var model: GameModel
    var controls: [StripControl]
    var onTapBuff: (Int) -> Void
    var inspectionPresenter: MarkerInspectionPresenter? = nil
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 6) {
            GameplayTopBar(coins: model.coins, controls: controls, charge: model.lastCoinCharge,
                           clueModel: model.page == .puzzle ? model : nil)
            BookmarkRow(model: model, isGameplay: true, onTapBuff: onTapBuff)
                .padding(.horizontal, 4)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.top, 2)
        .padding(.bottom, 4)
        .frame(maxWidth: 900)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .foregroundStyle(GameplaySurface.ink)
        .markerInspectionHost(model: model, presenter: inspectionPresenter)
        .handArrangementMenuHost(model: model)
    }
}

struct GameplayTopBar: View {
    var coins: Int
    var controls: [StripControl]
    var charge: GameModel.CoinCharge?
    var coinInk: Color? = nil
    var clueModel: GameModel? = nil

    var body: some View {
        HStack(spacing: 8) {
            CoinBadge(count: coins, onLightSurface: true, ink: coinInk)
                .overlay(alignment: .bottomLeading) {
                    if let charge {
                        CoinChargeReceipt(charge: charge)
                            .id(charge.id)
                            .offset(y: 10)
                    }
                }
            Spacer(minLength: 8)
            if let clueModel {
                ClueResourceButton(model: clueModel)
            }
            ForEach(controls) { control in
                RoundIconButton(control: control)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 5)
        .frame(height: 44)
    }
}

/// Only viewport and text category affect allocation; a new score, boss,
/// selection, clue, or overflowing Hand can never renegotiate the board.
struct GameplayPuzzleLayout {
    let available: CGSize
    var accessibilityText = false

    var compact: Bool { available.height < 620 }
    var scoreHeight: CGFloat { accessibilityText ? 108 : (compact ? 74 : 90) }
    var tileHeight: CGFloat { compact ? 44 : 50 }
    var handHeight: CGFloat { tileHeight + 52 }
    var actionHeight: CGFloat { accessibilityText ? 64 : (compact ? 44 : 50) }
    var turnHeight: CGFloat { 18 }
    var spacing: CGFloat { compact ? 4 : 6 }
    var boardSide: CGFloat {
        let reserved = scoreHeight + handHeight + actionHeight + turnHeight + spacing * 4
        return max(0, min(available.width, available.height - reserved))
    }
}
