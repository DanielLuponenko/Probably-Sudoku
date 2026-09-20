import XCTest
import SwiftUI
import UIKit
import Observation
import ProbablySudokuEngine
@testable import ProbablySudoku

@MainActor
final class GameMotionPreferencesTests: XCTestCase {
    func testFreshAndExistingPlayersGetFullMotionRegardlessOfInheritedMotionOrBackgroundPreference() async throws {
        for inheritedReduced in [false, true] {
            try await withDefaults { defaults in
                defaults.set(false, forKey: AppPreferences.Key.ambientMotion)
                defaults.set(false, forKey: AppPreferences.Key.haptics)
                try await withHost(defaults: defaults, inheritedReduced: inheritedReduced) { state in
                    try await waitFor { state.readings["game"]?.reduced == false }
                    XCTAssertEqual(state.readings["game"]?.textSize, .accessibility5)
                    XCTAssertNil(defaults.object(forKey: AppPreferences.Key.reducedMotion),
                                 "An inherited motion preference must not be imported into the game's new choice")
                    XCTAssertFalse(defaults.bool(forKey: AppPreferences.Key.ambientMotion))
                    XCTAssertFalse(defaults.bool(forKey: AppPreferences.Key.haptics))
                }
            }
        }
    }

    func testSavedReducedMotionChoiceWinsOverInheritedMotionAndSurvivesRemounting() async throws {
        try await withDefaults { defaults in
            for choice in [true, false] {
                defaults.set(choice, forKey: AppPreferences.Key.reducedMotion)
                for inheritedReduced in [false, true] {
                    try await withHost(defaults: defaults, inheritedReduced: inheritedReduced) { state in
                        try await waitFor { state.readings["game"]?.reduced == choice }
                        XCTAssertEqual(defaults.bool(forKey: AppPreferences.Key.reducedMotion), choice)
                    }
                }
            }
        }
    }

    func testLiveChangesReachOpenNestedPanelsWithoutResettingGameOrPresentationIdentity() async throws {
        try await withDefaults { defaults in
            try await withHost(defaults: defaults, inheritedReduced: true) { state in
                try await waitFor { state.readings["game"] != nil }
                let identity = try XCTUnwrap(state.readings["game"]?.identity)
                let game = try state.model.game.encoded()
                state.showsSettings = true
                try await waitFor { state.readings["settings"]?.reduced == false }
                state.showsDetail = true
                try await waitFor { state.readings["detail"]?.reduced == false }
                let presenter = try XCTUnwrap(state.presenter)
                let entries = presenter.entries.map(\.id)
                XCTAssertEqual(entries.count, 2)
                let panelIdentities = ["settings", "detail"].map { state.readings[$0]?.identity }

                for choice in [true, false, true, false] {
                    defaults.set(choice, forKey: AppPreferences.Key.reducedMotion)
                    try await waitFor {
                        ["game", "settings", "detail"].allSatisfy { state.readings[$0]?.reduced == choice }
                    }
                    XCTAssertEqual(state.readings["game"]?.identity, identity)
                    XCTAssertEqual(["settings", "detail"].map { state.readings[$0]?.identity }, panelIdentities)
                    XCTAssertEqual(presenter.entries.map(\.id), entries)
                    XCTAssertTrue(presenter === state.presenter)
                    XCTAssertEqual(try state.model.game.encoded(), game)
                    XCTAssertEqual(state.model.selectedHandIndex, 0)
                }

                // Incoming environment updates must not replace the saved game choice.
                // Actual iOS Reduce Motion is read-only and covered by native simulator QA.
                state.inheritedReduced = false
                try await Task.sleep(for: .milliseconds(80))
                state.inheritedReduced = true
                try await Task.sleep(for: .milliseconds(80))
                XCTAssertTrue(["game", "settings", "detail"].allSatisfy { state.readings[$0]?.reduced == false })
                XCTAssertEqual(presenter.entries.map(\.id), entries)
                XCTAssertEqual(try state.model.game.encoded(), game)
            }
        }
    }

    private func withDefaults(_ body: (UserDefaults) async throws -> Void) async throws {
        let name = "NumberClub.GameMotionPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        try await body(defaults)
    }

    private func withHost(defaults: UserDefaults, inheritedReduced: Bool,
                          _ body: (MotionPreferenceHarness) async throws -> Void) async throws {
        let state = try MotionPreferenceHarness(inheritedReduced: inheritedReduced)
        let controller = UIHostingController(rootView: MotionPreferenceRoot(state: state, defaults: defaults))
        controller.safeAreaRegions = []
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previous = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        window.rootViewController = controller
        defer {
            state.presenter?.cancelAll()
            window.isHidden = true
            window.rootViewController = nil
            previous?.makeKey()
        }
        window.makeKeyAndVisible()
        try await body(state)
    }

    private func waitFor(_ predicate: () -> Bool) async throws {
        for _ in 0..<100 {
            if predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("The mounted game or its paper panel did not receive the updated motion choice")
        throw MotionPreferenceError.timedOut
    }
}

private enum MotionPreferenceError: Error { case timedOut }

@MainActor @Observable
private final class MotionPreferenceHarness {
    var inheritedReduced: Bool
    var showsSettings = false
    var showsDetail = false
    @ObservationIgnored var readings: [String: MotionPreferenceReading] = [:]
    @ObservationIgnored var presenter: PaperPanelPresenter?
    let model: GameModel

    init(inheritedReduced: Bool) throws {
        self.inheritedReduced = inheritedReduced
        var game = Game(seed: "motion-preference-does-not-change-book")
        try game.startPuzzle()
        model = GameModel(frozen: game, page: .puzzle)
        model.selectedHandIndex = 0
    }
}

private struct MotionPreferenceReading: Equatable {
    let reduced: Bool
    let textSize: DynamicTypeSize
    let identity: UUID
}

private struct MotionPreferenceRoot: View {
    let state: MotionPreferenceHarness
    let defaults: UserDefaults

    var body: some View {
        MotionPreferenceGame(state: state)
            .modifier(GameMotionPreferences())
            .defaultAppStorage(defaults)
            .environment(\.gameReduceMotion, state.inheritedReduced)
            .environment(\.dynamicTypeSize, .accessibility5)
    }
}

private struct MotionPreferenceGame: View {
    @Bindable var state: MotionPreferenceHarness

    var body: some View {
        MotionPreferenceProbe(state: state, name: "game")
            .paperPanel(isPresented: $state.showsSettings) {
                MotionPreferenceProbe(state: state, name: "settings")
                    .paperPanel(isPresented: $state.showsDetail) {
                        MotionPreferenceProbe(state: state, name: "detail")
                    }
            }
            .paperPanelHost()
    }
}

private struct MotionPreferenceProbe: View {
    let state: MotionPreferenceHarness
    let name: String
    @Environment(\.gameReduceMotion) private var reduced
    @Environment(\.dynamicTypeSize) private var textSize
    @Environment(\.paperPanelPresenter) private var presenter
    @State private var identity = UUID()

    var body: some View {
        let reading = MotionPreferenceReading(reduced: reduced, textSize: textSize, identity: identity)
        Text(name)
            .onChange(of: reading, initial: true) { _, latest in
                state.readings[name] = latest
                if let presenter { state.presenter = presenter }
            }
    }
}
