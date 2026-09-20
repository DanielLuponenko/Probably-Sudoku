import SwiftUI
import ProbablySudokuEngine

/// A small, transient presentation of the Hand's existing sort actions.
/// It never enters the paper-panel flow, which would cancel Clue targeting.
@MainActor @Observable
final class HandArrangementPresenter {
    struct Session {
        let owner: UUID
        let anchor: CGRect
        let model: GameModel
        let context: String
    }
    private(set) var session: Session?

    func toggle(owner: UUID, anchor: CGRect, model: GameModel) {
        if session?.owner == owner {
            dismiss(owner: owner)
            return
        }
        guard model.page == .puzzle, model.acceptsPuzzleInput,
              !anchor.isEmpty, !anchor.isInfinite, !anchor.isNull else { return }
        session = Session(owner: owner, anchor: anchor, model: model, context: Self.context(of: model))
    }

    func choose(_ arrangement: GameModel.HandArrangement, owner: UUID) {
        guard let current = session, current.owner == owner else { return }
        session = nil
        guard current.model.page == .puzzle, current.model.acceptsPuzzleInput,
              current.context == Self.context(of: current.model) else { return }
        current.model.arrangeHand(arrangement)
    }

    func dismiss(owner: UUID? = nil) {
        guard owner == nil || session?.owner == owner else { return }
        session = nil
    }

    static func context(of model: GameModel) -> String {
        "\(model.run.seed):\(model.run.book):\(model.run.level):\(model.run.slot):\(model.page):\(model.puzzle?.turnNumber ?? 0):\(model.puzzle?.phase.rawValue ?? "")"
    }
}

private struct HandArrangementPresenterKey: EnvironmentKey {
    static let defaultValue: HandArrangementPresenter? = nil
}
extension EnvironmentValues {
    var handArrangementPresenter: HandArrangementPresenter? {
        get { self[HandArrangementPresenterKey.self] }
        set { self[HandArrangementPresenterKey.self] = newValue }
    }
}

extension View {
    func handArrangementMenuHost(model: GameModel) -> some View {
        modifier(HandArrangementMenuHost(model: model))
    }
}

private struct HandArrangementMenuHost: ViewModifier {
    @Bindable var model: GameModel
    @State private var presenter = HandArrangementPresenter()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var routeIsVisible
    @Environment(\.paperPanelPresenter) private var paperPresenter
    @Environment(\.gameReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .environment(\.handArrangementPresenter, presenter)
            .accessibilityHidden(presenter.session != nil)
            .allowsHitTesting(presenter.session == nil)
            .overlay {
                GeometryReader { geometry in
                    if routeIsVisible, scenePhase == .active, let session = presenter.session {
                        ZStack(alignment: .topLeading) {
                            // The transparent dismissal button consumes the
                            // outside tap; the board never receives that tap.
                            Button { presenter.dismiss() } label: {
                                Color.clear
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Dismiss arrangement menu")
                            .accessibilityIdentifier("hand-arrangement.dismiss")
                            .accessibilityAction(.escape) { presenter.dismiss() }
                            HandArrangementMenu(session: session, presenter: presenter,
                                                viewport: geometry.frame(in: .global))
                        }
                        .transition(.opacity)
                        .accessibilityElement(children: .contain)
                        .accessibilityAddTraits(.isModal)
                    }
                }
                .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: presenter.session != nil)
                .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { _ in
                    presenter.dismiss()
                }
            }
            .onChange(of: HandArrangementPresenter.context(of: model)) { _, _ in presenter.dismiss() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { presenter.dismiss() } }
            .onChange(of: routeIsVisible) { _, visible in if !visible { presenter.dismiss() } }
            .onChange(of: paperPresenter?.isPresenting) { _, showing in if showing == true { presenter.dismiss() } }
            .onDisappear { presenter.dismiss() }
    }
}

private struct HandArrangementMenu: View {
    let session: HandArrangementPresenter.Session
    let presenter: HandArrangementPresenter
    let viewport: CGRect
    @Environment(\.gameReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var labelSize: CGFloat = 15

    private var width: CGFloat { min(viewport.width - 16, max(168, labelSize * 10 + 12)) }
    private var rowHeight: CGFloat { max(44, labelSize * 1.35 + 16) }

    var body: some View {
        HandArrangementPlacement(anchor: session.anchor, viewport: viewport, width: width) {
            VStack(spacing: 0) {
                choice("Ascending", symbol: "arrow.up", arrangement: .ascending)
                choice("Descending", symbol: "arrow.down", arrangement: .descending)
                choice("Shuffle hand", symbol: "shuffle", arrangement: .random)
            }
            .padding(.vertical, 4)
            .frame(width: width)
            .background(GameplaySurface.ivory, in: RoundedRectangle(cornerRadius: 7))
            .overlay { RoundedRectangle(cornerRadius: 7).strokeBorder(GameplaySurface.sage.opacity(0.5), lineWidth: 1) }
            .shadow(color: .black.opacity(0.17), radius: 5, y: 3)
        }
    }

    private func choice(_ title: String, symbol: String, arrangement: GameModel.HandArrangement) -> some View {
        let selected = session.model.handArrangement == arrangement
        return Button {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                presenter.choose(arrangement, owner: session.owner)
            }
        } label: {
            HStack(spacing: 10) {
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: symbol).font(.system(size: labelSize - 2, weight: .medium))
                        .frame(width: labelSize)
                }
                Text(title).font(.system(size: labelSize, weight: selected ? .semibold : .regular))
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .minimumScaleFactor(dynamicTypeSize.isAccessibilitySize ? 1 : 0.8)
                    .fixedSize(horizontal: false, vertical: dynamicTypeSize.isAccessibilitySize)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 4)
                if !dynamicTypeSize.isAccessibilitySize {
                    Image(systemName: "checkmark").font(.system(size: labelSize - 2, weight: .semibold))
                        .opacity(selected ? 1 : 0)
                }
            }
            .foregroundStyle(GameplaySurface.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 8 : 0)
            .frame(minHeight: rowHeight)
            .frame(maxWidth: .infinity)
            .background(selected ? GameplaySurface.sage.opacity(0.12) : .clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(selected ? "Selected" : "")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
        .accessibilityIdentifier("hand-arrangement.\(arrangement.rawValue)")
        .accessibilityAction(.escape) { presenter.dismiss() }
    }
}

/// The menu grows for wrapped labels before it is clamped around its anchor.
/// The rest of the game never participates in this measurement.
private struct HandArrangementPlacement: Layout {
    let anchor: CGRect
    let viewport: CGRect
    let width: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions(by: viewport.size)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let menu = subviews.first else { return }
        let column = ProposedViewSize(width: width, height: nil)
        let height = menu.sizeThatFits(column).height
        let x = min(max(anchor.maxX - width, viewport.minX + 8), viewport.maxX - width - 8)
        let y = min(max(anchor.minY - height - 6, viewport.minY + 8), viewport.maxY - height - 8)
        menu.place(at: CGPoint(x: bounds.minX + x - viewport.minX, y: bounds.minY + y - viewport.minY), proposal: column)
    }
}
