import SwiftUI

/// A fixed little puzzle in the shop. It is deliberately not a running game:
/// the player can compare two skins at the identical point in play without
/// spending a Stamp, changing the live Book, or waiting for a deal.
struct CosmeticInPlayPreview: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let item: CosmeticItem
    let theme: CosmeticTheme
    let owned: Bool
    let equipped: Bool
    let stamps: Int
    var onClose: () -> Void
    var onPurchase: () -> Void

    @State private var placementShown = false

    private var canPurchase: Bool { !owned && stamps >= item.price }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("IN PLAY PREVIEW")
                        .font(Print.caption(10))
                        .tracking(1.4)
                        .foregroundStyle(Paper.inkFaint)
                    Text(item.name)
                        .font(Print.subheading(20))
                        .foregroundStyle(Paper.ink)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Label("Back", systemImage: "xmark")
                        .font(Print.caption(11))
                        .foregroundStyle(Paper.ink)
                        .padding(.horizontal, 10)
                        .frame(height: 34)
                        .overlay {
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Paper.rule, lineWidth: 1)
                        }
                }
                .buttonStyle(PressedPaperStyle())
                .accessibilityLabel("Back to Club Shop")
            }
            .padding(15)

            Divider().overlay(Paper.rule)

            VStack(spacing: 11) {
                PreviewPuzzleBoard(theme: theme, placementShown: placementShown)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Sample puzzle in progress. Row four has just cleared.")

                PreviewHand(theme: theme)
                    .accessibilityHidden(true)

                HStack(spacing: 8) {
                    if !owned {
                        Text("NOT OWNED")
                            .font(Print.caption(9))
                            .tracking(1.1)
                            .foregroundStyle(Paper.redPencil)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(Paper.pageWarm, in: RoundedRectangle(cornerRadius: 3))
                    } else if equipped {
                        Text("EQUIPPED")
                            .font(Print.caption(9))
                            .tracking(1.1)
                            .foregroundStyle(Paper.sageDeep)
                    } else {
                        Text("OWNED")
                            .font(Print.caption(9))
                            .tracking(1.1)
                            .foregroundStyle(Paper.sageDeep)
                    }

                    Spacer(minLength: 0)
                    Text("\(stamps) \(ClubCurrency.name)")
                        .font(Print.caption(10))
                        .foregroundStyle(Paper.inkFaint)
                }

                purchaseButton
            }
            .padding(15)
        }
        .frame(maxWidth: 460)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.paper.page)
                .overlay { PaperGrain(opacity: theme.paper.grain, seed: 17) }
                .overlay { PaperStockOverlay(treatment: theme.paper.treatment) }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.board.bold.opacity(0.75), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.42), radius: 18, y: 8)
        .accessibilityAddTraits(.isModal)
        .task {
            guard !reduceMotion else {
                placementShown = true
                return
            }
            try? await Task.sleep(for: .milliseconds(220))
            withAnimation(theme.numbers.motion.arrivalAnimation) { placementShown = true }
        }
    }

    @ViewBuilder
    private var purchaseButton: some View {
        if equipped {
            Text("Already equipped")
                .font(Print.caption(11))
                .foregroundStyle(Paper.inkFaint)
                .frame(maxWidth: .infinity, minHeight: 42)
                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.rule, lineWidth: 1) }
        } else if owned {
            Button("Equip this") { onPurchase() }
                .font(Print.caption(12))
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Paper.page)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Paper.sageDeep, in: RoundedRectangle(cornerRadius: 4))
                .buttonStyle(PressedPaperStyle())
        } else if canPurchase {
            Button("Buy for \(item.price) \(ClubCurrency.name)") { onPurchase() }
                .font(Print.caption(12))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Paper.page)
                .frame(maxWidth: .infinity, minHeight: 42)
                .background(Paper.sageDeep, in: RoundedRectangle(cornerRadius: 4))
                .buttonStyle(PressedPaperStyle())
        } else {
            Text("Need \(item.price - stamps) more \(ClubCurrency.name)")
                .font(Print.caption(11))
                .foregroundStyle(Paper.redPencil)
                .frame(maxWidth: .infinity, minHeight: 42)
                .overlay { RoundedRectangle(cornerRadius: 4).strokeBorder(Paper.redPencil.opacity(0.45), lineWidth: 1) }
        }
    }
}

