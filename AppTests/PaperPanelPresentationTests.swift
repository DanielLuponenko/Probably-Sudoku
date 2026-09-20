import XCTest
import SwiftUI
import UIKit
import Observation
@testable import ProbablySudoku

@MainActor
final class PaperPanelPresentationTests: XCTestCase {
    func testNestedSettingsPracticeSurvivesChangingTextSizeWhileOpen() async throws {
        let state = NestedPracticeRefreshState()
        let practice = try TutorialPractice.make()
        let settingsOpened = expectation(description: "Settings navigation mounted")
        let practiceOpened = expectation(description: "Nested practice mounted")
        let refreshed = expectation(description: "Nested practice receives enlarged source text")
        let controller = UIHostingController(rootView: NestedPracticeRefreshHarness(
            state: state, practice: practice, settingsOpened: { settingsOpened.fulfill() },
            practiceOpened: { practiceOpened.fulfill() }, refreshed: { refreshed.fulfill() }))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 375, height: 667)
        window.rootViewController = controller
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [settingsOpened], timeout: 3)
        try XCTUnwrap(state.openPractice)()
        await fulfillment(of: [practiceOpened], timeout: 3)
        let session = try XCTUnwrap(state.practiceState.session)
        let presenter = try XCTUnwrap(state.practiceState.presenter)
        let panelIDs = presenter.entries.map(\.id)
        XCTAssertEqual(panelIDs.count, 2)
        session.continueLesson()
        XCTAssertTrue(session.selectCard(try XCTUnwrap(session.targetCardID)))
        let snapshot = session.snapshot
        let selectedCard = session.selectedCardID
        let actions = session.completedActions

        state.textSize = .accessibility3
        await fulfillment(of: [refreshed], timeout: 3)
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(presenter.entries.map(\.id), panelIDs,
                       "Settings must keep its nested destination alive when its article changes size")
        XCTAssertEqual(presenter.activeID, panelIDs.last)
        XCTAssertEqual(state.settingsMountCount, 1)
        XCTAssertTrue(state.practiceState.session === session)
        XCTAssertFalse(session.isStopped)
        XCTAssertEqual(session.step, .place)
        XCTAssertEqual(session.snapshot, snapshot)
        XCTAssertEqual(session.selectedCardID, selectedCard)
        XCTAssertEqual(session.completedActions, actions)
    }

    func testLiveSourceEnvironmentRefreshPreservesMountedPracticeAndSelection() async throws {
        let state = PracticePanelRefreshState()
        let practice = try TutorialPractice.make()
        let opened = expectation(description: "Practice mounted with the source text size")
        let refreshed = expectation(description: "Open practice receives enlarged source text")
        let controller = UIHostingController(rootView: PracticePanelRefreshHarness(
            state: state, practice: practice, opened: { opened.fulfill() },
            refreshed: { refreshed.fulfill() }))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.rootViewController = controller
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [opened], timeout: 3)
        let session = try XCTUnwrap(state.session)
        let presenter = try XCTUnwrap(state.presenter)
        let panelID = try XCTUnwrap(presenter.activeID)
        session.continueLesson()
        XCTAssertTrue(session.selectCard(try XCTUnwrap(session.targetCardID)))
        let snapshot = session.snapshot
        let selectedCard = session.selectedCardID
        let actions = session.completedActions

        // VoiceOver's environment flag is read-only and owned by iOS. This
        // uses a real writable source value to exercise the same portal
        // refresh path without pretending to toggle the OS accessibility mode.
        state.textSize = .accessibility3
        await fulfillment(of: [refreshed], timeout: 3)
        XCTAssertTrue(state.session === session, "Refreshing a panel must not recreate practice")
        XCTAssertEqual(presenter.activeID, panelID)
        XCTAssertEqual(presenter.entries.count, 1)
        XCTAssertTrue(state.showsPractice)
        XCTAssertFalse(session.isStopped)
        XCTAssertEqual(session.step, .place)
        XCTAssertEqual(session.snapshot, snapshot)
        XCTAssertEqual(session.selectedCardID, selectedCard)
        XCTAssertEqual(session.completedActions, actions)
        XCTAssertNil(controller.presentedViewController)
    }

    func testSettingsHelpAndNestedTopicsShareTheVisibleRootWithoutUIKitPresentation() async throws {
        let state = NestedPanelState()
        let helpReady = expectation(description: "Settings Help is in the paper portal")
        let topicsReady = expectation(description: "Topics is above Help")
        let topicsClosed = expectation(description: "Closing Topics returns to Help")
        var theme = CosmeticTheme.standard
        theme.paper = CosmeticCatalog.paper("pp_night_sky")
        let controller = UIHostingController(rootView: NestedPanelHarness(
            state: state, helpReady: { helpReady.fulfill() },
            topicsReady: { topicsReady.fulfill() }, topicsClosed: { topicsClosed.fulfill() })
            .environment(\.cosmeticTheme, theme))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 640)
        window.rootViewController = controller
        defer {
            window.isHidden = true
            window.rootViewController = nil
            previousKey?.makeKey()
        }
        window.makeKeyAndVisible()
        await fulfillment(of: [helpReady], timeout: 3)
        XCTAssertNil(controller.presentedViewController)
        let presenter = try XCTUnwrap(state.helpPresenter)
        XCTAssertEqual(presenter.entries.count, 1)
        state.showsTopics = true
        await fulfillment(of: [topicsReady], timeout: 3)
        window.layoutIfNeeded()
        XCTAssertTrue(state.topicsPresenter === presenter)
        XCTAssertEqual(presenter.entries.count, 2)
        XCTAssertEqual(presenter.entries.last?.parentID, presenter.entries.first?.id)
        XCTAssertEqual(presenter.activeID, presenter.entries.last?.id)
        XCTAssertNil(controller.presentedViewController, "A UIKit cover would hide the root Topics panel")
        XCTAssertEqual(state.topicsTheme, theme, "Nested paper keeps the source's selected material")
        XCTAssertEqual(state.topicsSize.width, 320, accuracy: 1)
        XCTAssertEqual(state.topicsSize.height, 640, accuracy: 1)
        let dismiss = try XCTUnwrap(state.dismissTopics)
        dismiss()
        await fulfillment(of: [topicsClosed], timeout: 3)
        XCTAssertEqual(presenter.entries.count, 1)
        XCTAssertTrue(state.showsHelp)
        XCTAssertFalse(state.showsTopics)
    }

    func testNestedPanelsOwnInputUntilTheTopPanelHasFinishedDismissing() async {
        let presenter = PaperPanelPresenter()
        let parent = UUID(), child = UUID()
        presenter.present(id: parent, parentID: nil, content: AnyView(Text("Parent")), reduceMotion: true)
        presenter.present(id: child, parentID: parent, content: AnyView(Text("Child")), reduceMotion: true)
        XCTAssertEqual(presenter.activeID, child)
        XCTAssertTrue(presenter.isPresenting)
        let dismissed = expectation(description: "Child removal precedes handoff")
        presenter.dismiss(id: child, reduceMotion: true) {
            XCTAssertFalse(presenter.entries.contains { $0.id == child })
            XCTAssertEqual(presenter.activeID, parent)
            XCTAssertTrue(presenter.isPresenting)
            dismissed.fulfill()
        }
        if presenter.entries.contains(where: { $0.id == child }) {
            XCTAssertNil(presenter.activeID, "A fading child must not expose its parent to taps")
        }
        await fulfillment(of: [dismissed], timeout: 1)
    }

    func testOwnerNavigationCancelsEveryDescendantAndItsPendingHandoff() async {
        let presenter = PaperPanelPresenter()
        let owner = UUID(), child = UUID(), grandchild = UUID(), other = UUID()
        presenter.present(id: owner, parentID: nil, content: AnyView(Text("Owner")), reduceMotion: false)
        presenter.present(id: child, parentID: owner, content: AnyView(Text("Child")), reduceMotion: false)
        presenter.present(id: grandchild, parentID: child, content: AnyView(Text("Grandchild")), reduceMotion: false)
        presenter.present(id: other, parentID: nil, content: AnyView(Text("Other")), reduceMotion: false)
        presenter.cancel(id: owner)
        XCTAssertEqual(presenter.entries.map(\.id), [other])
        XCTAssertEqual(presenter.activeID, other)
        // A delayed source update from the departed page cannot queue its
        // purchase handoff after navigation has cancelled that whole family.
        var handedOff = false
        presenter.dismiss(id: owner, reduceMotion: true) { handedOff = true }
        await Task.yield()
        XCTAssertFalse(handedOff)
        presenter.cancelAll()
        XCTAssertFalse(presenter.isPresenting)
        XCTAssertNil(presenter.activeID)
    }

    func testDismissalCallbackCanOpenTheNextPanelAfterThePreviousOneIsRemoved() async {
        let presenter = PaperPanelPresenter()
        let offer = UUID(), placement = UUID()
        presenter.present(id: offer, parentID: nil, content: AnyView(Text("Offer")), reduceMotion: true)
        let handedOff = expectation(description: "Marker placement handoff")
        presenter.dismiss(id: offer, reduceMotion: true) {
            XCTAssertFalse(presenter.isPresenting)
            presenter.present(id: placement, parentID: nil, content: AnyView(Text("Place marker")), reduceMotion: true)
            handedOff.fulfill()
        }
        await fulfillment(of: [handedOff], timeout: 1)
        XCTAssertEqual(presenter.entries.map(\.id), [placement])
        XCTAssertEqual(presenter.activeID, placement)
    }

    func testReopenedOwnerIsNotRemovedByAnEarlierDismissalCompletion() async throws {
        let presenter = PaperPanelPresenter()
        let owner = UUID()
        presenter.present(id: owner, parentID: nil, content: AnyView(Text("Old offer")), reduceMotion: false)
        presenter.dismiss(id: owner, reduceMotion: false, onDismiss: nil)
        presenter.present(id: owner, parentID: nil, content: AnyView(Text("Current offer")), reduceMotion: false)
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(presenter.entries.map(\.id), [owner])
        XCTAssertEqual(presenter.activeID, owner)
        XCTAssertTrue(presenter.isPresenting)
    }
}

