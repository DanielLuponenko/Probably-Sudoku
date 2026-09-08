import SwiftUI

/// Explicit dashboard controls replace the native floating access-point badge.
struct GameCenterSection: View {
    let service: GameCenterService
    @State private var showingNotice = false
    @State private var dashboardResult = GameCenterService.DashboardResult.requested

    var body: some View {
        SlipSection(title: "Game Center", note: service.isAuthenticated
                    ? "Signed in. Your progress is also saved in the game."
                    : "Optional. Sign in to Game Center for online rankings and achievements.") {
            dashboardButton("Leaderboards", dashboard: .leaderboards)
                .accessibilityIdentifier("settings.gameCenter.leaderboards")
                .accessibilityHint("Opens Apple's Game Center leaderboards.")
            dashboardButton("Game Center achievements", dashboard: .achievements)
                .accessibilityIdentifier("settings.gameCenter.achievements")
                .accessibilityHint("Opens Apple's Game Center achievements. Your local collection remains available without signing in.")
        }
        .font(Print.body(14))
        .foregroundStyle(Paper.ink)
        .buttonStyle(PressedPaperStyle())
        .alert("Game Center", isPresented: $showingNotice) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(dashboardResult == .signInRequired
                 ? "Sign in from iOS Settings → Game Center, then return here. You can keep playing without signing in."
                 : "Game Center could not open right now. Try again when the game is active. Your progress is safe.")
        }
    }

    private func dashboardButton(_ title: String, dashboard: GameCenterService.Dashboard) -> some View {
        Button { open(dashboard) } label: {
            Text(title)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(.rect)
        }
    }

    private func open(_ dashboard: GameCenterService.Dashboard) {
        dashboardResult = service.openDashboard(dashboard)
        showingNotice = dashboardResult != .requested
    }
}
