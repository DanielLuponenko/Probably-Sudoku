import SwiftUI

/// Only the engine's saved suppressed interest is struck. The base reward,
/// unused Turns and all earned item coins remain unchanged in this receipt.
struct CollectorPayoutPrint: View {
    @Environment(\.gameReduceMotion) private var reduceMotion
    let details: String
    let suppressed: Int
    var eventKey: String?
    var consume: ((String) -> Bool)? = nil
    @State private var crossed = true

    var body: some View {
        (Text(details + (details.isEmpty ? "" : " · ") + "Interest ")
         + Text("+\(suppressed)").strikethrough(crossed, color: Paper.redPencil)
         + Text(" → 0").foregroundColor(Paper.redPencil))
            .accessibilityLabel(details + ". The Collector cancels \(suppressed) coins of interest.")
            .task(id: eventKey) {
                guard let eventKey, consume?(eventKey) == true, !reduceMotion else { return }
                crossed = false
                await Task.yield()
                guard !Task.isCancelled else { crossed = true; return }
                withAnimation(.easeOut(duration: 0.2)) { crossed = true }
            }
    }
}