@MainActor
@Observable
private final class PracticePanelRefreshState {
    var showsPractice = true
    var textSize = DynamicTypeSize.large
    var session: TutorialSession?
    var presenter: PaperPanelPresenter?
}

@MainActor
@Observable
private final class NestedPracticeRefreshState {
    var showsSettings = true
    var textSize = DynamicTypeSize.large
    var settingsMountCount = 0
    var openPractice: (() -> Void)?
    let practiceState = PracticePanelRefreshState()
}

private struct NestedPracticeRefreshHarness: View {
    @Bindable var state: NestedPracticeRefreshState
    let practice: TutorialPractice
    let settingsOpened: () -> Void
    let practiceOpened: () -> Void
    let refreshed: () -> Void

    var body: some View {
        Color.clear
            .paperPanel(isPresented: $state.showsSettings) {
                SettingsNavigationHost { destination in
                    PaperSlip(title: "Settings", subtitle: nil, onClose: {}) {
                        NestedPracticeNavigation(state: state, destination: destination,
                                                 settingsOpened: settingsOpened)
                    }
                } panel: { _ in
                    PracticePanelRefreshProbe(state: state.practiceState, practice: practice,
                                              opened: practiceOpened, refreshed: refreshed)
                }
                .onAppear { state.settingsMountCount += 1 }
            }
            .environment(\.dynamicTypeSize, state.textSize)
            .paperPanelHost()
    }
}

