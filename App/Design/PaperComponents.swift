import SwiftUI

/// Labels and slips use the same stock as the Book. Their size communicates
/// their job; a new border, badge or material does not invent another UI style.
enum PaperSurfaceKind: Equatable {
    case label, slip
}

extension View {
    func paperSurface(kind: PaperSurfaceKind) -> some View {
        modifier(PrintedPaperSurface(kind: kind))
    }
}

private struct PrintedPaperSurface: ViewModifier {
    @Environment(\.cosmeticTheme) private var theme
    let kind: PaperSurfaceKind

    func body(content: Content) -> some View {
        content.background {
            RoundedRectangle(cornerRadius: 4)
                .fill(theme.paper.page)
                .overlay {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(theme.paper.edge, lineWidth: 1)
                }
                .shadow(color: .black.opacity(kind == .label ? 0.18 : 0.25),
                        radius: kind == .label ? 2 : 6,
                        y: kind == .label ? 2 : 4)
        }
    }
}

/// The same little printed illustration on a benefit, Buff, or Shop detail.
/// No independent shadow or ongoing animation: the containing paper owns it.
struct PrintedItemIllustration<Content: View>: View {
    @Environment(\.cosmeticTheme) private var theme
    var size: CGFloat = 40
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(5)
            .frame(width: size, height: size)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.paper.warm)
                    .overlay {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(theme.paper.ruleInk.opacity(0.5), lineWidth: 0.75)
                    }
            }
            .accessibilityHidden(true)
    }
}
