import SwiftUI

@main
struct ProbablySudokuApp: App {
    @State private var profile = PlayerProfileStore.shared
    @State private var gameCenter = GameCenterService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.processInfo.arguments.contains("-clubShop") {
                    ClubShopView(onBack: {})
                } else {
                    ContentView()
                }
            }
            .environment(profile)
            .environment(gameCenter)
            .environment(\.cosmeticTheme, profile.theme)
            .task {
                gameCenter.start()
                gameCenter.setAppIsActive(scenePhase == .active)
                CloudSync.shared.start { remote in
                    PlayerProfileStore.shared.merge(remote: remote)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                gameCenter.setAppIsActive(newPhase == .active)
            }
        }
    }
}
