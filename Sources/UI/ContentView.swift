import SwiftUI
import AppKit

enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
    case dashboard = "Dashboard"
    case queue = "Queue"
    case scrobbles = "Listens"
    case charts = "Charts"
    case social = "Social"
    case shared = "Shared"
    case obsessions = "Obsessions"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .dashboard:
            return "rectangle.3.group.bubble.left"
        case .queue:
            return "text.line.first.and.arrowtriangle.forward"
        case .scrobbles:
            return "music.note.list"
        case .charts:
            return "list.number"
        case .social:
            return "person.3.sequence.fill"
        case .shared:
            return "square.and.arrow.up.on.square"
        case .obsessions:
            return "heart.text.square"
        }
    }
}

struct DeepLinkTarget: Identifiable, Equatable {
    enum Kind: String, Equatable {
        case track
        case artist
        case album
    }

    let id: String
    let scrobble: CompatibilityRecentScrobble
    let kind: Kind
}

// The main UI uses small draft/target values to decouple navigation, sheets,
// and inspector presentation from provider models. When adding a new surface,
// prefer threading one of these lightweight intents through ContentView rather
// than passing service internals deep into child views.
struct SocialGraphTarget: Identifiable, Equatable {
    let id: String
    let user: String
    let profileURL: String?
}

struct ShareDraft: Identifiable, Equatable {
    let id = UUID()
    let kind: SharedMusicEntry.EntityKind
    let artist: String
    let track: String?
    let album: String?
    let sourceURL: String?
    let imageURL: String?
    let artistMBID: String?
    let recordingMBID: String?
    let releaseMBID: String?
}

struct RecommendationComposerDraft: Identifiable, Equatable {
    let recommendation: ListenBrainzRecommendedRecording

    var id: String { recommendation.id }
}

struct ObsessionDraft: Identifiable, Equatable {
    let id = UUID()
    let artist: String
    let track: String
    let album: String?
    let sourceURL: String?
    let imageURL: String?
    let artistMBID: String?
    let recordingMBID: String?
    let releaseMBID: String?
}

