import SwiftUI
import Observation
import ProbablySudokuEngine

/// Geometry and release resolution live together so the visible target is the
/// exact target that commits. Global coordinates never clamp motion to the row.
struct InventoryDragSession: Equatable {
    enum Drop: Equatable { case sell(InventorySale), reorder(UUID, Int), cancel }
    let owner: UUID
    let sale: InventorySale
    let itemFrame: CGRect
    let bookmarkFrames: [CGRect]
    let trashFrame: CGRect
    let fingerOffset: CGSize
    var finger: CGPoint

    var center: CGPoint {
        CGPoint(x: finger.x + fingerOffset.width, y: finger.y + fingerOffset.height)
    }
    var overTrash: Bool { trashFrame.contains(finger) }
    var reorderIndex: Int? {
        guard sale.kind == .bookmark, !overTrash else { return nil }
        return bookmarkFrames.firstIndex { $0.contains(finger) }
    }
    var drop: Drop {
        if overTrash { return .sell(sale) }
        if let index = reorderIndex, let id = sale.bookmarkID, index != sale.index {
            return .reorder(id, index)
        }
        return .cancel
    }
}

/// A cancelled release is presentation only. The owned item never left the
/// inventory, and this flight cannot invoke a sale or other game mutation.
struct InventoryDragReturn: Identifiable {
    let id = UUID()
    let owner: UUID
    let sale: InventorySale
    let itemFrame: CGRect
    let start: CGPoint
}

@MainActor
@Observable
final class InventoryDragPresenter {
    private(set) var session: InventoryDragSession?
    private(set) var returning: InventoryDragReturn?
    private(set) var actionFrame: CGRect?
    private var actionOwner: UUID?

    func registerActions(owner: UUID, frame: CGRect) {
        if session != nil, actionOwner != owner || actionFrame != frame { cancel() }
        actionOwner = owner
        actionFrame = frame
    }

    func removeActions(owner: UUID) {
        guard actionOwner == owner else { return }
        cancel()
        actionOwner = nil
        actionFrame = nil
    }
    var rootFrame: CGRect = .zero {
        didSet { if oldValue != .zero && oldValue != rootFrame { cancel() } }
    }

    func begin(owner: UUID, sale: InventorySale, itemFrame: CGRect,
               bookmarkFrames: [CGRect], start: CGPoint, point: CGPoint) {
        guard session == nil, !rootFrame.isEmpty, !itemFrame.isEmpty else { return }
        returning = nil
        let width = max(0, rootFrame.width - 32)
        let fallback = CGRect(x: rootFrame.midX - width / 2, y: rootFrame.maxY - 90,
                              width: width, height: 64)
        let trash = actionFrame.flatMap { frame in
            !frame.isEmpty && rootFrame.contains(frame) ? frame : nil
        } ?? fallback
        session = InventoryDragSession(owner: owner, sale: sale, itemFrame: itemFrame,
            bookmarkFrames: bookmarkFrames, trashFrame: trash,
            fingerOffset: CGSize(width: itemFrame.midX - start.x, height: itemFrame.midY - start.y),
            finger: point)
    }

    func move(owner: UUID, to point: CGPoint) {
        guard session?.owner == owner else { return }
        session?.finger = point
    }

    /// Consume before invoking any gameplay mutation: repeated ends cannot sell
    /// twice, and a cancelled/navigation-owned gesture has no remaining action.
    func finish(owner: UUID, at point: CGPoint) -> InventoryDragSession.Drop {
        guard session?.owner == owner else { return .cancel }
        session?.finger = point
        guard let released = session else { return .cancel }
        let action = released.drop
        session = nil
        if action == .cancel {
            returning = InventoryDragReturn(owner: owner, sale: released.sale,
                itemFrame: released.itemFrame, start: released.center)
        }
        return action
    }

    func finishReturn(id: UUID) {
        guard returning?.id == id else { return }
        returning = nil
    }

    func cancel(owner: UUID? = nil) {
        if owner == nil || session?.owner == owner { session = nil }
        if owner == nil || returning?.owner == owner { returning = nil }
    }
}

private struct InventoryDragPresenterKey: EnvironmentKey {
    static let defaultValue: InventoryDragPresenter? = nil
}

extension EnvironmentValues {
    var inventoryDragPresenter: InventoryDragPresenter? {
        get { self[InventoryDragPresenterKey.self] }
        set { self[InventoryDragPresenterKey.self] = newValue }
    }
}

extension View {
    /// Apply before paperPanelHost at the screen root. The lifted inventory is
    /// above the Book, while open paper panels retain modal ownership.
    func inventoryDragHost(presenter: InventoryDragPresenter? = nil) -> some View {
        modifier(InventoryDragHost(presenter: presenter))
    }

