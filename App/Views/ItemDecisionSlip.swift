import SwiftUI
import ProbablySudokuEngine

/// Saved engine choices rendered as the game's own paper controls. Selection
/// remains presentation-only until Confirm; the engine validates the exact ID.
struct ItemDecisionSlip: View {
    @Bindable var model: GameModel
    let decision: ItemDecision
    @State private var selected: [String] = []
    @State private var error: String?
    @ScaledMetric(relativeTo: .body) private var copySize: CGFloat = 16

    private var squareChoices: Bool {
        !decision.options.isEmpty && decision.options.allSatisfy { $0.square != nil }
    }
    private var numberChoices: Bool {
        !decision.options.isEmpty && decision.options.allSatisfy { $0.digit != nil }
    }

    private var hidesMarkerSource: Bool {
        model.markersAreHidden && decision.kind.hasPrefix("marker.")
    }

    var presentedTitle: String { hidesMarkerSource ? "Choose" : decision.title }

    var instruction: String? {
        // Fog conceals the source square and its Marker, including after a
        // pending choice is restored. The options still explain the action.
        guard !hidesMarkerSource else { return nil }
        switch decision.sourceID {
        case Buffs.rebind:
            return decision.kind == "buff.commit" ? "Choose its new square." : "Choose the Marker to move."
        case Buffs.transposition:
            return decision.kind == "buff.commit" ? "Choose the second Marker." : "Choose the first Marker to swap."
        case Buffs.fairExchange:
            return decision.kind == "buff.commit" ? "Choose the number to take." : "Choose the card to return."
        default:
            return decision.detail.isEmpty ? nil : decision.detail
        }
    }

