import Foundation

struct SocialGraphNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let degree: Int
    let isTarget: Bool
    let isSource: Bool
}

struct SocialGraphEdge: Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
}

struct SocialGraphSnapshot: Equatable {
    let sourceUser: String
    let nodes: [SocialGraphNode]
    let edges: [SocialGraphEdge]
    let generatedAt: Date
}

struct ArtistAffinityNode: Identifiable, Equatable {
    let id: String
    let displayName: String
    let strength: Int
    let isSeed: Bool
    let connectionCount: Int
}

struct ArtistAffinityEdge: Identifiable, Equatable {
    let id: String
    let from: String
    let to: String
    let weight: Int
}

struct ArtistAffinityGraphSnapshot: Equatable {
    let range: ListenBrainzStatsRange
    let nodes: [ArtistAffinityNode]
    let edges: [ArtistAffinityEdge]
    let generatedAt: Date
}

// Contributor map:
// This value is the bridge between MusicBrainz identity resolution and the
// ListenBrainz ecosystem. Add new open-data context here when it should appear
// consistently in dashboard, detail panels, charts, and sharing surfaces.
struct OpenListeningEnrichment: Equatable {
    let userRecordingListenCount: Int?
    let userArtistListenCount: Int?
    let userReleaseListenCount: Int?
    let globalRecordingListenCount: Int?
    let globalRecordingListenerCount: Int?
    let globalArtistListenCount: Int?
    let globalArtistListenerCount: Int?
    let globalReleaseListenCount: Int?
    let globalReleaseListenerCount: Int?
    let topArtistRecordings: [ListenBrainzPopularRecording]
    let similarArtists: [ListenBrainzSimilarArtist]

    static let empty = OpenListeningEnrichment(
        userRecordingListenCount: nil,
        userArtistListenCount: nil,
        userReleaseListenCount: nil,
        globalRecordingListenCount: nil,
        globalRecordingListenerCount: nil,
        globalArtistListenCount: nil,
        globalArtistListenerCount: nil,
        globalReleaseListenCount: nil,
        globalReleaseListenerCount: nil,
        topArtistRecordings: [],
        similarArtists: []
    )

    var hasUsefulData: Bool {
        userRecordingListenCount != nil ||
            userArtistListenCount != nil ||
            userReleaseListenCount != nil ||
            globalRecordingListenCount != nil ||
            globalArtistListenCount != nil ||
            globalReleaseListenCount != nil ||
            !topArtistRecordings.isEmpty ||
            !similarArtists.isEmpty
    }
}

private struct OpenArtistFallback {
    let name: String
    let imageURL: String?
    let summary: String?
    let listeners: Int?
    let playcount: Int?
    let userPlaycount: Int?
    let tags: [String]
    let similarArtists: [ListenBrainzSimilarArtist]
}

@MainActor
final class ScrobbleService: ObservableObject {
    // ScrobbleService intentionally owns the app's high-level listening state.
    // UI views should read these published snapshots and call focused methods
    // below; provider-specific networking belongs in the service clients.
    @Published private(set) var currentTrack: Track?
    @Published private(set) var queuedScrobbles: [Track] = []
    @Published private(set) var queuedSubmissionJobs: [ScrobbleSubmissionJob] = []
    @Published private(set) var scrobblingEnabled = true
    @Published private(set) var isAuthenticated = false
    @Published private(set) var apiConfigured = false
    @Published private(set) var backendName = "Stub"
    @Published private(set) var authError: String?
    @Published private(set) var lastAPIError: String?
    @Published private(set) var monitorStatus = ""
    @Published private(set) var playbackState = "Stopped"
    @Published private(set) var lastSubmittedAt: Date?
    @Published private(set) var queueFilePath = ""
    @Published private(set) var sessionStatus = "Not authenticated"
    @Published private(set) var sessionUsername: String?
    @Published private(set) var listenBrainzEnabled = false
    @Published private(set) var listenBrainzAuthenticated = false
    @Published private(set) var listenBrainzUsername: String?
    @Published private(set) var listenBrainzBaseURL = URL(string: "https://api.listenbrainz.org")!
    @Published private(set) var listenBrainzSubmitNowPlaying = true
    @Published private(set) var listenBrainzSubmitListens = true
    @Published private(set) var listenBrainzStatus = "Not configured"
    @Published private(set) var listenBrainzLastError: String?
    @Published private(set) var listenBrainzStatsStatus = "Not loaded"
    @Published private(set) var listenBrainzStats: ListenBrainzStatsSnapshot?
    @Published private(set) var listenBrainzArtistMap: [ListenBrainzArtistMapEntry] = []
    @Published private(set) var listenBrainzArtistMapStatus = "Not loaded"
    @Published private(set) var listenBrainzArtistAffinityGraph: ArtistAffinityGraphSnapshot?
    @Published private(set) var listenBrainzArtistAffinityStatus = "Not loaded"
    @Published private(set) var listenBrainzFollowers: [String] = []
    @Published private(set) var listenBrainzFollowing: [String] = []
    @Published private(set) var listenBrainzSimilarUsers: [ListenBrainzSimilarUser] = []
    @Published private(set) var listenBrainzSocialListens: [ListenBrainzSocialListen] = []
    @Published private(set) var listenBrainzCompatibility: ListenBrainzUserCompatibility?
    @Published private(set) var listenBrainzCompatibilityTarget: String?
    @Published private(set) var listenBrainzCompatibilityStatus = "Not loaded"
    @Published private(set) var listenBrainzSocialStatus = "Not loaded"
    @Published private(set) var listenBrainzRecommendations: [ListenBrainzRecommendedRecording] = []
    @Published private(set) var listenBrainzRecommendationsStatus = "Not loaded"
    @Published private(set) var listenBrainzRecommendationShareStatus = "Pick a recommendation to share"
    @Published private(set) var listenBrainzCurrentPin: ListenBrainzPinnedRecording?
    @Published private(set) var listenBrainzPinnedHistory: [ListenBrainzPinnedRecording] = []
    @Published private(set) var listenBrainzFollowingPins: [ListenBrainzPinnedRecording] = []
    @Published private(set) var listenBrainzPinsStatus = "Not loaded"
    @Published private(set) var listenBrainzPlaylists: [ListenBrainzPlaylistSummary] = []
    @Published private(set) var listenBrainzRecommendationPlaylists: [ListenBrainzPlaylistSummary] = []
    @Published private(set) var listenBrainzPlaylistsStatus = "Not loaded"
    @Published private(set) var storedAccounts: [CompatibilitySession] = []
    @Published private(set) var capabilitiesStatus = "Unknown"
    @Published private(set) var validationSource = "Live"
    @Published private(set) var lastRecoveryHint: String?
    @Published private(set) var elapsedForCurrentTrack: TimeInterval = 0
    @Published private(set) var scrobbleThreshold: TimeInterval = 0
    @Published private(set) var scrobbleProgress: Double = 0
    @Published private(set) var retryDelaySeconds = 2
    @Published private(set) var isRetryScheduled = false
    @Published private(set) var nextRetryAt: Date?
    @Published private(set) var nowPlayingDelaySeconds = 10
    @Published private(set) var queueSubmitAttempts = 0
    @Published private(set) var queueSubmitFailures = 0
    @Published private(set) var playerEventCount = 0
    @Published private(set) var currentTrackDetails: CompatibilityTrackDetails?
    @Published private(set) var currentArtistDetails: CompatibilityArtistDetails?
    @Published private(set) var currentOpenEntityDetails: OpenMusicEntityDetails?
    @Published private(set) var currentOpenEnrichment: OpenListeningEnrichment?
    @Published private(set) var inspectedTrackDetails: CompatibilityTrackDetails?
    @Published private(set) var inspectedArtistDetails: CompatibilityArtistDetails?
    @Published private(set) var inspectedOpenEntityDetails: OpenMusicEntityDetails?
    @Published private(set) var inspectedOpenEnrichment: OpenListeningEnrichment?
    @Published private(set) var inspectedSimilarTracks: [CompatibilitySimilarTrack] = []
    @Published private(set) var inspectedSimilarAlbums: [CompatibilitySimilarAlbum] = []
    @Published private(set) var inspectStatus = "Select a listen to inspect"
    @Published private(set) var profile: CompatibilityUserProfile?
    @Published private(set) var latestScrobbles: [CompatibilityRecentScrobble] = []
    @Published private(set) var friendsListening: [CompatibilityFriendListening] = []
    @Published private(set) var neighbours: [CompatibilityNeighbour] = []
    @Published private(set) var separationByUser: [String: Int] = [:]
    @Published private(set) var separationStatus = "Not calculated"
    @Published private(set) var socialGraph: SocialGraphSnapshot?
    @Published private(set) var weeklyTopArtists: [CompatibilityTopArtist] = []
    @Published private(set) var monthlyTopArtists: [CompatibilityTopArtist] = []
    @Published private(set) var yearlyTopArtists: [CompatibilityTopArtist] = []
    @Published private(set) var overallTopArtists: [CompatibilityTopArtist] = []
    @Published private(set) var globalTopArtistNames: [String] = []
    @Published private(set) var lovedTracksCount: Int?
    @Published private(set) var tracksPerDayAverage: Int?
    @Published private(set) var isSubscriber = false
    @Published private(set) var exploreStatus = "Waiting for track"
    @Published private(set) var profileStatus = "Not loaded"
    @Published private(set) var scrobblesStatus = "Not loaded"
    @Published private(set) var friendsStatus = "Not loaded"
    @Published private(set) var neighboursStatus = "Not loaded"

    private var api: CompatibilityAPI
    private let listenBrainz: ListenBrainzService
    private let musicBrainz: MusicBrainzService
    private let monitor: PlayerMonitor
    private let sessionStore: CompatibilityAccountsStoring
    private let queueStore: ScrobbleQueueStoring

    private var currentTrackStart: Date?
    private var accumulatedPlayTime: TimeInterval = 0
    private var thresholdTask: Task<Void, Never>?
    private var nowPlayingTask: Task<Void, Never>?
    private var retryTask: Task<Void, Never>?
    private var progressTask: Task<Void, Never>?
    private var exploreTask: Task<Void, Never>?
    private var profileTask: Task<Void, Never>?
    private var friendsRefreshTask: Task<Void, Never>?
    private var separationTask: Task<Void, Never>?
    private var hasQueuedCurrentTrack = false
    private var hasSentNowPlayingForCurrentTrack = false
    private var recentScrobbles: [String: Date] = [:]
    private var friendGraphCache: [String: [String]] = [:]
    // Two graph depths are kept on purpose: quick probes keep list rows cheap,
    // while the detailed inspector can spend more requests to explain a path.
    private let inferredNowPlayingWindow: TimeInterval = 30 * 60
    private let quickSeparationDepth = 6
    private let detailedSeparationDepth = 24
    private let retryJitter: () -> Double
    private let sleepFunction: @Sendable (UInt64) async -> Void