    /// The sell destination replaces the route's decisions without moving its
    /// board, hand or stock. The measured frame is also the commit hit target.
    func inventorySaleActionArea() -> some View { modifier(InventorySaleActionArea()) }
}

private struct InventorySaleActionArea: ViewModifier {
    @Environment(\.inventoryDragPresenter) private var presenter
    @State private var owner = UUID()

    func body(content: Content) -> some View {
        content
            .opacity(presenter?.session == nil ? 1 : 0)
            .allowsHitTesting(presenter?.session == nil)
            .accessibilityHidden(presenter?.session != nil)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame in
                presenter?.registerActions(owner: owner, frame: frame)
            }
            .onDisappear { presenter?.removeActions(owner: owner) }
    }
}

private struct InventoryDragHost: ViewModifier {
    @State private var presenter: InventoryDragPresenter
    @Environment(\.scenePhase) private var scenePhase

    init(presenter: InventoryDragPresenter?) {
        _presenter = State(initialValue: presenter ?? InventoryDragPresenter())
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let frame = geometry.frame(in: .global)
                    ZStack(alignment: .topLeading) {
                        if let session = presenter.session {
                            InventoryDragLayer(session: session, rootFrame: frame)
                        }
                        if let returning = presenter.returning {
                            InventoryReturnLayer(returning: returning, rootFrame: frame) {
                                presenter.finishReturn(id: returning.id)
                            }
                            .id(returning.id)
                        }
                    }
                    .onChange(of: frame, initial: true) { _, value in presenter.rootFrame = value }
                }
                .allowsHitTesting(false)
            }
            .environment(\.inventoryDragPresenter, presenter)
            .onChange(of: scenePhase) { _, phase in if phase != .active { presenter.cancel() } }
            .onDisappear { presenter.cancel() }
    }
}

private struct InventoryDragLayer: View {
    let session: InventoryDragSession
    let rootFrame: CGRect

    var body: some View {
        ZStack(alignment: .topLeading) {
            HStack(spacing: 12) {
                Label(session.overTrash ? "Release to sell" : "Drag here to sell", systemImage: "trash")
                    .font(.system(size: 14, weight: .semibold))
                Text("+\(session.sale.refund) \(session.sale.refund == 1 ? "coin" : "coins")")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundStyle(session.overTrash ? GameplaySurface.ivory : GameplaySurface.ink)
            .frame(width: session.trashFrame.width, height: session.trashFrame.height)
            .background(session.overTrash ? GameplaySurface.sage : GameplaySurface.ivory,
                        in: .rect(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(GameplaySurface.sage, lineWidth: 2))
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            .position(local(CGPoint(x: session.trashFrame.midX, y: session.trashFrame.midY)))
            .accessibilityLabel("Sell \(Catalog.item(session.sale.defID)?.name ?? "item") for \(session.sale.refund) coins")
            .accessibilityIdentifier("inventory.sell-target")

            InventoryLiftedCard(sale: session.sale, size: session.itemFrame.size)
                .position(local(session.center))
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - rootFrame.minX, y: point.y - rootFrame.minY)
    }
}

private struct InventoryLiftedCard: View {
    let sale: InventorySale
    let size: CGSize

    var body: some View {
            ItemArtwork(id: sale.defID, size: min(size.width, size.height) * 0.72, style: .glyph)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(sale.kind == .buff ? GameplaySurface.ivory : GameplaySurface.ink)
                .frame(width: size.width, height: size.height)
                .background(sale.kind == .buff ? GameplaySurface.ink : GameplaySurface.ivory,
                            in: .rect(cornerRadius: 6))
                .overlay(alignment: .top) {
                    if sale.kind == .buff { Paper.coin.frame(height: 3).padding(.horizontal, 3) }
                }
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(GameplaySurface.sage, lineWidth: 1))
                .shadow(color: .black.opacity(0.3), radius: 9, y: 5)
    }
}

private struct InventoryReturnLayer: View {
    let returning: InventoryDragReturn
    let rootFrame: CGRect
    let onFinished: () -> Void
    @Environment(\.gameReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        let point = arrived
            ? CGPoint(x: returning.itemFrame.midX, y: returning.itemFrame.midY)
            : returning.start
        InventoryLiftedCard(sale: returning.sale, size: returning.itemFrame.size)
            .position(x: point.x - rootFrame.minX, y: point.y - rootFrame.minY)
            .accessibilityHidden(true)
            .task {
                guard !reduceMotion else { onFinished(); return }
                withAnimation(.spring(duration: 0.28, bounce: 0.12)) { arrived = true }
                do { try await Task.sleep(for: .milliseconds(300)) } catch { return }
                onFinished()
            }
    }
}
