import SwiftUI
import NumberClubEngine

/// The cover. You arrive here on launch, and you come back here whenever a
/// Book ends or is abandoned — §3 makes the Starting Board a choice you make
/// when you open a Book, so one is never dealt silently.
///
/// The background is a photograph of the book shut on the desk. It moves,
/// because a still image behind a menu reads as a screenshot: the camera
/// drifts very slowly and the lamp breathes, which is enough to make the desk
/// feel like a place rather than a picture of one.
struct StartBookView: View {
    var onStart: (StartingBoard) -> Void
    @State private var choice: StartingBoard = .scholar
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            CoverBackground(reduceMotion: reduceMotion)
            TitleBlock()
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, 120)
            controls
        }
        .background(Paper.deskDark)
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private var controls: some View {
        VStack(spacing: 9) {
            Spacer()

            Text("Choose a board")
                .font(Print.caption(10))
                .tracking(2)
                .textCase(.uppercase)
                .foregroundStyle(Paper.page.opacity(0.55))
                .padding(.bottom, 2)

            ForEach(StartingBoard.allCases, id: \.self) { board in
                BoardChoiceRow(board: board, isSelected: choice == board) {
                    withAnimation(.snappy(duration: 0.18)) { choice = board }
                }
            }

            PaperButton(title: "Open the Book", kind: .primary) { onStart(choice) }
                .padding(.top, 6)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 26)
    }
}

/// Set on the book's own cover, the way a title is blocked into cloth.
private struct TitleBlock: View {
    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(LinearGradient(colors: [Paper.coin, Paper.coinRim],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 46, height: 46)
                .overlay {
                    Text("N")
                        .font(Print.heading(22))
                        .foregroundStyle(Paper.ink.opacity(0.85))
                }
                .overlay { Circle().strokeBorder(.white.opacity(0.25), lineWidth: 0.8) }
                .shadow(color: .black.opacity(0.6), radius: 6, y: 3)

            Text(BookEdition.first.title)
                .font(Print.heading(28))
                .tracking(-0.4)
                .foregroundStyle(Paper.page.opacity(0.94))
                .shadow(color: .black.opacity(0.75), radius: 8, y: 2)
                .padding(.horizontal, 24)

            Text(BookEdition.first.blurb)
                .font(Print.body(13))
                .foregroundStyle(Paper.page.opacity(0.5))
                .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
        }
        .multilineTextAlignment(.center)
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
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Paper.ink)
                    .frame(width: 26)

                VStack(alignment: .leading, spacing: 1) {
                    Text(board.name)
                        .font(Print.subheading(14.5))
                        .foregroundStyle(Paper.ink)
                    Text(board.text)
                        .font(Print.body(11.5))
                        .foregroundStyle(Paper.inkSoft)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? Paper.sageDeep : Paper.rule)
            }
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Paper.page.opacity(isSelected ? 1 : 0.93))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(isSelected ? Paper.sageDeep : Paper.pageEdge,
                                  lineWidth: isSelected ? 2 : 1)
            }
            .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
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
