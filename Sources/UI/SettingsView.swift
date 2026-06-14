import SwiftUI

private enum PreferencesSection: String, CaseIterable, Identifiable {
    case general = "General"
    case listenBrainz = "ListenBrainz"
    case network = "Network"
    case advanced = "Advanced"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .general: return "slider.horizontal.3"
        case .listenBrainz: return "waveform.path.ecg.rectangle"
        case .network: return "network"
        case .advanced: return "gearshape.2"
        }
    }

    var subtitle: String {
        switch self {
        case .general:
            return "Startup and app behaviour"
        case .listenBrainz:
            return "Token, now playing, listens, and charts"
        case .network:
            return "Proxy and connectivity"
        case .advanced:
            return "Operational status"
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @EnvironmentObject private var launchAtLoginController: LaunchAtLoginController
    @EnvironmentObject private var proxySettingsController: ProxySettingsController

    @State private var selectedSection: PreferencesSection? = .listenBrainz
    @State private var proxyPortText = ""
    @State private var listenBrainzToken = ""
    @State private var listenBrainzBaseURL = "https://api.listenbrainz.org"
    @State private var listenBrainzEnabled = false
    @State private var listenBrainzSubmitNowPlaying = true
    @State private var listenBrainzSubmitListens = true
    @State private var isOpenMusicOnboardingPresented = false

    var body: some View {
        NavigationSplitView {
            List(PreferencesSection.allCases, selection: $selectedSection) { section in
                Label {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(section.rawValue)
                            .font(.custom("Avenir Next Demi Bold", size: 13))
                        Text(section.subtitle)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: section.symbol)
                }
                .tag(section)
                .padding(.vertical, 3)
            }
            .listStyle(.sidebar)
            .navigationTitle("Preferences")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 240)
        } detail: {
            ScrollView {
                Group {
                    switch selectedSection ?? .general {
                    case .general:
                        generalPane
                    case .listenBrainz:
                        listenBrainzPane
                    case .network:
                        networkPane
                    case .advanced:
                        advancedPane
                    }
                }
                .padding(24)
            }
            .background(Color.clear)
        }
        .sheet(isPresented: $isOpenMusicOnboardingPresented) {
            MacOpenMusicOnboardingView {
                isOpenMusicOnboardingPresented = false
            }
            .frame(width: 760, height: 620)
        }
        .task {
            launchAtLoginController.refreshStatus()
            proxySettingsController.reload()
            proxyPortText = proxySettingsController.settings.port.map(String.init) ?? ""
            reloadListenBrainzForm()
        }
    }

    private var generalPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "General",
                subtitle: "Core app behavior that should stay easy to reach."
            )

            GroupBox("Listening Submissions") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable listening submissions", isOn: Binding(
                        get: { scrobbleService.scrobblingEnabled },
                        set: { _ in scrobbleService.toggleScrobbling() }
                    ))

                    LabeledContent("Now Playing Delay", value: "\(scrobbleService.nowPlayingDelaySeconds)s")
                    LabeledContent("Retry Backoff (current)", value: "\(scrobbleService.retryDelaySeconds)s")
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            GroupBox("Startup") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch at login", isOn: Binding(
                        get: { launchAtLoginController.isEnabled },
                        set: { enabled in
                            Task { await launchAtLoginController.setEnabled(enabled) }
                        }
                    ))
                    .disabled(launchAtLoginController.isApplyingChange)

                    Text("If Dock icon is hidden, the app starts silently in the menu bar on login.")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)

                    LabeledContent("Login Item", value: launchAtLoginController.statusDescription)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var networkPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "Network",
                subtitle: "Corporate-friendly proxy controls applied centrally to music service requests."
            )

            GroupBox("Proxy") {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Proxy Mode", selection: Binding(
                        get: { proxySettingsController.settings.mode },
                        set: { mode in
                            proxySettingsController.settings.mode = mode
                            proxySettingsController.save()
                        }
                    )) {
                        ForEach(ProxyMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if proxySettingsController.settings.usesManualProxy {
                        HStack(spacing: 12) {
                            TextField("Host", text: Binding(
                                get: { proxySettingsController.settings.host },
                                set: { value in
                                    proxySettingsController.settings.host = value
                                    proxySettingsController.save()
                                }
                            ))

                            TextField("Port", text: Binding(
                                get: { proxyPortText },
                                set: { value in
                                    proxyPortText = value
                                    proxySettingsController.settings.port = Int(value)
                                    proxySettingsController.save()
                                }
                            ))
                            .frame(width: 90)
                        }

                        TextField("Username (optional)", text: Binding(
                            get: { proxySettingsController.settings.username },
                            set: { value in
                                proxySettingsController.settings.username = value
                                proxySettingsController.save()
                            }
                        ))

                        SecureField("Password (optional)", text: Binding(
                            get: { proxySettingsController.settings.password },
                            set: { value in
                                proxySettingsController.settings.password = value
                                proxySettingsController.save()
                            }
                        ))
                    }

                    Text(proxySettingsController.statusDescription)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var listenBrainzPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "ListenBrainz",
                subtitle: "The primary ListenScrobbler identity for submissions, charts, and social music data."
            )

            ListenBrainzAccountSetupPanel(
                connectionSummary: scrobbleService.listenBrainzStatus,
                connectedUsername: scrobbleService.listenBrainzUsername,
                hasError: scrobbleService.listenBrainzLastError != nil,
                showOnboarding: {
                    isOpenMusicOnboardingPresented = true
                }
            )

            GroupBox("Connection") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable ListenBrainz", isOn: $listenBrainzEnabled)

                    SecureField("User token", text: $listenBrainzToken)
                    TextField("API base URL", text: $listenBrainzBaseURL)

                    HStack(spacing: 10) {
                        Button("Save & Validate") {
                            Task { await saveListenBrainzSettings(validate: true) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Save") {
                            Task { await saveListenBrainzSettings(validate: false) }
                        }
                        .buttonStyle(.bordered)

                        Button(role: .destructive) {
                            scrobbleService.disconnectListenBrainz()
                            listenBrainzToken = ""
                            reloadListenBrainzForm()
                        } label: {
                            Text("Disconnect")
                        }
                        .buttonStyle(.bordered)
                    }

                    LabeledContent("Status", value: scrobbleService.listenBrainzStatus)
                    if let username = scrobbleService.listenBrainzUsername {
                        LabeledContent("User", value: username)
                    }
                    if let error = scrobbleService.listenBrainzLastError {
                        Text(error)
                            .font(.custom("Avenir Next Regular", size: 12))
                            .foregroundStyle(.red)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            GroupBox("Submissions") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Send now playing", isOn: $listenBrainzSubmitNowPlaying)
                    Toggle("Submit completed listens", isOn: $listenBrainzSubmitListens)

                    Text("ListenBrainz is the primary destination for now playing, completed listens, charts, and open social discovery.")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }
        }
    }

    private var advancedPane: some View {
        VStack(alignment: .leading, spacing: 16) {
            preferencesHeader(
                title: "Advanced",
                subtitle: "Operational state and backend detail. Keep this out of the day-to-day surface area."
            )

            GroupBox("Status") {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Backend", value: scrobbleService.backendName)
                    LabeledContent("Auth State", value: scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")
                    LabeledContent("Session", value: scrobbleService.sessionStatus)
                    LabeledContent("ListenBrainz", value: scrobbleService.listenBrainzStatus)
                    LabeledContent("Capabilities", value: scrobbleService.capabilitiesStatus)
                    LabeledContent("Validation", value: scrobbleService.validationSource)
                }
                .font(.custom("Avenir Next Medium", size: 12))
                .padding(.top, 2)
            }

            if let lastError = launchAtLoginController.lastErrorMessage {
                GroupBox("Warnings") {
                    Text(lastError)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func preferencesHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 24))
            Text(subtitle)
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private func reloadListenBrainzForm() {
        listenBrainzEnabled = scrobbleService.listenBrainzEnabled
        listenBrainzSubmitNowPlaying = scrobbleService.listenBrainzSubmitNowPlaying
        listenBrainzSubmitListens = scrobbleService.listenBrainzSubmitListens
        listenBrainzBaseURL = scrobbleService.listenBrainzBaseURL.absoluteString
    }

    private func saveListenBrainzSettings(validate: Bool) async {
        let fallbackBaseURL = URL(string: "https://api.listenbrainz.org")!
        await scrobbleService.configureListenBrainz(
            token: listenBrainzToken,
            baseURL: URL(string: listenBrainzBaseURL) ?? fallbackBaseURL,
            isEnabled: listenBrainzEnabled,
            submitNowPlaying: listenBrainzSubmitNowPlaying,
            submitListens: listenBrainzSubmitListens
        )
        if validate {
            await scrobbleService.validateListenBrainz()
        }
        listenBrainzToken = ""
        reloadListenBrainzForm()
    }
}