    var body: some View {
        PaperSlip(title: presentedTitle, subtitle: instruction,
                  closeLabel: decision.kind == "marker.pledge" ? "Place without bonus" : "Cancel",
                  showsCloseButton: decision.allowsCancel,
                  dismissesOnBackground: false, maximumWidth: 460, maximumHeight: 710,
                  footer: AnyView(PaperButton(title: decision.consumedOnReveal ? "Continue" : "Confirm",
                                             kind: .primary, isEnabled: decision.accepts(selected)) {
                      if !model.resolveItemDecision(id: decision.id, selected: selected) { error = model.message }
                  }.accessibilityIdentifier("item-choice.confirm")),
                  onClose: { _ = model.resolveItemDecision(id: decision.id, selected: nil) }) {
            VStack(alignment: .leading, spacing: 12) {
                if decision.maximum > 1 {
                    Text(decision.ordered ? "Tap in the order you want" : "Choose \(decision.minimum == decision.maximum ? "\(decision.maximum)" : "\(decision.minimum)–\(decision.maximum)")")
                        .font(Print.body(copySize)).foregroundStyle(Paper.inkSoft)
                }
                if decision.sourceID == Buffs.detour {
                    layoutChoices
                } else if decision.sourceID == Buffs.rainCheck {
                    amountChoice
                } else if squareChoices {
                    squareBoard
                } else if numberChoices {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 8)], spacing: 8) {
                        ForEach(decision.options) { option in choice(option) }
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(decision.options) { option in choice(option) }
                    }
                }
                if let error { Text(error).font(Print.body(copySize)).foregroundStyle(Paper.redPencil) }
            }
        }
        .accessibilityIdentifier("item-choice.slip")
    }

    private func choose(_ option: ItemChoiceOption) {
        if let index = selected.firstIndex(of: option.id) { selected.remove(at: index) }
        else if decision.maximum == 1 { selected = [option.id] }
        else if selected.count < decision.maximum { selected.append(option.id) }
        error = nil
    }

    private func choice(_ option: ItemChoiceOption) -> some View {
        Button { choose(option) } label: {
            HStack(spacing: 10) {
                if let id = option.itemID { ItemArtwork(id: id, size: 38) }
                if let digit = option.digit {
                    Text("\(digit.rawValue)").font(Print.numeral(26, weight: .semibold))
                } else {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(option.title).font(Print.subheading(copySize))
                        if !option.detail.isEmpty { Text(option.detail).font(Print.body(copySize - 1)).foregroundStyle(Paper.inkSoft) }
                    }
                }
                if !numberChoices { Spacer(minLength: 0) }
                if let index = selected.firstIndex(of: option.id) {
                    if decision.ordered { Text("\(index + 1)").font(Print.subheading(copySize)) }
                    else { Image(systemName: "checkmark").font(.body.weight(.semibold)) }
                }
            }
            .foregroundStyle(Paper.ink)
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(selected.contains(option.id) ? GameplaySurface.sage.opacity(0.15) : Paper.pageWarm,
                        in: .rect(cornerRadius: 5))
            .overlay { RoundedRectangle(cornerRadius: 5).strokeBorder(selected.contains(option.id) ? GameplaySurface.sage : Paper.rule, lineWidth: selected.contains(option.id) ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title + (option.detail.isEmpty ? "" : ". " + option.detail))
        .accessibilityAddTraits(selected.contains(option.id) ? .isSelected : [])
        .accessibilityIdentifier("item-choice.option.\(option.id)")
    }

    private var amountChoice: some View {
        VStack(spacing: 14) {
            let index = decision.options.firstIndex(where: { selected.contains($0.id) }) ?? 0
            let option = decision.options[index]
            Text(option.title).font(Print.subheading(20)).multilineTextAlignment(.center)
            HStack(spacing: 22) {
                Button { selected = [decision.options[max(0, index - 1)].id] } label: {
                    Image(systemName: "minus").frame(width: 52, height: 48)
                }.disabled(index == 0)
                Text(option.id.replacingOccurrences(of: "amount.", with: ""))
                    .font(Print.numeral(32, weight: .semibold)).frame(minWidth: 70)
                Button { selected = [decision.options[min(decision.options.count - 1, index + 1)].id] } label: {
                    Image(systemName: "plus").frame(width: 52, height: 48)
                }.disabled(index == decision.options.count - 1)
            }
            .buttonStyle(.plain).foregroundStyle(GameplaySurface.sage)
            HStack {
                PaperButton(title: "Minimum", kind: .quiet) { selected = [decision.options[0].id] }
                PaperButton(title: "Maximum", kind: .quiet) { selected = [decision.options[decision.options.count - 1].id] }
            }
        }.onAppear { if selected.isEmpty, let first = decision.options.first { selected = [first.id] } }
    }

    private var squareBoard: some View {
        GeometryReader { proxy in
            let side = proxy.size.width / 9
            let targets = Dictionary(uniqueKeysWithValues: decision.options.compactMap { option in option.square.map { ($0, option) } })
            VStack(spacing: 0) {
                ForEach(0..<9, id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<9, id: \.self) { col in
                            let square = Square(row: row, col: col)
                            let option = targets[square]
                            Button { if let option { choose(option) } } label: {
                                ZStack {
                                    Rectangle().fill(option.map { selected.contains($0.id) } == true ? GameplaySurface.sage.opacity(0.27) : Paper.page)
                                    if let digit = model.visibleDigit(at: square) {
                                        Text("\(digit.rawValue)").font(Print.numeral(side * 0.53, weight: .medium))
                                    } else if option != nil {
                                        Circle().fill(GameplaySurface.sage.opacity(0.45)).frame(width: 5, height: 5)
                                    }
                                }
                                .frame(width: side, height: side)
                                .overlay { Rectangle().strokeBorder(option.map { selected.contains($0.id) } == true ? Paper.ink : Paper.rule, lineWidth: 0.5) }
                            }
                            .buttonStyle(.plain).disabled(option == nil)
                            .accessibilityLabel(option?.title ?? square.description)
                            .accessibilityAddTraits(option.map { selected.contains($0.id) } == true ? .isSelected : [])
                        }
                    }
                }
            }
            .foregroundStyle(Paper.ink)
            .overlay {
                Path { path in
                    for third in 1...2 {
                        let p = proxy.size.width * CGFloat(third) / 3
                        path.move(to: CGPoint(x: p, y: 0)); path.addLine(to: CGPoint(x: p, y: proxy.size.width))
                        path.move(to: CGPoint(x: 0, y: p)); path.addLine(to: CGPoint(x: proxy.size.width, y: p))
                    }
                }.stroke(GameplaySurface.sage, lineWidth: 2).allowsHitTesting(false)
            }
            .overlay { Rectangle().strokeBorder(GameplaySurface.sage, lineWidth: 2).allowsHitTesting(false) }
        }.aspectRatio(1, contentMode: .fit)
    }

    private var layoutChoices: some View {
        let layouts = BuffRoutes.previewLayouts(run: model.run)
        return HStack(alignment: .top, spacing: 12) {
            ForEach(Array(decision.options.enumerated()), id: \.element.id) { index, option in
                VStack(spacing: 7) {
                    if layouts.indices.contains(index) {
                        GeometryReader { proxy in
                            let side = proxy.size.width / 9
                            VStack(spacing: 0) {
                                ForEach(0..<9, id: \.self) { row in
                                    HStack(spacing: 0) {
                                        ForEach(0..<9, id: \.self) { col in
                                            Text(layouts[index][row * 9 + col].map { "\($0.rawValue)" } ?? "")
                                                .font(Print.numeral(side * 0.62, weight: .medium))
                                                .frame(width: side, height: side)
                                                .background(Paper.page).border(Paper.rule, width: 0.4)
                                        }
                                    }
                                }
                            }
                        }.aspectRatio(1, contentMode: .fit).accessibilityHidden(true)
                    }
                    choice(option)
                }
            }
        }
    }
}