    var accountFooterText: String {
        if listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank {
            return "\(username) (ListenBrainz)"
        }
        if let name = profile?.name.nilIfBlank {
            return "\(name) (\(isAuthenticated ? "Online" : "Offline"))"
        }
        if let username = sessionUsername?.nilIfBlank {
            return "\(username) (\(isAuthenticated ? "Online" : "Offline"))"
        }
        return "Guest (Offline)"
    }

    init(
        api: CompatibilityAPI? = nil,
        listenBrainz: ListenBrainzService = ListenBrainzService(
            urlSession: URLSession.compatibilitySession(proxySettings: ProxySettingsStore().load())
        ),
        musicBrainz: MusicBrainzService = MusicBrainzService(
            urlSession: URLSession.compatibilitySession(proxySettings: ProxySettingsStore().load())
        ),
        monitor: PlayerMonitor = makeDefaultPlayerMonitor(),
        sessionStore: CompatibilityAccountsStoring = CompatibilitySessionStore(),
        queueStore: ScrobbleQueueStoring = ScrobbleQueueStore(),
        retryJitter: @escaping () -> Double = { Double.random(in: 0.85...1.15) },
        sleepFunction: @escaping @Sendable (UInt64) async -> Void = { nanos in
            try? await Task.sleep(nanoseconds: nanos)
        }
    ) {
        if let api {
            self.api = api
        } else if let config = CompatibilityAPIConfig.fromEnvironment() {
            self.api = CompatibilityAPIClient(
                config: config,
                sessionProvider: {
                    URLSession.compatibilitySession(proxySettings: ProxySettingsStore().load())
                }
            )
        } else {
            self.api = CompatibilityAPIStub()
        }

        self.monitor = monitor
        self.listenBrainz = listenBrainz
        self.musicBrainz = musicBrainz
        self.sessionStore = sessionStore
        self.queueStore = queueStore
        self.retryJitter = retryJitter
        self.sleepFunction = sleepFunction
        self.queuedSubmissionJobs = queueStore.loadJobs()
        self.queuedScrobbles = uniqueQueuedTracks(from: self.queuedSubmissionJobs)
        self.apiConfigured = self.api.isConfigured
        self.monitorStatus = monitor.statusDescription
        self.queueFilePath = queueStore.queueFileURL.path
        self.storedAccounts = sessionStore.allSessions()
        refreshListenBrainzState()
        refreshBackendName()

        if let session = sessionStore.load() {
            self.api.restoreSession(session)
        }
        self.isAuthenticated = self.api.isAuthenticated
        self.sessionUsername = self.api.sessionUsername
        self.sessionStatus = self.isAuthenticated ? "Authenticated (not yet validated)" : "Not authenticated"

        self.monitor.onEvent = { [weak self] event in
            Task { @MainActor in
                self?.handlePlayerEvent(event)
            }
        }
        self.monitor.start()

        if self.isAuthenticated {
            Task {
                await validateSessionOnStartup()
                await refreshProfileData()
                await refreshScrobblesData()
                await refreshFriendsData()
                await refreshNeighboursData()
                startFriendsAutoRefresh()
            }
        }

        if !self.queuedScrobbles.isEmpty {
            scheduleRetryIfNeeded()
        }
    }

    deinit {
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        retryTask?.cancel()
        progressTask?.cancel()
        exploreTask?.cancel()
        profileTask?.cancel()
        friendsRefreshTask?.cancel()
        separationTask?.cancel()
        monitor.stop()
    }

    func toggleScrobbling() {
        scrobblingEnabled.toggle()
        if scrobblingEnabled {
            scheduleRetryIfNeeded()
        } else {
            cancelRetrySchedule()
        }
    }

    func configureListenBrainz(
        token: String?,
        baseURL: URL,
        isEnabled: Bool,
        submitNowPlaying: Bool,
        submitListens: Bool
    ) async {
        listenBrainzLastError = nil
        let normalizedBaseURL = baseURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let settings = ListenBrainzSettings(
            isEnabled: isEnabled,
            submitNowPlaying: submitNowPlaying,
            submitListens: submitListens,
            baseURL: URL(string: normalizedBaseURL) ?? ListenBrainzSettings.default.baseURL,
            username: listenBrainzUsername
        )

        do {
            try listenBrainz.update(settings: settings, token: token)
            refreshListenBrainzState()
            refreshBackendName()
            if !isEnabled {
                listenBrainzAuthenticated = false
                listenBrainzStatus = "Configured but disabled"
            }
            scheduleRetryIfNeeded()
        } catch {
            handleListenBrainz(error: error)
        }
    }

    func validateListenBrainz() async {
        listenBrainzLastError = nil
        guard listenBrainzEnabled else {
            listenBrainzAuthenticated = false
            listenBrainzStatus = "Disabled"
            return
        }

        do {
            let validation = try await listenBrainz.validate()
            listenBrainzAuthenticated = validation.isValid
            listenBrainzUsername = validation.username
            listenBrainzStatus = validation.isValid ? "Session valid" : validation.message
            refreshListenBrainzState()
            refreshBackendName()
            scheduleRetryIfNeeded()
            await refreshListenBrainzStats()
            await refreshListenBrainzArtistMap()
            await refreshListenBrainzArtistAffinity()
            await refreshListenBrainzSocial()
            await refreshListenBrainzCompatibility()
            await refreshListenBrainzRecommendations()
            await refreshListenBrainzPins()
            await refreshListenBrainzPlaylists()
        } catch {
            listenBrainzAuthenticated = false
            handleListenBrainz(error: error)
        }
    }

