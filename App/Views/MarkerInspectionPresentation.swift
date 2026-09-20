import SwiftUI
import ProbablySudokuEngine

/// Inspection is presentation only. It deliberately owns no gameplay
/// selection, inventory, random stream, or persisted field.
@MainActor @Observable
final class MarkerInspectionPresenter {
    enum Source: Equatable { case touch(UUID), accessibility }
    struct Session {
        let square: Square
        let markerID: String
        let cellFrame: CGRect
        let source: Source
    }
    private(set) var session: Session?
    var popupFrame: CGRect = .zero

    func begin(square: Square, model: GameModel, cellFrame: CGRect, source: Source,
               feedback: (() -> Void)? = nil) {
        guard model.page == .puzzle, model.acceptsPuzzleInput, !cellFrame.isEmpty,
              let info = MarkerInspectionInfo.make(square: square, run: model.run) else { return }
        guard session?.square != square || session?.source != source else { return }
        session = Session(square: square, markerID: info.marker.defID,
                          cellFrame: cellFrame, source: source)
        if let feedback { feedback() } else { Haptics.lift() }
    }

    func endTouch(owner: UUID) {
        if session?.source == .touch(owner) { dismiss() }
    }

    func dismiss() { session = nil; popupFrame = .zero }

    func info(in model: GameModel) -> MarkerInspectionInfo? {
        guard model.page == .puzzle, model.acceptsPuzzleInput, let session,
              let info = MarkerInspectionInfo.make(square: session.square, run: model.run),
              info.marker.defID == session.markerID else { return nil }
        return info
    }
}

private struct MarkerInspectionPresenterKey: EnvironmentKey {
    static let defaultValue: MarkerInspectionPresenter? = nil
}
extension EnvironmentValues {
    var markerInspectionPresenter: MarkerInspectionPresenter? {
        get { self[MarkerInspectionPresenterKey.self] }
        set { self[MarkerInspectionPresenterKey.self] = newValue }
    }
}

extension View {
    func markerInspectionHost(model: GameModel, presenter: MarkerInspectionPresenter? = nil) -> some View {
        modifier(MarkerInspectionHost(model: model, presenter: presenter))
    }
}

/// All measurements use the same window space as the actual cell, including
/// safe areas. Prefer above; use below when it has room and above does not.
struct MarkerPopupPlacement {
    let viewport: CGRect
    let cell: CGRect
    let contentHeight: CGFloat
    let wideText: Bool
    private var margin: CGFloat { 8 }
    private var gap: CGFloat { 12 }
    var width: CGFloat { min(max(0, viewport.width - margin * 2), wideText ? 440 : 320) }
    private var above: CGFloat { max(0, cell.minY - gap - viewport.minY - margin) }
    private var below: CGFloat { max(0, viewport.maxY - margin - cell.maxY - gap) }
    var isAbove: Bool { above >= contentHeight || above >= below }
    var height: CGFloat {
        min(contentHeight, max(1, viewport.height - margin * 2), max(1, isAbove ? above : below))
    }
    var frame: CGRect {
        let x = min(max(cell.midX - width / 2, viewport.minX + margin), viewport.maxX - margin - width)
        let preferredY = isAbove ? cell.minY - gap - height : cell.maxY + gap
        let y = min(max(preferredY, viewport.minY + margin), viewport.maxY - margin - height)
        return CGRect(x: x, y: y, width: width, height: height)
    }
    var pointerX: CGFloat { min(max(cell.midX - frame.minX, 20), width - 20) }
}

private struct MarkerInspectionHost: ViewModifier {
    @Bindable var model: GameModel
    @State private var presenter: MarkerInspectionPresenter
    @State private var viewportFrame = CGRect.zero
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.bossMotionIsActive) private var routeIsVisible

    init(model: GameModel, presenter: MarkerInspectionPresenter?) {
        self.model = model
        _presenter = State(initialValue: presenter ?? MarkerInspectionPresenter())
    }

    // A new turn, puzzle, route, or concealment invalidates a held explanation.
    private var context: String {
        "\(model.run.seed):\(model.run.level):\(model.run.slot):\(model.page):\(model.puzzle?.turnNumber ?? 0):\(model.puzzle?.phase.rawValue ?? ""):\(model.markersAreHidden)"
    }

    func body(content: Content) -> some View {
        content
            .environment(\.markerInspectionPresenter, presenter)
            .overlay {
                GeometryReader { geometry in
                    ZStack {
                        if routeIsVisible, scenePhase == .active,
                           let session = presenter.session, let info = presenter.info(in: model) {
                            MarkerInspectionPopup(info: info, session: session,
                                viewport: geometry.frame(in: .global), presenter: presenter)
                        }
                    }
                    .onChange(of: geometry.frame(in: .global), initial: true) { _, frame in
                        if !viewportFrame.isEmpty && viewportFrame != frame { presenter.dismiss() }
                        viewportFrame = frame
                    }
                }
            }
            .onChange(of: context) { _, _ in presenter.dismiss() }
            .onChange(of: routeIsVisible) { _, visible in if !visible { presenter.dismiss() } }
            .onChange(of: scenePhase) { _, phase in if phase != .active { presenter.dismiss() } }
            .onDisappear { presenter.dismiss() }
    }
}