private struct NestedPracticeNavigation: View {
    let state: NestedPracticeRefreshState
    @Binding var destination: SettingsDestination?
    let settingsOpened: () -> Void

    var body: some View {
        Button("Replay tutorial") { destination = .practice }
            .onAppear {
                guard state.openPractice == nil else { return }
                state.openPractice = { destination = .practice }
                settingsOpened()
            }
    }
}

private struct PracticePanelRefreshHarness: View {
    @Bindable var state: PracticePanelRefreshState
    let practice: TutorialPractice
    let opened: () -> Void
    let refreshed: () -> Void

    var body: some View {
        Color.clear
            .paperPanel(isPresented: $state.showsPractice) {
                PracticePanelRefreshProbe(state: state, practice: practice,
                                          opened: opened, refreshed: refreshed)
            }
            .environment(\.dynamicTypeSize, state.textSize)
            .paperPanelHost()
    }
}

private struct PracticePanelRefreshProbe: View {
    let state: PracticePanelRefreshState
    let opened: () -> Void
    let refreshed: () -> Void
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.paperPanelPresenter) private var presenter
    @State private var session: TutorialSession

    init(state: PracticePanelRefreshState, practice: TutorialPractice,
         opened: @escaping () -> Void, refreshed: @escaping () -> Void) {
        self.state = state
        self.opened = opened
        self.refreshed = refreshed
        _session = State(initialValue: TutorialSession(practice: practice))
    }

    var body: some View {
        TutorialLessonPage(session: session, presentation: .replay)
            .onChange(of: textSize, initial: true) { _, newSize in
                state.session = session
                state.presenter = presenter
                if newSize == .large { opened() }
                if newSize == .accessibility3 { refreshed() }
            }
            .onDisappear { session.stop() }
    }
}