    func refreshListenBrainzStats(range: ListenBrainzStatsRange = .week) async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzStats = nil
            listenBrainzStatsStatus = "Connect ListenBrainz to load charts"
            return
        }
        listenBrainzStatsStatus = "Loading \(range.title.lowercased()) charts..."
        do {
            listenBrainzStats = try await listenBrainz.fetchStatsSnapshot(
                username: username,
                range: range,
                count: 30
            )
            listenBrainzStatsStatus = "Loaded \(range.title.lowercased()) charts"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzStatsStatus = "Failed to load ListenBrainz charts"
        }
    }

    func disconnectListenBrainz() {
        listenBrainz.clear()
        listenBrainzAuthenticated = false
        listenBrainzLastError = nil
        listenBrainzStats = nil
        listenBrainzStatsStatus = "Not configured"
        listenBrainzArtistMap = []
        listenBrainzArtistMapStatus = "Not configured"
        listenBrainzArtistAffinityGraph = nil
        listenBrainzArtistAffinityStatus = "Not configured"
        listenBrainzFollowers = []
        listenBrainzFollowing = []
        listenBrainzSimilarUsers = []
        listenBrainzSocialListens = []
        listenBrainzCompatibility = nil
        listenBrainzCompatibilityTarget = nil
        listenBrainzCompatibilityStatus = "Not configured"
        listenBrainzSocialStatus = "Not configured"
        listenBrainzRecommendations = []
        listenBrainzRecommendationsStatus = "Not configured"
        listenBrainzRecommendationShareStatus = "Pick a recommendation to share"
        listenBrainzCurrentPin = nil
        listenBrainzPinnedHistory = []
        listenBrainzFollowingPins = []
        listenBrainzPinsStatus = "Not configured"
        listenBrainzPlaylists = []
        listenBrainzRecommendationPlaylists = []
        listenBrainzPlaylistsStatus = "Not configured"
        refreshListenBrainzState()
        refreshBackendName()
    }

    func refreshListenBrainzSocial() async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzFollowers = []
            listenBrainzFollowing = []
            listenBrainzSimilarUsers = []
            listenBrainzSocialListens = []
            listenBrainzSocialStatus = "Connect ListenBrainz to load your social graph"
            return
        }

        listenBrainzSocialStatus = "Loading followers, following, and similar users..."
        do {
            async let followers = listenBrainz.fetchFollowers(username: username)
            async let following = listenBrainz.fetchFollowing(username: username)
            async let similarUsers = listenBrainz.fetchSimilarUsers(username: username, count: 12)
            listenBrainzFollowers = try await followers.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            listenBrainzFollowing = try await following.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            listenBrainzSimilarUsers = try await similarUsers
            let neighbors = Array(Set(listenBrainzFollowing + listenBrainzFollowers)).sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            listenBrainzSocialListens = try await listenBrainz.fetchSocialListenActivity(
                usernames: neighbors,
                countPerUser: 3
            )
            listenBrainzSocialStatus = "Loaded \(listenBrainzFollowers.count) followers, \(listenBrainzFollowing.count) following, \(listenBrainzSimilarUsers.count) similar users, and \(listenBrainzSocialListens.count) neighbor listens"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzSocialStatus = "Failed to load ListenBrainz social graph"
        }
    }

    func refreshListenBrainzCompatibility(targetUser: String? = nil) async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let sourceUser = listenBrainzUsername?.nilIfBlank else {
            listenBrainzCompatibility = nil
            listenBrainzCompatibilityTarget = nil
            listenBrainzCompatibilityStatus = "Connect ListenBrainz to compare archives"
            return
        }

        let resolvedTarget = targetUser?.nilIfBlank
            ?? listenBrainzCompatibilityTarget?.nilIfBlank
            ?? listenBrainzSimilarUsers.first?.userName
            ?? listenBrainzFollowing.first
            ?? listenBrainzFollowers.first

        guard let resolvedTarget, resolvedTarget.caseInsensitiveCompare(sourceUser) != .orderedSame else {
            listenBrainzCompatibility = nil
            listenBrainzCompatibilityTarget = nil
            listenBrainzCompatibilityStatus = "Choose another user to compare archives"
            return
        }

        listenBrainzCompatibilityTarget = resolvedTarget
        listenBrainzCompatibilityStatus = "Comparing \(sourceUser) and \(resolvedTarget)..."
        do {
            listenBrainzCompatibility = try await listenBrainz.fetchCompatibility(
                sourceUsername: sourceUser,
                targetUsername: resolvedTarget
            )
            listenBrainzCompatibilityStatus = "Loaded compatibility with \(resolvedTarget)"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzCompatibility = nil
            listenBrainzCompatibilityStatus = "Failed to load compatibility"
        }
    }

    func refreshListenBrainzArtistMap(range: ListenBrainzStatsRange = .week) async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzArtistMap = []
            listenBrainzArtistMapStatus = "Connect ListenBrainz to load artist origins"
            return
        }

        listenBrainzArtistMapStatus = "Loading artist origins..."
        do {
            listenBrainzArtistMap = try await listenBrainz.fetchArtistMap(username: username, range: range)
            listenBrainzArtistMapStatus = listenBrainzArtistMap.isEmpty
                ? "No artist origin data available"
                : "Loaded \(listenBrainzArtistMap.count) countries"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzArtistMapStatus = "Failed to load artist origins"
        }
    }

    func refreshListenBrainzArtistAffinity(range: ListenBrainzStatsRange = .week) async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzArtistAffinityGraph = nil
            listenBrainzArtistAffinityStatus = "Connect ListenBrainz to load artist affinity"
            return
        }

        listenBrainzArtistAffinityStatus = "Loading artist affinity..."
        do {
            let topArtists: [ListenBrainzArtistStat]
            if let snapshot = listenBrainzStats, snapshot.range == range, !snapshot.topArtists.isEmpty {
                topArtists = snapshot.topArtists
            } else {
                topArtists = try await listenBrainz.fetchTopArtists(username: username, range: range, count: 6)
            }

            let seeds = Array(topArtists.filter { ($0.mbid?.isEmpty == false) }.prefix(4))
            guard !seeds.isEmpty else {
                listenBrainzArtistAffinityGraph = nil
                listenBrainzArtistAffinityStatus = "Top artists need MusicBrainz IDs before we can draw affinity"
                return
            }

            var neighborLists: [(seed: ListenBrainzArtistStat, neighbors: [ListenBrainzSimilarArtist])] = []
            for seed in seeds {
                let neighbors = try await listenBrainz.fetchSimilarArtists(
                    seedArtistMBID: seed.mbid ?? "",
                    mode: .easy,
                    maxSimilarArtists: 8,
                    maxRecordingsPerArtist: 3
                )
                neighborLists.append((seed, neighbors))
            }

            var nodeStrengths: [String: Int] = [:]
            var nodeNames: [String: String] = [:]
            var seedIDs = Set<String>()
            var connectionCounts: [String: Int] = [:]
            var edges: [ArtistAffinityEdge] = []

            for seed in seeds {
                guard let seedID = seed.mbid else { continue }
                seedIDs.insert(seedID)
                nodeNames[seedID] = seed.name
                nodeStrengths[seedID] = max(nodeStrengths[seedID] ?? 0, seed.listenCount)
            }

            for result in neighborLists {
                guard let seedID = result.seed.mbid else { continue }
                for neighbor in result.neighbors where !neighbor.isSeedArtist {
                    nodeNames[neighbor.artistMbid] = neighbor.name
                    nodeStrengths[neighbor.artistMbid] = max(nodeStrengths[neighbor.artistMbid] ?? 0, neighbor.totalListenCount)
                    connectionCounts[neighbor.artistMbid, default: 0] += 1
                    edges.append(
                        ArtistAffinityEdge(
                            id: "\(seedID)->\(neighbor.artistMbid)",
                            from: seedID,
                            to: neighbor.artistMbid,
                            weight: neighbor.totalListenCount
                        )
                    )
                }
            }

            let allowedNeighborIDs = Set(
                nodeStrengths
                    .filter { !seedIDs.contains($0.key) }
                    .sorted { lhs, rhs in
                        if lhs.value == rhs.value {
                            return (nodeNames[lhs.key] ?? lhs.key) < (nodeNames[rhs.key] ?? rhs.key)
                        }
                        return lhs.value > rhs.value
                    }
                    .prefix(16)
                    .map(\.key)
            )

            let allowedNodeIDs = seedIDs.union(allowedNeighborIDs)
            let filteredEdges = edges.filter { allowedNodeIDs.contains($0.from) && allowedNodeIDs.contains($0.to) }
            let nodes = allowedNodeIDs.compactMap { id -> ArtistAffinityNode? in
                guard let displayName = nodeNames[id] else { return nil }
                return ArtistAffinityNode(
                    id: id,
                    displayName: displayName,
                    strength: nodeStrengths[id] ?? 0,
                    isSeed: seedIDs.contains(id),
                    connectionCount: connectionCounts[id, default: 0]
                )
            }
            .sorted { lhs, rhs in
                if lhs.isSeed != rhs.isSeed {
                    return lhs.isSeed && !rhs.isSeed
                }
                if lhs.strength == rhs.strength {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }
                return lhs.strength > rhs.strength
            }

            listenBrainzArtistAffinityGraph = ArtistAffinityGraphSnapshot(
                range: range,
                nodes: nodes,
                edges: filteredEdges,
                generatedAt: .now
            )
            listenBrainzArtistAffinityStatus = filteredEdges.isEmpty
                ? "No artist affinity edges available yet"
                : "Loaded \(filteredEdges.count) affinity connections"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzArtistAffinityGraph = nil
            listenBrainzArtistAffinityStatus = "Failed to load artist affinity"
        }
    }

    func refreshListenBrainzRecommendations() async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzRecommendations = []
            listenBrainzRecommendationsStatus = "Connect ListenBrainz to load recommendations"
            return
        }

        listenBrainzRecommendationsStatus = "Loading recommendations..."
        do {
            listenBrainzRecommendations = try await listenBrainz.fetchRecommendedRecordings(
                username: username,
                count: 24
            )
            listenBrainzRecommendationsStatus = "Loaded \(listenBrainzRecommendations.count) recommendations"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzRecommendationsStatus = "Failed to load recommendations"
        }
    }

    func refreshListenBrainzPins() async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzCurrentPin = nil
            listenBrainzPinnedHistory = []
            listenBrainzFollowingPins = []
            listenBrainzPinsStatus = "Connect ListenBrainz to load pins"
            return
        }

        listenBrainzPinsStatus = "Loading pins..."
        do {
            async let current = listenBrainz.fetchCurrentPin(username: username)
            async let history = listenBrainz.fetchPins(username: username, count: 12)
            async let following = listenBrainz.fetchFollowingPins(username: username, count: 12)
            listenBrainzCurrentPin = try await current
            listenBrainzPinnedHistory = try await history
            listenBrainzFollowingPins = try await following
            listenBrainzPinsStatus = "Loaded pins and following activity"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzPinsStatus = "Failed to load pins"
        }
    }

    func refreshListenBrainzPlaylists() async {
        refreshListenBrainzState()
        guard listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzPlaylists = []
            listenBrainzRecommendationPlaylists = []
            listenBrainzPlaylistsStatus = "Connect ListenBrainz to load playlists"
            return
        }

        listenBrainzPlaylistsStatus = "Loading playlists..."
        do {
            async let own = listenBrainz.fetchPlaylists(username: username, count: 16)
            async let recommended = listenBrainz.fetchRecommendationPlaylists(username: username, count: 16)
            listenBrainzPlaylists = try await own
            listenBrainzRecommendationPlaylists = try await recommended
            listenBrainzPlaylistsStatus = "Loaded \(listenBrainzPlaylists.count) playlists"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzPlaylistsStatus = "Failed to load playlists"
        }
    }

    func followListenBrainz(user: String) async {
        let normalized = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            listenBrainzSocialStatus = "Enter a username to follow"
            return
        }

        do {
            try await listenBrainz.follow(username: normalized)
            await refreshListenBrainzSocial()
            listenBrainzSocialStatus = "Now following \(normalized)"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzSocialStatus = "Could not follow \(normalized)"
        }
    }

    func unfollowListenBrainz(user: String) async {
        let normalized = user.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            listenBrainzSocialStatus = "Choose someone to unfollow"
            return
        }

        do {
            try await listenBrainz.unfollow(username: normalized)
            await refreshListenBrainzSocial()
            listenBrainzSocialStatus = "Unfollowed \(normalized)"
        } catch {
            handleListenBrainz(error: error)
            listenBrainzSocialStatus = "Could not unfollow \(normalized)"
        }
    }

    func shareListenBrainzRecommendation(
        _ recommendation: ListenBrainzRecommendedRecording,
        to recipients: [String],
        blurb: String
    ) async -> Bool {
        let users = recipients
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let username = listenBrainzUsername?.nilIfBlank else {
            listenBrainzRecommendationShareStatus = "Validate ListenBrainz before sending recommendations"
            return false
        }
        guard !users.isEmpty else {
            listenBrainzRecommendationShareStatus = "Select at least one follower"
            return false
        }

        listenBrainzRecommendationShareStatus = "Sending recommendation..."
        do {
            try await listenBrainz.recommendRecording(
                recordingMbid: recommendation.recordingMbid,
                to: users,
                blurb: blurb,
                from: username
            )
            listenBrainzRecommendationShareStatus = "Sent to \(users.count) follower\(users.count == 1 ? "" : "s")"
            return true
        } catch {
            handleListenBrainz(error: error)
            listenBrainzRecommendationShareStatus = "Could not send recommendation"
            return false
        }
    }

    func pinListenBrainzRecommendation(_ recommendation: ListenBrainzRecommendedRecording, blurb: String? = nil) async -> Bool {
        listenBrainzPinsStatus = "Pinning recording..."
        do {
            try await listenBrainz.pinRecording(recordingMbid: recommendation.recordingMbid, blurb: blurb)
            await refreshListenBrainzPins()
            listenBrainzPinsStatus = "Pinned \(recommendation.title)"
            return true
        } catch {
            handleListenBrainz(error: error)
            listenBrainzPinsStatus = "Could not pin recording"
            return false
        }
    }

    func unpinListenBrainzCurrent() async -> Bool {
        listenBrainzPinsStatus = "Removing current pin..."
        do {
            try await listenBrainz.unpinCurrentRecording()
            await refreshListenBrainzPins()
            listenBrainzPinsStatus = "Current pin removed"
            return true
        } catch {
            handleListenBrainz(error: error)
            listenBrainzPinsStatus = "Could not remove current pin"
            return false
        }
    }

    func createListenBrainzPlaylist(title: String, from recommendations: [ListenBrainzRecommendedRecording]) async -> Bool {
        let mbids = recommendations.map(\.recordingMbid)
        guard !mbids.isEmpty else {
            listenBrainzPlaylistsStatus = "Choose at least one recommendation"
            return false
        }

        listenBrainzPlaylistsStatus = "Creating playlist..."
        do {
            try await listenBrainz.createPlaylist(title: title, recordingMBIDs: mbids)
            await refreshListenBrainzPlaylists()
            listenBrainzPlaylistsStatus = "Created playlist \(title)"
            return true
        } catch {
            handleListenBrainz(error: error)
            listenBrainzPlaylistsStatus = "Could not create playlist"
            return false
        }
    }

    func signIn(username: String, password: String) async {
        authError = nil
        guard !username.isEmpty, !password.isEmpty else {
            authError = "Username and password are required."
            return
        }

        do {
            let session = try await api.authenticate(username: username, password: password)
            sessionStore.save(session)
            storedAccounts = sessionStore.allSessions()
            isAuthenticated = api.isAuthenticated
            sessionUsername = session.name
            friendGraphCache = [:]
            separationByUser = [:]
            separationStatus = "Not calculated"
            socialGraph = nil
            scheduleRetryIfNeeded()
            await validateSessionOnStartup()
            await refreshProfileData()
            await refreshScrobblesData()
            await refreshFriendsData()
            await refreshNeighboursData()
            startFriendsAutoRefresh()
        } catch {
            handle(error: error)
            authError = lastAPIError
        }
    }

    func signOut() {
        api.clearSession()
        sessionStore.clear()
        storedAccounts = sessionStore.allSessions()
        isAuthenticated = false
        sessionUsername = nil
        authError = nil
        sessionStatus = "Not authenticated"
        capabilitiesStatus = "Unknown"
        validationSource = "Live"
        profile = nil
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectedOpenEntityDetails = nil
        inspectStatus = "Select a listen to inspect"
        latestScrobbles = []
        weeklyTopArtists = []
        monthlyTopArtists = []
        yearlyTopArtists = []
        overallTopArtists = []
        globalTopArtistNames = []
        lovedTracksCount = nil
        tracksPerDayAverage = nil
        profileStatus = "Not loaded"
        scrobblesStatus = "Not loaded"
        isSubscriber = false
        friendsListening = []
        friendsStatus = "Not loaded"
        neighbours = []
        neighboursStatus = "Not loaded"
        listenBrainzFollowers = []
        listenBrainzFollowing = []
        listenBrainzSimilarUsers = []
        listenBrainzSocialListens = []
        listenBrainzCompatibility = nil
        listenBrainzCompatibilityTarget = nil
        listenBrainzCompatibilityStatus = "Not loaded"
        listenBrainzSocialStatus = "Not loaded"
        listenBrainzArtistMap = []
        listenBrainzArtistMapStatus = "Not loaded"
        listenBrainzArtistAffinityGraph = nil
        listenBrainzArtistAffinityStatus = "Not loaded"
        listenBrainzRecommendations = []
        listenBrainzRecommendationsStatus = "Not loaded"
        listenBrainzRecommendationShareStatus = "Pick a recommendation to share"
        listenBrainzCurrentPin = nil
        listenBrainzPinnedHistory = []
        listenBrainzFollowingPins = []
        listenBrainzPinsStatus = "Not loaded"
        listenBrainzPlaylists = []
        listenBrainzRecommendationPlaylists = []
        listenBrainzPlaylistsStatus = "Not loaded"
        separationByUser = [:]
        separationStatus = "Not calculated"
        socialGraph = nil
        separationTask?.cancel()
        separationTask = nil
        friendGraphCache = [:]
        friendsRefreshTask?.cancel()
        friendsRefreshTask = nil
        cancelRetrySchedule()
        scheduleRetryIfNeeded()
    }

    func switchAccount(username: String) async {
        guard let targetSession = sessionStore.allSessions().first(where: {
            $0.name.caseInsensitiveCompare(username) == .orderedSame
        }) else {
            return
        }
        sessionStore.setActive(username: targetSession.name)
        api.restoreSession(targetSession)
        storedAccounts = sessionStore.allSessions()
        isAuthenticated = api.isAuthenticated
        sessionUsername = targetSession.name
        authError = nil
        friendGraphCache = [:]
        separationByUser = [:]
        separationStatus = "Not calculated"
        socialGraph = nil
        scheduleRetryIfNeeded()
        await validateSessionOnStartup()
        await refreshProfileData()
        await refreshScrobblesData()
        await refreshFriendsData()
        await refreshNeighboursData()
        startFriendsAutoRefresh()
    }

    func removeAccount(username: String) async {
        let removingActive = sessionUsername?.caseInsensitiveCompare(username) == .orderedSame
        sessionStore.remove(username: username)
        storedAccounts = sessionStore.allSessions()

        guard removingActive else { return }

        api.clearSession()
        if let nextSession = sessionStore.load() {
            api.restoreSession(nextSession)
            isAuthenticated = api.isAuthenticated
            sessionUsername = nextSession.name
            authError = nil
            await validateSessionOnStartup()
            await refreshProfileData()
            await refreshScrobblesData()
            await refreshFriendsData()
            await refreshNeighboursData()
            startFriendsAutoRefresh()
        } else {
            isAuthenticated = false
            sessionUsername = nil
            sessionStatus = "Not authenticated"
            capabilitiesStatus = "Unknown"
            validationSource = "Live"
            profile = nil
            latestScrobbles = []
            friendsListening = []
            neighbours = []
            weeklyTopArtists = []
            monthlyTopArtists = []
            yearlyTopArtists = []
            overallTopArtists = []
            globalTopArtistNames = []
            lovedTracksCount = nil
            tracksPerDayAverage = nil
            profileStatus = "Not loaded"
            scrobblesStatus = "Not loaded"
            friendsStatus = "Not loaded"
            neighboursStatus = "Not loaded"
            isSubscriber = false
        }
    }

    func refreshExplore() async {
        guard let track = currentTrack else {
            exploreStatus = "Waiting for track"
            currentTrackDetails = nil
            currentArtistDetails = nil
            currentOpenEntityDetails = nil
            currentOpenEnrichment = nil
            return
        }
        await refreshExploreData(for: track)
    }

    func refreshProfile() async {
        await refreshProfileData()
    }

    func refreshScrobbles() async {
        await refreshScrobblesData()
    }

    func refreshFriends() async {
        await refreshFriendsData()
    }

    func refreshNeighbours() async {
        await refreshNeighboursData()
    }

    func prepareSocialGraph(for targetUser: String) async {
        let target = targetUser.trimmingCharacters(in: .whitespacesAndNewlines)
        separationTask?.cancel()
        socialGraph = nil
        guard !target.isEmpty else {
            separationStatus = "No target user selected"
            socialGraph = nil
            return
        }
        guard isAuthenticated else {
            separationStatus = "Sign in to calculate separation"
            socialGraph = nil
            return
        }
        guard let source = api.sessionUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            separationStatus = "No source user available"
            socialGraph = nil
            return
        }

        let targetLower = target.lowercased()
        let sourceLower = source.lowercased()
        if targetLower == sourceLower {
            separationByUser[targetLower] = 0
            separationStatus = "You are 0° away from \(target)"
            socialGraph = SocialGraphSnapshot(
                sourceUser: source,
                nodes: [
                    SocialGraphNode(
                        id: sourceLower,
                        displayName: source,
                        degree: 0,
                        isTarget: true,
                        isSource: true
                    )
                ],
                edges: [],
                generatedAt: Date()
            )
            return
        }

        separationStatus = "Calculating path to \(target)..."
        let results = await bfsDegrees(
            from: source,
            targets: [target],
            maxDepth: detailedSeparationDepth,
            includeContext: false
        )
        guard !Task.isCancelled else { return }
        socialGraph = results.graph

        if let degree = results.degrees[targetLower] {
            separationByUser[targetLower] = degree
            separationStatus = "Found a \(degree)° path to \(target)"
        } else {
            separationByUser[targetLower] = nil
            separationStatus = "No path found within \(detailedSeparationDepth)° for \(target)"
        }
    }

    func separationDegree(for user: String) -> Int? {
        separationByUser[user.lowercased()]
    }

    func inspect(track: String, artist: String) async {
        let item = CompatibilityRecentScrobble(
            id: "\(artist)|\(track)|inspect",
            track: track,
            artist: artist,
            album: nil,
            imageURL: nil,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false
        )
        await inspect(scrobble: item)
    }

    func inspect(scrobble: CompatibilityRecentScrobble) async {
        inspectStatus = "Loading detail..."
        lastAPIError = nil
        lastRecoveryHint = nil
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectedOpenEntityDetails = nil
        inspectedOpenEnrichment = nil
        inspectedSimilarTracks = []
        inspectedSimilarAlbums = []

        var loadedAnything = false
        var degraded = false
        let isArtistOnlyInspection = scrobble.id.hasPrefix("deep-artist-")
        let isAlbumInspection = scrobble.id.hasPrefix("deep-album-")

        do {
            inspectedOpenEntityDetails = try await musicBrainz.lookup(
                track: (!isArtistOnlyInspection && !isAlbumInspection) ? scrobble.track : nil,
                artist: scrobble.artist,
                release: isAlbumInspection ? (scrobble.album ?? scrobble.track) : scrobble.album
            )
            if let inspectedOpenEntityDetails {
                inspectedOpenEnrichment = await loadOpenEnrichment(
                    details: inspectedOpenEntityDetails,
                    track: (!isArtistOnlyInspection && !isAlbumInspection) ? scrobble.track : nil,
                    artist: scrobble.artist,
                    release: isAlbumInspection ? (scrobble.album ?? scrobble.track) : scrobble.album
                )
                inspectedArtistDetails = openArtistDetails(
                    fallback: openArtistFallback(from: inspectedOpenEntityDetails, enrichment: inspectedOpenEnrichment),
                    originalArtist: scrobble.artist
                )
            }
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            degraded = true
            lastAPIError = error.localizedDescription
        }

        guard isAuthenticated else {
            inspectStatus = loadedAnything
                ? (degraded ? "Loaded open metadata (limited)" : "Loaded open metadata")
                : "MusicBrainz lookup failed"
            return
        }

        if !isArtistOnlyInspection && !isAlbumInspection {
            do {
                inspectedTrackDetails = try await fetchWithRetry {
                    try await self.api.fetchTrackDetails(artist: scrobble.artist, track: scrobble.track)
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedTrackDetails = CompatibilityTrackDetails(
                    name: scrobble.track,
                    artist: scrobble.artist,
                    album: scrobble.album,
                    imageURL: scrobble.imageURL,
                    listeners: nil,
                    playcount: nil,
                    userPlaycount: nil,
                    url: scrobble.url,
                    summary: "Detailed track metadata is temporarily unavailable.",
                    tags: []
                )
                loadedAnything = true
                degraded = true
                handle(error: error)
            }

            do {
                inspectedSimilarTracks = try await fetchWithRetry {
                    try await self.api.fetchSimilarTracks(artist: scrobble.artist, track: scrobble.track, limit: 8)
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedSimilarTracks = []
                degraded = true
                handle(error: error)
            }
        }

        if isAlbumInspection {
            do {
                inspectedSimilarAlbums = try await fetchWithRetry {
                    try await self.api.fetchSimilarAlbums(
                        artist: scrobble.artist,
                        album: scrobble.album ?? scrobble.track,
                        limit: 8
                    )
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                inspectedSimilarAlbums = []
                degraded = true
                handle(error: error)
            }
        }

        do {
            inspectedArtistDetails = try await fetchWithRetry {
                try await self.api.fetchArtistDetails(artist: scrobble.artist)
            }
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            inspectedArtistDetails = inspectedArtistDetails ?? CompatibilityArtistDetails(
                    name: scrobble.artist,
                    imageURL: nil,
                    listeners: nil,
                    playcount: nil,
                    userPlaycount: nil,
                    url: nil,
                    summary: "Artist biography and stats are temporarily unavailable.",
                    tags: [],
                    similarArtists: []
                )
            loadedAnything = true
            degraded = true
            handle(error: error)
        }

        if loadedAnything {
            inspectStatus = degraded ? "Loaded (limited)" : "Loaded"
        } else {
            inspectStatus = "Failed to load detail"
        }
    }

    private func fetchWithRetry<T>(_ work: @escaping () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard shouldRetryInspection(error) else {
                throw error
            }
            await sleepFunction(550_000_000)
            return try await work()
        }
    }

    private func shouldRetryInspection(_ error: Error) -> Bool {
        if let apiError = error as? CompatibilityAPIError {
            switch apiError {
            case .networkUnavailable, .transport, .rateLimited:
                return true
            default:
                return false
            }
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost:
                return true
            default:
                return false
            }
        }
        return false
    }

    func clearInspection() {
        inspectedTrackDetails = nil
        inspectedArtistDetails = nil
        inspectedOpenEntityDetails = nil
        inspectedSimilarTracks = []
        inspectedSimilarAlbums = []
        inspectStatus = "Select a listen to inspect"
    }

    func love(scrobble: CompatibilityRecentScrobble) async {
        do {
            try await api.love(track: scrobble.track, artist: scrobble.artist)
            if let index = latestScrobbles.firstIndex(where: { $0.id == scrobble.id }) {
                let item = latestScrobbles[index]
                latestScrobbles[index] = CompatibilityRecentScrobble(
                    id: item.id,
                    track: item.track,
                    artist: item.artist,
                    album: item.album,
                    imageURL: item.imageURL,
                    url: item.url,
                    loved: true,
                    playedAt: item.playedAt,
                    nowPlaying: item.nowPlaying
                )
            }
        } catch {
            handle(error: error)
        }
    }

    func toggleLove(scrobble: CompatibilityRecentScrobble) async {
        do {
            if scrobble.loved {
                try await api.unlove(track: scrobble.track, artist: scrobble.artist)
                updateLovedState(for: scrobble.id, loved: false)
            } else {
                try await api.love(track: scrobble.track, artist: scrobble.artist)
                updateLovedState(for: scrobble.id, loved: true)
            }
        } catch {
            handle(error: error)
        }
    }

    private func updateLovedState(for id: String, loved: Bool) {
        guard let index = latestScrobbles.firstIndex(where: { $0.id == id }) else { return }
        let item = latestScrobbles[index]
        latestScrobbles[index] = CompatibilityRecentScrobble(
            id: item.id,
            track: item.track,
            artist: item.artist,
            album: item.album,
            imageURL: item.imageURL,
            url: item.url,
            loved: loved,
            playedAt: item.playedAt,
            nowPlaying: item.nowPlaying
        )
    }

    func submitQueued() async {
        guard scrobblingEnabled, hasSubmissionBackend else {
            cancelRetrySchedule()
            return
        }
        cancelRetrySchedule()
        queueSubmitAttempts += 1
        lastAPIError = nil
        listenBrainzLastError = nil
        var pending = queuedSubmissionJobs
        var retryableFailures: [ScrobbleSubmissionJob] = []
        var shouldRetry = false
        var shouldStop = false

        while !pending.isEmpty, !shouldStop {
            var job = pending.removeFirst()
            do {
                switch job.backend {
                case .compatibility:
                    guard isAuthenticated else {
                        continue
                    }
                    try await api.scrobble(job.track)
                case .listenBrainz:
                    guard listenBrainz.isReadyForListenSubmission else {
                        continue
                    }
                    try await listenBrainz.submitListen(job.track)
                    listenBrainzStatus = "Submitted listen"
                }
                recentScrobbles[job.track.fingerprint] = .now
            } catch {
                queueSubmitFailures += 1
                job.attempts += 1
                job.lastError = error.localizedDescription

                if error is ListenBrainzError {
                    handleListenBrainz(error: error)
                } else {
                    handle(error: error)
                }

                if isRetryableSubmissionError(error) {
                    shouldRetry = true
                    retryableFailures.append(job)
                    continue
                }

                // Drop permanently-failing submissions so the queue can keep moving.
                if let apiError = error as? CompatibilityAPIError {
                    switch apiError {
                    case .missingSession, .invalidSession, .invalidCredentials:
                        signOut()
                        shouldRetry = false
                        shouldStop = true
                    default:
                        break
                    }
                }
            }
        }

        pending.append(contentsOf: retryableFailures)
        queuedSubmissionJobs = pending
        queuedScrobbles = uniqueQueuedTracks(from: pending)
        if queuedSubmissionJobs.isEmpty {
            lastSubmittedAt = .now
            resetRetryBackoff()
        } else if shouldRetry {
            scheduleRetryIfNeeded()
        }
        persistQueue()
    }

    func queueCurrentTrack() {
        guard let currentTrack, scrobblingEnabled else { return }
        queueIfEligible(currentTrack)
    }

    func retryQueueNow() async {
        guard scrobblingEnabled, hasSubmissionBackend else { return }
        resetRetryBackoff()
        await submitQueued()
    }

    func clearQueue() {
        queuedSubmissionJobs.removeAll()
        queuedScrobbles.removeAll()
        resetRetryBackoff()
        persistQueue()
    }

    private func handlePlayerEvent(_ event: PlayerEvent) {
        playerEventCount += 1
        switch event {
        case let .trackStarted(track):
            handleTrackStarted(track)
        case .paused:
            handlePaused()
        case .resumed:
            handleResumed()
        case .stopped:
            handleStopped()
        }
    }

    private func handleTrackStarted(_ track: Track) {
        finalizeCurrentTrackIfNeeded()

        currentTrack = track
        currentTrackStart = .now
        accumulatedPlayTime = 0
        hasQueuedCurrentTrack = false
        hasSentNowPlayingForCurrentTrack = false
        elapsedForCurrentTrack = 0
        scrobbleThreshold = threshold(for: track)
        scrobbleProgress = 0
        playbackState = "Playing"

        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        scheduleThresholdCheck()
        scheduleNowPlayingIfNeeded()
        startProgressUpdates()

        exploreTask?.cancel()
        exploreTask = Task { @MainActor in
            await refreshExploreData(for: track)
        }
    }

    private func handlePaused() {
        guard playbackState == "Playing" else { return }
        updateElapsedPlayTime()
        playbackState = "Paused"
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
    }

    private func handleResumed() {
        guard playbackState == "Paused", currentTrack != nil else { return }
        playbackState = "Playing"
        currentTrackStart = .now
        scheduleThresholdCheck()
        scheduleNowPlayingIfNeeded()
        startProgressUpdates()
    }

    private func handleStopped() {
        finalizeCurrentTrackIfNeeded()
        nowPlayingTask?.cancel()
        progressTask?.cancel()
        resetPlaybackState()
    }

    private func finalizeCurrentTrackIfNeeded() {
        updateElapsedPlayTime()
        guard let track = currentTrack else { return }

        if elapsedForCurrentTrack >= threshold(for: track) {
            queueIfEligible(track)
        }
    }

    private func updateElapsedPlayTime() {
        guard let start = currentTrackStart else { return }
        accumulatedPlayTime += max(0, Date().timeIntervalSince(start))
        elapsedForCurrentTrack = accumulatedPlayTime
        scrobbleProgress = progressValue(elapsed: elapsedForCurrentTrack, threshold: scrobbleThreshold)
        currentTrackStart = nil
    }

    private func scheduleThresholdCheck() {
        guard let track = currentTrack else { return }
        let needed = max(0, threshold(for: track) - accumulatedPlayTime)
        guard needed > 0 else {
            queueIfEligible(track)
            return
        }

        thresholdTask?.cancel()
        thresholdTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(needed * 1_000_000_000))
            await MainActor.run {
                guard self.playbackState == "Playing", self.currentTrack?.id == track.id else { return }
                self.updateElapsedPlayTime()
                self.queueIfEligible(track)
            }
        }
    }

    private func queueIfEligible(_ track: Track) {
        guard scrobblingEnabled else { return }
        guard isTrackScrobblable(track) else { return }
        guard !hasQueuedCurrentTrack else { return }

        pruneRecentScrobbles()
        let fingerprint = track.fingerprint
        guard recentScrobbles[fingerprint] == nil else { return }
        let backends = activeSubmissionBackends
        guard !backends.isEmpty else { return }
        for backend in backends {
            let job = ScrobbleSubmissionJob(backend: backend, track: track)
            guard !queuedSubmissionJobs.contains(where: { $0.fingerprint == job.fingerprint }) else { continue }
            queuedSubmissionJobs.append(job)
        }
        queuedScrobbles = uniqueQueuedTracks(from: queuedSubmissionJobs)
        hasQueuedCurrentTrack = true
        persistQueue()
        scheduleRetryIfNeeded()
    }

    private func isTrackScrobblable(_ track: Track) -> Bool {
        guard !track.artist.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard !track.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        guard track.duration >= 30 else { return false }
        return true
    }

    private func threshold(for track: Track) -> TimeInterval {
        min(240, max(30, track.duration * 0.5))
    }

    private func persistQueue() {
        queueStore.saveJobs(queuedSubmissionJobs)
    }

    private func isRetryableSubmissionError(_ error: Error) -> Bool {
        if let listenBrainzError = error as? ListenBrainzError {
            switch listenBrainzError {
            case .missingToken, .invalidToken:
                return false
            case .invalidResponse, .api, .rateLimited, .transport:
                return true
            }
        }
        guard let apiError = error as? CompatibilityAPIError else {
            return true
        }
        switch apiError {
        case .networkUnavailable, .transport, .rateLimited:
            return true
        case .missingSession, .invalidCredentials, .invalidSession:
            return false
        case .invalidResponse:
            return true
        case .api:
            return false
        }
    }

    private func scheduleNowPlayingIfNeeded() {
        guard scrobblingEnabled, hasNowPlayingBackend else { return }
        guard playbackState == "Playing" else { return }
        guard let track = currentTrack else { return }
        guard !hasSentNowPlayingForCurrentTrack else { return }

        nowPlayingTask?.cancel()
        let delay = UInt64(nowPlayingDelaySeconds) * 1_000_000_000
        nowPlayingTask = Task {
            await sleepFunction(delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                guard self.playbackState == "Playing" else { return }
                guard self.currentTrack?.id == track.id else { return }
                guard !self.hasSentNowPlayingForCurrentTrack else { return }

                Task {
                    var sent = false
                    do {
                        if self.isAuthenticated {
                            try await self.api.nowPlaying(track)
                            sent = true
                        }
                        if self.listenBrainz.isReadyForNowPlaying {
                            try await self.listenBrainz.nowPlaying(track)
                            sent = true
                            await MainActor.run {
                                self.listenBrainzStatus = "Submitted now playing"
                            }
                        }
                        await MainActor.run {
                            self.hasSentNowPlayingForCurrentTrack = sent
                        }
                    } catch {
                        await MainActor.run {
                            if error is ListenBrainzError {
                                self.handleListenBrainz(error: error)
                            } else {
                                self.handle(error: error)
                            }
                        }
                    }
                }
            }
        }
    }

    private func scheduleRetryIfNeeded() {
        guard scrobblingEnabled, hasSubmissionBackend else { return }
        guard !queuedSubmissionJobs.isEmpty else { return }
        guard !isRetryScheduled else { return }

        let jittered = max(1, Int(Double(retryDelaySeconds) * retryJitter()))
        let fireDate = Date().addingTimeInterval(TimeInterval(jittered))
        isRetryScheduled = true
        nextRetryAt = fireDate

        retryTask?.cancel()
        retryTask = Task {
            await sleepFunction(UInt64(jittered) * 1_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !Task.isCancelled else { return }
                self.isRetryScheduled = false
                self.nextRetryAt = nil
                // Clear task reference before submit; submitQueued() may reset retry state.
                self.retryTask = nil
            }
            guard !Task.isCancelled else { return }
            await submitQueued()
        }

        retryDelaySeconds = min(retryDelaySeconds * 2, 7200)
    }

    private func cancelRetrySchedule() {
        retryTask?.cancel()
        retryTask = nil
        isRetryScheduled = false
        nextRetryAt = nil
    }

    private func resetRetryBackoff() {
        cancelRetrySchedule()
        retryDelaySeconds = 2
    }

    private func pruneRecentScrobbles() {
        let cutoff = Date().addingTimeInterval(-60 * 60)
        recentScrobbles = recentScrobbles.filter { $0.value >= cutoff }
    }

    private func resetPlaybackState() {
        thresholdTask?.cancel()
        nowPlayingTask?.cancel()
        thresholdTask = nil
        nowPlayingTask = nil
        currentTrack = nil
        currentTrackStart = nil
        currentTrackDetails = nil
        currentArtistDetails = nil
        currentOpenEntityDetails = nil
        currentOpenEnrichment = nil
        accumulatedPlayTime = 0
        elapsedForCurrentTrack = 0
        scrobbleThreshold = 0
        scrobbleProgress = 0
        playbackState = "Stopped"
        hasQueuedCurrentTrack = false
        hasSentNowPlayingForCurrentTrack = false
    }

    private func refreshExploreData(for track: Track) async {
        exploreStatus = apiConfigured
            ? "Loading track and artist details..."
            : "Loading open track metadata..."
        lastAPIError = nil
        lastRecoveryHint = nil

        var loadedAnything = false
        var degraded = false

        guard apiConfigured else {
            do {
                currentOpenEntityDetails = try await musicBrainz.lookup(
                    track: track.title,
                    artist: track.artist,
                    release: track.album
                )
                if let currentOpenEntityDetails {
                    currentOpenEnrichment = await loadOpenEnrichment(
                        details: currentOpenEntityDetails,
                        track: track.title,
                        artist: track.artist,
                        release: track.album
                    )
                    currentArtistDetails = openArtistDetails(
                        fallback: openArtistFallback(from: currentOpenEntityDetails, enrichment: currentOpenEnrichment),
                        originalArtist: track.artist
                    )
                }
                loadedAnything = true
            } catch is CancellationError {
                return
            } catch {
                currentOpenEntityDetails = nil
                currentOpenEnrichment = nil
                degraded = true
                lastAPIError = error.localizedDescription
            }
            currentTrackDetails = nil
            exploreStatus = loadedAnything
                ? (degraded ? "Loaded open metadata (limited)" : "Loaded open metadata")
                : "Failed to load open metadata"
            return
        }

        do {
            currentTrackDetails = try await api.fetchTrackDetails(artist: track.artist, track: track.title)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            currentTrackDetails = nil
            degraded = true
            handle(error: error)
        }

        do {
            currentArtistDetails = try await api.fetchArtistDetails(artist: track.artist)
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            currentArtistDetails = nil
            degraded = true
            handle(error: error)
        }

        do {
            currentOpenEntityDetails = try await musicBrainz.lookup(
                track: track.title,
                artist: track.artist,
                release: track.album
            )
            if let currentOpenEntityDetails {
                currentOpenEnrichment = await loadOpenEnrichment(
                    details: currentOpenEntityDetails,
                    track: track.title,
                    artist: track.artist,
                    release: track.album
                )
                if currentArtistDetails == nil {
                    currentArtistDetails = openArtistDetails(
                        fallback: openArtistFallback(from: currentOpenEntityDetails, enrichment: currentOpenEnrichment),
                        originalArtist: track.artist
                    )
                }
            }
            loadedAnything = true
        } catch is CancellationError {
            return
        } catch {
            currentOpenEntityDetails = nil
            currentOpenEnrichment = nil
            degraded = true
            if lastAPIError == nil {
                lastAPIError = error.localizedDescription
            }
        }

        exploreStatus = loadedAnything ? (degraded ? "Loaded (limited)" : "Loaded") : "Failed to load details"
    }

    private func loadOpenEnrichment(
        details: OpenMusicEntityDetails,
        track: String?,
        artist: String,
        release: String?
    ) async -> OpenListeningEnrichment? {
        refreshListenBrainzState()
        guard listenBrainzEnabled else { return nil }

        let username = listenBrainzUsername?.nilIfBlank
        let recordingPopularity = await firstPopularity(details.recordingMBID) { mbids in
            try await listenBrainz.fetchRecordingPopularity(recordingMBIDs: mbids)
        }
        let artistPopularity = await firstPopularity(details.artistMBID) { mbids in
            try await listenBrainz.fetchArtistPopularity(artistMBIDs: mbids)
        }
        let releasePopularity = await firstPopularity(details.releaseMBID) { mbids in
            try await listenBrainz.fetchReleasePopularity(releaseMBIDs: mbids)
        }

        let userRecordingCount: Int?
        let userArtistCount: Int?
        let userReleaseCount: Int?
        if let username {
            userRecordingCount = await userRecordingListenCount(
                username: username,
                recordingMBID: details.recordingMBID,
                track: details.trackName ?? track,
                artist: details.artistName
            )
            userArtistCount = await userArtistListenCount(
                username: username,
                artistMBID: details.artistMBID,
                artist: details.artistName.nilIfBlank ?? artist
            )
            userReleaseCount = await userReleaseListenCount(
                username: username,
                releaseMBID: details.releaseMBID,
                release: details.releaseName ?? release,
                artist: details.artistName.nilIfBlank ?? artist
            )
        } else {
            userRecordingCount = nil
            userArtistCount = nil
            userReleaseCount = nil
        }

        let topRecordings: [ListenBrainzPopularRecording]
        let similarArtists: [ListenBrainzSimilarArtist]
        if let artistMBID = details.artistMBID?.nilIfBlank {
            topRecordings = (try? await listenBrainz.fetchPopularRecordingsForArtist(
                artistMBID: artistMBID,
                count: 8
            )) ?? []
            let rawSimilarArtists = (try? await listenBrainz.fetchSimilarArtists(
                seedArtistMBID: artistMBID,
                maxSimilarArtists: 8,
                maxRecordingsPerArtist: 1
            )) ?? []
            similarArtists = await hydrateListenBrainzSimilarArtistImages(rawSimilarArtists)
        } else {
            topRecordings = []
            similarArtists = []
        }

        let enrichment = OpenListeningEnrichment(
            userRecordingListenCount: userRecordingCount,
            userArtistListenCount: userArtistCount,
            userReleaseListenCount: userReleaseCount,
            globalRecordingListenCount: recordingPopularity?.totalListenCount,
            globalRecordingListenerCount: recordingPopularity?.totalUserCount,
            globalArtistListenCount: artistPopularity?.totalListenCount,
            globalArtistListenerCount: artistPopularity?.totalUserCount,
            globalReleaseListenCount: releasePopularity?.totalListenCount,
            globalReleaseListenerCount: releasePopularity?.totalUserCount,
            topArtistRecordings: topRecordings,
            similarArtists: similarArtists
        )
        return enrichment.hasUsefulData ? enrichment : nil
    }

    private func openArtistFallback(
        from details: OpenMusicEntityDetails,
        enrichment: OpenListeningEnrichment?
    ) -> OpenArtistFallback {
        OpenArtistFallback(
            name: details.artistName,
            imageURL: details.artistImageURL,
            summary: details.artistSummary,
            listeners: enrichment?.globalArtistListenerCount,
            playcount: enrichment?.globalArtistListenCount,
            userPlaycount: enrichment?.userArtistListenCount,
            tags: details.tags,
            similarArtists: enrichment?.similarArtists ?? []
        )
    }

    private func openArtistDetails(
        fallback: OpenArtistFallback,
        originalArtist: String
    ) -> CompatibilityArtistDetails {
        CompatibilityArtistDetails(
            name: fallback.name.nilIfBlank ?? originalArtist,
            imageURL: fallback.imageURL,
            listeners: fallback.listeners,
            playcount: fallback.playcount,
            userPlaycount: fallback.userPlaycount,
            url: nil,
            summary: fallback.summary?.nilIfBlank ?? openArtistSummaryFallback(fallback, originalArtist: originalArtist),
            tags: fallback.tags,
            similarArtists: fallback.similarArtists.map {
                CompatibilitySimilarArtist(
                    id: $0.id,
                    name: $0.name,
                    imageURL: $0.imageURL,
                    url: nil
                )
            }
        )
    }

    private func openArtistSummaryFallback(_ fallback: OpenArtistFallback, originalArtist: String) -> String {
        var fragments: [String] = []
        let name = fallback.name.nilIfBlank ?? originalArtist
        fragments.append("\(name) is indexed in MusicBrainz")
        if let listeners = fallback.listeners {
            fragments.append("ListenBrainz shows \(listeners.formatted()) public listeners")
        }
        if let plays = fallback.playcount {
            fragments.append("\(plays.formatted()) public plays")
        }
        if !fallback.tags.isEmpty {
            fragments.append("Tags: \(fallback.tags.prefix(5).joined(separator: ", "))")
        }
        return fragments.joined(separator: ". ") + "."
    }

    private func hydrateListenBrainzSimilarArtistImages(_ artists: [ListenBrainzSimilarArtist]) async -> [ListenBrainzSimilarArtist] {
        var hydrated: [ListenBrainzSimilarArtist] = []
        hydrated.reserveCapacity(artists.count)
        for (index, artist) in artists.enumerated() {
            guard artist.imageURL == nil, index < 8 else {
                hydrated.append(artist)
                continue
            }
            let imageURL = await musicBrainz.fetchArtistArtwork(
                artistMBID: artist.artistMbid,
                artistName: artist.name
            )
            hydrated.append(
                ListenBrainzSimilarArtist(
                    id: artist.id,
                    artistMbid: artist.artistMbid,
                    name: artist.name,
                    totalListenCount: artist.totalListenCount,
                    isSeedArtist: artist.isSeedArtist,
                    imageURL: imageURL
                )
            )
        }
        return hydrated
    }

    private func firstPopularity(
        _ mbid: String?,
        fetch: ([String]) async throws -> [ListenBrainzPopularityCounts]
    ) async -> ListenBrainzPopularityCounts? {
        guard let mbid = mbid?.nilIfBlank else { return nil }
        return try? await fetch([mbid]).first
    }

    private func userRecordingListenCount(
        username: String,
        recordingMBID: String?,
        track: String?,
        artist: String
    ) async -> Int? {
        guard let recordings = try? await listenBrainz.fetchTopRecordings(
            username: username,
            range: .allTime,
            count: 1000
        ) else { return nil }

        if let recordingMBID = recordingMBID?.nilIfBlank,
           let match = recordings.first(where: { $0.mbid?.caseInsensitiveCompare(recordingMBID) == .orderedSame }) {
            return match.listenCount
        }

        guard let track = track?.nilIfBlank else { return nil }
        let normalizedTrack = normalizedName(track)
        let normalizedArtist = normalizedName(artist)
        return recordings.first {
            normalizedName($0.trackName) == normalizedTrack &&
                normalizedName($0.artistName) == normalizedArtist
        }?.listenCount
    }

    private func userArtistListenCount(username: String, artistMBID: String?, artist: String) async -> Int? {
        guard let artists = try? await listenBrainz.fetchTopArtists(
            username: username,
            range: .allTime,
            count: 1000
        ) else { return nil }

        if let artistMBID = artistMBID?.nilIfBlank,
           let match = artists.first(where: { $0.mbid?.caseInsensitiveCompare(artistMBID) == .orderedSame }) {
            return match.listenCount
        }
        let normalizedArtist = normalizedName(artist)
        return artists.first { normalizedName($0.name) == normalizedArtist }?.listenCount
    }

    private func userReleaseListenCount(
        username: String,
        releaseMBID: String?,
        release: String?,
        artist: String
    ) async -> Int? {
        guard let releases = try? await listenBrainz.fetchTopReleases(
            username: username,
            range: .allTime,
            count: 1000
        ) else { return nil }

        if let releaseMBID = releaseMBID?.nilIfBlank,
           let match = releases.first(where: { $0.mbid?.caseInsensitiveCompare(releaseMBID) == .orderedSame }) {
            return match.listenCount
        }
        guard let release = release?.nilIfBlank else { return nil }
        let normalizedRelease = normalizedName(release)
        let normalizedArtist = normalizedName(artist)
        return releases.first {
            normalizedName($0.name) == normalizedRelease &&
                normalizedName($0.artistName) == normalizedArtist
        }?.listenCount
    }

    private func normalizedName(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func refreshProfileData() async {
        guard isAuthenticated else {
            profileStatus = "Sign in to load profile"
            profile = nil
            weeklyTopArtists = []
            monthlyTopArtists = []
            yearlyTopArtists = []
            overallTopArtists = []
            globalTopArtistNames = []
            lovedTracksCount = nil
            tracksPerDayAverage = nil
            return
        }
        profileStatus = "Loading profile..."
        lastAPIError = nil
        lastRecoveryHint = nil

        profileTask?.cancel()
        profileTask = Task { @MainActor in
            do {
                let profile = try await api.fetchUserProfile()
                async let weekly = api.fetchTopArtists(period: .week, limit: 30)
                async let month = api.fetchTopArtists(period: .month, limit: 40)
                async let year = api.fetchTopArtists(period: .year, limit: 40)
                async let overall = api.fetchTopArtists(period: .overall, limit: 40)
                async let lovedCount = api.fetchLovedTracksCount()
                async let global = api.fetchGlobalTopArtists(limit: 1000)
                self.profile = profile
                let weeklyBase = try await weekly
                let monthlyBase = try await month
                let yearlyBase = try await year
                let overallBase = try await overall
                self.weeklyTopArtists = await self.hydrateTopArtistImages(weeklyBase)
                self.monthlyTopArtists = await self.hydrateTopArtistImages(monthlyBase)
                self.yearlyTopArtists = await self.hydrateTopArtistImages(yearlyBase)
                self.overallTopArtists = await self.hydrateTopArtistImages(overallBase)
                self.lovedTracksCount = try await lovedCount
                self.globalTopArtistNames = (try? await global) ?? []
                self.tracksPerDayAverage = self.computeTracksPerDayAverage(profile)
                self.profileStatus = "Loaded"
            } catch is CancellationError {
                return
            } catch {
                self.handle(error: error)
                self.profileStatus = "Failed to load profile"
            }
        }
    }

    private func refreshScrobblesData() async {
        refreshListenBrainzState()
        scrobblesStatus = "Loading listens..."
        lastAPIError = nil
        lastRecoveryHint = nil

        if listenBrainzEnabled, let username = listenBrainzUsername?.nilIfBlank {
            do {
                let listens = try await listenBrainz.fetchRecentListens(username: username, count: 100)
                latestScrobbles = listens.map(CompatibilityRecentScrobble.init(listenBrainzListen:))
                scrobblesStatus = "Loaded ListenBrainz listens"
                return
            } catch is CancellationError {
                return
            } catch {
                handleListenBrainz(error: error)
                if !isAuthenticated {
                    latestScrobbles = []
                    scrobblesStatus = "Failed to load ListenBrainz listens"
                    return
                }
            }
        }

        guard isAuthenticated else {
            scrobblesStatus = "Connect ListenBrainz to load listens"
            latestScrobbles = []
            return
        }

        do {
            latestScrobbles = try await api.fetchRecentScrobbles(limit: 1000)
            scrobblesStatus = "Loaded"
        } catch is CancellationError {
            return
        } catch {
            handle(error: error)
            scrobblesStatus = "Failed to load listens"
        }
    }

    private func refreshFriendsData() async {
        guard isAuthenticated else {
            friendsStatus = "Connect an account to load people"
            friendsListening = []
            return
        }
        friendsStatus = "Loading people..."
        lastAPIError = nil
        lastRecoveryHint = nil

        do {
            friendsListening = try await api.fetchFriendsListening(limit: 1000).map { friend in
                let inferredNowPlaying = inferredNowPlayingState(for: friend)
                guard inferredNowPlaying != friend.nowPlaying else { return friend }
                return CompatibilityFriendListening(
                    id: friend.id,
                    user: friend.user,
                    realname: friend.realname,
                    country: friend.country,
                    isSubscriber: friend.isSubscriber,
                    accountType: friend.accountType,
                    avatarURL: friend.avatarURL,
                    track: friend.track,
                    artist: friend.artist,
                    imageURL: friend.imageURL,
                    playedAt: friend.playedAt,
                    nowPlaying: inferredNowPlaying
                )
            }.sorted {
                if $0.nowPlaying != $1.nowPlaying {
                    return $0.nowPlaying && !$1.nowPlaying
                }
                let lhs = $0.playedAt ?? .distantPast
                let rhs = $1.playedAt ?? .distantPast
                return lhs > rhs
            }
            let nowCount = friendsListening.filter { inferredNowPlayingState(for: $0) }.count
            friendsStatus = "Loaded \(friendsListening.count) people (\(nowCount) listening now)"
            scheduleSeparationRefresh()
        } catch is CancellationError {
            return
        } catch {
            handle(error: error)
            friendsStatus = "Failed to load people"
        }
    }

    private func refreshNeighboursData() async {
        guard isAuthenticated else {
            neighboursStatus = "Connect an account to load related listeners"
            neighbours = []
            return
        }
        neighboursStatus = "Loading related listeners..."
        lastAPIError = nil
        lastRecoveryHint = nil

        do {
            neighbours = try await api.fetchNeighbours(limit: 500)
            neighboursStatus = "Loaded \(neighbours.count) related listeners"
            scheduleSeparationRefresh()
        } catch is CancellationError {
            return
        } catch let CompatibilityAPIError.api(code, message)
            where code == 3 && message.localizedCaseInsensitiveContains("invalid method") {
            if friendsListening.isEmpty {
                await refreshFriendsData()
            }
            neighbours = fallbackNeighboursFromFriends(limit: 500)
            neighboursStatus = "Related-listener endpoint unavailable; showing \(neighbours.count) people"
            scheduleSeparationRefresh()
        } catch {
            handle(error: error)
            neighboursStatus = "Failed to load related listeners"
        }
    }

    private func fallbackNeighboursFromFriends(limit: Int) -> [CompatibilityNeighbour] {
        let capped = min(max(1, limit), 1000)
        var seen: Set<String> = []
        var output: [CompatibilityNeighbour] = []
        output.reserveCapacity(min(capped, friendsListening.count))

        let sorted = friendsListening.sorted {
            if $0.nowPlaying != $1.nowPlaying {
                return $0.nowPlaying && !$1.nowPlaying
            }
            let lhs = $0.playedAt ?? .distantPast
            let rhs = $1.playedAt ?? .distantPast
            if lhs != rhs {
                return lhs > rhs
            }
            return $0.user.localizedCaseInsensitiveCompare($1.user) == .orderedAscending
        }

        for friend in sorted {
            let trimmedUser = friend.user.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedUser.isEmpty else { continue }
            let key = trimmedUser.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(
                CompatibilityNeighbour(
                    id: "friend-\(key)",
                    user: trimmedUser,
                    realname: friend.realname,
                    country: friend.country,
                    isSubscriber: friend.isSubscriber,
                    accountType: friend.accountType,
                    avatarURL: friend.avatarURL,
                    profileURL: "https://legacy-provider.invalid/user/\(trimmedUser)",
                    matchScore: nil
                )
            )
            if output.count >= capped {
                break
            }
        }
        return output
    }

    private func scheduleSeparationRefresh() {
        separationTask?.cancel()
        separationTask = Task { @MainActor in
            await refreshSeparationDegrees()
        }
    }

    private func refreshSeparationDegrees() async {
        guard isAuthenticated else {
            separationByUser = [:]
            separationStatus = "Sign in to calculate separation"
            return
        }
        guard let source = api.sessionUsername?.trimmingCharacters(in: .whitespacesAndNewlines), !source.isEmpty else {
            separationByUser = [:]
            separationStatus = "No source user available"
            return
        }

        let targetUsers = visibleTargetUsers(source: source)
        guard !targetUsers.isEmpty else {
            separationByUser = [:]
            separationStatus = "No users to compare"
            return
        }

        separationStatus = "Calculating separation paths..."
        let results = await bfsDegrees(from: source, targets: targetUsers, maxDepth: quickSeparationDepth, includeContext: true)
        guard !Task.isCancelled else { return }
        separationByUser = results.degrees
        let found = results.degrees.count
        separationStatus = "Found paths for \(found)/\(targetUsers.count) users"
    }

    private func visibleTargetUsers(source: String) -> [String] {
        let sourceLower = source.lowercased()
        var seen: Set<String> = []
        var targets: [String] = []

        for user in friendsListening.map(\.user) + neighbours.map(\.user) {
            let trimmed = user.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let lower = trimmed.lowercased()
            guard lower != sourceLower else { continue }
            guard !seen.contains(lower) else { continue }
            seen.insert(lower)
            targets.append(trimmed)
            if targets.count >= 80 { break }
        }
        return targets
    }

    private func bfsDegrees(
        from source: String,
        targets: [String],
        maxDepth: Int,
        includeContext: Bool
    ) async -> (degrees: [String: Int], graph: SocialGraphSnapshot?) {
        var targetMap: [String: String] = [:]
        for item in targets {
            targetMap[item.lowercased()] = item
        }
        var pending = Set(targetMap.keys)
        let sourceLower = source.lowercased()
        var visited: Set<String> = [sourceLower]
        var queue: [(user: String, depth: Int)] = [(source, 0)]
        var found: [String: Int] = [:]
        var parentByUser: [String: String] = [:]
        var depthByUser: [String: Int] = [sourceLower: 0]
        var displayByUser: [String: String] = [sourceLower: source]
        let maxExploredNodes = includeContext ? 1200 : min(10_000, max(2_000, maxDepth * 500))

        while !queue.isEmpty && !pending.isEmpty {
            guard !Task.isCancelled else { break }
            let current = queue.removeFirst()
            if current.depth >= maxDepth { continue }
            if visited.count > maxExploredNodes { break }

            let neighbors = await friendsOf(user: current.user)
            for neighbor in neighbors {
                let lower = neighbor.lowercased()
                guard !visited.contains(lower) else { continue }
                visited.insert(lower)
                let nextDepth = current.depth + 1
                queue.append((neighbor, nextDepth))
                parentByUser[lower] = current.user.lowercased()
                depthByUser[lower] = nextDepth
                displayByUser[lower] = neighbor
                if pending.contains(lower) {
                    if let original = targetMap[lower] {
                        found[original.lowercased()] = nextDepth
                    }
                    pending.remove(lower)
                }
            }
        }
        let graph = makeSocialGraph(
            source: source,
            targetLowerSet: Set(targetMap.keys),
            parentByUser: parentByUser,
            depthByUser: depthByUser,
            displayByUser: displayByUser,
            includeContext: includeContext
        )
        return (found, graph)
    }

    private func friendsOf(user: String) async -> [String] {
        let key = user.lowercased()
        if let cached = friendGraphCache[key] {
            return cached
        }
        do {
            let fetched = try await api.fetchFriendUsernames(user: user, limit: 120)
            friendGraphCache[key] = fetched
            return fetched
        } catch {
            return []
        }
    }

    private func makeSocialGraph(
        source: String,
        targetLowerSet: Set<String>,
        parentByUser: [String: String],
        depthByUser: [String: Int],
        displayByUser: [String: String],
        includeContext: Bool
    ) -> SocialGraphSnapshot? {
        let sourceLower = source.lowercased()
        guard !depthByUser.isEmpty else { return nil }

        var selected: Set<String> = [sourceLower]
        for target in targetLowerSet where depthByUser[target] != nil {
            var cursor: String? = target
            while let current = cursor {
                if selected.contains(current) { break }
                selected.insert(current)
                cursor = parentByUser[current]
            }
        }

        let remainingCapacity = max(0, 220 - selected.count)
        if includeContext, remainingCapacity > 0 {
            let extras = depthByUser
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value < rhs.value }
                    return lhs.key < rhs.key
                }
                .map(\.key)
                .filter { !selected.contains($0) }
            for key in extras.prefix(remainingCapacity) {
                selected.insert(key)
            }
        }

        let nodes = selected.compactMap { lower -> SocialGraphNode? in
            guard let degree = depthByUser[lower] else { return nil }
            let display = displayByUser[lower] ?? lower
            return SocialGraphNode(
                id: lower,
                displayName: display,
                degree: degree,
                isTarget: targetLowerSet.contains(lower),
                isSource: lower == sourceLower
            )
        }
        .sorted {
            if $0.degree != $1.degree { return $0.degree < $1.degree }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }

        let edges = selected.compactMap { child -> SocialGraphEdge? in
            guard let parent = parentByUser[child], selected.contains(parent) else { return nil }
            return SocialGraphEdge(id: "\(parent)->\(child)", from: parent, to: child)
        }

        return SocialGraphSnapshot(
            sourceUser: source,
            nodes: nodes,
            edges: edges,
            generatedAt: Date()
        )
    }

    private func isLikelyNowPlaying(playedAt: Date?) -> Bool {
        guard let playedAt else { return false }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= inferredNowPlayingWindow
    }

    private func inferredNowPlayingState(for friend: CompatibilityFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        return isLikelyNowPlaying(playedAt: friend.playedAt)
    }

    private func startProgressUpdates() {
        progressTask?.cancel()
        progressTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    guard self.playbackState == "Playing" else { return }
                    let base = self.accumulatedPlayTime
                    if let start = self.currentTrackStart {
                        self.elapsedForCurrentTrack = base + max(0, Date().timeIntervalSince(start))
                        self.scrobbleProgress = self.progressValue(
                            elapsed: self.elapsedForCurrentTrack,
                            threshold: self.scrobbleThreshold
                        )
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func startFriendsAutoRefresh() {
        friendsRefreshTask?.cancel()
        guard isAuthenticated else { return }
        friendsRefreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard self.isAuthenticated else { return }
                    Task { @MainActor in
                        await self.refreshFriendsData()
                    }
                }
            }
        }
    }

    private func progressValue(elapsed: TimeInterval, threshold: TimeInterval) -> Double {
        guard threshold > 0 else { return 0 }
        return min(1.0, max(0, elapsed / threshold))
    }

    private func validateSessionOnStartup() async {
        guard isAuthenticated else { return }
        do {
            let validation = try await api.validateSession()
            if validation.isValid {
                sessionStatus = "Session valid"
                capabilitiesStatus = formatCapabilities(validation.capabilities)
                isSubscriber = validation.capabilities.isSubscriber
                validationSource = validation.fromCache ? "Cache" : "Live"
            } else {
                signOut()
                sessionStatus = "Session invalid"
            }
        } catch {
            if error is CancellationError {
                return
            }
            handle(error: error)
            if let apiError = error as? CompatibilityAPIError, case .invalidSession = apiError {
                signOut()
                sessionStatus = "Session invalid"
                return
            }
            sessionStatus = "Validation failed"
        }
    }

    private var hasSubmissionBackend: Bool {
        isAuthenticated || listenBrainz.isReadyForListenSubmission
    }

    private var activeSubmissionBackends: [ScrobbleBackend] {
        var backends: [ScrobbleBackend] = []
        if isAuthenticated {
            backends.append(.compatibility)
        }
        if listenBrainz.isReadyForListenSubmission {
            backends.append(.listenBrainz)
        }
        return backends
    }

    private var hasNowPlayingBackend: Bool {
        isAuthenticated || listenBrainz.isReadyForNowPlaying
    }

    private func uniqueQueuedTracks(from jobs: [ScrobbleSubmissionJob]) -> [Track] {
        var seen: Set<String> = []
        return jobs.compactMap { job in
            guard !seen.contains(job.track.fingerprint) else { return nil }
            seen.insert(job.track.fingerprint)
            return job.track
        }
    }

    private func refreshListenBrainzState() {
        let settings = listenBrainz.settings
        listenBrainzEnabled = settings.isEnabled
        listenBrainzBaseURL = settings.baseURL
        listenBrainzSubmitNowPlaying = settings.submitNowPlaying
        listenBrainzSubmitListens = settings.submitListens
        listenBrainzUsername = settings.username
        let hasToken = listenBrainz.hasStoredToken

        if !settings.isEnabled {
            listenBrainzAuthenticated = false
            listenBrainzStatus = hasToken ? "Configured but disabled" : "Not configured"
        } else if let username = settings.username {
            listenBrainzAuthenticated = hasToken
            listenBrainzStatus = hasToken ? "Session valid for \(username)" : "Token missing"
        } else {
            listenBrainzAuthenticated = false
            listenBrainzStatus = hasToken ? "Token stored, validation pending" : "Token missing"
        }
    }

    private func refreshBackendName() {
        if listenBrainzEnabled {
            backendName = api.isConfigured
                ? "ListenBrainz + compatibility adapter"
                : "ListenBrainz"
        } else {
            backendName = api.isConfigured ? "Compatibility adapter" : "Local preview"
        }
    }

    private func handleListenBrainz(error: Error) {
        let message: String
        if let listenBrainzError = error as? ListenBrainzError {
            message = listenBrainzError.localizedDescription
            if listenBrainzError == .invalidToken || listenBrainzError == .missingToken {
                listenBrainzAuthenticated = false
            }
        } else {
            message = error.localizedDescription
        }
        listenBrainzLastError = message
        listenBrainzStatus = "Failed: \(message)"
    }

    private func handle(error: Error) {
        if let apiError = error as? CompatibilityAPIError {
            lastAPIError = apiError.localizedDescription.replacingOccurrences(of: "legacy provider", with: "the compatibility service")
            lastRecoveryHint = apiError.recoverySuggestion?.replacingOccurrences(of: "legacy provider", with: "the compatibility service")
        } else {
            lastAPIError = error.localizedDescription
            lastRecoveryHint = "Retry later. If this persists, verify API credentials and connectivity."
        }
    }

    private func formatCapabilities(_ capabilities: CompatibilityCapabilities) -> String {
        let tier = capabilities.isSubscriber ? "Supporter" : "Standard"
        let radio = capabilities.canUseRadio ? "Radio on" : "Radio off"
        if let accountType = capabilities.accountType, !accountType.isEmpty {
            return "\(tier), \(radio), \(accountType)"
        }
        return "\(tier), \(radio)"
    }

    private func computeTracksPerDayAverage(_ profile: CompatibilityUserProfile) -> Int? {
        guard let playcount = profile.playcount,
              let registeredAt = profile.registeredAt else { return nil }
        let days = max(1, Int(Date().timeIntervalSince(registeredAt) / 86_400))
        return playcount / days
    }

    private func hydrateTopArtistImages(_ artists: [CompatibilityTopArtist]) async -> [CompatibilityTopArtist] {
        var hydrated: [CompatibilityTopArtist] = []
        hydrated.reserveCapacity(artists.count)
        for (index, artist) in artists.enumerated() {
            if artist.imageURL != nil || index >= 12 {
                hydrated.append(artist)
                continue
            }
            do {
                let detail = try await api.fetchArtistDetails(artist: artist.name)
                hydrated.append(
                    CompatibilityTopArtist(
                        id: artist.id,
                        name: artist.name,
                        playcount: artist.playcount,
                        imageURL: detail.imageURL,
                        url: artist.url
                    )
                )
            } catch {
                hydrated.append(artist)
            }
        }
        return hydrated
    }
}

private extension CompatibilityRecentScrobble {
    init(listenBrainzListen listen: ListenBrainzListen) {
        self.init(
            id: "listenbrainz-\(listen.id)",
            track: listen.trackName,
            artist: listen.artistName,
            album: listen.releaseName,
            imageURL: listen.imageURL,
            url: listen.recordingMBID.map { "https://listenbrainz.org/player/?recording_mbids=\($0)" },
            loved: false,
            playedAt: listen.listenedAt,
            nowPlaying: false
        )
    }
}
