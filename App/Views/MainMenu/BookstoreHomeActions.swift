import SwiftUI

/// Two local choices at the front door. The saved Book is primary; browsing
/// never abandons it. A different Book still needs the explicit decision slip.
struct BookstoreHomeActions: View {
    // This compact control uses smaller copy than the painted bookstore signs.
    // Its opaque stock keeps ivory text legible regardless of the scene behind it.
    static let primaryFill = Color(hex: 0x4B5E50)
    @Environment(\.dynamicTypeSize) private var dynamicType
    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .body) private var detailSize: CGFloat = 12
    let saved: SavedBookSummary?
    let onContinue: () -> Void
    let onPlay: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if let saved {
                Button(action: onContinue) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(saved.actionTitle)
                                .font(Print.subheading(titleSize))
                            Text(saved.compactLocation).font(Print.body(detailSize))
                                .foregroundStyle(BookstoreInk.paper.opacity(0.88))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                            .accessibilityHidden(true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Self.primaryFill)
                    .overlay(Rectangle().stroke(BookstoreInk.brass.opacity(0.85), lineWidth: 1))
                }
                .accessibilityIdentifier("bookstore.continue")
                .accessibilityElement(children: .ignore)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(saved.actionTitle)
                .accessibilityValue(saved.decisionLabel)
                .accessibilityHint(saved.isCompleted ? "View the completed Book's final page"
                    : "Resume the saved puzzle, score and items")
            }
            Button(action: onPlay) {
                if saved != nil {
                    Text("Choose another Book")
                        .font(Print.body(detailSize + 1))
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(Color.black.opacity(0.58))
                        .overlay(Rectangle().stroke(BookstoreInk.brass.opacity(0.5), lineWidth: 1))
                } else {
                    VStack(spacing: 4) {
                        Label("PLAY", systemImage: "play.fill")
                            .font(Print.subheading(titleSize)).tracking(1.2)
                        Text("Choose a Book")
                            .font(Print.body(detailSize))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(Self.primaryFill)
                    .overlay(Rectangle().stroke(BookstoreInk.brass.opacity(0.85), lineWidth: 1))
                }
            }
            .accessibilityIdentifier("bookstore.play")
            .accessibilityHint("Browse Books. Your current attempt stays saved until you choose to abandon it.")
        }
        .foregroundStyle(BookstoreInk.paper)
        .buttonStyle(BookstorePressedStyle())
        .shadow(color: .black.opacity(0.55), radius: 12, y: 6)
        .frame(maxWidth: dynamicType.isAccessibilitySize ? .infinity : saved == nil ? 340 : 300)
    }
}
