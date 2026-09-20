import SwiftUI
import Observation

/// A callable action keeps custom panels independent of UIKit presentation.
struct PaperPanelDismissAction {
    private let action: () -> Void
    init(_ action: @escaping () -> Void = {}) { self.action = action }
    func callAsFunction() { action() }
}

private struct PaperPanelPresenterKey: EnvironmentKey {
    static let defaultValue: PaperPanelPresenter? = nil
}
private struct PaperPanelOwnerKey: EnvironmentKey {
    static let defaultValue: UUID? = nil
}
private struct PaperPanelDismissKey: EnvironmentKey {
    static let defaultValue = PaperPanelDismissAction()
}

extension EnvironmentValues {
    var paperPanelPresenter: PaperPanelPresenter? {
        get { self[PaperPanelPresenterKey.self] }
        set { self[PaperPanelPresenterKey.self] = newValue }
    }
    fileprivate var paperPanelOwner: UUID? {
        get { self[PaperPanelOwnerKey.self] }
        set { self[PaperPanelOwnerKey.self] = newValue }
    }
    var paperPanelDismiss: PaperPanelDismissAction {
        get { self[PaperPanelDismissKey.self] }
        set { self[PaperPanelDismissKey.self] = newValue }
    }
}

/// One in-game overlay stack, mounted above the Book and its capture host.
/// A closing panel remains modal until its last rendered frame is removed.
@MainActor
@Observable
final class PaperPanelPresenter {
    struct Entry: Identifiable {
        let id: UUID
        let parentID: UUID?
        var content: AnyView
        var isVisible = true
        var dismissalID: UUID?
    }

    private(set) var entries: [Entry] = []
    var isPresenting: Bool { !entries.isEmpty }
    var activeID: UUID? {
        guard let top = entries.last, top.isVisible else { return nil }
        return top.id
    }

    func present(id: UUID, parentID: UUID?, content: AnyView, reduceMotion: Bool) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].content = content
            entries[index].isVisible = true
            entries[index].dismissalID = nil
            return
        }
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.18)) {
            entries.append(Entry(id: id, parentID: parentID, content: content))
        }
    }

    func dismiss(id: UUID, reduceMotion: Bool, onDismiss: (() -> Void)?) {
        guard let index = entries.firstIndex(where: { $0.id == id }),
              entries[index].dismissalID == nil else { return }
        let dismissalID = UUID()
        let family = descendants(of: id).union([id])
        entries[index].dismissalID = dismissalID
        withAnimation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.18),
                      completionCriteria: .removed) {
            for offset in entries.indices where family.contains(entries[offset].id) {
                entries[offset].isVisible = false
            }
        } completion: { [weak self] in
            guard let self,
                  self.entries.first(where: { $0.id == id })?.dismissalID == dismissalID else { return }
            self.entries.removeAll { family.contains($0.id) }
            // Shop's marker-placement handoff happens after both paper and
            // backdrop have disappeared, never behind a departing panel.
            onDismiss?()
        }
    }

    /// An owner that navigated away cannot leave a panel or delayed callback
    /// over the next page. Descendants belong to the same lifetime.
    func cancel(id: UUID) {
        let family = descendants(of: id).union([id])
        entries.removeAll { family.contains($0.id) }
    }

    func cancelAll() { entries.removeAll() }

    private func descendants(of parent: UUID) -> Set<UUID> {
        var family = Set<UUID>()
        var frontier = [parent]
        while let current = frontier.popLast() {
            for child in entries where child.parentID == current && !family.contains(child.id) {
                family.insert(child.id)
                frontier.append(child.id)
            }
        }
        return family
    }
}

extension View {
    /// Mount once at the screen root so panels are not constrained by a Hand
    /// row, board cell, Book margin, or a Shop's scaled design coordinates.
    func paperPanelHost() -> some View { modifier(PaperPanelHostModifier()) }

    func paperPanel<Item: Identifiable, Panel: View>(
        item: Binding<Item?>, onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Panel
    ) -> some View {
        modifier(PaperPanelItemModifier(item: item, onDismiss: onDismiss, panel: content))
    }

    func paperPanel<Panel: View>(
        isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Panel
    ) -> some View {
        paperPanel(item: Binding<PaperPanelFlag?>(
            get: { isPresented.wrappedValue ? .presented : nil },
            set: { isPresented.wrappedValue = $0 != nil }), onDismiss: onDismiss) { _ in content() }
    }
}

