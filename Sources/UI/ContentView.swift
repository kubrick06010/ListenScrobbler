import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

private enum WorkspaceTab: String, CaseIterable, Hashable, Identifiable {
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

private struct DeepLinkTarget: Identifiable, Equatable {
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
private struct SocialGraphTarget: Identifiable, Equatable {
    let id: String
    let user: String
    let profileURL: String?
}

private struct ShareDraft: Identifiable, Equatable {
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

private struct RecommendationComposerDraft: Identifiable, Equatable {
    let recommendation: ListenBrainzRecommendedRecording

    var id: String { recommendation.id }
}

private struct ObsessionDraft: Identifiable, Equatable {
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

private func accountBadgeLabel(for normalizedType: String) -> String {
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
    @StateObject private var sharedVaultStore = SharedMusicVaultStore()
    @StateObject private var obsessionVaultStore = ObsessionVaultStore()
    @State private var selectedTab: WorkspaceTab? = .dashboard
    @State private var scrobblesQuery = ""
    @State private var recommendationDraft: RecommendationComposerDraft?
    @State private var deepLinkTarget: DeepLinkTarget?
    @State private var socialGraphTarget: SocialGraphTarget?
    @State private var selectedProfileURL: URL?
    @State private var isDiagnosticsPresented = false
    @State private var shareDraft: ShareDraft?
    @State private var obsessionDraft: ObsessionDraft?

    var body: some View {
        NavigationSplitView {
            List(availableTabs, selection: $selectedTab) { tab in
                    Label(tab.rawValue, systemImage: tab.symbol)
                        .tag(tab)
                        .font(.custom("Avenir Next Medium", size: 13))
            }
            .navigationTitle("OpenScrobbler")
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        Text("OpenScrobbler")
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
                            ScrobblesView(query: $scrobblesQuery) { item in
                                openDeepLink(scrobble: item)
                            }
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
            nowPlaying: false
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
            nowPlaying: false
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

private struct BottomTabShell: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selectedTab: WorkspaceTab
    private let tabs: [WorkspaceTab] = [.scrobbles, .charts, .social]
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.id) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: tab.symbol)
                            .font(.system(size: 18, weight: .semibold))
                        Text(tab.rawValue)
                            .font(.custom("Avenir Next Medium", size: 13))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(selectedTab == tab ? accent : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.9), Color(red: 0.12, green: 0.13, blue: 0.16)]
                    : [Color.white.opacity(0.88), Color(red: 0.92, green: 0.94, blue: 0.98)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08))
                .frame(height: 1)
        }
    }
}

private struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var moodPalette = DashboardMoodPalette.fallback
    let onOpenTrackDetail: (_ track: String, _ artist: String, _ album: String?, _ imageURL: String?) -> Void
    let onShareTrack: (ShareDraft) -> Void
    let onCaptureObsession: (ObsessionDraft) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = DashboardMetrics(width: proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                    Text("Listening Dashboard")
                        .font(.custom("Avenir Next Medium", size: metrics.screenTitleFont))
                        .foregroundStyle(.primary)

                    if let nowPlaying = scrobbleService.currentTrack {
                        VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                            if metrics.isCompact {
                                VStack(alignment: .leading, spacing: 10) {
                                    sourceLabel(nowPlaying)
                                    dashboardMiniProgress(compact: true)
                                }
                            } else {
                                HStack(alignment: .top) {
                                    sourceLabel(nowPlaying)
                                    Spacer()
                                    dashboardMiniProgress(compact: false)
                                }
                            }

                            Divider().overlay(sectionDividerColor)

                            if metrics.isCompact {
                                VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                    dashboardArt(dashboardTrackImageURL, size: metrics.trackArtSize)
                                        .onTapGesture {
                                            openDetailForCurrentTrack(nowPlaying)
                                        }
                                    trackSummary(nowPlaying, metrics: metrics)
                                }
                            } else {
                                HStack(alignment: .top, spacing: metrics.cardSpacing) {
                                    dashboardArt(dashboardTrackImageURL, size: metrics.trackArtSize)
                                        .onTapGesture {
                                            openDetailForCurrentTrack(nowPlaying)
                                        }
                                    trackSummary(nowPlaying, metrics: metrics)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }

                            trackInsightsCard(fontSize: metrics.bodyFont)

                            Divider().overlay(sectionDividerColor)

                            VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                Text(scrobbleService.currentArtistDetails?.name ?? nowPlaying.artist)
                                    .font(.custom("Avenir Next Demi Bold", size: metrics.artistTitleFont))

                                if metrics.isCompact {
                                    VStack(alignment: .leading, spacing: metrics.cardSpacing) {
                                        dashboardArt(scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL, size: metrics.artistArtSize)
                                        HTMLSummaryText(rawHTML: artistSummaryText, fontSize: metrics.bodyFont, lineLimit: metrics.summaryLineLimit)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                } else {
                                    HStack(alignment: .top, spacing: metrics.cardSpacing) {
                                        dashboardArt(scrobbleService.currentArtistDetails?.imageURL ?? dashboardTrackImageURL, size: metrics.artistArtSize)
                                        HTMLSummaryText(rawHTML: artistSummaryText, fontSize: metrics.bodyFont, lineLimit: metrics.summaryLineLimit)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                if let enrichment = scrobbleService.currentOpenEnrichment {
                                    listenBrainzArtistContext(enrichment, metrics: metrics)
                                }

                                statGrid(metrics: metrics)

                                if let weightedTags = scrobbleService.currentOpenEnrichment?.artistProfile?.tags,
                                   !weightedTags.isEmpty {
                                    weightedTagLinks(title: "ListenBrainz tags", tags: Array(weightedTags.prefix(metrics.maxTagCount + 4)))
                                } else {
                                    let tags = dashboardTags
                                    if !tags.isEmpty {
                                        tagLinks(title: "Open tags", tags: Array(tags.prefix(metrics.maxTagCount)))
                                    }
                                }

                                if let similar = scrobbleService.currentArtistDetails?.similarArtists, !similar.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Similar Artists")
                                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionTitleFont))
                                        similarArtistsGrid(Array(similar.prefix(metrics.maxSimilarArtists)), metrics: metrics)
                                    }
                                } else if let similar = scrobbleService.currentOpenEnrichment?.similarArtists, !similar.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Similar Artists")
                                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionTitleFont))
                                        listenBrainzSimilarArtistsGrid(Array(similar.prefix(metrics.maxSimilarArtists)), metrics: metrics)
                                    }
                                }

                                if let top = scrobbleService.currentOpenEnrichment?.topArtistRecordings, !top.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Top ListenBrainz Tracks")
                                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionTitleFont))
                                        popularRecordingsList(Array(top.prefix(metrics.isNarrow ? 4 : 5)))
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                        .padding(metrics.cardPadding)
                        .background {
                            dashboardBackgroundArt(dashboardHeroImageURL)
                        }
                        .background(dashboardCardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(cardBorderColor, lineWidth: 1)
                        )
                        .animation(.easeInOut(duration: 0.45), value: moodPalette)
                    } else {
                        Text("No track detected.")
                            .font(.custom("Avenir Next Medium", size: 14))
                            .foregroundStyle(.secondary)
                            .padding(20)
                            .appPanelStyle()
                    }
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task(id: dashboardMoodKey) {
            let palette = await MoodPaletteEngine.resolvePalette(
                trackTags: scrobbleService.currentTrackDetails?.tags ?? [],
                artistTags: scrobbleService.currentArtistDetails?.tags ?? [],
                artworkURL: dashboardHeroImageURL
            )
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.55)) {
                    moodPalette = palette
                }
            }
        }
    }

    @ViewBuilder
    private func dashboardArt(_ urlString: String?, size: CGFloat = 120) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                placeholderFill
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(placeholderFill)
                .frame(width: size, height: size)
        }
    }

    // The dashboard follows the same responsive rule used in the inspector:
    // reflow before shrink. Modern desktop UI tends to preserve readable type
    // and information hierarchy by changing composition first (stacking,
    // adaptive grids, capped content widths) and only then reducing font size.
    // References:
    // Apple. (n.d.). Human Interface Guidelines. https://developer.apple.com/design/human-interface-guidelines/
    // Apple. (n.d.). ViewThatFits. https://developer.apple.com/documentation/swiftui/viewthatfits
    private struct DashboardMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 960 }
        var isNarrow: Bool { width < 760 }
        var contentMaxWidth: CGFloat { isCompact ? .infinity : 1180 }
        var screenTitleFont: CGFloat { isNarrow ? 20 : 24 }
        var cardPadding: CGFloat { isNarrow ? 18 : 22 }
        var cardSpacing: CGFloat { isNarrow ? 10 : 14 }
        var sectionSpacing: CGFloat { isNarrow ? 16 : 18 }
        var trackArtSize: CGFloat { isNarrow ? 112 : 132 }
        var artistArtSize: CGFloat { isNarrow ? 112 : 126 }
        var titleFont: CGFloat { isNarrow ? 22 : 28 }
        var subtitleFont: CGFloat { isNarrow ? 16 : 18 }
        var bodyFont: CGFloat { isNarrow ? 14 : 15 }
        var artistTitleFont: CGFloat { isNarrow ? 20 : 22 }
        var sectionTitleFont: CGFloat { isNarrow ? 16 : 18 }
        var summaryLineLimit: Int { isNarrow ? 5 : 6 }
        var maxTagCount: Int { isNarrow ? 5 : 6 }
        var maxSimilarArtists: Int { isCompact ? 6 : 8 }
        var statColumns: [GridItem] {
            isCompact
                ? [GridItem(.adaptive(minimum: isNarrow ? 140 : 160), alignment: .leading)]
                : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        }
        var similarArtistColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 84 : 92), spacing: 18, alignment: .topLeading)]
        }
    }

    private func sourceLabel(_ nowPlaying: Track) -> some View {
        Label {
            Text("Listening from \(nowPlaying.sourceApp ?? "Music")")
                .font(.custom("Avenir Next Medium", size: 15))
        } icon: {
            Image(systemName: "music.note")
                .font(.system(size: 15, weight: .semibold))
        }
    }

    private func trackSummary(_ nowPlaying: Track, metrics: DashboardMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(scrobbleService.currentTrackDetails?.name ?? nowPlaying.title)
                .font(.custom("Avenir Next Demi Bold", size: metrics.titleFont))
                .lineLimit(metrics.isNarrow ? 4 : 3)
                .contentShape(Rectangle())
                .onTapGesture {
                    openDetailForCurrentTrack(nowPlaying)
                }
                .simultaneousGesture(
                    MagnificationGesture()
                        .onEnded { value in
                            guard value > 1.05 else { return }
                            openDetailForCurrentTrack(nowPlaying)
                        }
                )
            Text("by \(scrobbleService.currentTrackDetails?.artist ?? nowPlaying.artist)")
                .font(.custom("Avenir Next Demi Bold", size: metrics.subtitleFont))
                .foregroundStyle(.secondary)
                .lineLimit(metrics.isNarrow ? 3 : 2)
            if let album = scrobbleService.currentTrackDetails?.album ?? nowPlaying.album {
                Text("from \(album)")
                    .font(.custom("Avenir Next Medium", size: metrics.bodyFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isNarrow ? 3 : 2)
            }
            HStack(spacing: 10) {
                Button {
                    Task { await scrobbleService.toggleCurrentTrackLove() }
                } label: {
                    Image(systemName: scrobbleService.listenBrainzCurrentTrackLoved ? "heart.fill" : "heart")
                }
                .disabled(scrobbleService.isUpdatingListenBrainzFeedback)
                .help(scrobbleService.listenBrainzCurrentTrackLoved ? "Unlove on ListenBrainz" : "Love on ListenBrainz")
                .foregroundStyle(scrobbleService.listenBrainzCurrentTrackLoved ? .pink : .secondary)

                Button {
                    onCaptureObsession(obsessionDraft(for: nowPlaying))
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .help("Capture obsession")
                .foregroundStyle(.secondary)

                Button {
                    onShareTrack(shareDraft(for: nowPlaying))
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Archive share")
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .font(.system(size: 18, weight: .medium))
            .padding(.top, 2)
            Text(scrobbleService.listenBrainzFeedbackStatus)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private func statGrid(metrics: DashboardMetrics) -> some View {
        LazyVGrid(columns: metrics.statColumns, alignment: .leading, spacing: 12) {
            statColumn(
                "Artist listeners",
                scrobbleService.currentArtistDetails?.listeners
                    ?? scrobbleService.currentOpenEnrichment?.globalArtistListenerCount
            )
            statColumn(
                "Artist plays",
                scrobbleService.currentArtistDetails?.playcount
                    ?? scrobbleService.currentOpenEnrichment?.globalArtistListenCount
            )
            statColumn(
                "Track plays in your library",
                scrobbleService.currentTrackDetails?.userPlaycount
                    ?? scrobbleService.currentOpenEnrichment?.userRecordingListenCount
            )
        }
    }

    private func similarArtistsGrid(_ artists: [CompatibilitySimilarArtist], metrics: DashboardMetrics) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: scrobbleService.currentArtistDetails?.name ?? scrobbleService.currentTrack?.artist ?? "Artist",
                    nodes: artists.enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.name)",
                            name: artist.name,
                            value: Double(max(1, artists.count - index)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: metrics.isNarrow
                )
                .frame(height: metrics.isNarrow ? 320 : 420)
            } else {
                LazyVGrid(columns: metrics.similarArtistColumns, alignment: .leading, spacing: 14) {
                    ForEach(artists, id: \.name) { item in
                        similarArtistLink(item, compact: metrics.isNarrow)
                    }
                }
            }
        }
    }

    private func listenBrainzSimilarArtistsGrid(_ artists: [ListenBrainzSimilarArtist], metrics: DashboardMetrics) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: scrobbleService.currentArtistDetails?.name ?? scrobbleService.currentTrack?.artist ?? "Artist",
                    nodes: artists.enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.id)",
                            name: artist.name,
                            value: Double(max(1, artist.totalListenCount)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: metrics.isNarrow
                )
                .frame(height: metrics.isNarrow ? 320 : 420)
            } else {
                LazyVGrid(columns: metrics.similarArtistColumns, alignment: .leading, spacing: 14) {
                    ForEach(artists) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            dashboardArt(item.imageURL, size: metrics.isNarrow ? 64 : 72)
                            Text(item.name)
                                .font(.custom("Avenir Next Medium", size: metrics.isNarrow ? 13 : 14))
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(width: metrics.isNarrow ? 84 : 96, alignment: .leading)
                            Text("\(item.totalListenCount.formatted()) plays")
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func popularRecordingsList(_ recordings: [ListenBrainzPopularRecording]) -> some View {
        VStack(spacing: 8) {
            ForEach(recordings) { recording in
                HStack(spacing: 10) {
                    dashboardArt(recording.imageURL, size: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(recording.title)
                            .font(.custom("Avenir Next Medium", size: 13))
                            .lineLimit(1)
                        Text(recording.releaseName ?? recording.artistName)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Text(count(recording.totalListenCount))
                        .font(.custom("Avenir Next Demi Bold", size: 12))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private func dashboardBackgroundArt(_ urlString: String?) -> some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(nsColor: moodPalette.gradientStart),
                        Color(nsColor: moodPalette.gradientEnd)
                    ]
                    : [
                        Color(nsColor: moodPalette.gradientStart).opacity(0.22),
                        Color(nsColor: moodPalette.gradientEnd).opacity(0.14)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let urlString, let url = URL(string: urlString) {
                CachedAsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 30)
                        .saturation(0.72)
                        .opacity(colorScheme == .dark ? 0.34 : 0.22)
                } placeholder: {
                    Color.clear
                }
            }
            // The mood engine picks a tag-driven palette and then folds dominant
            // artwork color back into it, so the backdrop feels responsive to the
            // current artist without becoming unreadable.
            Circle()
                .fill(Color(nsColor: moodPalette.glowPrimary).opacity(colorScheme == .dark ? 0.22 : 0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 28)
                .offset(x: 160, y: -80)
            Circle()
                .fill(Color(nsColor: moodPalette.glowSecondary).opacity(colorScheme == .dark ? 0.18 : 0.14))
                .frame(width: 240, height: 240)
                .blur(radius: 22)
                .offset(x: -180, y: 60)
            Circle()
                .fill(Color(nsColor: moodPalette.accent).opacity(colorScheme == .dark ? 0.10 : 0.08))
                .frame(width: 180, height: 180)
                .blur(radius: 20)
                .offset(x: 40, y: 120)
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.black.opacity(0.24), Color.black.opacity(0.52)]
                    : [Color.white.opacity(0.24), Color.white.opacity(0.62)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
    }

    private var playbackChip: some View {
        Text(scrobbleService.playbackState)
            .font(.custom("Avenir Next Medium", size: 12))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(scrobbleService.playbackState == "Playing" ? .green : .secondary)
            .background(
                (scrobbleService.playbackState == "Playing" ? Color.green : Color.white)
                    .opacity(colorScheme == .dark ? 0.12 : 0.18),
                in: Capsule()
            )
    }

    private func dashboardMiniProgress(compact: Bool) -> some View {
        VStack(alignment: compact ? .leading : .trailing, spacing: 4) {
            playbackChip
            ProgressView(value: scrobbleService.scrobbleProgress, total: 1)
                .frame(width: compact ? 132 : 90)
                .progressViewStyle(.linear)
            Text("\(Int(scrobbleService.elapsedForCurrentTrack))s / \(Int(scrobbleService.scrobbleThreshold))s")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func trackInsightsCard(fontSize: CGFloat) -> some View {
        // Keeps the library callout readable even when user-specific counters are unavailable.
        let artistPlays = scrobbleService.currentArtistDetails?.userPlaycount
            ?? scrobbleService.currentOpenEnrichment?.userArtistListenCount
        let trackPlays = scrobbleService.currentTrackDetails?.userPlaycount
            ?? scrobbleService.currentOpenEnrichment?.userRecordingListenCount
        let artist = scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist ?? "this artist"
        let track = scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title ?? "this track"
        return Text("ListenBrainz has \(count(scrobbleService.currentOpenEnrichment?.globalRecordingListenCount)) public plays for \(track). You've listened to \(artist) \(count(artistPlays)) times and \(track) \(count(trackPlays)) time(s).")
            .font(.custom("Avenir Next Medium", size: fontSize))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(calloutBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var artistSummaryText: String {
        if let summary = scrobbleService.currentArtistDetails?.summary, !summary.isEmpty {
            return summary
        }
        if let details = scrobbleService.currentOpenEntityDetails {
            var fragments: [String] = []
            if let profile = scrobbleService.currentOpenEnrichment?.artistProfile {
                let type = profile.type?.nilIfBlank ?? details.type?.nilIfBlank
                var leading = "\(details.artistName) is indexed in ListenBrainz"
                if let type {
                    leading += " as \(type.lowercased())"
                }
                if let beginYear = profile.beginYear {
                    leading += " formed in \(beginYear)"
                }
                fragments.append(leading + ".")
                if let area = profile.area {
                    fragments.append("Area: \(area).")
                }
            } else {
                if let type = details.type?.nilIfBlank {
                    fragments.append("\(details.artistName) is indexed in MusicBrainz as \(type.lowercased()).")
                } else {
                    fragments.append("\(details.artistName) is resolved through MusicBrainz open metadata.")
                }
            }
            if let country = details.country?.nilIfBlank {
                fragments.append("Country: \(country).")
            }
            if let plays = scrobbleService.currentOpenEnrichment?.globalArtistListenCount {
                let listeners = count(scrobbleService.currentOpenEnrichment?.globalArtistListenerCount)
                fragments.append("ListenBrainz shows \(plays.formatted()) public plays from \(listeners) listeners.")
            }
            let tags = scrobbleService.currentOpenEnrichment?.artistProfile?.tags.map(\.name) ?? details.tags
            if !tags.isEmpty {
                fragments.append("Tags: \(tags.prefix(4).joined(separator: ", ")).")
            }
            return fragments.joined(separator: " ")
        }
        return "Open artist metadata is still loading."
    }

    private func listenBrainzArtistContext(_ enrichment: OpenListeningEnrichment, metrics: DashboardMetrics) -> some View {
        let profile = enrichment.artistProfile
        let details = scrobbleService.currentOpenEntityDetails
        let tags = profile?.tags ?? details?.tags.map {
            ListenBrainzArtistTag(id: $0.lowercased(), name: $0, count: 0)
        } ?? []

        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundStyle(.secondary)
                Text("ListenBrainz Artist Context")
                    .font(.custom("Avenir Next Demi Bold", size: metrics.sectionTitleFont - 2))
                Spacer()
            }

            LazyVGrid(columns: metrics.statColumns, alignment: .leading, spacing: 10) {
                profileFact("Plays", count(enrichment.globalArtistListenCount))
                profileFact("Listeners", count(enrichment.globalArtistListenerCount))
                profileFact("Formed", profile?.beginYear.map(String.init) ?? "—")
                profileFact("Area", profile?.area ?? details?.country ?? "—")
                profileFact("Type", profile?.type ?? details?.type ?? "—")
            }

            if !tags.isEmpty {
                weightedTagLinks(title: "Top tags", tags: Array(tags.prefix(metrics.isNarrow ? 5 : 8)))
            }

            let links = preferredArtistLinks(profile?.links ?? [])
            if !links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(links.prefix(4)) { link in
                        Button(link.title) {
                            openURL(link.url)
                        }
                        .buttonStyle(.bordered)
                        .font(.custom("Avenir Next Medium", size: 12))
                    }
                }
            }
        }
        .padding(10)
        .background(calloutBackground, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private func profileFact(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .lineLimit(1)
        }
    }

    private func statColumn(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(count(value))
                .font(.custom("Avenir Next Demi Bold", size: 20))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openDetailForCurrentTrack(_ nowPlaying: Track) {
        onOpenTrackDetail(
            scrobbleService.currentTrackDetails?.name ?? nowPlaying.title,
            scrobbleService.currentTrackDetails?.artist ?? nowPlaying.artist,
            scrobbleService.currentTrackDetails?.album ?? nowPlaying.album,
            dashboardTrackImageURL
        )
    }

    private func shareDraft(for track: Track) -> ShareDraft {
        ShareDraft(
            kind: .track,
            artist: scrobbleService.currentTrackDetails?.artist ?? track.artist,
            track: scrobbleService.currentTrackDetails?.name ?? track.title,
            album: scrobbleService.currentTrackDetails?.album ?? track.album,
            sourceURL: scrobbleService.currentTrackDetails?.url,
            imageURL: dashboardTrackImageURL,
            artistMBID: scrobbleService.currentOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.currentOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.currentOpenEntityDetails?.releaseMBID
        )
    }

    private func obsessionDraft(for track: Track) -> ObsessionDraft {
        ObsessionDraft(
            artist: scrobbleService.currentTrackDetails?.artist ?? track.artist,
            track: scrobbleService.currentTrackDetails?.name ?? track.title,
            album: scrobbleService.currentTrackDetails?.album ?? track.album,
            sourceURL: scrobbleService.currentTrackDetails?.url,
            imageURL: dashboardTrackImageURL,
            artistMBID: scrobbleService.currentOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.currentOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.currentOpenEntityDetails?.releaseMBID
        )
    }

    private var dashboardHeroImageURL: String? {
        // Prefer artist hero art for background bokeh; fallback to resolved track artwork.
        scrobbleService.currentArtistDetails?.imageURL
            ?? dashboardTrackImageURL
            ?? scrobbleService.currentOpenEntityDetails?.imageURL
    }

    private var dashboardMoodKey: String {
        [
            scrobbleService.currentTrack?.title ?? "",
            scrobbleService.currentTrack?.artist ?? "",
            dashboardHeroImageURL ?? "",
            (scrobbleService.currentTrackDetails?.tags ?? []).joined(separator: "|"),
            (scrobbleService.currentArtistDetails?.tags ?? []).joined(separator: "|")
        ].joined(separator: "::")
    }

    private var dashboardTrackImageURL: String? {
        // Artwork resolution chain:
        // 1) track.getInfo image
        // 2) player-supplied artwork
        // 3) MusicBrainz/Cover Art Archive release artwork
        // 4) matching recent scrobble image (same title + artist)
        // 5) artist image as final fallback.
        if let explicit = scrobbleService.currentTrackDetails?.imageURL, !explicit.isEmpty {
            return explicit
        }
        if let localArtwork = scrobbleService.currentTrack?.artworkURL, !localArtwork.isEmpty {
            return localArtwork
        }
        if let openArtwork = scrobbleService.currentOpenEntityDetails?.imageURL, !openArtwork.isEmpty {
            return openArtwork
        }
        guard let now = scrobbleService.currentTrack else {
            return scrobbleService.currentArtistDetails?.imageURL
        }
        let normalizedTitle = now.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedArtist = now.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let matched = scrobbleService.latestScrobbles.first(where: {
            $0.track.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTitle &&
            $0.artist.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedArtist &&
            ($0.imageURL?.isEmpty == false)
        })?.imageURL {
            return matched
        }
        return scrobbleService.currentArtistDetails?.imageURL
    }

    private var dashboardTags: [String] {
        let legacy = (scrobbleService.currentArtistDetails?.tags ?? []) +
            (scrobbleService.currentTrackDetails?.tags ?? [])
        let open = scrobbleService.currentOpenEntityDetails?.tags ?? []
        return (legacy + open).uniquedCaseInsensitive()
    }

    private func count(_ value: Int?) -> String {
        value.map { $0.formatted() } ?? "—"
    }

    private func tagLinks(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func weightedTagLinks(title: String, tags: [ListenBrainzArtistTag]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    HStack(spacing: 7) {
                        Text(tag.name)
                            .font(.custom("Avenir Next Medium", size: 13))
                        if tag.count > 0 {
                            Text("\(tag.count)")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func preferredArtistLinks(_ links: [ListenBrainzArtistLink]) -> [ListenBrainzArtistLink] {
        let priority = ["Official Homepage", "Youtube", "Streaming", "Social Network", "Wikidata"]
        return links.sorted { lhs, rhs in
            let left = priority.firstIndex(of: lhs.title) ?? priority.count
            let right = priority.firstIndex(of: rhs.title) ?? priority.count
            if left == right {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return left < right
        }
    }

    private func similarArtistLink(_ similar: CompatibilitySimilarArtist, compact: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            dashboardArt(similar.imageURL, size: compact ? 64 : 72)
            Text(similar.name)
                .font(.custom("Avenir Next Medium", size: compact ? 13 : 14))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: compact ? 84 : 90, alignment: .leading)
        }
    }

    private var placeholderFill: Color {
        colorScheme == .dark ? Color.white.opacity(0.06) : Color.black.opacity(0.06)
    }

    private var cardBorderColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.12) : Color.black.opacity(0.08)
    }

    private var dashboardCardBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.72))
    }

    private var calloutBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05)
    }

    private var sectionDividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.10)
    }
}

