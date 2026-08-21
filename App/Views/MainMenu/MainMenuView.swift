import SwiftUI

/// The club room. Where the app opens.
///
/// Everything on this screen is drawn: the wall, the cabinet, the lamp, the
/// plaque, the tiles, the buttons and the note. Nothing is a photograph of an
/// interface, so nothing has a word baked into it, and the composition holds
/// from the smallest phone to the largest because the objects are placed by
/// proportion rather than by pixel.
///
/// The scene spends its motion on one thing — the board of numbers under the
/// lamp. The room around it moves so little that you should feel it before you
/// can point at it.
struct MainMenuView: View {
    var onPlay: () -> Void
    var onShop: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppPreferences.Key.ambientMotion) private var ambientMotion = true

    /// One clock for the whole room, counted the way the shelf counts its own:
    /// linear, never reversed, and every movement taken from a sine of it, so
    /// nothing stalls at either end of the cycle.
    @State private var roomPhase: Double = 0
    /// 0 to 1 across the first three-quarters of a second.
    @State private var entrance: Double = 0
    @State private var revealed = false
    @State private var controlsEnabled = false
    /// Play has been pressed and the room is on its way out.
    @State private var leaving = false
    @State private var showingSettings = false

    /// The full entrance is worth watching once. Coming back from the shelf or
    /// closing the settings slip should not make anyone sit through it again.
    private enum Session {
        static var hasEntered = false
    }

    private var allowsAmbientMotion: Bool { !reduceMotion && ambientMotion }
    /// What the room's own clock reads. Frozen at zero when ambient motion is
    /// off, which leaves every drift, sheen and mote at its resting value.
    private var phase: Double { allowsAmbientMotion ? roomPhase : 0 }

    var body: some View {
        GeometryReader { proxy in
            let metrics = MainMenuSceneMetrics(size: proxy.size,
                                               safeArea: proxy.safeAreaInsets)
            ZStack(alignment: .topLeading) {
                // 00–07: the room.
                ClubRoomBackdrop(metrics: metrics, phase: phase,
                                 reduceMotion: !allowsAmbientMotion)

                // 05: the cone of light in the air, behind everything solid.
                LampLighting(metrics: metrics)
                BulbGlow(phase: phase, centre: metrics.bulbCentre, scale: metrics.scale)

                // 06: what the things standing on the desk put on the desk.
                // Drawn here — between the surface and the objects — so their
                // top edges are the contact plane itself.
                deskContactShadows(metrics: metrics)
                    .opacity(leaving ? 0 : 1)

                // 08–15: the interface, which leaves as one thing when Play is
                // pressed.
                interface(metrics: metrics)
                    .offset(y: leaving ? -6 : 0)
                    .opacity(leaving ? 0 : 1)

                // 17: the lamp again, this time falling across the plaque, the
                // board and the controls, so the room and the interface are
                // lit by the same bulb.
                LampSurfaceLight(metrics: metrics)
                if allowsAmbientMotion {
                    DustMotes(phase: roomPhase, bulb: metrics.bulbCentre,
                              reach: metrics.boardFrame.maxY - metrics.bulbCentre.y,
                              spread: metrics.width * 0.30)
                }

                // 16–18: what the room puts in front of everything.
                ClubRoomForeground(metrics: metrics, phase: phase,
                                   reduceMotion: !allowsAmbientMotion)

                // 19: the gear.
                SettingsButton(metrics: metrics) {
                    withAnimation(.snappy(duration: 0.22)) { showingSettings = true }
                }
                .frame(width: metrics.settingsFrame.width, height: metrics.settingsFrame.height)
                .position(x: metrics.settingsFrame.midX, y: metrics.settingsFrame.midY)
                .opacity(revealed ? 1 : 0)
                .disabled(!controlsEnabled || leaving)
                .animation(entranceAnimation(delay: 0.48), value: revealed)
                .accessibilitySortPriority(1)

                // 20: settings, laid on the desk under a warmer light.
                if showingSettings {
                    ClubRoomMaterial.lampWarm.opacity(0.07)
                        .ignoresSafeArea()
                        .transition(.opacity)
                    AppSettingsSlip(onOpenShop: {
                        withAnimation(.snappy(duration: 0.2)) { showingSettings = false }
                        onShop()
                    }) {
                        withAnimation(.snappy(duration: 0.2)) { showingSettings = false }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .ignoresSafeArea()
        .background(Paper.deskDark)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .animation(.snappy(duration: 0.22), value: showingSettings)
        .onAppear { arrive() }
        .task {
            #if DEBUG
            // `-menuSettings` opens the slip on launch, so it can be
            // photographed without a finger on the glass.
            if ProcessInfo.processInfo.arguments.contains("-menuSettings") {
                try? await Task.sleep(for: .milliseconds(700))
                withAnimation(.snappy(duration: 0.22)) { showingSettings = true }
            }
            // `-tapPlay` presses Play, so the whole route can be walked
            // without a finger on the glass.
            if ProcessInfo.processInfo.arguments.contains("-tapPlay") {
                try? await Task.sleep(for: .milliseconds(900))
                startPlaying()
            }
            if ProcessInfo.processInfo.arguments.contains("-tapShop") {
                try? await Task.sleep(for: .milliseconds(900))
                onShop()
            }
            #endif
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Nothing should be driving a display link behind the home screen.
            if newPhase == .active { startRoomClock() } else { stopRoomClock() }
        }
        .onDisappear { stopRoomClock() }
    }

    /// Every footprint on the desk, placed against the desk's own plane rather
    /// than against the frame of the thing casting it.
    @ViewBuilder
    private func deskContactShadows(metrics: MainMenuSceneMetrics) -> some View {
        let plane = metrics.deskContactY

        contactShadow(width: metrics.boardFrame.width * 1.02,
                      centreX: metrics.boardFrame.midX, plane: plane, metrics: metrics)

        if !metrics.isCompact {
            contactShadow(width: metrics.leftPropsFrame.width * 0.80,
                          centreX: metrics.leftPropsFrame.midX - metrics.leftPropsFrame.width * 0.08,
                          plane: plane, metrics: metrics)
        }
    }

    private func contactShadow(width: CGFloat, centreX: CGFloat, plane: CGFloat,
                               metrics: MainMenuSceneMetrics) -> some View {
        let height = DeskContactShadow.height(for: width)
        return DeskContactShadow(width: width, scale: metrics.scale)
            .position(x: centreX, y: plane + height / 2)
    }

    // MARK: The interface

    @ViewBuilder
    private func interface(metrics: MainMenuSceneMetrics) -> some View {
        let scale = metrics.scale

        // 08 — the sign.
        ClubTitlePlaque(metrics: metrics, phase: phase, reduceMotion: !allowsAmbientMotion)
            .frame(width: metrics.titlePlaqueFrame.width,
                   height: metrics.titlePlaqueFrame.height)
            .position(x: metrics.titlePlaqueFrame.midX, y: metrics.titlePlaqueFrame.midY)
            .offset(y: revealed ? 0 : -6 * scale)
            .opacity(revealed ? 1 : 0)
            .animation(entranceAnimation(delay: 0.12), value: revealed)
            .accessibilitySortPriority(5)

        // 09 — the strip under it.
        ClubSubtitlePlaque(metrics: metrics)
            .position(x: metrics.subtitlePlaqueFrame.midX, y: metrics.subtitlePlaqueFrame.midY)
            .opacity(revealed ? 1 : 0)
            .animation(entranceAnimation(delay: 0.20), value: revealed)
            .accessibilitySortPriority(4)

        // 10 — the pencils and the succulent, at the left edge of the desk.
        if !metrics.isCompact {
            LeftDeskProps(scale: scale, showPencils: !metrics.isVeryCompact)
                .frame(width: metrics.leftPropsFrame.width,
                       height: metrics.leftPropsFrame.height)
                .position(x: metrics.leftPropsFrame.midX, y: metrics.leftPropsFrame.midY)
                .opacity(revealed ? 1 : 0)
                .animation(entranceAnimation(delay: 0.10), value: revealed)
        }

        // 11 — the signature.
        NumberTileBoard(phase: phase, entrance: entrance, reduceMotion: reduceMotion)
            .frame(width: metrics.boardFrame.width, height: metrics.boardFrame.height)
            .position(x: metrics.boardFrame.midX, y: metrics.boardFrame.midY)

        // 13 — Play.
        MainMenuButton(kind: .play, title: "Play", symbol: "play.fill",
                       metrics: metrics, phase: phase,
                       reduceMotion: !allowsAmbientMotion,
                       accessibilityHint: "Choose a Book or continue your current Book",
                       isEnabled: controlsEnabled && !leaving,
                       isHeld: leaving,
                       action: startPlaying)
            .frame(width: metrics.playFrame.width, height: metrics.playFrame.height)
            .position(x: metrics.playFrame.midX, y: metrics.playFrame.midY)
            .offset(y: revealed ? 0 : 8 * scale)
            .opacity(revealed ? 1 : 0)
            .animation(entranceAnimation(delay: 0.55), value: revealed)
            .accessibilitySortPriority(3)

        // 14 — Shop.
        MainMenuButton(kind: .shop, title: "Shop", symbol: "basket.fill",
                       metrics: metrics, phase: phase,
                       reduceMotion: !allowsAmbientMotion,
                       accessibilityHint: "Buy and equip permanent visual skins",
                       isEnabled: controlsEnabled && !leaving,
                       action: onShop)
            .frame(width: metrics.shopFrame.width, height: metrics.shopFrame.height)
            .position(x: metrics.shopFrame.midX, y: metrics.shopFrame.midY)
            .offset(y: revealed ? 0 : 6 * scale)
            .opacity(revealed ? 1 : 0)
            .animation(entranceAnimation(delay: 0.65), value: revealed)
            .accessibilitySortPriority(2)

        // 15 — the note. Overlapping the Shop panel's corner, and never its
        // label or its target.
        HumourNote(metrics: metrics)
            .position(x: metrics.humourNoteFrame.midX, y: metrics.humourNoteFrame.midY)
            .opacity(revealed ? 1 : 0)
            .scaleEffect(revealed ? 1 : 0.97)
            .animation(entranceAnimation(delay: 0.74), value: revealed)
            .allowsHitTesting(false)
            .accessibilitySortPriority(0)
    }

    // MARK: Arriving and leaving

    private func entranceAnimation(delay: Double) -> Animation {
        guard !reduceMotion else { return .easeOut(duration: 0.18) }
        guard !Session.hasEntered else { return .easeOut(duration: 0.2) }
        return .spring(response: 0.34, dampingFraction: 0.86).delay(delay)
    }

    private func arrive() {
        startRoomClock()
        Haptics.prepare()

        let returning = Session.hasEntered
        Session.hasEntered = true

        guard !reduceMotion, !returning else {
            // Reduced Motion, or a second visit: everything is already where
            // it belongs.
            entrance = 1
            revealed = true
            controlsEnabled = true
            return
        }

        entrance = 0
        withAnimation(.linear(duration: 0.72)) { entrance = 1 }
        revealed = true

        Task { @MainActor in
            // Play is reachable well before the last of the room has settled.
            try? await Task.sleep(for: .milliseconds(500))
            controlsEnabled = true
        }
    }

    private func startRoomClock() {
        guard allowsAmbientMotion, !leaving else { return }
        roomPhase = 0
        withAnimation(.linear(duration: 18).repeatForever(autoreverses: false)) {
            roomPhase = 1
        }
    }

    /// Takes the repeating animation off the clock. Without this the room goes
    /// on turning behind the shelf, the Book and the home screen.
    private func stopRoomClock() {
        withAnimation(.linear(duration: 0)) { roomPhase = 0 }
    }

    /// Play: the panel goes down, the board takes the light for a moment, and
    /// the room lifts and fades off the shelf.
    ///
    /// The Book-opening animation does not belong here. That happens when a
    /// Book is chosen, which has not happened yet.
    private func startPlaying() {
        guard !leaving else { return }
        controlsEnabled = false
        stopRoomClock()

        Task { @MainActor in
            // The press is seen before anything routes.
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeInOut(duration: reduceMotion ? 0.15 : 0.30)) {
                leaving = true
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 160 : 300))
            onPlay()
        }
    }
}
#Preview("Main menu") {
    MainMenuView(onPlay: {}, onShop: {})
}