private struct PreviewPuzzleBoard: View {
    let theme: CosmeticTheme
    let placementShown: Bool

    // This is a constant sample: every skin is judged against the exact same
    // givens, placed numbers, marker and completed row.
    private let givens: [Int: Int] = [0: 5, 1: 3, 4: 7, 9: 6, 12: 1, 13: 9,
                                      19: 9, 20: 8, 25: 6, 27: 8, 31: 6,
                                      36: 4, 40: 8, 44: 1, 54: 9, 60: 2,
                                      66: 4, 76: 8, 80: 9]
    private let placed: [Int: Int] = [28: 2, 29: 7, 30: 9, 32: 3, 33: 4,
                                      34: 5, 35: 6, 41: 5, 42: 9, 43: 2]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                Rectangle().fill(theme.paper.warm)
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { row in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                sampleCell(index: row * 9 + col)
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                .frame(width: side, height: side)

                Rectangle()
                    .fill(Paper.markerColor(theme.marker.id).opacity(0.28))
                    .frame(width: cell, height: cell)
                    .offset(x: cell * 5, y: cell * 4)

                rules(side: side, cell: cell)

                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Paper.sageDeep.opacity(0.9), lineWidth: 2)
                    .frame(width: side, height: cell)
                    .offset(y: cell * 3)
                    .opacity(placementShown ? 1 : 0)

                Text("LINE CLEAR +45")
                    .font(Print.caption(max(8, cell * 0.28)))
                    .tracking(0.7)
                    .foregroundStyle(Paper.page)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Paper.sageDeep, in: RoundedRectangle(cornerRadius: 3))
                    .offset(x: cell * 4.1, y: cell * 2.55)
                    .opacity(placementShown ? 1 : 0)
            }
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 5))
        }
        .aspectRatio(1, contentMode: .fit)
        .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(theme.board.bold, lineWidth: 1.5) }
    }

    @ViewBuilder
    private func sampleCell(index: Int) -> some View {
        if let digit = givens[index] {
            Text("\(digit)")
                .font(theme.numbers.font(16, weight: .bold))
                .foregroundStyle(theme.numbers.givenInk)
        } else if let digit = placed[index] {
            Text("\(digit)")
                .font(theme.numbers.font(16, weight: .medium))
                .foregroundStyle(theme.numbers.ink)
                .scaleEffect(index == 35 && !placementShown ? theme.numbers.motion.arrivalScale : 1)
                .opacity(index == 35 && !placementShown ? 0 : 1)
        } else {
            Color.clear
        }
    }

    private func rules(side: CGFloat, cell: CGFloat) -> some View {
        Canvas { context, _ in
            for step in 1..<9 {
                let position = CGFloat(step) * cell
                var vertical = Path()
                vertical.move(to: .init(x: position, y: 0))
                vertical.addLine(to: .init(x: position, y: side))
                var horizontal = Path()
                horizontal.move(to: .init(x: 0, y: position))
                horizontal.addLine(to: .init(x: side, y: position))
                let bold = step.isMultiple(of: 3)
                context.stroke(vertical, with: .color(bold ? theme.board.bold : theme.board.hair),
                               lineWidth: bold ? theme.board.boldWidth : theme.board.hairWidth)
                context.stroke(horizontal, with: .color(bold ? theme.board.bold : theme.board.hair),
                               lineWidth: bold ? theme.board.boldWidth : theme.board.hairWidth)
            }
        }
    }
}

private struct PreviewHand: View {
    let theme: CosmeticTheme

    var body: some View {
        HStack(spacing: 7) {
            Text("NUMBERS DRAWN")
                .font(Print.caption(9))
                .tracking(0.8)
                .foregroundStyle(Paper.inkFaint)
            Spacer(minLength: 0)
            ForEach([3, 6, 9], id: \.self) { digit in
                Text("\(digit)")
                    .font(theme.numbers.font(18, weight: .medium))
                    .foregroundStyle(theme.numbers.ink)
                    .frame(width: 35, height: 32)
                    .background(theme.paper.warm, in: RoundedRectangle(cornerRadius: 3))
                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(theme.board.hair, lineWidth: 1) }
            }
        }
    }
}