private enum PaperPanelFlag: Identifiable {
    case presented
    var id: Self { self }
}

private struct PaperPanelHostModifier: ViewModifier {
    @State private var presenter = PaperPanelPresenter()

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(!presenter.isPresenting)
            .accessibilityHidden(presenter.isPresenting)
            .overlay { PaperPanelLayers(presenter: presenter) }
            .environment(\.paperPanelPresenter, presenter)
            .onDisappear { presenter.cancelAll() }
    }
}

private struct PaperPanelLayers: View {
    let presenter: PaperPanelPresenter

    var body: some View {
        ZStack {
            ForEach(presenter.entries) { entry in
                if entry.isVisible {
                    entry.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .allowsHitTesting(entry.id == presenter.activeID)
                        .accessibilityHidden(entry.id != presenter.activeID)
                        .accessibilityAddTraits(.isModal)
                        .transition(.opacity)
                        .zIndex(Double(presenter.entries.firstIndex(where: { $0.id == entry.id }) ?? 0))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PaperPanelItemModifier<Item: Identifiable, Panel: View>: ViewModifier {
    @Binding var item: Item?
    let onDismiss: (() -> Void)?
    let panel: (Item) -> Panel
    @Environment(\.self) private var sourceEnvironment
    @State private var ownerID = UUID()
    @State private var fallbackPresenter = PaperPanelPresenter()

    private var presenter: PaperPanelPresenter { sourceEnvironment.paperPanelPresenter ?? fallbackPresenter }

    func body(content: Content) -> some View {
        content
            .allowsHitTesting(sourceEnvironment.paperPanelPresenter != nil || !fallbackPresenter.isPresenting)
            .accessibilityHidden(sourceEnvironment.paperPanelPresenter == nil && fallbackPresenter.isPresenting)
            .overlay {
                // Isolated previews/tests can present without requiring an
                // app-owned environment object. Production uses the root host.
                if sourceEnvironment.paperPanelPresenter == nil {
                    PaperPanelLayers(presenter: fallbackPresenter)
                }
            }
            .onChange(of: item?.id, initial: true) { _, _ in synchronize() }
            .onChange(of: sourceEnvironment.cosmeticTheme) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.bookPresentation) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.levelPalette) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.dynamicTypeSize) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.accessibilityVoiceOverEnabled) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.colorScheme) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.locale) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.scenePhase) { _, _ in refreshEnvironment() }
            .onChange(of: sourceEnvironment.gameReduceMotion) { _, _ in refreshEnvironment() }
            .onDisappear {
                presenter.cancel(id: ownerID)
                item = nil
            }
    }

    private func refreshEnvironment() {
        guard item != nil else { return }
        synchronize()
    }

    private func synchronize() {
        guard let item else {
            presenter.dismiss(id: ownerID, reduceMotion: sourceEnvironment.gameReduceMotion,
                              onDismiss: onDismiss)
            return
        }
        let dismiss = PaperPanelDismissAction { self.item = nil }
        // A whole-environment write closer to the content would override
        // separate outer key writes. Compose the portal's ownership and
        // dismissal action into the source snapshot before forwarding it.
        var panelEnvironment = sourceEnvironment
        panelEnvironment.paperPanelPresenter = presenter
        panelEnvironment.paperPanelOwner = ownerID
        panelEnvironment.paperPanelDismiss = dismiss
        let hosted = PaperPanelBoundContent(item: $item, fallback: item, panel: panel)
            .id(item.id)
            .environment(\.self, panelEnvironment)
        presenter.present(id: ownerID, parentID: sourceEnvironment.paperPanelOwner,
                          content: AnyView(hosted), reduceMotion: sourceEnvironment.gameReduceMotion)
    }
}

/// Keep outgoing paper intact during dismissal even after its binding is nil;
/// while open, same-identity item changes still update its visible content.
private struct PaperPanelBoundContent<Item: Identifiable, Panel: View>: View {
    @Binding var item: Item?
    let fallback: Item
    let panel: (Item) -> Panel

    var body: some View {
        let current = item.flatMap { $0.id == fallback.id ? $0 : nil } ?? fallback
        panel(current)
    }
}
