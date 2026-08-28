import SwiftUI

/// A front-door decision written in the same physical language as the Books.
/// The run copies remain untouched until one of the two explicit buttons wins.
struct RunConflictSlip: View {
    var localLabel: String
    var remoteLabel: String
    var onChooseLocal: () -> Void
    var onChooseRemote: () -> Void
    var onCancel: () -> Void

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("TWO UNFINISHED BOOKS")
                            .font(Print.caption(10))
                            .tracking(1.8)
                            .foregroundStyle(Paper.redPencil)

                        Text("Which copy stays open?")
                            .font(.system(size: 24, weight: .semibold, design: .serif))
                            .foregroundStyle(Paper.ink)

                        Text("Both copies are safe until you choose.")
                            .font(.system(size: 13, design: .serif))
                            .foregroundStyle(Paper.inkSoft)
                    }

                    Spacer(minLength: 8)

                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Paper.inkSoft)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(Paper.pageEdge.opacity(0.55)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Decide later")
                }
                .padding(.horizontal, 20)
                .padding(.top, 19)
                .padding(.bottom, 15)

                Rectangle()
                    .fill(Paper.redPencil.opacity(0.48))
                    .frame(height: 1)
                    .padding(.horizontal, 20)

                VStack(spacing: 11) {
                    copyButton(
                        eyebrow: "THIS DEVICE",
                        label: localLabel,
                        symbol: "iphone",
                        action: onChooseLocal
                    )

                    copyButton(
                        eyebrow: "OTHER DEVICE",
                        label: remoteLabel,
                        symbol: "icloud",
                        action: onChooseRemote
                    )

                    Button("DECIDE LATER", action: onCancel)
                        .font(Print.caption(10))
                        .tracking(1.5)
                        .foregroundStyle(Paper.inkSoft)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .buttonStyle(.plain)
                }
                .padding(16)
            }
            .frame(width: min(proxy.size.width - 30, 390))
            .background {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Paper.page)
                    .overlay {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(Paper.pageEdge, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.45), radius: 20, y: 12)
            }
            .overlay(alignment: .leading) {
                Rectangle()
                    .fill(Paper.redPencil)
                    .frame(width: 3)
                    .padding(.vertical, 18)
            }
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .ignoresSafeArea()
    }

    private func copyButton(
        eyebrow: String,
        label: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(Paper.sage)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Paper.sage.opacity(0.65), lineWidth: 1))

                VStack(alignment: .leading, spacing: 4) {
                    Text(eyebrow)
                        .font(Print.caption(9))
                        .tracking(1.4)
                        .foregroundStyle(Paper.redPencil)
                    Text(label)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(Paper.ink)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)
                Image(systemName: "arrow.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Paper.inkSoft)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(RoundedRectangle(cornerRadius: 3).fill(Paper.pageWarm))
            .overlay {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Paper.pageEdge, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(eyebrow.lowercased()), \(label)")
    }
}
