import SwiftUI
import AppKit
import ServiceManagement

enum AppEvents {
    static let showDiagnostics = Notification.Name("fm.listenscrobbler.showDiagnostics")
}

@main
struct ListenScrobblerApp: App {
    @StateObject private var scrobbleService = ScrobbleService()
    @StateObject private var launchAtLoginController = LaunchAtLoginController()
    @StateObject private var proxySettingsController = ProxySettingsController()
    @Environment(\.openWindow) private var openWindow
    @AppStorage("ui.showDockIcon") private var showDockIcon = true
    @AppStorage("app.launchAtLogin") private var launchAtLoginEnabled = false
    @State private var handledInitialWindowPresentation = false

    var body: some Scene {
        Window("ListenScrobbler", id: "main") {
            ContentView()
                .environmentObject(scrobbleService)
                .environmentObject(launchAtLoginController)
                .environmentObject(proxySettingsController)
                .frame(minWidth: 760, minHeight: 560)
                .onAppear {
                    applyDockIconVisibility()
                    handleInitialWindowPresentation()
                }
                .onChange(of: showDockIcon) { _ in
                    applyDockIconVisibility()
                }
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("Tools") {
                Button(showDockIcon ? "Switch To Menu Bar Only" : "Show Dock Icon") {
                    toggleDockIconVisibility()
                }
                .keyboardShortcut("m", modifiers: [.command, .option])
            }

            CommandGroup(replacing: .help) {
                Button("ListenScrobbler Help") {
                    openExternalURL(AppLinks.userGuide)
                }
                .keyboardShortcut("?", modifiers: [.command])

                Button("ListenBrainz Token Page") {
                    openExternalURL(AppLinks.listenBrainzToken)
                }

                Button("Report an Issue") {
                    openExternalURL(AppLinks.issues)
                }
            }
        }

        MenuBarExtra {
            MenuBarPanel(
                scrobbleService: scrobbleService,
                showDockIcon: showDockIcon,
                toggleDockIconVisibility: toggleDockIconVisibility,
                openMainWindow: openMainWindow,
                openLegacySettingsWindow: openLegacySettingsWindow,
                quitApp: quitApp
            )
        } label: {
            MenuBarStatusIcon(isEnabled: scrobbleService.scrobblingEnabled)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(scrobbleService)
                .environmentObject(launchAtLoginController)
                .environmentObject(proxySettingsController)
                .frame(minWidth: 760, minHeight: 520)
        }
    }

    private func toggleDockIconVisibility() {
        showDockIcon.toggle()
        applyDockIconVisibility()
    }

    private func applyDockIconVisibility() {
        // `.regular` shows Dock icon + app switcher presence.
        // `.accessory` keeps the app alive as menu-bar-focused without Dock icon.
        let targetPolicy: NSApplication.ActivationPolicy = showDockIcon ? .regular : .accessory
        guard NSApp.activationPolicy() != targetPolicy else { return }
        NSApp.setActivationPolicy(targetPolicy)
    }

    private func showDiagnosticsInMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: AppEvents.showDiagnostics, object: nil)
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openLegacySettingsWindow() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func quitApp() {
        NSApp.terminate(nil)
    }

    private func openExternalURL(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func handleInitialWindowPresentation() {
        guard !handledInitialWindowPresentation else { return }
        handledInitialWindowPresentation = true

        // Login-launched apps are typically not the active app when they finish
        // booting. Use that as a best-effort signal to keep startup silent when
        // the user asked for menu-bar-only mode.
        guard launchAtLoginEnabled, !showDockIcon else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard !NSApp.isActive else { return }
            NSApp.windows
                .first(where: { $0.identifier?.rawValue == "main" || $0.title == "ListenScrobbler" })?
                .orderOut(nil)
        }
    }
}

private enum AppLinks {
    static let userGuide = URL(string: "https://github.com/kubrick06010/ListenScrobbler/blob/main/docs/USER_GUIDE.md")!
    static let listenBrainzToken = URL(string: "https://listenbrainz.org/profile/")!
    static let issues = URL(string: "https://github.com/kubrick06010/ListenScrobbler/issues")!
}

