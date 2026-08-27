import SwiftUI
import ProbablySudokuEngine

/// The nineteen Boss boards share one printer's language: subdued underprint,
/// one specific piece of broken or overworked furniture, and a small stamp in
/// the header. None of these views knows a rule or changes a square's hit
/// target; it only turns existing Boss state into paper.
struct BossBoardDesign {
    let boss: BossModifier

    var symbol: String {
        switch boss {
        case .censor: return "rectangle.and.text.magnifyingglass"
        case .editor: return "pencil.line"
        case .deadline: return "clock"
        case .fog: return "cloud.fog"
        case .critic: return "pencil.tip.crop.circle"
        case .mirror: return "rectangle.on.rectangle"
        case .paywall: return "lock.rectangle"
        case .erratum: return "text.badge.xmark"
        case .collector: return "tray.full"
        case .heavyLifter: return "dumbbell"
        case .unluckyLucky: return "bookmark.slash"
        case .buffborger: return "bandage"
        case .sashimi: return "scissors"
        case .overPusher: return "drop.fill"
        case .accountant: return "list.bullet.rectangle"
        case .tikTak: return "timer"
        case .handyDandy: return "hand.raised.slash"
        case .grayTheGarry: return "rectangle.split.3x1"
        case .garryTheGray: return "square.grid.3x3"
        }
    }

    var ink: Color {
        switch boss {
        case .critic, .censor, .erratum, .handyDandy: return Paper.redPencil
        case .fog, .grayTheGarry, .garryTheGray: return Paper.inkFaint
        case .paywall, .collector, .accountant: return Paper.inkSoft
        default: return Paper.sageDeep
        }
    }

    var angle: Double {
        switch boss {
        case .critic, .erratum: return -2.2
        case .collector, .accountant: return 1.4
        default: return -1.0
        }
    }
}

/// Printed below the grid contents. Variants use inexpensive paths and simple
/// transforms, so the same layer remains safe when several squares are fouled.
struct BossBoardUnderprint: View {
    var boss: BossModifier?
    var fouled: Set<Square>
    var greyed: Set<Square>

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                if let boss {
                    paper(for: boss, side: side, cell: cell)
                }
                ForEach(fouled.sorted(by: { $0.index < $1.index }), id: \.index) { square in
                    InkBlot()
                        .frame(width: cell * 0.78, height: cell * 0.60)
                        .position(x: (CGFloat(square.col) + 0.5) * cell,
                                  y: (CGFloat(square.row) + 0.5) * cell)
                }
                ForEach(greyed.sorted(by: { $0.index < $1.index }), id: \.index) { square in
                    Rectangle()
                        .fill(Paper.ink.opacity(0.07))
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(square.col) * cell, y: CGFloat(square.row) * cell)
                }
            }
            .frame(width: side, height: side)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func paper(for boss: BossModifier, side: CGFloat, cell: CGFloat) -> some View {
        switch boss {
        case .censor:
            ZStack(alignment: .topLeading) {
                Rectangle().fill(.black.opacity(0.035))
                ForEach(0..<4, id: \.self) { index in
                    Rectangle().fill(.black.opacity(0.22))
                        .frame(width: side * (index.isMultiple(of: 2) ? 0.19 : 0.12), height: 5)
                        .offset(x: side * (0.05 + Double(index) * 0.21), y: side * 0.04)
                }
            }
        case .editor:
            Canvas { context, size in
                let blue = GraphicsContext.Shading.color(Paper.editorBlue.opacity(0.28))
                for offset in stride(from: size.height * 0.12, through: size.height * 0.92, by: size.height * 0.16) {
                    var line = Path()
                    line.move(to: .init(x: size.width * 0.06, y: offset))
                    line.addLine(to: .init(x: size.width * 0.94, y: offset - size.height * 0.035))
                    context.stroke(line, with: blue, lineWidth: 1)
                }
            }
        case .deadline:
            CornerClock().frame(width: cell * 2.15, height: cell * 2.15)
                .offset(x: side - cell * 2.25, y: cell * 0.1)
        case .fog:
            FogStrata().opacity(0.24)
        case .critic:
            RedPencilMarks(side: side)
        case .mirror:
            Text("MIRROR")
                .font(Print.heading(side * 0.19))
                .foregroundStyle(Paper.ink.opacity(0.045))
                .rotationEffect(.degrees(180))
                .frame(width: side, height: side)
        case .paywall:
            Rectangle().fill(Paper.ink.opacity(0.07)).frame(height: cell * 0.86)
                .overlay { Text("SUBSCRIBERS' EDITION").font(Print.caption(10)).tracking(2).foregroundStyle(Paper.ink.opacity(0.28)) }
                .offset(y: side * 0.46)
        case .erratum:
            Text("CORRECTION")
                .font(Print.caption(cell * 0.33)).tracking(1.6)
                .foregroundStyle(Paper.redPencil.opacity(0.38))
                .padding(.horizontal, cell * 0.28).padding(.vertical, cell * 0.1)
                .background(Rectangle().fill(Paper.page.opacity(0.82)))
                .rotationEffect(.degrees(-7))
                .offset(x: side * 0.51, y: side * 0.78)
        case .collector:
            ReceiptLines(side: side, ink: Paper.inkSoft.opacity(0.16))
        case .heavyLifter:
            Rectangle().strokeBorder(Paper.ink.opacity(0.12), lineWidth: cell * 0.18)
                .padding(cell * 0.24)
        case .unluckyLucky:
            BookmarkGhosts(side: side)
        case .buffborger:
            TapeStripes(side: side)
        case .sashimi:
            DiagonalCut(side: side)
        case .overPusher:
            Rectangle().fill(Paper.ink.opacity(0.025))
        case .accountant:
            ReceiptLines(side: side, ink: Paper.redPencil.opacity(0.16))
        case .tikTak:
            CornerClock().frame(width: cell * 3.1, height: cell * 3.1)
                .offset(x: cell * 0.12, y: cell * 0.12)
        case .handyDandy:
            HandCross(side: side)
        case .grayTheGarry:
            Rectangle().fill(Paper.ink.opacity(0.035)).frame(height: cell * 1.05).offset(y: side * 0.48)
        case .garryTheGray:
            Rectangle().fill(Paper.ink.opacity(0.035)).frame(width: cell * 3.05, height: cell * 3.05).offset(x: cell * 2.98, y: cell * 2.98)
        }
    }
}