private struct MarkerInspectionPopup: View {
    let info: MarkerInspectionInfo
    let session: MarkerInspectionPresenter.Session
    let viewport: CGRect
    let presenter: MarkerInspectionPresenter
    @Environment(\.dynamicTypeSize) private var textSize
    @ScaledMetric(relativeTo: .body) private var bodySize = 16.0
    @ScaledMetric(relativeTo: .headline) private var titleSize = 21.0
    @State private var contentHeight: CGFloat = 260
    @AccessibilityFocusState private var titleFocused: Bool

    private var accessible: Bool { session.source == .accessibility }
    private var dismissHeight: CGFloat { accessible ? max(44, bodySize * 1.35 + 16) : 0 }
    private var placement: MarkerPopupPlacement {
        MarkerPopupPlacement(viewport: viewport, cell: session.cellFrame,
                             contentHeight: contentHeight + dismissHeight, wideText: textSize.isAccessibilitySize)
    }

    var body: some View {
        let layout = placement
        VStack(spacing: 0) {
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(info.title)
                        .font(.system(size: titleSize, weight: .bold, design: .serif))
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleFocused)
                    Text(info.compactExplanation)
                        .font(.system(size: bodySize, design: .serif))
                    if let notice = info.inspectionNotice {
                        Text(notice)
                            .font(.system(size: bodySize))
                            .foregroundStyle(GameplaySurface.softInk)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(16)
                .padding(.top, 4)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
            }
            .scrollBounceBehavior(.basedOnSize)
            if accessible {
                Button { presenter.dismiss() } label: {
                    Text("Dismiss")
                        .font(.system(size: bodySize, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: dismissHeight)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(GameplaySurface.sage)
                .buttonStyle(.plain)
                .overlay(alignment: .top) { Rectangle().fill(GameplaySurface.sage.opacity(0.3)).frame(height: 1) }
                .accessibilityLabel("Dismiss marker")
                .accessibilityIdentifier("marker-inspection-dismiss")
            }
        }
        .frame(width: layout.width, height: layout.height)
        .foregroundStyle(GameplaySurface.ink)
        .background {
            RoundedRectangle(cornerRadius: 9).fill(GameplaySurface.ivory)
                .overlay(alignment: .top) {
                    Rectangle().fill(GameplaySurface.sage).frame(height: 5)
                }
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .overlay { RoundedRectangle(cornerRadius: 9).strokeBorder(GameplaySurface.sage.opacity(0.5), lineWidth: 1) }
                .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
        }
        .overlay(alignment: layout.isAbove ? .bottomLeading : .topLeading) {
            MarkerPopupPointer(pointsDown: layout.isAbove)
                .fill(GameplaySurface.ivory)
                .frame(width: 16, height: 10)
                .offset(x: layout.pointerX - 8, y: layout.isAbove ? 9 : -9)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .position(x: layout.frame.midX - viewport.minX, y: layout.frame.midY - viewport.minY)
        .allowsHitTesting(accessible)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(accessible ? .isModal : [])
        .accessibilityIdentifier("marker-inspection-popup")
        .accessibilityAction(.escape) { presenter.dismiss() }
        .onChange(of: layout.frame, initial: true) { _, frame in presenter.popupFrame = frame }
        .onAppear { if accessible { titleFocused = true } }
        // Appearance cannot shift the board or start another animation clock.
        .transaction { $0.animation = nil }
    }
}

private struct MarkerPopupPointer: Shape {
    var pointsDown: Bool
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX, y: pointsDown ? rect.minY : rect.maxY))
            path.addLine(to: CGPoint(x: rect.midX, y: pointsDown ? rect.maxY : rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: pointsDown ? rect.minY : rect.maxY))
            path.closeSubpath()
        }
    }
}