func accountBadgeLabel(for normalizedType: String) -> String {
    switch normalizedType {
    case "alum":
        return "ALUM"
    case "subscriber":
        return "SUPPORTER"
    default:
        return normalizedType.uppercased()
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @AppStorage("ui.detailInspectorWidth") private var detailInspectorWidth = 560.0
    @AppStorage("ui.socialInspectorWidth") private var socialInspectorWidth = 860.0
    @AppStorage("experimental.vault.enabled") private var vaultEnabled = true
    @AppStorage("experimental.shared.enabled") private var sharedVaultEnabled = true
    @AppStorage("experimental.obsessions.enabled") private var obsessionsVaultEnabled = true
    @AppStorage("onboarding.openMusic.completed") private var didCompleteOpenMusicOnboarding = false
    @StateObject private var sharedVaultStore = SharedMusicVaultStore()
    @StateObject private var obsessionVaultStore = ObsessionVaultStore()
    @State private var selectedTab: WorkspaceTab? = .dashboard
    @State private var scrobblesQuery = ""
    @State private var recommendationDraft: RecommendationComposerDraft?
    @State private var deepLinkTarget: DeepLinkTarget?
    @State private var socialGraphTarget: SocialGraphTarget?
    @State private var selectedProfileURL: URL?
    @State private var isDiagnosticsPresented = false
    @State private var isOpenMusicOnboardingPresented = false
    @State private var shareDraft: ShareDraft?
    @State private var obsessionDraft: ObsessionDraft?

    var body: some View {
        NavigationSplitView {
            List(availableTabs, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol)
                        .tag(tab)
                        .font(.custom("Avenir Next Medium", size: 13))
            }
            .navigationTitle("ListenScrobbler")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("ListenScrobbler")
                            .font(.custom("Avenir Next Medium", size: 21))
                        Text(nowPlayingSubtitle)
                            .font(.custom("Avenir Next Medium", size: 13))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(appBarBackground)

                GeometryReader { proxy in
                    let availableWidth = proxy.size.width
                    let resolvedDetailWidth = clampedInspectorWidth(
                        preferred: detailInspectorWidth,
                        availableWidth: availableWidth,
                        minimum: 500,
                        maximumRatio: 0.46,
                        hardCap: 860
                    )
                    let resolvedSocialWidth = clampedInspectorWidth(
                        preferred: socialInspectorWidth,
                        availableWidth: availableWidth,
                        minimum: 720,
                        maximumRatio: 0.68,
                        hardCap: 1180
                    )

                    ZStack {
                        AppBackdrop()
                        switch selectedTab ?? .dashboard {
                        case .dashboard:
                            DashboardView(
                                onOpenTrackDetail: { track, artist, album, imageURL in
                                    openDeepLink(track: track, artist: artist, album: album, imageURL: imageURL)
                                },
                                onShareTrack: { draft in
                                    shareDraft = draft
                                },
                                onCaptureObsession: { draft in
                                    obsessionDraft = draft
                                }
                            )
                        case .queue:
                            QueueView()
                        case .scrobbles:
                            ScrobblesView(
                                query: $scrobblesQuery,
                                onOpenDetail: { item in
                                    openDeepLink(scrobble: item)
                                },
                                onShare: { draft in
                                    shareDraft = draft
                                }
                            )
                        case .charts:
                            ChartsView(
                                onOpenTrack: { track, artist in
                                    openDeepLink(track: track, artist: artist)
                                },
                                onOpenArtist: { artist in
                                    openDeepLink(track: nil, artist: artist)
                                },
                                onOpenAlbum: { album, artist, imageURL in
                                    openAlbumDeepLink(album: album, artist: artist, imageURL: imageURL)
                                },
                                onShareListen: { draft in
                                    shareDraft = draft
                                }
                            )
                        case .social:
                            ListenBrainzSocialView(
                                onOpenRecommendation: { recommendation in
                                    openDeepLink(
                                        track: recommendation.title,
                                        artist: recommendation.artistName ?? "Unknown Artist",
                                        imageURL: nil
                                    )
                                },
                                onShareRecommendation: { recommendation in
                                    shareDraft = ShareDraft(
                                        kind: .track,
                                        artist: recommendation.artistName ?? "Unknown Artist",
                                        track: recommendation.title,
                                        album: recommendation.releaseName,
                                        sourceURL: nil,
                                        imageURL: nil,
                                        artistMBID: nil,
                                        recordingMBID: recommendation.recordingMbid,
                                        releaseMBID: nil
                                    )
                                },
                                onRecommendToFollowers: { recommendation in
                                    recommendationDraft = RecommendationComposerDraft(recommendation: recommendation)
                                }
                            )
                        case .shared:
                            SharedVaultView(store: sharedVaultStore)
                        case .obsessions:
                            ObsessionsVaultView(store: obsessionVaultStore)
                        }

                        if let deepLinkTarget {
                            appModalScrim
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        self.deepLinkTarget = nil
                                        scrobbleService.clearInspection()
                                    }
                                }

                            HStack(spacing: 0) {
                                Spacer()
                                InspectorResizeHandle(
                                    width: $detailInspectorWidth,
                                    minimum: 500,
                                    maximum: min(860, availableWidth * 0.46)
                                )
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 12) {
                                        HStack {
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.22)) {
                                                    self.deepLinkTarget = nil
                                                    scrobbleService.clearInspection()
                                                }
                                            } label: {
                                                Label("Back", systemImage: "chevron.left")
                                                    .font(.custom("Avenir Next Medium", size: 14))
                                            }
                                            .buttonStyle(.plain)
                                            Spacer()
                                        }

                                        // Pass the resolved inspector width down so the detail panel
                                        // can reflow against the real container size instead of using
                                        // a GeometryReader inside a ScrollView, which over-reports width
                                        // and leads to unreadable two-column layouts on narrower windows.
                                        ScrobbleDetailPanel(
                                            item: deepLinkTarget.scrobble,
                                            kind: deepLinkTarget.kind,
                                            availableWidth: resolvedDetailWidth - 32,
                                            onShare: { draft in
                                                shareDraft = draft
                                            },
                                            onCaptureObsession: { draft in
                                                obsessionDraft = draft
                                            }
                                        )
                                        .appPanelStyle()
                                    }
                                    .padding(16)
                                }
                                .frame(width: resolvedDetailWidth)
                                .background(appSidebarBackground)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(appDividerColor).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                            .animation(.easeInOut(duration: 0.22), value: deepLinkTarget.id)
                        }

                        if let socialGraphTarget {
                            appModalScrim
                                .ignoresSafeArea()
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.22)) {
                                        self.socialGraphTarget = nil
                                        self.selectedProfileURL = nil
                                    }
                                }

                            HStack(spacing: 0) {
                                Spacer()
                                InspectorResizeHandle(
                                    width: $socialInspectorWidth,
                                    minimum: 720,
                                    maximum: min(1180, availableWidth * 0.68)
                                )
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        Button {
                                            withAnimation(.easeInOut(duration: 0.22)) {
                                                self.socialGraphTarget = nil
                                                self.selectedProfileURL = nil
                                            }
                                        } label: {
                                            Label("Back", systemImage: "chevron.left")
                                                .font(.custom("Avenir Next Medium", size: 14))
                                        }
                                        .buttonStyle(.plain)
                                        Spacer()
                                        Text("Separation Graph: \(socialGraphTarget.user)")
                                            .font(.custom("Avenir Next Demi Bold", size: 16))
                                    }

                                    Text(scrobbleService.separationStatus)
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)

                                    if let graph = scrobbleService.socialGraph, !graph.nodes.isEmpty {
                                        InteractiveSeparationGraphView(graph: graph) { username in
                                            selectedProfileURL = userProfileURL(username: username)
                                        }
                                        .frame(height: 300)
                                        .appPanelStyle()
                                    } else {
                                        Text("No graph data available.")
                                            .font(.custom("Avenir Next Medium", size: 12))
                                            .foregroundStyle(.secondary)
                                            .appPanelStyle()
                                    }

                                    if let selectedProfileURL {
                                        ProfileWebView(url: selectedProfileURL)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    } else {
                                        Text("Click a node to open profile in-app.")
                                            .font(.custom("Avenir Next Medium", size: 12))
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                                            .appPanelStyle()
                                    }
                                }
                                .padding(16)
                                .frame(width: resolvedSocialWidth, height: min(max(760, proxy.size.height - 24), 980))
                                .background(appSidebarBackground)
                                .overlay(alignment: .leading) {
                                    Rectangle().fill(appDividerColor).frame(width: 1)
                                }
                                .transition(.move(edge: .trailing))
                            }
                            .animation(.easeInOut(duration: 0.22), value: socialGraphTarget.id)
                        }
                    }
                }

                VStack(spacing: 0) {
                    settingsFooter
                        .background(appBarBackground)

                    BottomTabShell(selectedTab: Binding(
                        get: { selectedTab ?? .scrobbles },
                        set: { selectedTab = $0 }
                    ))
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: AppEvents.showDiagnostics)) { _ in
            isDiagnosticsPresented = true
        }
        .onAppear {
            configureVaultStores()
            presentOnboardingIfNeeded()
        }
        .onChange(of: scrobbleService.sessionUsername ?? "local") { _ in
            configureVaultStores()
        }
        .onChange(of: selectedTab) { newValue in
            guard newValue == .scrobbles else { return }
            Task {
                await scrobbleService.refreshScrobbles()
            }
        }
        .sheet(isPresented: $isDiagnosticsPresented) {
            DiagnosticsView()
                .environmentObject(scrobbleService)
                .frame(minWidth: 680, minHeight: 520)
        }
        .sheet(isPresented: $isOpenMusicOnboardingPresented) {
            MacOpenMusicOnboardingView {
                didCompleteOpenMusicOnboarding = true
                isOpenMusicOnboardingPresented = false
            }
            .frame(width: 760, height: 620)
        }
        .sheet(item: $shareDraft) { draft in
            ShareComposerView(store: sharedVaultStore, draft: draft) { _ in
                selectedTab = .shared
                shareDraft = nil
            }
            .frame(width: 560, height: 560)
            .padding()
        }
        .sheet(item: $obsessionDraft) { draft in
            ObsessionComposerView(store: obsessionVaultStore, draft: draft) { _ in
                selectedTab = .obsessions
                obsessionDraft = nil
            }
            .frame(width: 560, height: 460)
            .padding()
        }
        .sheet(item: $recommendationDraft) { draft in
            ListenBrainzRecommendationComposerView(recommendation: draft.recommendation) {
                recommendationDraft = nil
                selectedTab = .social
            }
            .environmentObject(scrobbleService)
            .frame(width: 560, height: 620)
            .padding()
        }
    }

    private var availableTabs: [WorkspaceTab] {
        WorkspaceTab.allCases.filter { tab in
            switch tab {
            case .shared:
                return vaultEnabled && sharedVaultEnabled
            case .obsessions:
                return vaultEnabled && obsessionsVaultEnabled
            default:
                return true
            }
        }
    }

    private func configureVaultStores() {
        let username = scrobbleService.sessionUsername
        sharedVaultStore.configure(username: username)
        obsessionVaultStore.configure(username: username)
        if let selectedTab, !availableTabs.contains(selectedTab) {
            self.selectedTab = .dashboard
        }
    }

    private func presentOnboardingIfNeeded() {
        guard !didCompleteOpenMusicOnboarding else { return }
        guard scrobbleService.listenBrainzUsername?.isEmpty != false else { return }
        isOpenMusicOnboardingPresented = true
    }

    private var nowPlayingSubtitle: String {
        if let current = scrobbleService.currentTrack {
            return "\(current.artist) - \(current.title)"
        }
        return "No track playing"
    }

    private var appBarBackground: Color {
        colorScheme == .dark ? Color.black.opacity(0.28) : Color.white.opacity(0.78)
    }

    private var appModalScrim: Color {
        colorScheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.12)
    }

    private var appSidebarBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.regularMaterial)
    }

    private var appDividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
    }

    @ViewBuilder
    private var settingsFooter: some View {
        if #available(macOS 14.0, *) {
            SettingsLink {
                settingsFooterLabel
            }
            .buttonStyle(.plain)
        } else {
            Button {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                settingsFooterLabel
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsFooterLabel: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape.fill")
            Text(scrobbleService.accountFooterText)
                .font(.custom("Avenir Next Medium", size: 14))
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func openDeepLink(scrobble: CompatibilityRecentScrobble) {
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(id: scrobble.id, scrobble: scrobble, kind: .track)
        }
        Task {
            await scrobbleService.inspect(scrobble: scrobble)
        }
    }

    private func openDeepLink(track: String?, artist: String, album: String? = nil, imageURL: String? = nil) {
        let hasTrack = track?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let title = hasTrack ? track! : artist
        let item = CompatibilityRecentScrobble(
            id: "deep-\(hasTrack ? "track" : "artist")-\(artist)|\(title)",
            track: title,
            artist: artist,
            album: album,
            imageURL: imageURL,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false,
            recordingMbid: nil,
            recordingMsid: nil
        )
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(
                id: item.id,
                scrobble: item,
                kind: hasTrack ? .track : .artist
            )
        }
        Task {
            await scrobbleService.inspect(scrobble: item)
        }
    }

    private func openAlbumDeepLink(album: String, artist: String, imageURL: String? = nil) {
        let item = CompatibilityRecentScrobble(
            id: "deep-album-\(artist)|\(album)",
            track: album,
            artist: artist,
            album: album,
            imageURL: imageURL,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false,
            recordingMbid: nil,
            recordingMsid: nil
        )
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = DeepLinkTarget(id: item.id, scrobble: item, kind: .album)
        }
        Task {
            await scrobbleService.inspect(scrobble: item)
        }
    }

    private func openSocialGraph(for neighbour: CompatibilityNeighbour) {
        openSocialGraph(forUser: neighbour.user, profileURL: neighbour.profileURL)
    }

    private func openSocialGraph(forUser user: String, profileURL: String?) {
        withAnimation(.easeInOut(duration: 0.22)) {
            deepLinkTarget = nil
            socialGraphTarget = SocialGraphTarget(
                id: user.lowercased(),
                user: user,
                profileURL: profileURL
            )
            selectedProfileURL = profileURLString(profileURL, fallbackUser: user)
        }
        Task {
            await scrobbleService.prepareSocialGraph(for: user)
        }
    }

    private func profileURLString(_ raw: String?, fallbackUser: String) -> URL? {
        if let raw, let url = URL(string: raw) {
            return url
        }
        return userProfileURL(username: fallbackUser)
    }

    private func userProfileURL(username: String) -> URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = username.addingPercentEncoding(withAllowedCharacters: allowed) ?? username
        return URL(string: "https://listenbrainz.org/user/\(encoded)")
    }

    private func clampedInspectorWidth(
        preferred: Double,
        availableWidth: CGFloat,
        minimum: CGFloat,
        maximumRatio: CGFloat,
        hardCap: CGFloat
    ) -> CGFloat {
        let maximum = min(hardCap, availableWidth * maximumRatio)
        return min(max(CGFloat(preferred), minimum), maximum)
    }
}