private struct QueueView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Submission Queue")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Spacer()
                Text("\(scrobbleService.queuedSubmissionJobs.count) jobs")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }

            if scrobbleService.queuedSubmissionJobs.isEmpty {
                Text("Queue is empty. Tracks that pass threshold rules will appear here for each enabled backend.")
                    .font(.custom("Avenir Next Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appPanelStyle()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(scrobbleService.queuedSubmissionJobs) { job in
                            HStack(spacing: 10) {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.track.title).font(.custom("Avenir Next Medium", size: 14))
                                    Text(job.track.artist).font(.custom("Avenir Next Regular", size: 13)).foregroundStyle(.secondary)
                                    if let album = job.track.album, !album.isEmpty {
                                        Text(album).font(.custom("Avenir Next Regular", size: 12)).foregroundStyle(.secondary)
                                    }
                                    if let lastError = job.lastError {
                                        Text(lastError)
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .foregroundStyle(.red)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text(job.backend.displayName)
                                        .font(.custom("Avenir Next Demi Bold", size: 11))
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(Color.accentColor.opacity(0.12), in: Capsule())
                                    Text(job.track.startedAt.formatted(date: .omitted, time: .shortened))
                                        .font(.custom("Avenir Next Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                    if job.attempts > 0 {
                                        Text("\(job.attempts) tries")
                                            .font(.custom("Avenir Next Regular", size: 10))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(10)
                            .appPanelStyle()
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct AccountView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var username: String
    @Binding var password: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account And Session")
                    .font(.custom("Avenir Next Demi Bold", size: 28))

                VStack(alignment: .leading, spacing: 12) {
                    TextField("Username", text: $username)
                    SecureField("Password", text: $password)

                    HStack {
                        Button("Sign In") {
                            Task { await scrobbleService.signIn(username: username, password: password) }
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Sign Out") {
                            scrobbleService.signOut()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Backend: \(scrobbleService.backendName)")
                    Text("Auth State: \(scrobbleService.isAuthenticated ? "Authenticated" : "Not authenticated")")
                    Text("Session: \(scrobbleService.sessionStatus)")
                    Text("Capabilities: \(scrobbleService.capabilitiesStatus)")
                    Text("Operational state: Preferences > Advanced")
                        .foregroundStyle(.secondary)
                }
                .font(.custom("Avenir Next Medium", size: 13))
                .appPanelStyle()

                if let authError = scrobbleService.authError {
                    Text(authError)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.red)
                        .padding(10)
                        .appPanelStyle()
                }
            }
            .padding(24)
            .frame(maxWidth: 1280, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

private struct ExploreView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Track And Artist Explore")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshExplore() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.exploreStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let track = scrobbleService.currentTrackDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            trackArt(track.imageURL)
                            VStack(alignment: .leading, spacing: 5) {
                                detailRow("Track", track.name)
                                detailRow("Artist", track.artist)
                                if let album = track.album {
                                    detailRow("Album", album)
                                }
                                detailRow("Listeners", formatCount(track.listeners))
                                detailRow("Playcount", formatCount(track.playcount))
                                if let user = track.userPlaycount {
                                    detailRow("Your Plays", "\(user)")
                                }
                                if !track.tags.isEmpty {
                                    Text("Tags: \(track.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = track.summary {
                            HTMLSummaryText(rawHTML: summary, fontSize: 12, lineLimit: 4)
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No track details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artist = scrobbleService.currentArtistDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            trackArt(artist.imageURL)
                            VStack(alignment: .leading, spacing: 4) {
                                detailRow("Artist", artist.name)
                                detailRow("Listeners", formatCount(artist.listeners))
                                detailRow("Playcount", formatCount(artist.playcount))
                                if let user = artist.userPlaycount {
                                    detailRow("In your library", "\(user)")
                                }
                                if !artist.tags.isEmpty {
                                    Text("Tags: \(artist.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = artist.summary {
                            HTMLSummaryText(rawHTML: summary, fontSize: 12, lineLimit: 5)
                        }
                        if !artist.similarArtists.isEmpty {
                            Text("Similar Artists")
                                .font(.custom("Avenir Next Medium", size: 12))
                            HStack(spacing: 12) {
                                ForEach(artist.similarArtists.prefix(4)) { similar in
                                    VStack(alignment: .leading, spacing: 3) {
                                        trackArt(similar.imageURL, size: 54)
                                        Text(similar.name)
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No artist details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.custom("Avenir Next Medium", size: 12))
    }

    private func formatCount(_ value: Int?) -> String {
        guard let value else { return "Unknown" }
        return value.formatted()
    }

    @ViewBuilder
    private func trackArt(_ urlString: String?, size: CGFloat = 110) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }
}

private struct ProfileView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Profile")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshProfile() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.profileStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let profile = scrobbleService.profile {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 6) {
                            profileAvatar(profile.imageURL)
                            if let accountBadge = accountBadgeType(profile: profile) {
                                badgeView(accountBadge, fontSize: 10, horizontal: 8, vertical: 3)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name)
                                .font(.custom("Avenir Next Demi Bold", size: 22))
                            if let realname = profile.realname, !realname.isEmpty {
                                Text(realname)
                                    .font(.custom("Avenir Next Medium", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 14) {
                                profilePill("Tracks", profile.trackCount)
                                profilePill("Artists", profile.artistCount)
                                profilePill("Albums", profile.albumCount)
                                profilePill("Plays", profile.playcount)
                                profilePill("Loved", scrobbleService.lovedTracksCount)
                            }
                            if let registered = profile.registeredAt {
                                Text("Listening since \(registered.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No profile loaded.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artistCount = profileArtistCount, let avg = scrobbleService.tracksPerDayAverage {
                    Text("You have \(artistCount.formatted()) artists in your library and on average listen to \(avg.formatted()) tracks per day.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .appPanelStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists This Week")
                    .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.weeklyTopArtists.isEmpty {
                        Text("No weekly top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.weeklyTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                artistImage(artist.imageURL, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: 13))
                                    Text("\((artist.playcount ?? 0).formatted()) plays")
                                        .font(.custom("Avenir Next Regular", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                                bar(artist.playcount, max: weeklyMax)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists Overall")
                        .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.overallTopArtists.isEmpty {
                        Text("No overall top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.overallTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    artistImage(artist.imageURL, size: 24)
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Regular", size: 12))
                                    Spacer()
                                    Text((artist.playcount ?? 0).formatted())
                                        .font(.custom("Avenir Next Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                bar(artist.playcount, max: overallMax)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func profilePill(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text((value ?? 0).formatted())
                .font(.custom("Avenir Next Medium", size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bar(_ value: Int?, max: Int) -> some View {
        let ratio = max > 0 ? Double(value ?? 0) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 12)
    }

    @ViewBuilder
    private func artistImage(_ urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "music.mic")
                    .font(.system(size: max(10, size * 0.35)))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func profileAvatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AnimatedAvatarImage(
                urls: animatedAvatarCandidates(for: url),
                size: 56
            )
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
        }
    }

    private func animatedAvatarCandidates(for baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        // Some profile providers expose PNG avatars that redirect to GIF when animated.
        // Trying GIF first avoids rendering static avatars for animated profiles.
        let path = baseURL.path.lowercased()
        if path.contains("/avatar"), path.hasSuffix(".png") {
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            let gifPath = baseURL.path.replacingOccurrences(of: ".png", with: ".gif")
            comps?.path = gifPath
            if let gifURL = comps?.url {
                candidates.append(gifURL)
            }
        }
        candidates.append(baseURL)
        return candidates
    }

    private var weeklyMax: Int {
        scrobbleService.weeklyTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var overallMax: Int {
        scrobbleService.overallTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var profileArtistCount: Int? {
        scrobbleService.profile?.artistCount
    }

    private func accountBadgeType(profile: CompatibilityUserProfile) -> String? {
        if let raw = profile.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return scrobbleService.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct ScrobblesView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenDetail: (CompatibilityRecentScrobble) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your Listens")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshScrobbles() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter listens", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.scrobblesStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredScrobbles.isEmpty {
                    Text("No recent listens available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredScrobbles) { item in
                            HStack(spacing: 10) {
                                HStack(spacing: 10) {
                                    scrobbleArtwork(item.imageURL, nowPlaying: item.nowPlaying)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.track)
                                            .font(.custom("Avenir Next Medium", size: 13))
                                        Text(item.artist)
                                            .font(.custom("Avenir Next Regular", size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenDetail(item)
                                }

                                Spacer()

                                if scrobbleService.isAuthenticated {
                                    Button {
                                        Task { await scrobbleService.toggleLove(scrobble: item) }
                                    } label: {
                                        Image(systemName: item.loved ? "heart.fill" : "heart")
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                                }

                                Text(item.nowPlaying ? "Now" : (item.playedAt?.formatted(date: .omitted, time: .shortened) ?? "-"))
                                    .font(.custom("Avenir Next Regular", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(item.nowPlaying ? Color.yellow.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    @ViewBuilder
    private func scrobbleArtwork(_ urlString: String?, nowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackScrobbleArtwork(nowPlaying: nowPlaying)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackScrobbleArtwork(nowPlaying: nowPlaying)
        }
    }

    private func fallbackScrobbleArtwork(nowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: nowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(nowPlaying ? .green : .orange)
        }
        .frame(width: 32, height: 32)
    }

    private var filteredScrobbles: [CompatibilityRecentScrobble] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.latestScrobbles }
        return scrobbleService.latestScrobbles.filter { item in
            item.track.localizedCaseInsensitiveContains(trimmed) ||
            item.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

}

private struct ScrobbleDetailPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    let item: CompatibilityRecentScrobble
    let kind: DeepLinkTarget.Kind
    let availableWidth: CGFloat
    let onShare: (ShareDraft) -> Void
    let onCaptureObsession: (ObsessionDraft) -> Void

    var body: some View {
        let metrics = DetailPanelMetrics(width: availableWidth)

        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                HStack {
                    Text(panelTitle)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.headerFont))
                    Spacer()
                    detailActions
                    Text(scrobbleService.inspectStatus)
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                }

                if kind == .track || kind == .album {
                    trackHeader(metrics: metrics)
                }

                if let openDetails = scrobbleService.inspectedOpenEntityDetails {
                    openMetadataSection(openDetails)
                }

                if let enrichment = scrobbleService.inspectedOpenEnrichment {
                    openEnrichmentSection(enrichment, metrics: metrics)
                }

                // Mirror the legacy iOS navigation model here: related content must follow the
                // entity the user opened, not the artist context we happen to have loaded.
                if kind == .track, let track = scrobbleService.inspectedTrackDetails {
                    statGrid(
                        listeners: track.listeners,
                        plays: track.playcount,
                        library: track.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !track.tags.isEmpty {
                        tagLinks(title: "Popular tags", tags: Array(track.tags.prefix(7)))
                    }
                    if !scrobbleService.inspectedSimilarTracks.isEmpty {
                        Text("Similar Tracks")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarTracksGrid(scrobbleService.inspectedSimilarTracks, compact: metrics.isCompact)
                    }
                }

                if kind == .album, !scrobbleService.inspectedSimilarAlbums.isEmpty {
                    Text("Similar Albums")
                        .font(.custom("Avenir Next Medium", size: 17))
                    similarAlbumsGrid(scrobbleService.inspectedSimilarAlbums, compact: metrics.isCompact)
                }

                if let artist = scrobbleService.inspectedArtistDetails {
                    if kind == .track || kind == .album {
                        Divider()
                    }
                    Text(artist.name)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.artistTitleFont))
                        .lineLimit(metrics.isCompact ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    artistSection(artist, metrics: metrics)

                    statGrid(
                        listeners: artist.listeners,
                        plays: artist.playcount,
                        library: artist.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !artist.tags.isEmpty {
                        tagLinks(title: "Tags", tags: Array(artist.tags.prefix(10)))
                    }
                    // Match the classic iOS app's semantics: only artist detail
                    // renders similar artists. Track/album detail get their own
                    // "similar" blocks instead of inheriting artist similarity.
                    if kind == .artist, !artist.similarArtists.isEmpty {
                        Text("Similar Artists")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarArtistsGrid(artist.similarArtists, compact: metrics.isCompact)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)
        }
    }

    private var panelTitle: String {
        switch kind {
        case .track:
            return "Track Detail"
        case .artist:
            return "Artist Detail"
        case .album:
            return "Album Detail"
        }
    }

    private var detailActions: some View {
        HStack(spacing: 8) {
            if kind == .track {
                Button {
                    onCaptureObsession(obsessionDraft)
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .help("Capture obsession")
            }

            Button {
                onShare(shareDraft)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Archive share")
        }
        .buttonStyle(.bordered)
    }

    private var shareDraft: ShareDraft {
        ShareDraft(
            kind: shareKind,
            artist: item.artist,
            track: kind == .track ? item.track : nil,
            album: kind == .album ? (item.album ?? item.track) : item.album,
            sourceURL: item.url,
            imageURL: detailArtworkURL,
            artistMBID: scrobbleService.inspectedOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.inspectedOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.inspectedOpenEntityDetails?.releaseMBID
        )
    }

    private var obsessionDraft: ObsessionDraft {
        ObsessionDraft(
            artist: item.artist,
            track: item.track,
            album: scrobbleService.inspectedTrackDetails?.album ?? item.album,
            sourceURL: scrobbleService.inspectedTrackDetails?.url ?? item.url,
            imageURL: detailArtworkURL,
            artistMBID: scrobbleService.inspectedOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.inspectedOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.inspectedOpenEntityDetails?.releaseMBID
        )
    }

    private var detailArtworkURL: String? {
        scrobbleService.inspectedTrackDetails?.imageURL
            ?? item.imageURL
            ?? scrobbleService.inspectedOpenEntityDetails?.imageURL
    }

    private var shareKind: SharedMusicEntry.EntityKind {
        switch kind {
        case .track:
            return .track
        case .artist:
            return .artist
        case .album:
            return .album
        }
    }

    // Apple’s current adaptive-layout guidance favors reflow over brute-force
    // shrinking: keep hierarchy intact, switch arrangement when width becomes
    // constrained, and only scale typography within safe bounds. This panel
    // follows that approach by collapsing from a side-by-side inspector into a
    // stacked detail layout before text becomes unreadably narrow.
    // References:
    // Apple. (n.d.). ViewThatFits. https://developer.apple.com/documentation/swiftui/viewthatfits
    // Apple. (n.d.). Human Interface Guidelines. https://developer.apple.com/design/human-interface-guidelines/
    private struct DetailPanelMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 620 }
        var isNarrowCompact: Bool { width < 500 }
        var artworkSize: CGFloat {
            if isNarrowCompact { return min(180, max(128, width - 56)) }
            if isCompact { return min(220, max(150, width - 48)) }
            return 180
        }
        var headerFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 20 : 24) }
        var titleFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 22 : 26) }
        var subtitleFont: CGFloat { isNarrowCompact ? 14 : (isCompact ? 16 : 20) }
        var albumFont: CGFloat { isNarrowCompact ? 13 : (isCompact ? 14 : 16) }
        var artistTitleFont: CGFloat { isNarrowCompact ? 22 : (isCompact ? 26 : 32) }
        var sectionSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
        var stackSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
    }

    @ViewBuilder
    private func trackHeader(metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    private func trackTextBlock(metrics: DetailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerPrimaryText)
                .font(.custom("Avenir Next Demi Bold", size: metrics.titleFont))
                .lineLimit(metrics.isNarrowCompact ? 5 : 4)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(headerSecondaryText)
                .font(.custom("Avenir Next Medium", size: metrics.subtitleFont))
                .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                .fixedSize(horizontal: false, vertical: true)
            if let tertiary = headerTertiaryText {
                Text(tertiary)
                    .font(.custom("Avenir Next Medium", size: metrics.albumFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerPrimaryText: String {
        switch kind {
        case .track:
            return item.track
        case .artist:
            return item.artist
        case .album:
            return item.album ?? item.track
        }
    }

    private var headerSecondaryText: String {
        switch kind {
        case .track:
            return "by \(item.artist)"
        case .artist:
            return "Artist overview"
        case .album:
            return "by \(item.artist)"
        }
    }

    private var headerTertiaryText: String? {
        switch kind {
        case .track:
            if let album = scrobbleService.inspectedTrackDetails?.album ?? item.album {
                return "from \(album)"
            }
            return nil
        case .artist:
            return nil
        case .album:
            return nil
        }
    }

    @ViewBuilder
    private func artistSection(_ artist: CompatibilityArtistDetails, metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL, size: metrics.artworkSize)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openMetadataSection(_ details: OpenMusicEntityDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Open Metadata")
                    .font(.custom("Avenir Next Medium", size: 17))
                Spacer()
                Text(details.hasResolvedMusicBrainzEntity ? "MusicBrainz resolved" : "Best effort")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 8) {
                metadataCell("Recording MBID", details.recordingMBID)
                metadataCell("Artist MBID", details.artistMBID)
                metadataCell("Release MBID", details.releaseMBID)
                metadataCell("Country", details.country)
                metadataCell("Type", details.type)
                metadataCell("Disambiguation", details.disambiguation)
            }

            if !details.tags.isEmpty {
                tagLinks(title: "MusicBrainz tags", tags: details.tags)
            }

            if !details.links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(details.links) { link in
                        Button(link.title) {
                            openURL(link.url)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func openEnrichmentSection(_ enrichment: OpenListeningEnrichment, metrics: DetailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ListenBrainz Context")
                    .font(.custom("Avenir Next Medium", size: 17))
                Spacer()
                Text("Open data")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            LazyVGrid(
                columns: metrics.isCompact
                    ? [GridItem(.adaptive(minimum: 142), alignment: .leading)]
                    : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                stat("Your track plays", enrichment.userRecordingListenCount)
                stat("Your artist plays", enrichment.userArtistListenCount)
                stat("Your album plays", enrichment.userReleaseListenCount)
                stat("Global track plays", enrichment.globalRecordingListenCount)
                stat("Global track listeners", enrichment.globalRecordingListenerCount)
                stat("Global artist plays", enrichment.globalArtistListenCount)
            }

            if let profile = enrichment.artistProfile {
                listenBrainzArtistProfileSection(profile)
            }

            if !enrichment.similarArtists.isEmpty {
                Text("Similar Artists")
                    .font(.custom("Avenir Next Medium", size: 15))
                openSimilarArtistsGrid(enrichment.similarArtists, compact: metrics.isCompact)
            }

            if !enrichment.topArtistRecordings.isEmpty {
                Text("Top Tracks By This Artist")
                    .font(.custom("Avenir Next Medium", size: 15))
                openPopularRecordingsGrid(enrichment.topArtistRecordings, compact: metrics.isCompact)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func listenBrainzArtistProfileSection(_ profile: ListenBrainzArtistProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Artist Profile")
                .font(.custom("Avenir Next Medium", size: 15))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                metadataCell("Formed", profile.beginYear.map(String.init))
                metadataCell("Area", profile.area)
                metadataCell("Type", profile.type)
            }

            if !profile.tags.isEmpty {
                weightedTagLinks(title: "ListenBrainz tags", tags: Array(profile.tags.prefix(10)))
            }

            let links = preferredArtistLinks(profile.links)
            if !links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(links.prefix(5)) { link in
                        Button(link.title) {
                            openURL(link.url)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metadataCell(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text(value?.nilIfBlank ?? "—")
                .font(.custom("Avenir Next Medium", size: 12))
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func statGrid(listeners: Int?, plays: Int?, library: Int?, compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 132), alignment: .leading)]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            stat("Listeners", listeners)
            stat("Plays", plays)
            stat("In your library", library)
        }
    }

    private func similarArtistsGrid(_ artists: [CompatibilitySimilarArtist], compact: Bool) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: item.artist,
                    nodes: Array(artists.prefix(compact ? 8 : 12)).enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.id)",
                            name: artist.name,
                            value: Double(max(1, artists.count - index)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: compact
                )
                .frame(height: compact ? 300 : 360)
            } else {
                let columns = compact
                    ? [GridItem(.adaptive(minimum: 88), spacing: 14, alignment: .topLeading)]
                    : [GridItem(.adaptive(minimum: 90), spacing: 16, alignment: .topLeading)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(artists.prefix(compact ? 6 : 8)) { similar in
                        similarArtistLink(similar)
                    }
                }
            }
        }
    }

    private func openSimilarArtistsGrid(_ artists: [ListenBrainzSimilarArtist], compact: Bool) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: item.artist,
                    nodes: Array(artists.prefix(compact ? 8 : 12)).enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.id)",
                            name: artist.name,
                            value: Double(max(1, artist.totalListenCount)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: compact
                )
                .frame(height: compact ? 300 : 360)
            } else {
                let columns = compact
                    ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
                    : [GridItem(.adaptive(minimum: 132), spacing: 16, alignment: .topLeading)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(artists.prefix(compact ? 6 : 8)) { artist in
                        VStack(alignment: .leading, spacing: 4) {
                            artworkThumbnail(artist.imageURL, size: 74)
                            Text(artist.name)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .lineLimit(2)
                            Text("\(artist.totalListenCount.formatted()) plays")
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func openPopularRecordingsGrid(_ recordings: [ListenBrainzPopularRecording], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 180), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(recordings.prefix(compact ? 4 : 8)) { recording in
                HStack(alignment: .top, spacing: 10) {
                    artworkThumbnail(recording.imageURL, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recording.title)
                            .font(.custom("Avenir Next Medium", size: 12))
                            .lineLimit(2)
                        if let release = recording.releaseName {
                            Text(release)
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("\(count(recording.totalListenCount)) plays")
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func similarTracksGrid(_ tracks: [CompatibilitySimilarTrack], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(tracks.prefix(compact ? 6 : 8)) { track in
                similarTrackLink(track)
            }
        }
    }

    private func similarAlbumsGrid(_ albums: [CompatibilitySimilarAlbum], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(albums.prefix(compact ? 6 : 8)) { album in
                similarAlbumLink(album)
            }
        }
    }

    @ViewBuilder
    private func artwork(size: CGFloat = 180) -> some View {
        if let urlString = detailArtworkURL,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func artistArt(_ urlString: String?, size: CGFloat = 180) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { $0.formatted() } ?? "—")
                .font(.custom("Avenir Next Demi Bold", size: 22))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            .foregroundStyle(.secondary)
        }
    }

    private func count(_ value: Int?) -> String {
        value.map { $0.formatted() } ?? "—"
    }

    private func tagLinks(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func weightedTagLinks(title: String, tags: [ListenBrainzArtistTag]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    HStack(spacing: 7) {
                        Text(tag.name)
                            .font(.custom("Avenir Next Medium", size: 13))
                        if tag.count > 0 {
                            Text("\(tag.count)")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func preferredArtistLinks(_ links: [ListenBrainzArtistLink]) -> [ListenBrainzArtistLink] {
        let priority = ["Official Homepage", "Youtube", "Streaming", "Social Network", "Wikidata"]
        return links.sorted { lhs, rhs in
            let left = priority.firstIndex(of: lhs.title) ?? priority.count
            let right = priority.firstIndex(of: rhs.title) ?? priority.count
            if left == right {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return left < right
        }
    }

    private func similarArtistLink(_ similar: CompatibilitySimilarArtist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artistArt(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 74, alignment: .leading)
        }
    }

    private func similarTrackLink(_ similar: CompatibilitySimilarTrack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artworkThumbnail(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 92, alignment: .leading)
            Text(similar.artist)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
        }
    }

    private func similarAlbumLink(_ similar: CompatibilitySimilarAlbum) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artworkThumbnail(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 92, alignment: .leading)
            Text(similar.artist)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
        }
    }

    @ViewBuilder
    private func artworkThumbnail(_ urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? 400
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        return CGSize(width: maxWidth, height: currentY + lineHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
    }
}

private struct InspectorResizeHandle: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var width: Double
    let minimum: CGFloat
    let maximum: CGFloat
    @State private var dragBaseWidth: Double?
    @State private var isHovering = false

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.clear)
                .frame(width: 18)
                .contentShape(Rectangle())

            Capsule(style: .continuous)
                .fill(handleColor)
                .frame(width: isHovering ? 6 : 4, height: 72)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08), radius: 8, y: 0)
        }
        .onHover { hovering in
            isHovering = hovering
            if hovering {
                NSCursor.resizeLeftRight.push()
            } else {
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    let base = dragBaseWidth ?? width
                    dragBaseWidth = base
                    let candidate = base - value.translation.width
                    width = min(max(candidate, Double(minimum)), Double(maximum))
                }
                .onEnded { _ in
                    dragBaseWidth = nil
                    width = min(max(width, Double(minimum)), Double(maximum))
                }
        )
        .accessibilityLabel("Resize inspector")
    }

    private var handleColor: Color {
        if isHovering {
            return Color(red: 1.0, green: 0.33, blue: 0.36).opacity(0.92)
        }
        return colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.16)
    }
}

private struct ReportsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var period: ReportPeriod = .week
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Reports")
                    .font(.custom("Avenir Next Demi Bold", size: 24))

                Picker("Period", selection: $period) {
                    ForEach(ReportPeriod.allCases, id: \.self) { option in
                        Text(option.label).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("\(currentCount.formatted()) Listens")
                        .font(.custom("Avenir Next Demi Bold", size: 34))
                    Text("vs. \(comparisonCount.formatted()) \(comparisonTitle)")
                        .font(.custom("Avenir Next Medium", size: 20))
                    Text("\(periodTitle) trend: \(trendPercentString)")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Avg. listens per day")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    reportBar("This \(periodTitle)", value: currentAvg, max: max(currentAvg, comparisonAvg))
                    reportBar(period.previousLabel, value: comparisonAvg, max: max(currentAvg, comparisonAvg))
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top tags")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    if topTags.isEmpty {
                        Text("No tags available yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(topTags.prefix(5), id: \.name) { tag in
                            reportBar(tag.name, value: tag.count, max: topTags.first?.count ?? 1)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Listening clock")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("You listened the most at \(peakHourLabel) this period.")
                        .font(.custom("Avenir Next Medium", size: 14))
                        .foregroundStyle(.secondary)
                    ListeningClockView(
                        thisWeek: hourlyCountsCurrent,
                        comparison: hourlyCountsComparison,
                        accent: accent
                    )
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Mainstream score")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Text("With a \(mainstreamScore)% mainstream score, you are \(mainstreamTone) compared to your recent baseline.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .foregroundStyle(.secondary)
                    reportBar("Mainstream", value: mainstreamScore, max: 100)
                    Text("vs. \(mainstreamBaseline)% baseline")
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Trends vs. \(comparisonTitle)")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    ForEach(weekdayTrends, id: \.day) { point in
                        HStack {
                            Text(point.day)
                                .font(.custom("Avenir Next Medium", size: 13))
                                .frame(width: 42, alignment: .leading)
                            reportBarInline(value: point.current, max: weekdayMax)
                            Text(point.current.formatted())
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                            Text("vs \(point.previous.formatted())")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func reportBar(_ label: String, value: Int, max: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.custom("Avenir Next Medium", size: 15))
                Spacer()
                Text(value.formatted())
                    .font(.custom("Avenir Next Medium", size: 15))
            }
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            GeometryReader { geo in
                                let ratio = max > 0 ? Double(value) / Double(max) : 0
                                Rectangle().frame(width: geo.size.width * ratio)
                            }
                        )
                }
                .frame(height: 12)
        }
    }

    private var currentCount: Int {
        let direct = countScrobbles(in: rangeCurrent)
        if direct > 0 { return direct }
        // If local recent history is too shallow, fall back to period top-artist aggregates.
        return topArtistAggregate(for: period)
    }

    private var comparisonCount: Int {
        let direct = countScrobbles(in: rangeComparison)
        if direct > 0 { return direct }
        return 0
    }

    private var currentAvg: Int {
        currentCount / max(1, period.days)
    }

    private var comparisonAvg: Int {
        comparisonCount / max(1, period.days)
    }

    private var trendPercentString: String {
        guard comparisonCount > 0 else { return "Not enough historical data" }
        let delta = Double(currentCount - comparisonCount) / Double(comparisonCount)
        let pct = Int((delta * 100).rounded())
        return pct >= 0 ? "+\(pct)%" : "\(pct)%"
    }

    private func countScrobbles(in range: DateInterval) -> Int {
        return scrobbleService.latestScrobbles.filter { item in
            guard let played = item.playedAt else { return false }
            return range.contains(played)
        }.count
    }

    private var topTags: [(name: String, count: Int)] {
        var counts: [String: Int] = [:]
        for artist in topArtistsForPeriod(period).prefix(12) {
            let name = artist.name.lowercased()
            counts[name, default: 0] += max(1, artist.playcount ?? 0)
        }
        return counts
            .map { ($0.key, $0.value) }
            .sorted { $0.1 > $1.1 }
    }

    private var rangeCurrent: DateInterval {
        period.interval(offsetUnits: 0)
    }

    private var rangeComparison: DateInterval {
        period.interval(offsetUnits: 1)
    }

    private var comparisonTitle: String {
        period.previousLabel
    }

    private var periodTitle: String {
        period.currentLabel
    }

    private func topArtistsForPeriod(_ period: ReportPeriod) -> [CompatibilityTopArtist] {
        switch period {
        case .week:
            return scrobbleService.weeklyTopArtists
        case .month:
            return scrobbleService.monthlyTopArtists
        case .year:
            return scrobbleService.yearlyTopArtists
        }
    }

    private func topArtistAggregate(for period: ReportPeriod) -> Int {
        topArtistsForPeriod(period).reduce(0) { $0 + max(0, $1.playcount ?? 0) }
    }

    private var hourlyCountsCurrent: [Int] {
        hourCounts(in: rangeCurrent)
    }

    private var hourlyCountsComparison: [Int] {
        hourCounts(in: rangeComparison)
    }

    private func hourCounts(in range: DateInterval) -> [Int] {
        var bins = Array(repeating: 0, count: 24)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt, range.contains(played) else { continue }
            let hour = Calendar.current.component(.hour, from: played)
            bins[hour] += 1
        }
        return bins
    }

    private var peakHourLabel: String {
        let counts = hourlyCountsCurrent
        guard let max = counts.max(), max > 0, let idx = counts.firstIndex(of: max) else { return "00:00" }
        return String(format: "%02d:00", idx)
    }

    private var mainstreamScore: Int {
        switch period {
        case .week:
            let weeklyScore = mainstreamScore(from: scrobbleService.weeklyTopArtists)
            if weeklyScore > 0 {
                return weeklyScore
            }
            return mainstreamScore(in: rangeCurrent)
        case .month:
            let monthlyScore = mainstreamScore(from: scrobbleService.monthlyTopArtists)
            if monthlyScore > 0 {
                return monthlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        case .year:
            let yearlyScore = mainstreamScore(from: scrobbleService.yearlyTopArtists)
            if yearlyScore > 0 {
                return yearlyScore
            }
            return mainstreamScore(from: scrobbleService.overallTopArtists)
        }
    }

    private var mainstreamBaseline: Int {
        let baseline: Int
        switch period {
        case .week:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        case .month:
            baseline = mainstreamScore(from: scrobbleService.yearlyTopArtists)
        case .year:
            baseline = mainstreamScore(from: scrobbleService.overallTopArtists)
        }
        if baseline > 0 {
            return baseline
        }
        let previous = mainstreamScore(in: rangeComparison)
        return previous > 0 ? previous : max(0, min(100, mainstreamScore - 6))
    }

    private var mainstreamTone: String {
        if mainstreamScore >= 55 { return "more mainstream" }
        if mainstreamScore <= 25 { return "more adventurous" }
        return "balanced"
    }

    private var mainstreamReferenceArtists: Set<String> {
        let global = Set(scrobbleService.globalTopArtistNames.map { $0.lowercased() })
        if !global.isEmpty {
            return global
        }
        return [
            "drake", "taylor swift", "the weeknd", "billie eilish",
            "bad bunny", "dua lipa", "ariana grande", "coldplay",
            "radiohead", "pink floyd"
        ]
    }

    private var mainstreamRankByArtist: [String: Int] {
        var map: [String: Int] = [:]
        for (index, artist) in scrobbleService.globalTopArtistNames.enumerated() {
            map[artist.lowercased()] = index + 1
        }
        return map
    }

    private func mainstreamScore(from artists: [CompatibilityTopArtist]) -> Int {
        let rankedArtists = artists.filter { !$0.name.isEmpty }
        guard !rankedArtists.isEmpty else { return 0 }

        let weighted = rankedArtists.map { (name: $0.name.lowercased(), weight: max(1, $0.playcount ?? 1)) }
        let totalWeight = weighted.reduce(0) { $0 + $1.weight }
        guard totalWeight > 0 else { return 0 }

        let rank = mainstreamRankByArtist
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let score = weighted.reduce(0.0) { partial, item in
                let popularity: Double
                if let artistRank = rank[item.name] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(item.weight) * popularity
            }
            return Int((score / Double(totalWeight) * 100).rounded())
        }

        let mainstreamWeight = weighted
            .filter { mainstreamReferenceArtists.contains($0.name) }
            .reduce(0) { $0 + $1.weight }
        return Int((Double(mainstreamWeight) / Double(totalWeight) * 100).rounded())
    }

    private func mainstreamScore(in range: DateInterval) -> Int {
        var counts: [String: Int] = [:]
        for item in scrobbleService.latestScrobbles {
            guard let playedAt = item.playedAt, range.contains(playedAt) else { continue }
            counts[item.artist.lowercased(), default: 0] += 1
        }
        guard !counts.isEmpty else { return 0 }

        let rank = mainstreamRankByArtist
        let total = counts.values.reduce(0, +)
        guard total > 0 else { return 0 }
        if !rank.isEmpty {
            let maxRank = max(1, rank.count)
            let weightedScore = counts.reduce(0.0) { partial, entry in
                let popularity: Double
                if let artistRank = rank[entry.key] {
                    popularity = Double(maxRank - artistRank + 1) / Double(maxRank)
                } else {
                    popularity = 0.03
                }
                return partial + Double(entry.value) * popularity
            }
            return Int((weightedScore / Double(total) * 100).rounded())
        }

        let mainstreamHits = counts.reduce(0) { partial, entry in
            mainstreamReferenceArtists.contains(entry.key) ? partial + entry.value : partial
        }
        return Int((Double(mainstreamHits) / Double(total) * 100).rounded())
    }

    private var weekdayTrends: [(day: String, current: Int, previous: Int)] {
        let symbols = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        var current = Array(repeating: 0, count: 7)
        var previous = Array(repeating: 0, count: 7)
        for item in scrobbleService.latestScrobbles {
            guard let played = item.playedAt else { continue }
            let weekday = Calendar.current.component(.weekday, from: played)
            let idx = (weekday + 5) % 7
            if rangeCurrent.contains(played) {
                current[idx] += 1
            } else if rangeComparison.contains(played) {
                previous[idx] += 1
            }
        }
        return symbols.indices.map { (symbols[$0], current[$0], previous[$0]) }
    }

    private var weekdayMax: Int {
        max(1, weekdayTrends.map { max($0.current, $0.previous) }.max() ?? 1)
    }

    private func reportBarInline(value: Int, max: Int) -> some View {
        let ratio = max > 0 ? Double(value) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 10)
    }
}

private enum ReportPeriod: CaseIterable {
    case week
    case month
    case year

    var label: String {
        switch self {
        case .week: return "Last.week"
        case .month: return "Last.month"
        case .year: return "Last.year"
        }
    }

    var currentLabel: String {
        switch self {
        case .week: return "week"
        case .month: return "month"
        case .year: return "year"
        }
    }

    var previousLabel: String {
        switch self {
        case .week: return "last week"
        case .month: return "last month"
        case .year: return "last year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }

    func interval(offsetUnits: Int) -> DateInterval {
        let now = Date()
        let days = self.days
        let end = Calendar.current.date(byAdding: .day, value: -(offsetUnits * days), to: now) ?? now
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? now
        return DateInterval(start: start, end: end)
    }
}

private struct ListeningClockView: View {
    let thisWeek: [Int]
    let comparison: [Int]
    let accent: Color
    private let comparisonColor = Color.white.opacity(0.2)

    var body: some View {
        GeometryReader { proxy in
            let chartSize = min(proxy.size.width, 320)
            VStack(spacing: 12) {
                ZStack {
                    ForEach(0..<24, id: \.self) { hour in
                        let start = angle(for: hour, offsetDegrees: 0.8)
                        let end = angle(for: hour + 1, offsetDegrees: -0.8)
                        let current = normalized(value(for: hour, in: thisWeek))
                        let previous = normalized(value(for: hour, in: comparison))

                        ClockWedge(startAngle: start, endAngle: end, innerRatio: 0.30, outerRatio: 0.82)
                            .fill(Color.white.opacity(0.05))

                        if previous > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + previous * 0.50
                            )
                            .fill(comparisonColor)
                        }

                        if current > 0 {
                            ClockWedge(
                                startAngle: start,
                                endAngle: end,
                                innerRatio: 0.30,
                                outerRatio: 0.30 + current * 0.50
                            )
                            .fill(
                                LinearGradient(
                                    colors: [accent.opacity(0.95), accent.opacity(0.75)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        }
                    }

                    Circle()
                        .fill(Color.black.opacity(0.35))
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        .frame(width: chartSize * 0.36, height: chartSize * 0.36)

                    Group {
                        clockLabel("00", x: 0, y: -chartSize * 0.42)
                        clockLabel("06", x: chartSize * 0.42, y: 0)
                        clockLabel("12", x: 0, y: chartSize * 0.42)
                        clockLabel("18", x: -chartSize * 0.42, y: 0)
                    }
                }
                .frame(width: chartSize, height: chartSize)
                .frame(maxWidth: .infinity)

                HStack(spacing: 14) {
                    legendSwatch(color: accent, label: "Current")
                    legendSwatch(color: comparisonColor, label: "Comparison")
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 356)
    }

    private func value(for hour: Int, in source: [Int]) -> Int {
        source.indices.contains(hour) ? source[hour] : 0
    }

    private func normalized(_ value: Int) -> CGFloat {
        let peak = max(1, (thisWeek + comparison).max() ?? 1)
        return CGFloat(Double(value) / Double(peak))
    }

    private func angle(for hour: Int, offsetDegrees: Double) -> Angle {
        Angle.degrees((Double(hour % 24) / 24.0) * 360.0 - 90.0 + offsetDegrees)
    }

    private func clockLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.custom("Avenir Next Medium", size: 11))
            .foregroundStyle(.secondary)
            .offset(x: x, y: y)
    }

    private func legendSwatch(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 14, height: 10)
            Text(label)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ClockWedge: Shape {
    let startAngle: Angle
    let endAngle: Angle
    let innerRatio: CGFloat
    let outerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let inner = radius * min(max(innerRatio, 0.0), 0.98)
        let outer = radius * min(max(outerRatio, innerRatio), 1.0)

        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        path.closeSubpath()
        return path
    }
}

private struct ChartsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var listenBrainzRange: ListenBrainzStatsRange = .week
    let onOpenTrack: (_ track: String, _ artist: String) -> Void
    let onOpenArtist: (_ artist: String) -> Void
    let onOpenAlbum: (_ album: String, _ artist: String, _ imageURL: String?) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = ChartsMetrics(width: proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Charts")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.screenTitleFont))

                    listenBrainzCharts(metrics: metrics)
                    listenBrainzArtistOrigins(metrics: metrics)
                    listenBrainzArtistAffinity(metrics: metrics)

                    if !scrobbleService.weeklyTopArtists.isEmpty {
                        Text("\(scrobbleService.weeklyTopArtists.count) Artists")
                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))

                        LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                            ForEach(scrobbleService.weeklyTopArtists.prefix(8)) { artist in
                                VStack(alignment: .leading, spacing: 6) {
                                    cover(
                                        artist.imageURL,
                                        size: metrics.coverSize,
                                        placeholder: artist.name
                                    )
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\((artist.playcount ?? 0).formatted()) listens")
                                        .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenArtist(artist.name)
                                }
                            }
                        }
                        .appPanelStyle()
                    }

                    Text("\(topAlbums.count) Albums")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                        ForEach(topAlbums.prefix(8), id: \.id) { album in
                            VStack(alignment: .leading, spacing: 6) {
                                cover(album.imageURL, size: metrics.coverSize)
                                Text(album.title)
                                    .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(album.artist)
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("\(album.count.formatted()) listens")
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont - 1))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenAlbum(album.title, album.artist, album.imageURL)
                            }
                        }
                    }
                    .appPanelStyle()

                    Text("\(topTracks.count) Tracks")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    VStack(spacing: 10) {
                        ForEach(topTracks.prefix(10), id: \.id) { track in
                            HStack(alignment: .top, spacing: 10) {
                                cover(track.imageURL, size: metrics.trackCoverSize)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.custom("Avenir Next Medium", size: metrics.trackTitleFont))
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                    Text(track.artist)
                                        .font(.custom("Avenir Next Regular", size: metrics.trackMetaFont))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                }
                                Spacer(minLength: 8)
                                Text("\(track.count.formatted())")
                                    .font(.custom("Avenir Next Medium", size: metrics.trackCountFont))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenTrack(track.title, track.artist)
                            }
                        }
                    }
                    .appPanelStyle()
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .task {
            guard scrobbleService.listenBrainzEnabled else { return }
            await refreshListenBrainzArchive()
        }
    }

    @ViewBuilder
    private func listenBrainzCharts(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ListenBrainz Archive")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    Text(scrobbleService.listenBrainzStatsStatus)
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Range", selection: $listenBrainzRange) {
                    ForEach(ListenBrainzStatsRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 360)
                .onChange(of: listenBrainzRange) { range in
                    Task { await refreshListenBrainzArchive(range: range) }
                }
                Button {
                    Task { await refreshListenBrainzArchive() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }

            if let snapshot = scrobbleService.listenBrainzStats {
                HStack(spacing: 12) {
                    metricPill("User", snapshot.username)
                    metricPill("Range", snapshot.range.title)
                    metricPill("Listens", snapshot.totalListenCount?.formatted() ?? "Pending")
                    metricPill("Fetched", snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))
                }

                if !snapshot.listeningActivity.isEmpty {
                    Text("Listening Activity")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    listeningActivityChart(snapshot.listeningActivity, range: snapshot.range)
                }

                if !snapshot.topRecordings.isEmpty {
                    Text("\(snapshot.topRecordings.count) ListenBrainz Tracks")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    VStack(spacing: 8) {
                        ForEach(snapshot.topRecordings.prefix(10)) { recording in
                            chartRow(
                                title: recording.trackName,
                                subtitle: recordingSubtitle(recording),
                                count: recording.listenCount
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onOpenTrack(recording.trackName, recording.artistName) }
                        }
                    }
                }

                if !snapshot.topArtists.isEmpty {
                    Text("\(snapshot.topArtists.count) ListenBrainz Artists")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    VStack(spacing: 8) {
                        ForEach(snapshot.topArtists.prefix(8)) { artist in
                            chartRow(
                                title: artist.name,
                                subtitle: "Artist",
                                count: artist.listenCount
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onOpenArtist(artist.name) }
                        }
                    }
                }

                if !snapshot.topReleases.isEmpty {
                    Text("\(snapshot.topReleases.count) ListenBrainz Releases")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                        ForEach(snapshot.topReleases.prefix(8)) { release in
                            VStack(alignment: .leading, spacing: 6) {
                                cover(nil, size: metrics.coverSize, placeholder: release.name)
                                Text(release.name)
                                    .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                    .lineLimit(2)
                                Text(release.artistName)
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                    .foregroundStyle(.secondary)
                                Text("\(release.listenCount.formatted()) listens")
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont - 1))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenAlbum(release.name, release.artistName, nil)
                            }
                        }
                    }
                }

                if !snapshot.recentListens.isEmpty {
                    Text("Recent ListenBrainz Activity")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    VStack(spacing: 8) {
                        ForEach(snapshot.recentListens.prefix(8)) { listen in
                            chartRow(
                                title: listen.trackName,
                                subtitle: "\(listen.artistName)\(listen.listenedAt.map { " - \($0.formatted(date: .omitted, time: .shortened))" } ?? "")",
                                count: 1
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { onOpenTrack(listen.trackName, listen.artistName) }
                        }
                    }
                }
            } else if scrobbleService.listenBrainzEnabled {
                Text("No ListenBrainz charts loaded yet.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("Connect ListenBrainz in Preferences to unlock open archive charts, recent listens, and cross-platform history.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    @ViewBuilder
    private func listenBrainzArtistOrigins(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Artist Origins")
                    .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                Text(scrobbleService.listenBrainzArtistMapStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            if !scrobbleService.listenBrainzArtistMap.isEmpty {
                HStack(spacing: 12) {
                    metricPill("Countries", "\(scrobbleService.listenBrainzArtistMap.count)")
                    metricPill("Top Origin", countryLabel(for: scrobbleService.listenBrainzArtistMap.first?.countryCode))
                    metricPill("Range", listenBrainzRange.title)
                }

                VStack(spacing: 8) {
                    ForEach(scrobbleService.listenBrainzArtistMap.prefix(10)) { entry in
                        artistOriginRow(entry, max: scrobbleService.listenBrainzArtistMap.first?.artistCount ?? 1)
                    }
                }
            } else if scrobbleService.listenBrainzEnabled {
                Text("No origin map available yet for this range.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    @ViewBuilder
    private func listenBrainzArtistAffinity(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Affinity Network")
                    .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                Text(scrobbleService.listenBrainzArtistAffinityStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            if let graph = scrobbleService.listenBrainzArtistAffinityGraph, !graph.nodes.isEmpty {
                HStack(spacing: 12) {
                    metricPill("Seed Artists", "\(graph.nodes.filter(\.isSeed).count)")
                    metricPill("Nodes", "\(graph.nodes.count)")
                    metricPill("Edges", "\(graph.edges.count)")
                }

                ArtistAffinityGraphView(graph: graph) { artist in
                    onOpenArtist(artist)
                }
                .frame(height: 360)
            } else if scrobbleService.listenBrainzEnabled {
                Text("No affinity network available yet for this range.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    private func metricPill(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("Avenir Next Medium", size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func recordingSubtitle(_ recording: ListenBrainzRecordingStat) -> String {
        if let release = recording.releaseName?.nilIfBlank {
            return "\(recording.artistName) - \(release)"
        }
        return recording.artistName
    }

    private func chartRow(title: String, subtitle: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Avenir Next Medium", size: 15))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(count.formatted())
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func listeningActivityChart(_ activity: [ListenBrainzListeningActivity], range: ListenBrainzStatsRange) -> some View {
        let visible = Array(activity.suffix(28))
        let maxCount = max(visible.map(\.listenCount).max() ?? 1, 1)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .bottom, spacing: 5) {
                ForEach(visible) { entry in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [Color.accentColor.opacity(0.9), Color.cyan.opacity(0.72)],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(height: max(8, CGFloat(entry.listenCount) / CGFloat(maxCount) * 118))
                            .help("\(entry.label): \(entry.listenCount.formatted()) listens")
                        Text(shortActivityLabel(entry, range: range))
                            .font(.custom("Avenir Next Medium", size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 30)
                    }
                    .frame(maxWidth: .infinity, alignment: .bottom)
                }
            }
            .frame(height: 152)
            HStack {
                Text("X-axis: \(activityAxisLabel(for: range))")
                Spacer()
                Text("Y-axis: listens")
            }
            .font(.custom("Avenir Next Medium", size: 10))
            .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func shortActivityLabel(_ activity: ListenBrainzListeningActivity, range: ListenBrainzStatsRange) -> String {
        if let from = activity.from {
            if range == .year || range == .allTime {
                return from.formatted(.dateTime.month(.abbreviated))
            }
            return from.formatted(.dateTime.day())
        }
        return String(activity.label.prefix(3))
    }

    private func activityAxisLabel(for range: ListenBrainzStatsRange) -> String {
        switch range {
        case .week, .month:
            return "days"
        case .year, .allTime:
            return "months"
        }
    }

    private func artistOriginRow(_ entry: ListenBrainzArtistMapEntry, max: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(countryLabel(for: entry.countryCode))
                    .font(.custom("Avenir Next Medium", size: 15))
                Text(entry.countryCode)
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.92), Color.accentColor.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            GeometryReader { geo in
                                let ratio = max > 0 ? Double(entry.artistCount) / Double(max) : 0
                                Rectangle().frame(width: geo.size.width * ratio)
                            }
                        )
                }
                .frame(height: 12)

            Text(entry.artistCount.formatted())
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(8)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func countryLabel(for code: String?) -> String {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return "Unknown"
        }
        return code
    }

    private func refreshListenBrainzArchive(range: ListenBrainzStatsRange? = nil) async {
        let selectedRange = range ?? listenBrainzRange
        await scrobbleService.refreshListenBrainzStats(range: selectedRange)
        await scrobbleService.refreshListenBrainzArtistMap(range: selectedRange)
        await scrobbleService.refreshListenBrainzArtistAffinity(range: selectedRange)
    }

    // Charts use adaptive card columns instead of hard-coded horizontal strips.
    // The current desktop pattern is to let cards wrap as width changes and keep
    // content readable, rather than preserving a fixed card width that forces
    // clipping or excessive horizontal scrolling.
    private struct ChartsMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 980 }
        var isNarrow: Bool { width < 760 }
        var contentMaxWidth: CGFloat { isCompact ? .infinity : 1240 }
        var screenTitleFont: CGFloat { isNarrow ? 22 : 24 }
        var sectionCountFont: CGFloat { isNarrow ? 24 : 30 }
        var coverSize: CGFloat { isNarrow ? 136 : 156 }
        var trackCoverSize: CGFloat { isNarrow ? 46 : 54 }
        var cardTitleFont: CGFloat { isNarrow ? 15 : 16 }
        var cardMetaFont: CGFloat { isNarrow ? 13 : 14 }
        var trackTitleFont: CGFloat { isNarrow ? 16 : 18 }
        var trackMetaFont: CGFloat { isNarrow ? 14 : 16 }
        var trackCountFont: CGFloat { isNarrow ? 14 : 16 }
        var cardColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 144 : 160), spacing: 16, alignment: .topLeading)]
        }
    }

    @ViewBuilder
    private func cover(_ urlString: String?, size: CGFloat, placeholder: String? = nil) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                coverPlaceholder(size: size, text: placeholder)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            coverPlaceholder(size: size, text: placeholder)
        }
    }

    private func coverPlaceholder(size: CGFloat, text: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let text, !text.isEmpty {
                Text(monogram(for: text))
                    .font(.custom("Avenir Next Demi Bold", size: max(18, size * 0.26)))
                    .foregroundStyle(Color.white.opacity(0.78))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: max(14, size * 0.2), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func monogram(for text: String) -> String {
        let parts = text.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map { String($0).uppercased() }
        if !chars.isEmpty {
            return chars.joined()
        }
        return String(text.prefix(2)).uppercased()
    }

    private var topTracks: [ChartEntry] {
        groupedEntries { item in
            (title: item.track, artist: item.artist, imageURL: item.imageURL)
        }
    }

    private var topAlbums: [ChartEntry] {
        groupedEntries { item in
            let title = item.album ?? "Unknown Album"
            return (title: title, artist: item.artist, imageURL: item.imageURL)
        }
    }

    private func groupedEntries(
        _ key: (CompatibilityRecentScrobble) -> (title: String, artist: String, imageURL: String?)
    ) -> [ChartEntry] {
        var map: [String: ChartEntry] = [:]
        for item in scrobbleService.latestScrobbles {
            let parts = key(item)
            let id = "\(parts.artist)|\(parts.title)"
            if var existing = map[id] {
                existing.count += 1
                if existing.imageURL == nil { existing.imageURL = parts.imageURL }
                map[id] = existing
            } else {
                map[id] = ChartEntry(
                    id: id,
                    title: parts.title,
                    artist: parts.artist,
                    imageURL: parts.imageURL,
                    count: 1
                )
            }
        }
        return map.values.sorted { $0.count > $1.count }
    }
}

private struct ChartEntry {
    let id: String
    let title: String
    let artist: String
    var imageURL: String?
    var count: Int
}

private struct ArtistAffinityGraphView: View {
    let graph: ArtistAffinityGraphSnapshot
    let onOpenArtist: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Connected through ListenBrainz similarity data")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Pinch to zoom, drag to pan")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        zoom = 1
                        accumulatedZoom = 1
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 11))
            }

            GeometryReader { geo in
                let positions = layoutPositions(in: geo.size)
                ZStack {
                    ForEach(graph.edges) { edge in
                        if let from = positions[edge.from], let to = positions[edge.to] {
                            Path { path in
                                path.move(to: from)
                                path.addLine(to: to)
                            }
                            .stroke(Color.white.opacity(0.12), lineWidth: edgeWidth(edge.weight))
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenArtist(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSeed ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSeed || node.connectionCount > 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 16)
                            }
                        }
                    }
                }
                .scaleEffect(zoom)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: accumulatedOffset.width + value.translation.width,
                                height: accumulatedOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            accumulatedOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(4.0, max(0.55, accumulatedZoom * value))
                        }
                        .onEnded { _ in
                            accumulatedZoom = zoom
                        }
                )
            }

            HStack(spacing: 14) {
                legendDot(accent, "Seeds")
                legendDot(.cyan, "Cross-linked")
                legendDot(.white.opacity(0.65), "Related")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let seeds = graph.nodes.filter(\.isSeed)
        let nonSeeds = graph.nodes.filter { !$0.isSeed }
        var positions: [String: CGPoint] = [:]

        if seeds.isEmpty {
            return positions
        }

        let innerRadius = min(size.width, size.height) * 0.18
        for (index, node) in seeds.enumerated() {
            let angle = (2 * Double.pi * (Double(index) / Double(max(1, seeds.count)))) - Double.pi / 2
            positions[node.id] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * innerRadius,
                y: center.y + CGFloat(sin(angle)) * innerRadius
            )
        }

        let outerRadius = min(size.width, size.height) * 0.39
        for (index, node) in nonSeeds.enumerated() {
            let angle = (2 * Double.pi * (Double(index) / Double(max(1, nonSeeds.count)))) - Double.pi / 2
            positions[node.id] = CGPoint(
                x: center.x + CGFloat(cos(angle)) * outerRadius,
                y: center.y + CGFloat(sin(angle)) * outerRadius
            )
        }

        return positions
    }

    private func nodeColor(_ node: ArtistAffinityNode) -> Color {
        if node.isSeed { return accent }
        if node.connectionCount > 1 { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: ArtistAffinityNode) -> CGFloat {
        if node.isSeed { return 18 }
        if node.connectionCount > 1 { return 14 }
        return 10
    }

    private func edgeWidth(_ weight: Int) -> CGFloat {
        if weight > 100_000 { return 2.4 }
        if weight > 10_000 { return 1.8 }
        return 1.2
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct SharedVaultView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: SharedMusicVaultStore
    @State private var query = ""
    @State private var selectedEntry: SharedMusicEntry?
    @State private var isShareComposerPresented = false

    private var filteredEntries: [SharedMusicEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.entries }
        return store.entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(trimmed) ||
            entry.artist.localizedCaseInsensitiveContains(trimmed) ||
            entry.participantSummary.localizedCaseInsensitiveContains(trimmed) ||
            (entry.message?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sharedHeader
                sharedToolbar
                sharedMetrics
                sharedTimeline
            }
            .padding(24)
        }
        .onAppear {
            store.configure(username: scrobbleService.sessionUsername)
            selectedEntry = selectedEntry ?? store.entries.first
        }
        .onChange(of: scrobbleService.sessionUsername ?? "local") { username in
            store.configure(username: username)
            selectedEntry = store.entries.first
        }
        .sheet(isPresented: $isShareComposerPresented) {
            ShareComposerView(store: store, draft: nil) { entry in
                selectedEntry = entry
            }
            .frame(width: 560, height: 560)
            .padding()
        }
    }

    private var sharedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Shared")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Text("Local-first")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Spacer()
                Button { importSharedBundle() } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                Button { importSharedJSPF() } label: {
                    Label("Import JSPF", systemImage: "music.note.house")
                }
                .buttonStyle(.bordered)
                Button { exportSharedBundle() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.isEmpty)
                Button { exportSharedJSPF() } label: {
                    Label("Export JSPF", systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.filter { $0.entityKind == .track }.isEmpty)
            }

            Text("Share with another app user by exporting a `.openscrobbler-shared.json` bundle, or move track-based shares into portable `.jspf` playlists with MusicBrainz identifiers when available.")
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
        .appPanelStyle()
    }

    private var sharedToolbar: some View {
        HStack(spacing: 10) {
            Label("People, messages, and imported bundles", systemImage: "person.2.wave.2.fill")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(store.status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            TextField("Search people, notes, music", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
        }
        .appPanelStyle()
    }

    private var sharedMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10)
        ], spacing: 10) {
            VaultMetricCard(title: "Archived shares", value: "\(store.entries.count)", detail: "\(sentCount) sent, \(receivedCount) received, \(importedCount) imported")
            VaultMetricCard(title: "People", value: "\(peopleCount)", detail: topPerson.map { "Most shared with \($0)" } ?? "No shared history yet")
            VaultMetricCard(title: "Formats", value: "JSON + JSPF", detail: "\(jspfReadyCount) track shares ready for open playlist export")
        }
    }

    private var sharedTimeline: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Shared Music Timeline", systemImage: "square.and.arrow.up.on.square")
                        .font(.custom("Avenir Next Demi Bold", size: 16))
                    Spacer()
                    Button {
                        isShareComposerPresented = true
                    } label: {
                        Label("Share", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if filteredEntries.isEmpty {
                    VaultEmptyState(title: "No shared music archived", detail: "Create a share or import a bundle from another OpenScrobbler user.")
                } else {
                    ForEach(filteredEntries) { entry in
                        SharedTimelineRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture { selectedEntry = entry }
                    }
                }
            }
            .appPanelStyle()

            SharedDetailView(entry: selectedEntry ?? filteredEntries.first) { entry in
                store.delete(entry)
                selectedEntry = store.entries.first
            }
            .frame(minWidth: 300, maxWidth: 420)
            .appPanelStyle()
        }
    }

    private var sentCount: Int { store.entries.filter { $0.direction == .sent }.count }
    private var receivedCount: Int { store.entries.filter { $0.direction == .received }.count }
    private var importedCount: Int { store.entries.filter { $0.direction == .imported }.count }
    private var jspfReadyCount: Int { store.entries.filter { $0.entityKind == .track }.count }
    private var peopleCount: Int { Set(store.entries.flatMap(\.recipients) + store.entries.compactMap(\.sender)).count }

    private var topPerson: String? {
        let people = store.entries.flatMap(\.recipients) + store.entries.compactMap(\.sender)
        return Dictionary(grouping: people, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }

    private func exportSharedBundle() {
        guard let url = savePanelURL(defaultName: "openscrobbler-shared.openscrobbler-shared.json") else { return }
        do {
            try store.export(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importSharedBundle() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importBundle(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }

    private func exportSharedJSPF() {
        guard let url = savePanelURL(defaultName: "openscrobbler-shared.jspf") else { return }
        do {
            try store.exportJSPF(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importSharedJSPF() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importJSPF(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }
}

private struct ObsessionsVaultView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: ObsessionVaultStore
    @State private var query = ""
    @State private var selectedEntry: ObsessionEntry?
    @State private var isObsessionComposerPresented = false

    private var mergedEntries: [ObsessionEntry] {
        let localRecordingMBIDs = Set(store.entries.compactMap { $0.musicBrainzRecordingID?.nilIfBlank?.lowercased() })
        let remoteEntries = listenBrainzPinEntries.filter { entry in
            guard let recordingMBID = entry.musicBrainzRecordingID?.nilIfBlank?.lowercased() else { return true }
            return !localRecordingMBIDs.contains(recordingMBID)
        }
        return (store.entries + remoteEntries).sorted {
            ($0.setAt ?? $0.firstSeenAt) > ($1.setAt ?? $1.firstSeenAt)
        }
    }

    private var filteredEntries: [ObsessionEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return mergedEntries }
        return mergedEntries.filter { entry in
            entry.track.localizedCaseInsensitiveContains(trimmed) ||
            entry.artist.localizedCaseInsensitiveContains(trimmed) ||
            (entry.note?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            entry.source.displayName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var listenBrainzPinEntries: [ObsessionEntry] {
        var seenRowIDs = Set<Int>()
        return ([scrobbleService.listenBrainzCurrentPin].compactMap { $0 } + scrobbleService.listenBrainzPinnedHistory)
            .filter { seenRowIDs.insert($0.id).inserted }
            .map { pin in
                let createdAt = pin.createdAt ?? Date()
                let recordingMBID = pin.recordingMbid?.nilIfBlank
                return ObsessionEntry(
                    id: listenBrainzPinObsessionID(rowID: pin.id),
                    ownerUsername: pin.userName?.nilIfBlank ?? scrobbleService.listenBrainzUsername ?? "listenbrainz",
                    artist: pin.artistName,
                    track: pin.trackName,
                    album: nil,
                    note: pin.blurb?.nilIfBlank,
                    imageURL: nil,
                    compatibilityURL: recordingMBID.map { "https://listenbrainz.org/player/?recording_mbids=\($0)" },
                    musicBrainzArtistID: nil,
                    musicBrainzRecordingID: recordingMBID,
                    musicBrainzReleaseID: nil,
                    firstSeenAt: createdAt,
                    setAt: createdAt,
                    endedAt: pin.pinnedUntil,
                    rankMarker: nil,
                    source: .listenBrainzPin
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                obsessionsHeader
                obsessionsToolbar
                obsessionsMetrics
                obsessionsTimeline
            }
            .padding(24)
        }
        .onAppear {
            store.configure(username: scrobbleService.sessionUsername)
            selectedEntry = selectedEntry ?? mergedEntries.first
        }
        .task(id: scrobbleService.listenBrainzUsername ?? "obsessions-listenbrainz-pins") {
            guard scrobbleService.listenBrainzEnabled else { return }
            if scrobbleService.listenBrainzCurrentPin == nil && scrobbleService.listenBrainzPinnedHistory.isEmpty {
                await scrobbleService.refreshListenBrainzPins()
            }
        }
        .onChange(of: scrobbleService.sessionUsername ?? "local") { username in
            store.configure(username: username)
            selectedEntry = mergedEntries.first
        }
        .sheet(isPresented: $isObsessionComposerPresented) {
            ObsessionComposerView(store: store, currentTrack: scrobbleService.currentTrack, draft: nil) { entry in
                selectedEntry = entry
            }
            .frame(width: 560, height: 460)
            .padding()
        }
    }

    private var obsessionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Obsessions")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Text("Local-first")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Spacer()
                Button { importObsessionBundle() } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                Button { exportObsessionBundle() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.isEmpty)
            }

            Text("Obsessions are recovered from this app's local per-account store and optional `.openscrobbler-obsessions.json` imports. They remain portable, private, and independent from any single platform.")
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
        .appPanelStyle()
    }

    private var obsessionsToolbar: some View {
        HStack(spacing: 10) {
            Label("Track intensity, notes, and official-page provenance", systemImage: "sparkles")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(store.status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            if scrobbleService.listenBrainzPinsStatus != "Not loaded" {
                Label(scrobbleService.listenBrainzPinsStatus, systemImage: "pin")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            TextField("Search obsessions", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
        }
        .appPanelStyle()
    }

    private var obsessionsMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10)
        ], spacing: 10) {
            VaultMetricCard(title: "Captured obsessions", value: "\(store.entries.count)", detail: "\(notesCount) with text memories")
            VaultMetricCard(title: "Imports", value: "\(importedCount)", detail: "Recovered from portable bundle files")
            VaultMetricCard(title: "ListenBrainz pins", value: "\(listenBrainzPinEntries.count)", detail: "Remote pins mixed into the timeline")
        }
    }

    private var obsessionsTimeline: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Obsession Timeline", systemImage: "heart.text.square")
                        .font(.custom("Avenir Next Demi Bold", size: 16))
                    Spacer()
                    Button {
                        isObsessionComposerPresented = true
                    } label: {
                        Label("Capture", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if filteredEntries.isEmpty {
                    VaultEmptyState(title: "No obsessions captured", detail: "Capture a track from Now Playing or import a bundle.")
                } else {
                    ForEach(filteredEntries) { entry in
                        ObsessionTimelineRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture { selectedEntry = entry }
                    }
                }
            }
            .appPanelStyle()

            ObsessionDetailView(entry: selectedEntry ?? filteredEntries.first) { entry in
                store.delete(entry)
                selectedEntry = mergedEntries.first
            }
            .frame(minWidth: 300, maxWidth: 420)
            .appPanelStyle()
        }
    }

    private var notesCount: Int { store.entries.filter { !($0.note?.isBlank ?? true) }.count }
    private var importedCount: Int { store.entries.filter { $0.source != .userCaptured }.count }

    private func exportObsessionBundle() {
        guard let url = savePanelURL(defaultName: "openscrobbler-obsessions.openscrobbler-obsessions.json") else { return }
        do {
            try store.export(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importObsessionBundle() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importBundle(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }
}

private struct VaultMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 28))
            Text(detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}

private struct SharedTimelineRow: View {
    let entry: SharedMusicEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.20))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .lineLimit(1)
                    Text(entry.direction.displayName)
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text(entry.artist)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
                Text(entry.message ?? entry.participantSummary)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(vaultDate(entry.createdAt))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Text(entry.source.displayName)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(tint)
            }
        }
        .padding(10)
        .background(isSelected ? tint.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? tint.opacity(0.42) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: String {
        switch entry.entityKind {
        case .track: return "music.note"
        case .album: return "rectangle.stack.fill"
        case .artist: return "person.wave.2.fill"
        }
    }

    private var tint: Color {
        switch entry.direction {
        case .sent: return .cyan
        case .received: return .pink
        case .imported: return .orange
        }
    }
}

private struct ObsessionTimelineRow: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let entry: ObsessionEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.purple.opacity(0.20))
                Image(systemName: "heart.text.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.track)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .lineLimit(1)
                    Text(entry.source.displayName)
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.custom("Avenir Next Demi Bold", size: 9))
                            .foregroundStyle(.white)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.82), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                Text(entry.artist)
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                Text(entry.note ?? "No note captured.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(vaultDate(entry.setAt ?? entry.firstSeenAt))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                if let rank = entry.rankMarker {
                    Text(rank)
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Color.purple.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.purple.opacity(0.42) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SharedDetailView: View {
    let entry: SharedMusicEntry?
    let onDelete: (SharedMusicEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Card")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            if let entry {
                VaultHeroCard(title: entry.title, subtitle: entry.artist, label: entry.entityKind.displayName, tint: .cyan)
                Label(entry.participantSummary, systemImage: "person.2.fill")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(vaultDate(entry.createdAt), systemImage: "calendar")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(entry.apiStatus ?? entry.source.displayName, systemImage: "checkmark.seal")
                    .font(.custom("Avenir Next Medium", size: 13))
                Divider()
                Text(entry.message ?? "No message attached.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    if let urlString = entry.sourceURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Open Source Link", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Select a shared entry.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ObsessionDetailView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let entry: ObsessionEntry?
    let onDelete: (ObsessionEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Obsession Card")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            if let entry {
                VaultHeroCard(title: entry.track, subtitle: entry.artist, label: "Track", tint: .purple)
                Label(vaultDate(entry.setAt ?? entry.firstSeenAt), systemImage: "calendar")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(entry.source.displayName, systemImage: "archivebox")
                    .font(.custom("Avenir Next Medium", size: 13))
                if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
                    Label("Pinned on ListenBrainz", systemImage: "pin.fill")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(.green)
                }
                Divider()
                Text(entry.note ?? "No note captured.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    if let urlString = entry.sourceURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Open Source Link", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        toggleListenBrainzPin(entry)
                    } label: {
                        Label(
                            listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) == nil ? "Pin on ListenBrainz" : "Delete ListenBrainz Pin",
                            systemImage: listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) == nil ? "pin" : "pin.slash"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canToggleListenBrainzPin(entry, scrobbleService: scrobbleService))
                    if entry.source != .listenBrainzPin {
                        Button(role: .destructive) {
                            onDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("Select an obsession.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleListenBrainzPin(_ entry: ObsessionEntry) {
        if let rowID = listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) {
            Task { _ = await scrobbleService.deleteListenBrainzPin(rowID: rowID, title: entry.track) }
            return
        }

        Task {
            _ = await scrobbleService.pinListenBrainzTrack(
                title: entry.track,
                artist: entry.artist,
                album: entry.album,
                recordingMbid: pinRecordingMBID(for: entry, scrobbleService: scrobbleService),
                blurb: entry.note
            )
        }
    }
}

private struct VaultHeroCard: View {
    let title: String
    let subtitle: String
    let label: String
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.22))
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 22))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(height: 170)
    }
}

