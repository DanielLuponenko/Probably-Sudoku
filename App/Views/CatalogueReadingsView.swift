import SwiftUI
import ProbablySudokuEngine

/// Embeddable content; the containing Run Info or PaperSlip owns scrolling.
struct CatalogueReadingsView: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var run: RunState

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(CatalogueReadings(run: run).entries) { reading in
                VStack(alignment: .leading, spacing: 7) {
                    Text(reading.title)
                        .font(Print.subheading(17 * textScale))
                        .foregroundStyle(theme.paper.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(reading.scope)
                        .font(Print.body(14 * textScale))
                        .foregroundStyle(theme.paper.softInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if reading.usesCountGrid {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: min(160, 76 * textScale)), spacing: 8)], spacing: 8) {
                            ForEach(reading.rows) { row in
                                VStack(spacing: 3) {
                                    Text(row.label)
                                        .font(Print.numeral(23 * textScale, weight: .semibold))
                                    Text("\(row.value) in Pool")
                                        .font(Print.body(14 * textScale))
                                        .foregroundStyle(theme.paper.softInk)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(theme.paper.warm, in: RoundedRectangle(cornerRadius: 5))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(theme.paper.ruleInk, lineWidth: 0.7))
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("Number \(row.label), \(row.value) in the Pool")
                            }
                        }
                    } else {
                        ForEach(reading.rows) { row in
                            ViewThatFits(in: .horizontal) {
                                HStack(alignment: .firstTextBaseline, spacing: 15) {
                                    Text(row.label).font(Print.subheading(15 * textScale)).fixedSize()
                                    Spacer(minLength: 0)
                                    Text(row.value).font(Print.body(17 * textScale)).fixedSize()
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(row.label).font(Print.subheading(15 * textScale))
                                    Text(row.value).font(Print.body(17 * textScale))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .foregroundStyle(theme.paper.ink)
                            .padding(.vertical, 3)
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
                .accessibilityIdentifier("catalogue-reading.\(reading.id)")
            }
        }
    }
}

struct CatalogueReadingsSlip: View {
    @Environment(\.cosmeticTheme) private var theme
    @ScaledMetric(relativeTo: .body) private var textScale = 1.0
    var run: RunState
    var onClose: () -> Void

    var body: some View {
        PaperSlip(title: "Your readings", subtitle: nil, maximumWidth: 480, fitsContent: true, onClose: onClose) {
            if CatalogueReadings(run: run).isEmpty {
                Text("No readings are active.")
                    .font(Print.body(16 * textScale))
                    .foregroundStyle(theme.paper.softInk)
            } else {
                CatalogueReadingsView(run: run)
            }
        }
    }
}