@MainActor
@Observable
private final class NestedPanelState {
    var showsHelp = true
    var showsTopics = false
    var helpPresenter: PaperPanelPresenter?
    var topicsPresenter: PaperPanelPresenter?
    var topicsTheme: CosmeticTheme?
    var topicsSize = CGSize.zero
    var dismissTopics: PaperPanelDismissAction?
}

private struct NestedPanelHarness: View {
    @Bindable var state: NestedPanelState
    let helpReady: () -> Void
    let topicsReady: () -> Void
    let topicsClosed: () -> Void

    var body: some View {
        Color.clear
            .frame(width: 200, height: 160)
            .paperPanel(isPresented: $state.showsHelp) {
                NestedSettingsHelp(state: state, helpReady: helpReady,
                                   topicsReady: topicsReady, topicsClosed: topicsClosed)
            }
            .frame(width: 320, height: 640)
            .paperPanelHost()
    }
}

private struct NestedSettingsHelp: View {
    @Bindable var state: NestedPanelState
    @Environment(\.paperPanelPresenter) private var presenter
    let helpReady: () -> Void
    let topicsReady: () -> Void
    let topicsClosed: () -> Void

    var body: some View {
        SettingsDestinationPresentation(destination: .guide)
            .paperPanel(isPresented: $state.showsTopics, onDismiss: topicsClosed) {
                NestedTopicsProbe(state: state, ready: topicsReady)
            }
            .onAppear {
                state.helpPresenter = presenter
                helpReady()
            }
    }
}

private struct NestedTopicsProbe: View {
    @Bindable var state: NestedPanelState
    @Environment(\.paperPanelPresenter) private var presenter
    @Environment(\.paperPanelDismiss) private var dismiss
    @Environment(\.cosmeticTheme) private var theme
    let ready: () -> Void

    var body: some View {
        PaperSlip(title: "Topics", subtitle: nil, onClose: { dismiss() }) {
            Text("Placement")
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { size in
            guard size.width > 0, size.height > 0, state.topicsPresenter == nil else { return }
            state.topicsPresenter = presenter
            state.topicsTheme = theme
            state.topicsSize = size
            state.dismissTopics = dismiss
            ready()
        }
    }
}
