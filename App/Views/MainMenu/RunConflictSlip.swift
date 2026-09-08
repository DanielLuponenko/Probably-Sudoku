import SwiftUI

/// Choosing a saved copy uses the same paper and controls as every other
/// decision. Neither copy is changed until the player presses a choice.
struct RunConflictSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var bodySize: CGFloat = 14
    var localLabel: String
    var remoteLabel: String
    var onChooseLocal: () -> Void
    var onChooseRemote: () -> Void
    var onCancel: () -> Void

    var body: some View {
        PaperSlip(title: "Which copy stays open?",
                  subtitle: "Two unfinished Books were found. Both stay safe until you choose.",
                  closeLabel: "Decide later",
                  dismissesOnBackground: false,
                  dimsBackground: false,
                  maximumWidth: 390,
                  onClose: onCancel) {
            VStack(alignment: .leading, spacing: 12) {
                Text(localLabel)
                    .font(Print.body(bodySize))
                    .foregroundStyle(theme.paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                PaperButton(title: "Use this device's copy", kind: .quiet, action: onChooseLocal)

                Rectangle().fill(theme.paper.ruleInk).frame(height: 1)

                Text(remoteLabel)
                    .font(Print.body(bodySize))
                    .foregroundStyle(theme.paper.ink)
                    .fixedSize(horizontal: false, vertical: true)
                PaperButton(title: "Use the other device's copy", kind: .quiet, action: onChooseRemote)
            }
        }
    }
}