private struct VaultEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 14))
            Text(detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ShareComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: SharedMusicVaultStore
    let draft: ShareDraft?
    let onSave: (SharedMusicEntry) -> Void
    @State private var kind: SharedMusicEntry.EntityKind = .track
    @State private var direction: SharedMusicEntry.Direction = .sent
    @State private var artist = ""
    @State private var track = ""
    @State private var album = ""
    @State private var recipients = ""
    @State private var sender = ""
    @State private var message = ""
    @State private var makePublic = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Share to Vault")
                .font(.custom("Avenir Next Demi Bold", size: 24))
            Picker("Kind", selection: $kind) {
                ForEach(SharedMusicEntry.EntityKind.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Picker("Direction", selection: $direction) {
                ForEach(SharedMusicEntry.Direction.allCases.filter { $0 != .imported }) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            TextField("Artist", text: $artist)
                .textFieldStyle(.roundedBorder)
            if kind == .track {
                TextField("Track", text: $track)
                    .textFieldStyle(.roundedBorder)
            }
            if kind == .album {
                TextField("Album", text: $album)
                    .textFieldStyle(.roundedBorder)
            }
            if direction == .sent {
                TextField("Recipients, comma-separated", text: $recipients)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("Sender", text: $sender)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Mark as public for future open sharing integrations", isOn: $makePublic)
            TextEditor(text: $message)
                .font(.custom("Avenir Next Regular", size: 13))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            Text("\(message.count)/1000 characters")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(message.count > 1000 ? .red : .secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Archive Share") {
                    let entry = store.makeEntry(
                        kind: kind,
                        direction: direction,
                        artist: artist,
                        track: track,
                        album: album,
                        recipients: recipients.split(separator: ",").map(String.init),
                        sender: sender,
                        message: message,
                        isPublic: makePublic,
                        sourceURL: draft?.sourceURL,
                        imageURL: draft?.imageURL,
                        artistMBID: draft?.artistMBID,
                        recordingMBID: draft?.recordingMBID,
                        releaseMBID: draft?.releaseMBID
                    )
                    store.add(entry)
                    onSave(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSaveShare)
            }
        }
        .onAppear {
            guard let draft else { return }
            kind = draft.kind
            artist = draft.artist
            track = draft.track ?? ""
            album = draft.album ?? ""
        }
    }

    private var canSaveShare: Bool {
        guard !artist.isBlank, message.count <= 1000 else { return false }
        if kind == .track, track.isBlank { return false }
        if kind == .album, album.isBlank { return false }
        if direction == .sent, recipients.isBlank { return false }
        if direction == .received, sender.isBlank { return false }
        return true
    }
}

private struct ObsessionComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: ObsessionVaultStore
    var currentTrack: Track? = nil
    let draft: ObsessionDraft?
    let onSave: (ObsessionEntry) -> Void
    @State private var track = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture Obsession")
                .font(.custom("Avenir Next Demi Bold", size: 24))
            TextField("Track", text: $track)
                .textFieldStyle(.roundedBorder)
            TextField("Artist", text: $artist)
                .textFieldStyle(.roundedBorder)
            TextField("Album", text: $album)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $note)
                .font(.custom("Avenir Next Regular", size: 13))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Button {
                    if let url = store.makeEntry(
                        artist: artist,
                        track: track,
                        album: album,
                        note: note,
                        sourceURL: resolvedSourceURL,
                        imageURL: resolvedImageURL,
                        artistMBID: resolvedArtistMBID,
                        recordingMBID: resolvedRecordingMBID,
                        releaseMBID: resolvedReleaseMBID
                    ).sourceURL.flatMap(URL.init(string:)) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Source Link", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(track.isBlank || artist.isBlank)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save Memory") {
                    let entry = store.makeEntry(
                        artist: artist,
                        track: track,
                        album: album,
                        note: note,
                        sourceURL: resolvedSourceURL,
                        imageURL: resolvedImageURL,
                        artistMBID: resolvedArtistMBID,
                        recordingMBID: resolvedRecordingMBID,
                        releaseMBID: resolvedReleaseMBID
                    )
                    store.add(entry)
                    onSave(entry)
                    pinObsessionIfPossible(entry)
                    dismiss()
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(track.isBlank || artist.isBlank)
            }
        }
        .onAppear {
            if let draft {
                track = draft.track
                artist = draft.artist
                album = draft.album ?? ""
                return
            }
            guard track.isBlank, artist.isBlank, let currentTrack else { return }
            track = currentTrack.title
            artist = currentTrack.artist
            album = currentTrack.album ?? ""
        }
    }

    private var resolvedSourceURL: String? {
        draft?.sourceURL ?? scrobbleService.currentTrackDetails?.url
    }

    private var resolvedImageURL: String? {
        draft?.imageURL ?? scrobbleService.currentOpenEntityDetails?.imageURL ?? scrobbleService.currentTrackDetails?.imageURL
    }

    private var resolvedArtistMBID: String? {
        draft?.artistMBID ?? scrobbleService.currentOpenEntityDetails?.artistMBID
    }

    private var resolvedRecordingMBID: String? {
        draft?.recordingMBID ?? scrobbleService.currentOpenEntityDetails?.recordingMBID
    }

    private var resolvedReleaseMBID: String? {
        draft?.releaseMBID ?? scrobbleService.currentOpenEntityDetails?.releaseMBID
    }

    private func pinObsessionIfPossible(_ entry: ObsessionEntry) {
        Task {
            _ = await scrobbleService.pinListenBrainzTrack(
                title: entry.track,
                artist: entry.artist,
                album: entry.album,
                recordingMbid: entry.musicBrainzRecordingID?.nilIfBlank,
                blurb: entry.note
            )
        }
    }
}

