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
            CoverPhotograph(still: reduceMotion)
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

/// The photograph, drifting. The motion is slow enough that it is never the
/// thing you are looking at — about a percent of the frame over half a minute.
private struct CoverPhotograph: View {
    var still: Bool
    @State private var drifted = false
    @State private var lamped = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Image("Cover")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .scaleEffect(drifted ? 1.075 : 1.02, anchor: .center)
                    .offset(x: drifted ? 7 : -7, y: drifted ? -10 : 8)
                    .clipped()

                // The lamp, up and to the left, the same one the desk and the
                // page turn are lit by.
                RadialGradient(
                    colors: [Color(hex: 0xFFD9A0).opacity(lamped ? 0.20 : 0.11), .clear],
                    center: .init(x: 0.12, y: 0.06),
                    startRadius: 10,
                    endRadius: proxy.size.height * 0.85
                )
                .blendMode(.plusLighter)

                // Keeps the type legible over whatever the photograph is doing.
                LinearGradient(
                    stops: [
                        .init(color: .black.opacity(0.55), location: 0),
                        .init(color: .black.opacity(0.12), location: 0.32),
                        .init(color: .black.opacity(0.30), location: 0.62),
                        .init(color: .black.opacity(0.88), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )
            }
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
        .onAppear {
            guard !still else { return }
            withAnimation(.easeInOut(duration: 34).repeatForever(autoreverses: true)) {
                drifted = true
            }
            // Off the drift's rhythm, so the two never pulse together.
            withAnimation(.easeInOut(duration: 11).repeatForever(autoreverses: true)) {
                lamped = true
            }
        }
        .accessibilityHidden(true)
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

            Text("The Number Club")
                .font(Print.heading(30))
                .tracking(-0.4)
                .foregroundStyle(Paper.page.opacity(0.94))
                .shadow(color: .black.opacity(0.75), radius: 8, y: 2)

            Text("27 puzzles. One book.")
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