private struct MenuBarStatusIcon: View {
    let isEnabled: Bool

    var body: some View {
        // Render explicit enabled/disabled bitmap states so the menu bar icon
        // changes reliably instead of depending on template tint handling.
        Image(nsImage: menuBarStatusImage(isEnabled: isEnabled))
            .frame(width: 18, height: 18)
            .accessibilityLabel(isEnabled ? "Listening submissions enabled" : "Listening submissions disabled")
    }

    private func menuBarStatusImage(isEnabled: Bool) -> NSImage {
        guard let base = NSImage(named: "MenuBarScrobbler") else {
            return NSImage()
        }
        let source = base.copy() as? NSImage ?? base
        if isEnabled {
            source.isTemplate = true
            return source
        }
        source.isTemplate = false
        return source.tinted(with: NSColor(calibratedWhite: 0.78, alpha: 1))
    }
}

private struct MenuBarPanel: View {
    @ObservedObject var scrobbleService: ScrobbleService
    let showDockIcon: Bool
    let toggleDockIconVisibility: () -> Void
    let openMainWindow: () -> Void
    let openLegacySettingsWindow: () -> Void
    let quitApp: () -> Void

    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            nowPlayingHeader

            Divider()

            Toggle(isOn: Binding(
                get: { scrobbleService.scrobblingEnabled },
                set: { enabled in
                    if enabled != scrobbleService.scrobblingEnabled {
                        scrobbleService.toggleScrobbling()
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Listening Submissions")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                    Text(scrobbleService.scrobblingEnabled ? "Enabled" : "Disabled")
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)

            if let username = scrobbleService.sessionUsername, !username.isEmpty {
                accountSection(username: username)
            }

            LazyVGrid(columns: gridColumns, spacing: 8) {
                commandButton(showDockIcon ? "Menu Bar Only" : "Show Dock", systemImage: "rectangle.on.rectangle") {
                    toggleDockIconVisibility()
                }
                commandButton("Open App", systemImage: "macwindow") {
                    openMainWindow()
                }
                settingsButton
                commandButton("Quit", systemImage: "power") {
                    quitApp()
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var nowPlayingHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            menuArtwork

            VStack(alignment: .leading, spacing: 4) {
                Text(trackTitle)
                    .font(.custom("Avenir Next Demi Bold", size: 15))
                    .lineLimit(2)

                Text(trackSubtitle)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if let source = scrobbleService.currentTrack?.sourceApp, !source.isEmpty {
                    Text(source.uppercased())
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(.orange)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var menuArtwork: some View {
        Group {
            if let url = resolvedArtworkURL, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 54, height: 54)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var placeholderArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
            Image(systemName: "music.note")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func accountSection(username: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Listener")
                .font(.custom("Avenir Next Demi Bold", size: 12))
            HStack {
                Text(username)
                    .font(.custom("Avenir Next Medium", size: 13))
                Spacer()
                Text("Single account")
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func commandButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            commandLabel(title: title, systemImage: systemImage)
        }
        .buttonStyle(.plain)
    }

    private var settingsButton: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    commandLabel(title: "Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    openLegacySettingsWindow()
                } label: {
                    commandLabel(title: "Settings", systemImage: "gearshape")
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func commandLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var trackTitle: String {
        scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title ?? "No track playing"
    }

    private var trackSubtitle: String {
        guard let currentTrack = scrobbleService.currentTrack else {
            return scrobbleService.sessionUsername.map { "Signed in as \($0)" }
                ?? scrobbleService.listenBrainzUsername.map { "ListenBrainz: \($0)" }
                ?? "Waiting for playback"
        }

        let artist = scrobbleService.currentTrackDetails?.artist ?? currentTrack.artist
        if let album = scrobbleService.currentTrackDetails?.album ?? currentTrack.album, !album.isEmpty {
            return "\(artist) — \(album)"
        }
        return artist
    }

    private var resolvedArtworkURL: String? {
        if let explicit = scrobbleService.currentTrackDetails?.imageURL, !explicit.isEmpty {
            return explicit
        }
        if let localArtwork = scrobbleService.currentTrack?.artworkURL, !localArtwork.isEmpty {
            return localArtwork
        }
        if let openArtwork = scrobbleService.currentOpenEntityDetails?.imageURL, !openArtwork.isEmpty {
            return openArtwork
        }
        if let artistImage = scrobbleService.currentArtistDetails?.imageURL, !artistImage.isEmpty {
            return artistImage
        }
        return nil
    }
}

private extension NSImage {
    func tinted(with color: NSColor) -> NSImage {
        let image = copy() as? NSImage ?? self
        let result = NSImage(size: image.size)
        result.lockFocus()
        let rect = NSRect(origin: .zero, size: image.size)
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        result.unlockFocus()
        result.isTemplate = false
        return result
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Diagnostics")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                GroupBox("Session") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Backend", scrobbleService.backendName)
                        diagnosticsRow("Auth", scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")
                        diagnosticsRow("Session", scrobbleService.sessionStatus)
                        diagnosticsRow("ListenBrainz", scrobbleService.listenBrainzStatus)
                        diagnosticsRow("ListenBrainz Charts", scrobbleService.listenBrainzStatsStatus)
                        diagnosticsRow("Capabilities", scrobbleService.capabilitiesStatus)
                        diagnosticsRow("Validation Source", scrobbleService.validationSource)
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                GroupBox("Playback") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Monitor", scrobbleService.monitorStatus)
                        diagnosticsRow("State", scrobbleService.playbackState)
                        diagnosticsRow("Elapsed", "\(Int(scrobbleService.elapsedForCurrentTrack))s")
                        diagnosticsRow("Threshold", "\(Int(scrobbleService.scrobbleThreshold))s")
                        diagnosticsRow("Now Playing Delay", "\(scrobbleService.nowPlayingDelaySeconds)s")
                        diagnosticsRow("Player Events", "\(scrobbleService.playerEventCount)")
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                GroupBox("Queue And Retry") {
                    VStack(alignment: .leading, spacing: 8) {
                        diagnosticsRow("Queued Tracks", "\(scrobbleService.queuedScrobbles.count)")
                        diagnosticsRow("Queued Jobs", "\(scrobbleService.queuedSubmissionJobs.count)")
                        diagnosticsRow("Submit Attempts", "\(scrobbleService.queueSubmitAttempts)")
                        diagnosticsRow("Submit Failures", "\(scrobbleService.queueSubmitFailures)")
                        diagnosticsRow("Retry Delay", "\(scrobbleService.retryDelaySeconds)s")
                        diagnosticsRow("Retry Scheduled", scrobbleService.isRetryScheduled ? "Yes" : "No")
                        diagnosticsRow("Queue File", scrobbleService.queueFilePath)
                        if let lastSubmittedAt = scrobbleService.lastSubmittedAt {
                            diagnosticsRow("Last Submit", lastSubmittedAt.formatted())
                        }
                        if let nextRetryAt = scrobbleService.nextRetryAt {
                            diagnosticsRow("Next Retry", nextRetryAt.formatted())
                        }

                        HStack(spacing: 10) {
                            Button("Retry now") {
                                Task { await scrobbleService.retryQueueNow() }
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Clear queue") {
                                scrobbleService.clearQueue()
                            }
                            .buttonStyle(.bordered)
                            .disabled(scrobbleService.queuedScrobbles.isEmpty)
                        }
                        .padding(.top, 4)
                    }
                    .font(.custom("Avenir Next Medium", size: 12))
                    .padding(.top, 2)
                }

                if let apiError = scrobbleService.lastAPIError {
                    GroupBox("Last API Error") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(apiError)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.red)
                            if let hint = scrobbleService.lastRecoveryHint {
                                Text(hint)
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
            }
            .padding(20)
        }
    }

    private func diagnosticsRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(key)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}