@MainActor
private func isPinnedOnListenBrainz(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    guard let entryRecordingMBID = pinRecordingMBID(for: entry, scrobbleService: scrobbleService),
          let currentPinMBID = scrobbleService.listenBrainzCurrentPin?.recordingMbid?.nilIfBlank else {
        return false
    }
    return entryRecordingMBID.caseInsensitiveCompare(currentPinMBID) == .orderedSame
}

@MainActor
private func listenBrainzPinRowID(for entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Int? {
    if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
        return scrobbleService.listenBrainzCurrentPin?.id
    }
    guard entry.source == .listenBrainzPin else { return nil }
    return listenBrainzPinRowID(from: entry.id)
}

@MainActor
private func canToggleListenBrainzPin(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    if listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) != nil {
        return true
    }
    guard scrobbleService.listenBrainzEnabled else { return false }
    guard !entry.track.isBlank, !entry.artist.isBlank else { return false }
    return entry.source != .listenBrainzPin || pinRecordingMBID(for: entry, scrobbleService: scrobbleService) != nil
}

@MainActor
private func pinRecordingMBID(for entry: ObsessionEntry, scrobbleService: ScrobbleService) -> String? {
    if let recordingMBID = entry.musicBrainzRecordingID?.nilIfBlank {
        return recordingMBID
    }
    guard currentTrackMatches(entry, scrobbleService: scrobbleService) else { return nil }
    return scrobbleService.currentOpenEntityDetails?.recordingMBID?.nilIfBlank
}

