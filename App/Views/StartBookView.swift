import SwiftUI
import NumberClubEngine

/// §3 — the Starting Board is chosen once, at the start of a Book. It is the
/// cover of the book you are about to open, so it gets the cover's treatment
/// rather than a settings list.
struct StartBookView: View {
    var onStart: (StartingBoard) -> Void
    @State private var choice: StartingBoard = .scholar

    var body: some View {
        DeskView {
            VStack(spacing: 0) {
                Spacer(minLength: 20)

                cover

                Spacer(minLength: 16)

                VStack(spacing: 9) {
                    Text("Choose a board")
                        .font(Print.caption(11)).tracking(1.8).textCase(.uppercase)
                        .foregroundStyle(Paper.page.opacity(0.6))

                    ForEach(StartingBoard.allCases, id: \.self) { board in
                        BoardChoiceRow(board: board, isSelected: choice == board) {
                            choice = board
                        }
                    }
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 16)

                PaperButton(title: "Open the Book", kind: .primary) { onStart(choice) }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var cover: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(LinearGradient(colors: [Paper.coverBoard, Color(hex: 0x1D1A18)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { RoundedRectangle(cornerRadius: 6).strokeBorder(Paper.coin.opacity(0.35), lineWidth: 1) }

            VStack(spacing: 10) {
                Circle()
                    .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 54, height: 54)
                    .overlay {
                        Text("N").font(Print.heading(26)).foregroundStyle(Paper.ink.opacity(0.85))
                    }
                Text("The Number Club")
                    .font(Print.heading(26))
                    .tracking(-0.5)
                    .foregroundStyle(Paper.page)
                    .multilineTextAlignment(.center)
                Text("27 puzzles. One book.")
                    .font(Print.body(13))
                    .foregroundStyle(Paper.page.opacity(0.55))
            }
            .padding(24)
        }
        .frame(maxWidth: 300)
        .frame(height: 260)
        .shadow(color: .black.opacity(0.6), radius: 26, y: 14)
    }
}

private struct BoardChoiceRow: View {
    var board: StartingBoard
    var isSelected: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(Paper.ink)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(board.name)
                        .font(Print.subheading(15))
                        .foregroundStyle(Paper.ink)
                    Text(board.text)
                        .font(Print.body(12))
                        .foregroundStyle(Paper.inkSoft)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 19))
                    .foregroundStyle(isSelected ? Paper.sageDeep : Paper.rule)
            }
            .padding(13)
            .background { RoundedRectangle(cornerRadius: 6).fill(Paper.page) }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Paper.sageDeep : Paper.pageEdge,
                                  lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(PressedPaperStyle())
        .accessibilityLabel("\(board.name). \(board.text)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var symbol: String {
        switch board {
        case .scholar: return "graduationcap"
        case .merchant: return "bag"
        case .oracle: return "eye"
        }
    }
}
