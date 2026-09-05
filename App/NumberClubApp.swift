import SwiftUI

@main
struct ProbablySudokuApp: App {
    @State private var profile = PlayerProfileStore.shared
    @State private var gameCenter = GameCenterService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
            .environment(profile)
            .environment(gameCenter)
            // Core gameplay currently has one fixed visual language. Saved
            // cosmetic selections are intentionally not injected into any
            // gameplay view, so a prior skin can never alter a new Puzzle.
            .environment(\.cosmeticTheme, .standard)
            .task {
                gameCenter.start()
                gameCenter.setAppIsActive(scenePhase == .active)
                CloudSync.shared.start(
                    receivingProfiles: { remote in
                        PlayerProfileStore.shared.merge(remote: remote)
                    },
                    receivingEquipped: { equipped, decisionAt in
                        PlayerProfileStore.shared.applyRemoteEquipped(
                            equipped,
                            decisionAt: decisionAt
                        )
                    }
                )
            }
            .onChange(of: scenePhase) { _, newPhase in
                gameCenter.setAppIsActive(newPhase == .active)
            }
        }
    }
}