@MainActor
private func currentTrackMatches(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    let currentTrack = scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title
    let currentArtist = scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist
    return currentTrack?.caseInsensitiveCompare(entry.track) == .orderedSame &&
        currentArtist?.caseInsensitiveCompare(entry.artist) == .orderedSame
}

private func listenBrainzPinObsessionID(rowID: Int) -> UUID {
    let suffixValue = UInt64(max(rowID, 0)) % 0x1_0000_0000_0000
    let suffix = String(format: "%012llx", suffixValue)
    return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
}

private func listenBrainzPinRowID(from id: UUID) -> Int? {
    let uuid = id.uuidString.lowercased()
    guard uuid.hasPrefix("00000000-0000-0000-0000-") else { return nil }
    guard let suffix = uuid.split(separator: "-").last,
          let value = UInt64(suffix, radix: 16),
          value <= UInt64(Int.max) else {
        return nil
    }
    return Int(value)
}

private func vaultDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
}

private func savePanelURL(defaultName: String) -> URL? {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = defaultName
    panel.canCreateDirectories = true
    panel.allowedContentTypes = [.json]
    return panel.runModal() == .OK ? panel.url : nil
}

private func openPanelURL() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    return panel.runModal() == .OK ? panel.url : nil
}

private func presentVaultError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Vault operation failed"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