private struct InkBlot: View {
    var body: some View {
        ZStack {
            Circle().fill(Paper.ink.opacity(0.13)).scaleEffect(x: 1.15, y: 0.78)
            Circle().fill(Paper.ink.opacity(0.08)).scaleEffect(x: 0.62, y: 1.13).rotationEffect(.degrees(28))
        }
        .rotationEffect(.degrees(-14))
    }
}

private struct CornerClock: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Paper.redPencil.opacity(0.26), lineWidth: 2)
            Rectangle().fill(Paper.redPencil.opacity(0.28)).frame(width: 1.5, height: 28).offset(y: -10)
            Rectangle().fill(Paper.redPencil.opacity(0.28)).frame(width: 20, height: 1.5).rotationEffect(.degrees(35)).offset(x: 8, y: 5)
        }
    }
}

private struct FogStrata: View {
    var body: some View {
        VStack(spacing: 18) {
            ForEach(0..<5, id: \.self) { index in
                Capsule().fill(Paper.ink.opacity(0.055 + Double(index) * 0.008))
                    .frame(height: 22).offset(x: index.isMultiple(of: 2) ? -30 : 34)
            }
        }
        .rotationEffect(.degrees(-8))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RedPencilMarks: View {
    var side: CGFloat
    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<6, id: \.self) { index in
                Rectangle().fill(Paper.redPencil.opacity(0.22)).frame(width: side * 0.12, height: 1.5)
                    .rotationEffect(.degrees(index.isMultiple(of: 2) ? -12 : 9))
                    .offset(x: side * (0.06 + Double(index % 3) * 0.30), y: side * (0.10 + Double(index / 3) * 0.70))
            }
        }
    }
}

private struct ReceiptLines: View {
    var side: CGFloat
    var ink: Color
    var body: some View {
        VStack(alignment: .trailing, spacing: side * 0.045) {
            ForEach(0..<8, id: \.self) { line in
                Rectangle().fill(ink).frame(width: side * (line.isMultiple(of: 3) ? 0.42 : 0.27), height: 1)
            }
        }
        .frame(width: side, height: side, alignment: .bottomTrailing)
        .padding(side * 0.09)
    }
}

private struct BookmarkGhosts: View {
    var side: CGFloat
    var body: some View {
        HStack(spacing: side * 0.055) {
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2).fill(Paper.redPencil.opacity(index == 2 ? 0.2 : 0.07))
                    .frame(width: side * 0.06, height: side * 0.25)
                    .offset(y: index == 2 ? side * 0.04 : 0)
            }
        }
        .frame(width: side, height: side, alignment: .topTrailing)
        .padding(side * 0.08)
    }
}

private struct TapeStripes: View {
    var side: CGFloat
    var body: some View {
        VStack(spacing: side * 0.07) {
            ForEach(0..<3, id: \.self) { _ in
                Rectangle().fill(Paper.pageEdge.opacity(0.19)).frame(width: side * 0.76, height: side * 0.055)
                    .overlay { Rectangle().strokeBorder(Paper.ink.opacity(0.1), lineWidth: 1) }
            }
        }
        .frame(width: side, height: side, alignment: .top)
        .padding(.top, side * 0.12)
    }
}

private struct DiagonalCut: View {
    var side: CGFloat
    var body: some View {
        Rectangle().fill(Paper.redPencil.opacity(0.12)).frame(width: side * 1.45, height: 2)
            .rotationEffect(.degrees(-18)).offset(x: -side * 0.2, y: side * 0.47)
    }
}

private struct HandCross: View {
    var side: CGFloat
    var body: some View {
        ZStack {
            Rectangle().fill(Paper.redPencil.opacity(0.13)).frame(width: side * 0.58, height: 2).rotationEffect(.degrees(21))
            Rectangle().fill(Paper.redPencil.opacity(0.13)).frame(width: side * 0.58, height: 2).rotationEffect(.degrees(-21))
        }
        .frame(width: side, height: side)
    }
}
