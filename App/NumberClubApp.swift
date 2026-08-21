import SwiftUI

@main
struct NumberClubApp: App {
    @State private var profile = PlayerProfileStore.shared

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
            .environment(\.cosmeticTheme, profile.theme)
        }
    }
}