private struct ListenBrainzSocialView: View {
    private enum SocialSection: String, CaseIterable, Identifiable {
        case people = "People"
        case activity = "Activity"
        case recommendations = "Recommendations"
        case playlists = "Playlists"

        var id: String { rawValue }
    }

    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var usernameToFollow = ""
    @State private var usernameToCompare = ""
    @State private var playlistTitle = "OpenScrobbler Picks"
    @State private var selectedSection: SocialSection = .people
    let onOpenRecommendation: (ListenBrainzRecommendedRecording) -> Void
    let onShareRecommendation: (ListenBrainzRecommendedRecording) -> Void
    let onRecommendToFollowers: (ListenBrainzRecommendedRecording) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ListenBrainz Social")
                            .font(.custom("Avenir Next Demi Bold", size: 28))
                        Text(scrobbleService.listenBrainzUsername ?? "Connect your ListenBrainz account to unlock the social graph.")
                            .font(.custom("Avenir Next Medium", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await scrobbleService.refreshListenBrainzSocial()
                            await scrobbleService.refreshListenBrainzCompatibility()
                            await scrobbleService.refreshListenBrainzRecommendations()
                            await scrobbleService.refreshListenBrainzPins()
                            await scrobbleService.refreshListenBrainzPlaylists()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                socialOverview

                Picker("Social Section", selection: $selectedSection) {
                    ForEach(SocialSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                selectedSocialSection
            }
            .padding(24)
        }
        .task(id: scrobbleService.listenBrainzUsername ?? "listenbrainz-social") {
            guard scrobbleService.listenBrainzEnabled else { return }
            if scrobbleService.listenBrainzFollowers.isEmpty && scrobbleService.listenBrainzFollowing.isEmpty {
                await scrobbleService.refreshListenBrainzSocial()
            }
            if scrobbleService.listenBrainzCompatibility == nil {
                await scrobbleService.refreshListenBrainzCompatibility()
            }
            if scrobbleService.listenBrainzRecommendations.isEmpty {
                await scrobbleService.refreshListenBrainzRecommendations()
            }
            if scrobbleService.listenBrainzPinnedHistory.isEmpty && scrobbleService.listenBrainzCurrentPin == nil {
                await scrobbleService.refreshListenBrainzPins()
            }
            if scrobbleService.listenBrainzPlaylists.isEmpty && scrobbleService.listenBrainzRecommendationPlaylists.isEmpty {
                await scrobbleService.refreshListenBrainzPlaylists()
            }
        }
    }

    private var socialOverview: some View {
        HStack(spacing: 10) {
            compactMetric("Followers", scrobbleService.listenBrainzFollowers.count)
            compactMetric("Following", scrobbleService.listenBrainzFollowing.count)
            compactMetric("Similar", scrobbleService.listenBrainzSimilarUsers.count)
            compactMetric("Recs", scrobbleService.listenBrainzRecommendations.count)
            compactMetric("Playlists", scrobbleService.listenBrainzPlaylists.count + scrobbleService.listenBrainzRecommendationPlaylists.count)
        }
        .appPanelStyle()
    }

    @ViewBuilder
    private var selectedSocialSection: some View {
        switch selectedSection {
        case .people:
            peopleSection
        case .activity:
            activitySection
        case .recommendations:
            recommendationsSection
        case .playlists:
            playlistsSection
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                followCard
                compareCard
            }

            HStack(alignment: .top, spacing: 14) {
                socialColumn(
                    title: "Followers",
                    subtitle: "People who can receive your personal recommendations.",
                    users: scrobbleService.listenBrainzFollowers,
                    actionTitle: nil,
                    action: nil
                )

                socialColumn(
                    title: "Following",
                    subtitle: "People you follow on ListenBrainz.",
                    users: scrobbleService.listenBrainzFollowing,
                    actionTitle: "Unfollow",
                    action: { user in
                        Task { await scrobbleService.unfollowListenBrainz(user: user) }
                    }
                )
            }

            socialColumn(
                title: "Similar Users",
                subtitle: "Official ListenBrainz compatibility candidates.",
                users: scrobbleService.listenBrainzSimilarUsers.map(\.userName),
                actionTitle: "Compare",
                action: { user in
                    Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: user) }
                }
            )
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            socialListenActivityCard
            HStack(alignment: .top, spacing: 14) {
                currentPinCard
                pinColumn(
                    title: "Following Pins",
                    subtitle: "Active pins from people you follow.",
                    pins: scrobbleService.listenBrainzFollowingPins
                )
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                currentPinCard
                playlistBuilderCard
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended For You")
                    .font(.custom("Avenir Next Demi Bold", size: 18))

                if scrobbleService.listenBrainzRecommendations.isEmpty {
                    Text("No recommendations loaded yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(scrobbleService.listenBrainzRecommendations) { recommendation in
                            recommendationRow(recommendation)
                        }
                    }
                }
            }
            .appPanelStyle()
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                playlistBuilderCard
                pinColumn(
                    title: "Pin History",
                    subtitle: "Your recent pinned recordings.",
                    pins: scrobbleService.listenBrainzPinnedHistory
                )
            }

            HStack(alignment: .top, spacing: 14) {
                playlistColumn(
                    title: "Your Playlists",
                    subtitle: "Metadata pulled from ListenBrainz.",
                    playlists: scrobbleService.listenBrainzPlaylists
                )

                playlistColumn(
                    title: "Recommendation Playlists",
                    subtitle: "Algorithmic or highlighted recommendation lists.",
                    playlists: scrobbleService.listenBrainzRecommendationPlaylists
                )
            }
        }
    }

    private var followCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Follow Someone")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            HStack(spacing: 10) {
                TextField("ListenBrainz username", text: $usernameToFollow)
                    .textFieldStyle(.roundedBorder)
                Button("Follow") {
                    let target = usernameToFollow
                    Task { await scrobbleService.followListenBrainz(user: target) }
                    usernameToFollow = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameToFollow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(scrobbleService.listenBrainzSocialStatus)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare Archives")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            HStack(spacing: 10) {
                TextField("ListenBrainz username", text: $usernameToCompare)
                    .textFieldStyle(.roundedBorder)
                Button("Compare") {
                    let target = usernameToCompare
                    Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: target) }
                    usernameToCompare = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameToCompare.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            compatibilitySummaryCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func compactMetric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.custom("Avenir Next Demi Bold", size: 18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compatibilitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let compatibility = scrobbleService.listenBrainzCompatibility {
                let percentage = Int((compatibility.similarityScore * 100).rounded())
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(compatibility.targetUserName)
                            .font(.custom("Avenir Next Demi Bold", size: 16))
                        Text("\(percentage)% compatibility")
                            .font(.custom("Avenir Next Medium", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh Match") {
                        Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: compatibility.targetUserName) }
                    }
                    .buttonStyle(.bordered)
                }

                if compatibility.sharedArtists.isEmpty {
                    Text("No shared top artists yet.")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(compatibility.sharedArtists.prefix(8)) { artist in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Demi Bold", size: 13))
                                    Text("You \(artist.yourListenCount) · Them \(artist.otherListenCount)")
                                        .font(.custom("Avenir Next Medium", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            } else {
                Text("Pick someone you follow, someone who follows you, or a similar user to compare your open listening history.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentPinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Pin")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Spacer()
                if scrobbleService.listenBrainzCurrentPin != nil {
                    Button("Unpin") {
                        Task { _ = await scrobbleService.unpinListenBrainzCurrent() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let pin = scrobbleService.listenBrainzCurrentPin {
                pinCard(pin)
            } else {
                Text("Nothing pinned right now.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private var socialListenActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Neighbor Listening")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Spacer()
                Text("Followers + Following")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if scrobbleService.listenBrainzSocialListens.isEmpty {
                Text("No public neighbor listens loaded yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(scrobbleService.listenBrainzSocialListens.prefix(18)) { activity in
                        socialListenRow(activity)
                    }
                }
            }
        }
        .appPanelStyle()
    }

    private func socialListenRow(_ activity: ListenBrainzSocialListen) -> some View {
        HStack(alignment: .top, spacing: 10) {
            socialListenArtwork(activity.listen.imageURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.listen.trackName)
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                Text("\(activity.listen.artistName) · \(activity.userName)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                if let release = activity.listen.releaseName {
                    Text(release)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let listenedAt = activity.listen.listenedAt {
                Text(listenedAt.formatted(date: .omitted, time: .shortened))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenRecommendation(
                ListenBrainzRecommendedRecording(
                    id: activity.listen.recordingMBID ?? activity.listen.id,
                    recordingMbid: activity.listen.recordingMBID ?? "",
                    title: activity.listen.trackName,
                    artistName: activity.listen.artistName,
                    releaseName: activity.listen.releaseName,
                    score: 0
                )
            )
        }
    }

    @ViewBuilder
    private func socialListenArtwork(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                socialListenArtworkPlaceholder
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            socialListenArtworkPlaceholder
        }
    }

    private var socialListenArtworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(width: 34, height: 34)
    }

    private var playlistBuilderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build Playlist")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text("Create a ListenBrainz playlist from the first eight recommendations currently loaded.")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            TextField("Playlist title", text: $playlistTitle)
                .textFieldStyle(.roundedBorder)
            Button("Create from Recommendations") {
                let picks = Array(scrobbleService.listenBrainzRecommendations.prefix(8))
                let title = playlistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    _ = await scrobbleService.createListenBrainzPlaylist(
                        title: title.isEmpty ? "OpenScrobbler Picks" : title,
                        from: picks
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(scrobbleService.listenBrainzRecommendations.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func statusCard(title: String, status: String, counts: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(counts, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(.secondary)
                        Text("\(item.1)")
                            .font(.custom("Avenir Next Demi Bold", size: 18))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .appPanelStyle()
    }

    private func socialColumn(
        title: String,
        subtitle: String,
        users: [String],
        actionTitle: String?,
        action: ((String) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if users.isEmpty {
                Text("Nobody here yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(users, id: \.self) { user in
                    HStack {
                        Text(user)
                            .font(.custom("Avenir Next Medium", size: 13))
                        Spacer()
                        if let actionTitle, let action {
                            Button(actionTitle) { action(user) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func recommendationRow(_ recommendation: ListenBrainzRecommendedRecording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                    Text(recommendation.artistName ?? "Unknown artist")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                    if let releaseName = recommendation.releaseName {
                        Text(releaseName)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(String(format: "%.2f", recommendation.score))
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            HStack(spacing: 10) {
                Button("Inspect") {
                    onOpenRecommendation(recommendation)
                }
                .buttonStyle(.bordered)

                Button("Share to Vault") {
                    onShareRecommendation(recommendation)
                }
                .buttonStyle(.bordered)

                Button("Pin") {
                    Task { _ = await scrobbleService.pinListenBrainzRecommendation(recommendation) }
                }
                .buttonStyle(.bordered)

                Button("Recommend") {
                    onRecommendToFollowers(recommendation)
                }
                .buttonStyle(.borderedProminent)
                .disabled(scrobbleService.listenBrainzFollowers.isEmpty)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func pinColumn(title: String, subtitle: String, pins: [ListenBrainzPinnedRecording]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if pins.isEmpty {
                Text("No pin activity yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pins.prefix(6)) { pin in
                    pinCard(pin)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func pinCard(_ pin: ListenBrainzPinnedRecording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pin.trackName)
                .font(.custom("Avenir Next Demi Bold", size: 13))
            Text(pin.artistName)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            if let userName = pin.userName {
                Text(userName)
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
            if let blurb = pin.blurb {
                Text(blurb)
                    .font(.custom("Avenir Next Regular", size: 11))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func playlistColumn(title: String, subtitle: String, playlists: [ListenBrainzPlaylistSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if playlists.isEmpty {
                Text("No playlists loaded.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playlists.prefix(6)) { playlist in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(playlist.title)
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                            Spacer()
                            if let count = playlist.trackCount {
                                Text("\(count) tracks")
                                    .font(.custom("Avenir Next Medium", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let creator = playlist.creator {
                            Text(creator)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if let description = playlist.description {
                            Text(description)
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}

private struct SimilarArtistGraphNode: Identifiable, Equatable {
    let id: String
    let name: String
    let value: Double
    let imageURL: String?
}

private struct SimilarArtistGraphView: View {
    @Environment(\.colorScheme) private var colorScheme
    let centerName: String
    let nodes: [SimilarArtistGraphNode]
    let compact: Bool

    private var visibleNodes: [SimilarArtistGraphNode] {
        Array(nodes.prefix(compact ? 8 : 14))
    }

    var body: some View {
        GeometryReader { proxy in
            let layout = graphLayout(in: proxy.size)
            ZStack {
                graphBackground

                ForEach(visibleNodes) { node in
                    if let point = layout.nodePositions[node.id] {
                        Path { path in
                            path.move(to: layout.center)
                            path.addLine(to: point)
                        }
                        .stroke(edgeColor(for: node).opacity(colorScheme == .dark ? 0.46 : 0.34), lineWidth: 1.25)
                    }
                }

                ForEach(clusterEdges(in: layout.nodePositions), id: \.0) { edge in
                    if let from = layout.nodePositions[edge.0], let to = layout.nodePositions[edge.1] {
                        Path { path in
                            path.move(to: from)
                            path.addLine(to: to)
                        }
                        .stroke(Color.secondary.opacity(0.18), lineWidth: 1)
                    }
                }

                artistNode(
                    title: centerName,
                    fill: Color(red: 0.24, green: 0.20, blue: 0.50),
                    textColor: .white,
                    size: layout.centerSize,
                    fontSize: compact ? 20 : 25
                )
                .position(layout.center)

                ForEach(Array(visibleNodes.enumerated()), id: \.element.id) { index, node in
                    if let point = layout.nodePositions[node.id] {
                        artistNode(
                            title: node.name,
                            fill: nodeFill(index: index, node: node),
                            textColor: nodeTextColor(index: index),
                            size: layout.nodeSizes[node.id] ?? 72,
                            fontSize: compact ? 11 : 13
                        )
                        .position(point)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var graphBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.white.opacity(0.04), Color.white.opacity(0.015)]
                : [Color.white.opacity(0.82), Color(red: 0.91, green: 0.94, blue: 0.99)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.secondary.opacity(0.16), lineWidth: 1)
        }
    }

    private func artistNode(
        title: String,
        fill: Color,
        textColor: Color,
        size: CGFloat,
        fontSize: CGFloat
    ) -> some View {
        ZStack {
            Circle()
                .fill(fill)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 7, x: 0, y: 4)
            Text(title)
                .font(.custom("Avenir Next Medium", size: fontSize))
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.68)
                .padding(.horizontal, 8)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .help(title)
    }

    private struct GraphLayout {
        let center: CGPoint
        let centerSize: CGFloat
        let nodePositions: [String: CGPoint]
        let nodeSizes: [String: CGFloat]
    }

    private func graphLayout(in size: CGSize) -> GraphLayout {
        let center = CGPoint(x: size.width * 0.52, y: size.height * 0.53)
        let centerSize = min(compact ? 108 : 136, min(size.width, size.height) * 0.34)
        let baseRadius = max(92, min(size.width, size.height) * (compact ? 0.34 : 0.38))
        let maxValue = max(1, visibleNodes.map(\.value).max() ?? 1)
        var positions: [String: CGPoint] = [:]
        var sizes: [String: CGFloat] = [:]

        for (index, node) in visibleNodes.enumerated() {
            let count = max(1, visibleNodes.count)
            let spread = count > 10 ? 0.94 : 0.88
            let angle = (2 * Double.pi * (Double(index) / Double(count))) - Double.pi / 2
            let radiusJitter = CGFloat(index % 3) * (compact ? 8 : 14)
            let radius = baseRadius * spread + radiusJitter
            let x = center.x + CGFloat(cos(angle)) * radius
            let y = center.y + CGFloat(sin(angle)) * radius * (compact ? 0.86 : 0.92)
            positions[node.id] = CGPoint(
                x: min(max(x, 44), size.width - 44),
                y: min(max(y, 44), size.height - 44)
            )
            let normalized = CGFloat(node.value / maxValue)
            sizes[node.id] = (compact ? 62 : 76) + normalized * (compact ? 18 : 26)
        }

        return GraphLayout(center: center, centerSize: centerSize, nodePositions: positions, nodeSizes: sizes)
    }

    private func clusterEdges(in positions: [String: CGPoint]) -> [(String, String)] {
        guard visibleNodes.count >= 6 else { return [] }
        return stride(from: 1, to: visibleNodes.count, by: 4).compactMap { index in
            guard index + 1 < visibleNodes.count else { return nil }
            return (visibleNodes[index].id, visibleNodes[index + 1].id)
        }
    }

    private func nodeFill(index: Int, node: SimilarArtistGraphNode) -> Color {
        let palette: [Color] = [
            Color(red: 0.48, green: 0.59, blue: 0.82),
            Color(red: 0.50, green: 0.54, blue: 0.64),
            Color(red: 0.54, green: 0.52, blue: 0.44),
            Color(red: 0.42, green: 0.52, blue: 0.77)
        ]
        return palette[index % palette.count].opacity(node.imageURL == nil ? 0.92 : 1)
    }

    private func nodeTextColor(index: Int) -> Color {
        index % 4 == 0 ? Color.primary.opacity(colorScheme == .dark ? 0.95 : 0.78) : .white
    }

    private func edgeColor(for node: SimilarArtistGraphNode) -> Color {
        node.imageURL == nil ? .secondary : Color(red: 0.48, green: 0.58, blue: 0.82)
    }
}

private struct ListenBrainzRecommendationComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let recommendation: ListenBrainzRecommendedRecording
    let onComplete: () -> Void
    @State private var selectedRecipients: Set<String> = []
    @State private var blurb = ""
    @State private var isSending = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Send Recommendation")
                .font(.custom("Avenir Next Demi Bold", size: 24))

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Text(recommendation.artistName ?? "Unknown artist")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
                if let releaseName = recommendation.releaseName {
                    Text(releaseName)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .appPanelStyle()

            Text("Followers")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(scrobbleService.listenBrainzFollowers, id: \.self) { follower in
                        Toggle(isOn: binding(for: follower)) {
                            Text(follower)
                                .font(.custom("Avenir Next Medium", size: 13))
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
            .frame(maxHeight: 220)
            .appPanelStyle()

            VStack(alignment: .leading, spacing: 8) {
                Text("Blurb")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                TextEditor(text: $blurb)
                    .font(.custom("Avenir Next Regular", size: 13))
                    .frame(height: 120)
                    .padding(8)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }

            Text(scrobbleService.listenBrainzRecommendationShareStatus)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button(isSending ? "Sending..." : "Send") {
                    Task {
                        isSending = true
                        let sent = await scrobbleService.shareListenBrainzRecommendation(
                            recommendation,
                            to: Array(selectedRecipients).sorted(),
                            blurb: blurb
                        )
                        isSending = false
                        if sent {
                            onComplete()
                            dismiss()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSending || selectedRecipients.isEmpty)
            }
        }
    }

    private func binding(for follower: String) -> Binding<Bool> {
        Binding(
            get: { selectedRecipients.contains(follower) },
            set: { isSelected in
                if isSelected {
                    selectedRecipients.insert(follower)
                } else {
                    selectedRecipients.remove(follower)
                }
            }
        )
    }
}

private struct FriendsView: View {
    private enum ActivityFilter: String, CaseIterable, Identifiable {
        case nowPlaying = "Now Playing"
        case hybrid = "Hybrid"
        case all = "All"

        var id: String { rawValue }
    }

    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var query: String
    let onOpenFriendTrack: (CompatibilityFriendListening) -> Void
    let onOpenGraph: (CompatibilityFriendListening) -> Void
    @State private var activityFilter: ActivityFilter = .hybrid
    private let recentNowPlayingWindow: TimeInterval = 30 * 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("People Listening Now")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshFriends() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter people", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.friendsStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Picker("Activity", selection: $activityFilter) {
                    ForEach(ActivityFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                Text("Showing \(filteredFriends.count) of \(scrobbleService.friendsListening.count) people")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredFriends.isEmpty {
                    Text("No public listening activity available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if activityFilter == .hybrid {
                            sectionHeader("Now Playing", count: nowPlayingFriends.count)
                            ForEach(nowPlayingFriends) { friend in
                                friendRow(friend)
                            }

                            sectionHeader("Recently Active", count: recentFriends.count)
                            ForEach(recentFriends) { friend in
                                friendRow(friend)
                            }
                        } else {
                            ForEach(filteredFriends) { friend in
                                friendRow(friend)
                            }
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func time(_ value: Date?) -> String {
        value?.formatted(date: .omitted, time: .shortened) ?? "-"
    }

    @ViewBuilder
    private func friendAvatar(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackFriendAvatar(isNowPlaying: isNowPlaying)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            fallbackFriendAvatar(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendAvatar(isNowPlaying: Bool) -> some View {
        Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(isNowPlaying ? .green : .orange)
            .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func friendTrackArtwork(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendTrackArtwork(isNowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(isNowPlaying ? .green : .secondary)
                .font(.system(size: 11))
        }
        .frame(width: 26, height: 26)
    }

    private var filteredFriends: [CompatibilityFriendListening] {
        let activityFiltered: [CompatibilityFriendListening]
        switch activityFilter {
        case .nowPlaying:
            activityFiltered = scrobbleService.friendsListening.filter(isNowPlaying)
        case .hybrid:
            let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
            activityFiltered = scrobbleService.friendsListening.filter { friend in
                isNowPlaying(friend) || (friend.playedAt ?? .distantPast) >= cutoff
            }
        case .all:
            activityFiltered = scrobbleService.friendsListening
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activityFiltered }
        return activityFiltered.filter { friend in
            friend.user.localizedCaseInsensitiveContains(trimmed) ||
            (friend.track?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (friend.artist?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var nowPlayingFriends: [CompatibilityFriendListening] {
        filteredFriends.filter(isNowPlaying)
    }

    private var recentFriends: [CompatibilityFriendListening] {
        filteredFriends.filter { !isNowPlaying($0) }
    }

    private func isNowPlaying(_ friend: CompatibilityFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        guard let playedAt = friend.playedAt else {
            return false
        }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= recentNowPlayingWindow
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            Text("\(count)")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func friendRow(_ friend: CompatibilityFriendListening) -> some View {
        let nowPlaying = isNowPlaying(friend)
        return HStack(spacing: 10) {
            friendAvatar(friend.avatarURL, isNowPlaying: nowPlaying)
            friendTrackArtwork(friend.imageURL, isNowPlaying: nowPlaying)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = friendBadgeType(friend) {
                        badgeView(badge, fontSize: 9, horizontal: 6, vertical: 2)
                    }
                }
                Text(friend.country ?? "Unknown location")
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
                if let track = friend.track, let artist = friend.artist {
                    Text("\(track) - \(artist)")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.primary)
                } else {
                    Text("No current track")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onOpenGraph(friend)
            } label: {
                separationChip(for: friend.user)
            }
            .buttonStyle(.plain)
            Text(nowPlaying ? "Now" : time(friend.playedAt))
                .font(.custom("Avenir Next Regular", size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .padding(8)
        .background(nowPlaying ? Color.yellow.opacity(0.24) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpenFriendTrack(friend)
        }
    }

    private func friendBadgeType(_ friend: CompatibilityFriendListening) -> String? {
        if let raw = friend.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return friend.isSubscriber ? "subscriber" : nil
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct NeighboursView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenGraph: (CompatibilityNeighbour) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Related Listeners")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshNeighbours() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter related listeners", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.neighboursStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredNeighbours.isEmpty {
                    Text("No related listeners available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    Text("Showing \(filteredNeighbours.count) of \(scrobbleService.neighbours.count) related listeners")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)

                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredNeighbours) { neighbour in
                            neighbourRow(neighbour)
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private var filteredNeighbours: [CompatibilityNeighbour] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.neighbours }
        return scrobbleService.neighbours.filter { item in
            item.user.localizedCaseInsensitiveContains(trimmed) ||
            (item.realname?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (item.country?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func neighbourRow(_ neighbour: CompatibilityNeighbour) -> some View {
        HStack(spacing: 10) {
            Button {
                onOpenGraph(neighbour)
            } label: {
                avatar(neighbour.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(neighbour.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = badgeType(neighbour) {
                        badgeView(badge)
                    }
                }
                if let realname = neighbour.realname, !realname.isEmpty {
                    Text(realname)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                } else if let country = neighbour.country, !country.isEmpty {
                    Text(country)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Compatibility")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.secondary)
                    Text(matchLabel(neighbour.matchScore))
                        .font(.custom("Avenir Next Medium", size: 11))
                }
                matchBar(neighbour.matchScore)
            }
            Spacer()
            Button {
                onOpenGraph(neighbour)
            } label: {
                separationChip(for: neighbour.user)
            }
            .buttonStyle(.plain)
            Button {
                if let raw = neighbour.profileURL, let url = URL(string: raw) {
                    openURL(url)
                } else if let url = URL(string: "https://listenbrainz.org/user/\(neighbour.user)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func avatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackAvatar()
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackAvatar()
        }
    }

    private func fallbackAvatar() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private func matchLabel(_ score: Double?) -> String {
        guard let score else { return "-" }
        return "\(Int((score * 100).rounded()))%"
    }

    private func matchBar(_ score: Double?) -> some View {
        let ratio = min(1, max(0, score ?? 0))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 8)
            .frame(width: 180)
    }

    private func badgeType(_ neighbour: CompatibilityNeighbour) -> String? {
        if let raw = neighbour.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return neighbour.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)
        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

private struct InteractiveSeparationGraphView: View {
    let graph: SocialGraphSnapshot
    let onOpenUser: (String) -> Void
    private let accent = Color(red: 1.0, green: 0.30, blue: 0.35)

    @State private var zoom: CGFloat = 1
    @State private var accumulatedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var accumulatedOffset: CGSize = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Separation Network")
                    .font(.custom("Avenir Next Demi Bold", size: 18))
                Spacer()
                Text("Pinch to zoom, drag to pan")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Button("Reset") {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        zoom = 1
                        accumulatedZoom = 1
                        offset = .zero
                        accumulatedOffset = .zero
                    }
                }
                .buttonStyle(.plain)
                .font(.custom("Avenir Next Medium", size: 11))
            }

            GeometryReader { geo in
                let positions = layoutPositions(in: geo.size)
                ZStack {
                    ForEach(graph.edges) { edge in
                        if let from = positions[edge.from], let to = positions[edge.to] {
                            Path { path in
                                path.move(to: from)
                                path.addLine(to: to)
                            }
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        }
                    }

                    ForEach(graph.nodes) { node in
                        if let point = positions[node.id] {
                            Button {
                                onOpenUser(node.displayName)
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(nodeColor(node))
                                    Circle()
                                        .stroke(Color.white.opacity(0.24), lineWidth: node.isSource ? 2 : 1)
                                }
                                .frame(width: nodeSize(node), height: nodeSize(node))
                            }
                            .buttonStyle(.plain)
                            .position(point)

                            if node.isSource || node.isTarget || node.degree <= 1 {
                                Text(node.displayName)
                                    .font(.custom("Avenir Next Medium", size: 10))
                                    .lineLimit(1)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                                    .position(x: point.x, y: point.y + 14)
                            }
                        }
                    }
                }
                .scaleEffect(zoom)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(
                                width: accumulatedOffset.width + value.translation.width,
                                height: accumulatedOffset.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            accumulatedOffset = offset
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            zoom = min(4.0, max(0.55, accumulatedZoom * value))
                        }
                        .onEnded { _ in
                            accumulatedZoom = zoom
                        }
                )
            }

            HStack(spacing: 14) {
                legendDot(accent, "You")
                legendDot(.cyan, "Target")
                legendDot(.white.opacity(0.6), "Intermediate")
            }
        }
    }

    private func layoutPositions(in size: CGSize) -> [String: CGPoint] {
        guard !graph.nodes.isEmpty else { return [:] }
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let maxDegree = max(1, graph.nodes.map(\.degree).max() ?? 1)
        let baseRadius = min(size.width, size.height) * 0.44
        let ringStep = baseRadius / CGFloat(maxDegree)
        let groups = Dictionary(grouping: graph.nodes, by: \.degree)
        var positions: [String: CGPoint] = [:]
        positions.reserveCapacity(graph.nodes.count)

        for degree in groups.keys.sorted() {
            guard let nodesAtDegree = groups[degree] else { continue }
            if degree == 0 {
                if let source = nodesAtDegree.first {
                    positions[source.id] = center
                }
                continue
            }
            let radius = ringStep * CGFloat(degree)
            let count = nodesAtDegree.count
            for (idx, node) in nodesAtDegree.enumerated() {
                let angle = (2 * Double.pi * (Double(idx) / Double(max(1, count)))) - Double.pi / 2
                let x = center.x + CGFloat(cos(angle)) * radius
                let y = center.y + CGFloat(sin(angle)) * radius
                positions[node.id] = CGPoint(x: x, y: y)
            }
        }
        return positions
    }

    private func nodeColor(_ node: SocialGraphNode) -> Color {
        if node.isSource { return accent }
        if node.isTarget { return .cyan }
        return .white.opacity(0.72)
    }

    private func nodeSize(_ node: SocialGraphNode) -> CGFloat {
        if node.isSource { return 12 }
        if node.isTarget { return 10 }
        return 8
    }

    private func legendDot(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(text)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

private struct ProfileWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

private struct AnimatedAvatarImage: NSViewRepresentable {
    let urls: [URL]
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.enclosingScrollView?.drawsBackground = false
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.load(urls: urls, into: webView)
    }

    final class Coordinator {
        private var lastMarkup: String?

        func load(urls: [URL], into webView: WKWebView) {
            let candidates = urls.map(\.absoluteString)
            guard let data = try? JSONSerialization.data(withJSONObject: candidates),
                  let json = String(data: data, encoding: .utf8) else { return }

            // Use HTML img object-fit cover so avatar is cropped like native cover mode,
            // while still preserving GIF animation.
            let markup = """
            <html>
              <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <style>
                  html,body{margin:0;padding:0;overflow:hidden;background:transparent;width:100%;height:100%;}
                  #avatar{width:100%;height:100%;object-fit:cover;border-radius:50%;display:block;}
                </style>
              </head>
              <body>
                <img id="avatar" alt="" />
                <script>
                  const urls = \(json);
                  let i = 0;
                  const img = document.getElementById('avatar');
                  function next() {
                    if (i >= urls.length) return;
                    img.src = urls[i++];
                  }
                  img.onerror = next;
                  next();
                </script>
              </body>
            </html>
            """

            guard markup != lastMarkup else { return }
            lastMarkup = markup
            webView.loadHTMLString(markup, baseURL: nil)
        }
    }
}

private struct AppBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { proxy in
            let glyphWidth = min(proxy.size.width * 0.50, 860)
            let glyphHeight = glyphWidth * 0.62

            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [
                            Color(red: 0.10, green: 0.10, blue: 0.11),
                            Color(red: 0.05, green: 0.05, blue: 0.06)
                        ]
                        : [
                            Color(red: 0.97, green: 0.96, blue: 0.95),
                            Color(red: 0.93, green: 0.92, blue: 0.90)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.22), .clear]
                        : [Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.12), .clear],
                    center: .topLeading,
                    startRadius: 40,
                    endRadius: 520
                )
                .offset(x: -120, y: -80)

                RadialGradient(
                    colors: colorScheme == .dark
                        ? [Color.white.opacity(0.05), .clear]
                        : [Color.white.opacity(0.18), .clear],
                    center: .center,
                    startRadius: 40,
                    endRadius: 420
                )
                .offset(x: 220, y: -120)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.16)
                        : Color(red: 0.83, green: 0.06, blue: 0.09).opacity(0.09),
                    width: glyphWidth,
                    height: glyphHeight
                )
                .offset(x: -proxy.size.width * 0.10, y: -proxy.size.height * 0.08)

                backdropGlyph(
                    color: colorScheme == .dark
                        ? Color.white.opacity(0.04)
                        : Color.black.opacity(0.035),
                    width: glyphWidth * 0.92,
                    height: glyphHeight * 0.92
                )
                .offset(x: -proxy.size.width * 0.085, y: -proxy.size.height * 0.06)
            }
            .ignoresSafeArea()
        }
    }

    private func backdropGlyph(color: Color, width: CGFloat, height: CGFloat) -> some View {
        // Use a scalable text-based mark here instead of the 18x18 menu bar bitmap.
        // The tray asset is intentionally tiny; blowing it up for the app backdrop
        // creates visible pixelation on large windows.
        Text("as")
            .font(.custom("Avenir Next Heavy", size: width * 0.68))
            .italic()
            .tracking(-width * 0.035)
            .foregroundStyle(color)
            .frame(width: width, height: height, alignment: .center)
            .minimumScaleFactor(0.7)
            .blur(radius: colorScheme == .dark ? 24 : 20)
            .drawingGroup()
    }
}

private struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL
    let content: (Image) -> Content
    let placeholder: () -> Placeholder
    @State private var image: NSImage?
    @State private var loadedURL: URL?
    @State private var failedURL: URL?

    var body: some View {
        Group {
            if let image, loadedURL == url {
                content(Image(nsImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await load(url)
        }
    }

    private func load(_ targetURL: URL) async {
        guard loadedURL != targetURL, failedURL != targetURL else { return }
        image = nil
        loadedURL = nil
        failedURL = nil

        let request = URLRequest(url: targetURL, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)

        if let cached = URLCache.shared.cachedResponse(for: request),
           let decoded = NSImage(data: cached.data) {
            image = decoded
            loadedURL = targetURL
            return
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let decoded = NSImage(data: data) else {
                failedURL = targetURL
                return
            }
            URLCache.shared.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            image = decoded
            loadedURL = targetURL
        } catch {
            failedURL = targetURL
        }
    }
}

private struct HTMLSummaryText: View {
    let rawHTML: String
    let fontSize: CGFloat
    var lineLimit: Int? = nil

    var body: some View {
        Group {
            if let attributed = htmlSummaryAttributedString(from: rawHTML) {
                Text(attributed)
            } else {
                Text(rawHTML)
            }
        }
        .font(.custom("Avenir Next Regular", size: fontSize))
        .foregroundStyle(.secondary)
        .lineLimit(lineLimit)
        .tint(.accentColor)
        .textSelection(.enabled)
    }

    private func htmlSummaryAttributedString(from rawHTML: String) -> AttributedString? {
        guard let data = rawHTML.data(using: .utf8) else { return nil }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        guard let nsAttributed = try? NSAttributedString(data: data, options: options, documentAttributes: nil),
              let attributed = try? AttributedString(nsAttributed, including: AttributeScopes.FoundationAttributes.self) else {
            return nil
        }
        return attributed
    }
}

private extension View {
    func appPanelStyle() -> some View {
        modifier(AppPanelModifier())
    }
}

private extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        return filter { value in
            let key = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !key.isEmpty else { return false }
            return seen.insert(key).inserted
        }
    }
}

private struct AppPanelModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding()
            .background(panelBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(panelBorder, lineWidth: 1)
            )
    }

    private var panelBackground: AnyShapeStyle {
        colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(Color.white.opacity(0.72))
    }

    private var panelBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.08)
    }
}
