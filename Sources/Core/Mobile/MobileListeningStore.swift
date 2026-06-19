import Combine
import Foundation
import OSLog

protocol MobileListenBrainzClient {
    func update(settings: ListenBrainzSettings, token: String?) throws
    func clear()
    func validate() async throws -> ListenBrainzValidation
    func fetchRecentListens(username: String, count: Int) async throws -> [ListenBrainzListen]
    func fetchCurrentPin(username: String) async throws -> ListenBrainzPinnedRecording?
    func deleteListen(listenedAt: Date, recordingMsid: String) async throws
    func loveRecording(recordingMbid: String) async throws
    func loveRecording(recordingMsid: String) async throws
    func unloveRecording(recordingMbid: String) async throws
    func unloveRecording(recordingMsid: String) async throws
    func pinRecording(recordingMbid: String, blurb: String?, pinnedUntil: Date?) async throws
    func pinRecording(recordingMsid: String, blurb: String?, pinnedUntil: Date?) async throws
    func unpinCurrentRecording() async throws
    func fetchStatsSnapshot(username: String, range: ListenBrainzStatsRange, count: Int) async throws -> ListenBrainzStatsSnapshot
    func fetchRecommendedRecordings(username: String, count: Int, offset: Int) async throws -> [ListenBrainzRecommendedRecording]
    func fetchSimilarArtists(
        seedArtistMBID: String,
        mode: ListenBrainzSimilarityMode,
        maxSimilarArtists: Int,
        maxRecordingsPerArtist: Int,
        popularityRange: ClosedRange<Int>
    ) async throws -> [ListenBrainzSimilarArtist]
    func fetchFollowers(username: String) async throws -> [String]
    func fetchFollowing(username: String) async throws -> [String]
    func fetchSimilarUsers(username: String, count: Int) async throws -> [ListenBrainzSimilarUser]
    func fetchSocialListenActivity(usernames: [String], countPerUser: Int) async throws -> [ListenBrainzSocialListen]
    func submitListen(_ track: Track) async throws
}

extension ListenBrainzService: MobileListenBrainzClient {}

protocol MobileOpenMetadataClient {
    func lookup(track: String?, artist: String, release: String?) async throws -> OpenMusicEntityDetails
    func search(query: String, kind: OpenMusicSearchKind, limit: Int) async throws -> [OpenMusicSearchResult]
}

extension MusicBrainzService: MobileOpenMetadataClient {}

public struct MobileListenSummary: Identifiable, Equatable {
    public let id: String
    public let trackName: String
    public let artistName: String
    public let releaseName: String?
    public let listenedAt: Date?
    public let imageURL: String?
    public let recordingMBID: String?
    public let recordingMSID: String?
    public let artistMBID: String?
    public let releaseMBID: String?
}

public struct MobilePinnedRecording: Identifiable, Equatable {
    public let id: Int
    public let recordingMBID: String?
    public let recordingMSID: String?
    public let trackName: String
    public let artistName: String
    public let blurb: String?
}

public enum MobileMusicEntityKind: String, Equatable, Hashable {
    case track
    case release
    case artist

    public var title: String {
        switch self {
        case .track: return String(localized: "Song")
        case .release: return String(localized: "Release")
        case .artist: return String(localized: "Artist")
        }
    }

    public var symbolName: String {
        switch self {
        case .track: return "music.note"
        case .release: return "opticaldisc"
        case .artist: return "person.wave.2"
        }
    }
}

public struct MobileMusicDetailSeed: Identifiable, Equatable, Hashable {
    public let id: String
    public let kind: MobileMusicEntityKind
    public let trackName: String?
    public let artistName: String
    public let releaseName: String?
    public let recordingMBID: String?
    public let recordingMSID: String?
    public let artistMBID: String?
    public let releaseMBID: String?
    public let imageURL: String?

    public init(
        kind: MobileMusicEntityKind,
        trackName: String? = nil,
        artistName: String,
        releaseName: String? = nil,
        recordingMBID: String? = nil,
        recordingMSID: String? = nil,
        artistMBID: String? = nil,
        releaseMBID: String? = nil,
        imageURL: String? = nil
    ) {
        let normalizedTrackName = trackName?.nilIfBlank
        let normalizedArtistName = artistName.nilIfBlank ?? String(localized: "Unknown artist")
        let normalizedReleaseName = releaseName?.nilIfBlank
        let normalizedRecordingMBID = recordingMBID?.nilIfBlank
        let normalizedRecordingMSID = recordingMSID?.nilIfBlank
        let normalizedArtistMBID = artistMBID?.nilIfBlank
        let normalizedReleaseMBID = releaseMBID?.nilIfBlank
        let normalizedImageURL = imageURL?.nilIfBlank

        self.kind = kind
        self.trackName = normalizedTrackName
        self.artistName = normalizedArtistName
        self.releaseName = normalizedReleaseName
        self.recordingMBID = normalizedRecordingMBID
        self.recordingMSID = normalizedRecordingMSID
        self.artistMBID = normalizedArtistMBID
        self.releaseMBID = normalizedReleaseMBID
        self.imageURL = normalizedImageURL
        let idParts: [String?] = [
            kind.rawValue,
            normalizedRecordingMBID,
            normalizedRecordingMSID,
            normalizedArtistMBID,
            normalizedReleaseMBID,
            normalizedTrackName,
            normalizedArtistName,
            normalizedReleaseName
        ]
        self.id = idParts
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "|")
    }

    public var displayTitle: String {
        switch kind {
        case .track:
            return trackName ?? releaseName ?? artistName
        case .release:
            return releaseName ?? trackName ?? artistName
        case .artist:
            return artistName
        }
    }
}

public struct MobileOpenMusicLink: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let url: URL
}

public struct MobileMusicDetail: Equatable {
    public let seed: MobileMusicDetailSeed
    public let trackName: String?
    public let artistName: String
    public let releaseName: String?
    public let recordingMBID: String?
    public let recordingMSID: String?
    public let artistMBID: String?
    public let releaseMBID: String?
    public let imageURL: String?
    public let artistImageURL: String?
    public let artistSummary: String?
    public let artistSummaryURL: URL?
    public let artistSummaryLanguageCode: String?
    public let disambiguation: String?
    public let country: String?
    public let type: String?
    public let tags: [String]
    public let links: [MobileOpenMusicLink]
    public let fetchedAt: Date
}

public enum MobileDiscoverySearchScope: String, CaseIterable, Identifiable {
    case tracks
    case artists
    case releases

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .tracks: return String(localized: "Songs")
        case .artists: return String(localized: "Artists")
        case .releases: return String(localized: "Releases")
        }
    }

    public var symbolName: String {
        switch self {
        case .tracks: return "music.note"
        case .artists: return "person.wave.2"
        case .releases: return "opticaldisc"
        }
    }
}

public struct MobileDiscoverySearchResult: Identifiable, Equatable {
    public let id: String
    public let scope: MobileDiscoverySearchScope
    public let title: String
    public let subtitle: String?
    public let detail: String?
    public let seed: MobileMusicDetailSeed
}

public struct MobileRadioSeed: Identifiable, Equatable {
    public let id: String
    public let artistName: String
    public let artistMBID: String?
}

public struct MobileRadioQueueItem: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let artistName: String?
    public let releaseName: String?
    public let score: Double
    public let seed: MobileMusicDetailSeed
}

public struct MobileRadioArtist: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let totalListenCount: Int
}

public enum MobileStatsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case allTime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .week: return String(localized: "Week")
        case .month: return String(localized: "Month")
        case .year: return String(localized: "Year")
        case .allTime: return String(localized: "All Time")
        }
    }
}

public struct MobileArtistStat: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let listenCount: Int
    public let artistMBID: String?
}

public struct MobileRecordingStat: Identifiable, Equatable {
    public let id: String
    public let trackName: String
    public let artistName: String
    public let releaseName: String?
    public let listenCount: Int
}

public struct MobileReleaseStat: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let artistName: String
    public let listenCount: Int
}

public struct MobileStatsSnapshot: Equatable {
    public let username: String
    public let range: MobileStatsRange
    public let totalListenCount: Int?
    public let topArtists: [MobileArtistStat]
    public let topReleases: [MobileReleaseStat]
    public let topRecordings: [MobileRecordingStat]
    public let fetchedAt: Date
}

public struct MobileRecommendedRecording: Identifiable, Equatable {
    public let id: String
    public let recordingMBID: String
    public let title: String
    public let artistName: String?
    public let releaseName: String?
    public let score: Double
}

public struct MobileSimilarUser: Identifiable, Equatable {
    public let id: String
    public let userName: String
    public let similarityScore: Double
}

public struct MobileSocialListen: Identifiable, Equatable {
    public let id: String
    public let userName: String
    public let trackName: String
    public let artistName: String
    public let releaseName: String?
    public let listenedAt: Date?
}

public struct MobileSocialSnapshot: Equatable {
    public let followers: [String]
    public let following: [String]
    public let similarUsers: [MobileSimilarUser]
    public let neighborListens: [MobileSocialListen]
    public let fetchedAt: Date
}

public struct MobileScrobbleSourceMetadata: Codable, Equatable {
    public let mediaPlayer: String?
    public let musicService: String?
    public let musicServiceName: String?
    public let originURL: String?
    public let spotifyID: String?
    public let durationPlayed: TimeInterval?
    public let originalSubmissionClient: String?

    public init(
        mediaPlayer: String? = nil,
        musicService: String? = nil,
        musicServiceName: String? = nil,
        originURL: String? = nil,
        spotifyID: String? = nil,
        durationPlayed: TimeInterval? = nil,
        originalSubmissionClient: String? = nil
    ) {
        self.mediaPlayer = mediaPlayer
        self.musicService = musicService
        self.musicServiceName = musicServiceName
        self.originURL = originURL
        self.spotifyID = spotifyID
        self.durationPlayed = durationPlayed
        self.originalSubmissionClient = originalSubmissionClient
    }
}

public struct MobileScrobbleCandidate: Codable, Equatable {
    public let title: String
    public let artist: String
    public let album: String?
    public let duration: TimeInterval
    public let listenedAt: Date
    public let source: String
    public let sourceMetadata: MobileScrobbleSourceMetadata?

    public init(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        listenedAt: Date,
        source: String,
        sourceMetadata: MobileScrobbleSourceMetadata? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.listenedAt = listenedAt
        self.source = source
        self.sourceMetadata = sourceMetadata
    }
}

@MainActor
public final class MobileListeningStore: ObservableObject {
    public enum ConnectionState: Equatable {
        case disconnected
        case connected(username: String)
        case loading
        case failed(String)

        public var statusText: String {
            switch self {
            case .disconnected:
                return String(localized: "Connect ListenBrainz")
            case let .connected(username):
                return String.localizedStringWithFormat(String(localized: "%@ on ListenBrainz"), username)
            case .loading:
                return String(localized: "Loading ListenBrainz")
            case let .failed(message):
                return message
            }
        }
    }

    @Published public private(set) var connectionState: ConnectionState
    @Published public private(set) var recentListens: [MobileListenSummary] = []
    @Published public private(set) var currentPin: MobilePinnedRecording?
    @Published public private(set) var statsSnapshot: MobileStatsSnapshot?
    @Published public private(set) var statsStatus = String(localized: "Connect ListenBrainz to load stats")
    @Published public private(set) var recommendedRecordings: [MobileRecommendedRecording] = []
    @Published public private(set) var recommendationsStatus = String(localized: "Connect ListenBrainz to load recommendations")
    @Published public private(set) var socialSnapshot: MobileSocialSnapshot?
    @Published public private(set) var socialStatus = String(localized: "Connect ListenBrainz to load social activity")
    @Published public private(set) var searchResults: [MobileDiscoverySearchResult] = []
    @Published public private(set) var searchStatus = String(localized: "Search MusicBrainz for songs, artists, and releases")
    @Published public private(set) var radioQueue: [MobileRadioQueueItem] = []
    @Published public private(set) var radioArtists: [MobileRadioArtist] = []
    @Published public private(set) var radioStatus = String(localized: "Load a recommendation radio queue")
    @Published public private(set) var listenActionStatus = ""
    @Published public private(set) var isRefreshing = false
    @Published public private(set) var isRefreshingStats = false
    @Published public private(set) var isRefreshingRecommendations = false
    @Published public private(set) var isRefreshingSocial = false
    @Published public private(set) var isSearching = false
    @Published public private(set) var isRefreshingRadio = false
    @Published public private(set) var isUpdatingListenAction = false

    private let settingsStore: ListenBrainzSettingsStore
    private let listenBrainz: MobileListenBrainzClient
    private let openMetadata: MobileOpenMetadataClient
    private let widgetSnapshotStore: MobileWidgetSnapshotStore
    private let logger = Logger(subsystem: "org.listenscrobbler.app.ios", category: "listenbrainz")

    public convenience init() {
        let settingsStore = ListenBrainzSettingsStore()
        self.init(
            settingsStore: settingsStore,
            listenBrainz: ListenBrainzService(settingsStore: settingsStore),
            openMetadata: MusicBrainzService()
        )
    }

    init(
        settingsStore: ListenBrainzSettingsStore,
        listenBrainz: MobileListenBrainzClient,
        openMetadata: MobileOpenMetadataClient = MusicBrainzService(),
        widgetSnapshotStore: MobileWidgetSnapshotStore = MobileWidgetSnapshotStore()
    ) {
        self.settingsStore = settingsStore
        self.listenBrainz = listenBrainz
        self.openMetadata = openMetadata
        self.widgetSnapshotStore = widgetSnapshotStore
        let settings = settingsStore.load()
        if let username = Self.nonBlank(settings.username), settingsStore.hasStoredToken() {
            self.connectionState = .connected(username: username)
            logger.info("Mobile listening store restored connected session for user \(username, privacy: .public)")
        } else {
            self.connectionState = .disconnected
            logger.info("Mobile listening store initialized disconnected")
        }
        persistWidgetSnapshot()
    }

    public var configuredUsername: String {
        switch connectionState {
        case let .connected(username):
            return username
        default:
            return settingsStore.load().username ?? ""
        }
    }

    public var hasStoredToken: Bool {
        settingsStore.hasStoredToken()
    }

    public func connect(token: String, baseURL: URL = URL(string: "https://api.listenbrainz.org")!) async {
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedToken.isEmpty else {
            logger.warning("ListenBrainz connect rejected empty token")
            connectionState = .failed(String(localized: "Paste a ListenBrainz token."))
            return
        }

        logger.info("ListenBrainz connect started")
        connectionState = .loading

        do {
            try listenBrainz.update(
                settings: ListenBrainzSettings(
                    isEnabled: true,
                    submitNowPlaying: true,
                    submitListens: true,
                    baseURL: baseURL,
                    username: settingsStore.load().username
                ),
                token: trimmedToken
            )

            let validation = try await listenBrainz.validate()
            guard validation.isValid, let username = Self.nonBlank(validation.username) else {
                logger.error("ListenBrainz token validation failed: \(validation.message, privacy: .public)")
                connectionState = .failed(validation.message)
                return
            }

            try listenBrainz.update(
                settings: ListenBrainzSettings(
                    isEnabled: true,
                    submitNowPlaying: true,
                    submitListens: true,
                    baseURL: baseURL,
                    username: username
                ),
                token: trimmedToken
            )

            connectionState = .connected(username: username)
            logger.info("ListenBrainz connect succeeded for user \(username, privacy: .public)")
            await refresh()
            await refreshStats()
            await refreshRecommendations()
            await refreshSocial()
        } catch {
            logger.error("ListenBrainz connect failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed(error.localizedDescription)
            persistWidgetSnapshot()
        }
    }

    public func disconnect() {
        logger.info("ListenBrainz disconnect requested")
        listenBrainz.clear()
        recentListens = []
        currentPin = nil
        statsSnapshot = nil
        statsStatus = String(localized: "Connect ListenBrainz to load stats")
        recommendedRecordings = []
        recommendationsStatus = String(localized: "Connect ListenBrainz to load recommendations")
        socialSnapshot = nil
        socialStatus = String(localized: "Connect ListenBrainz to load social activity")
        searchResults = []
        searchStatus = String(localized: "Search MusicBrainz for songs, artists, and releases")
        radioQueue = []
        radioArtists = []
        radioStatus = String(localized: "Load a recommendation radio queue")
        listenActionStatus = ""
        connectionState = .disconnected
        widgetSnapshotStore.clear()
        persistWidgetSnapshot()
    }

    public func refresh() async {
        guard case let .connected(username) = connectionState else {
            persistWidgetSnapshot()
            return
        }

        logger.info("ListenBrainz refresh started for user \(username, privacy: .public)")
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let listens = listenBrainz.fetchRecentListens(username: username, count: 25)
            async let pin = listenBrainz.fetchCurrentPin(username: username)

            recentListens = try await listens.map(MobileListenSummary.init(listen:))
            currentPin = try await pin.map(MobilePinnedRecording.init(pin:))
            persistWidgetSnapshot()
            logger.info("ListenBrainz refresh succeeded with \(self.recentListens.count, privacy: .public) recent listens; pin present: \(self.currentPin != nil, privacy: .public)")
        } catch {
            logger.error("ListenBrainz refresh failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed(error.localizedDescription)
            persistWidgetSnapshot()
        }
    }

    public func deleteListen(_ listen: MobileListenSummary) async -> Bool {
        guard let listenedAt = listen.listenedAt,
              let recordingMSID = Self.nonBlank(listen.recordingMSID) else {
            logger.error("ListenBrainz listen delete skipped because identity is missing")
            return false
        }

        logger.info("ListenBrainz listen delete requested for \(listen.trackName, privacy: .public)")
        do {
            try await listenBrainz.deleteListen(listenedAt: listenedAt, recordingMsid: recordingMSID)
            recentListens.removeAll { $0.id == listen.id }
            persistWidgetSnapshot()
            return true
        } catch {
            logger.error("ListenBrainz listen delete failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    public func love(_ seed: MobileMusicDetailSeed) async -> Bool {
        await submitFeedback(seed: seed, love: true)
    }

    public func unlove(_ seed: MobileMusicDetailSeed) async -> Bool {
        await submitFeedback(seed: seed, love: false)
    }

    public func loveListen(_ listen: MobileListenSummary) async -> Bool {
        await love(MobileMusicDetailSeed(listen: listen))
    }

    public func unloveListen(_ listen: MobileListenSummary) async -> Bool {
        await unlove(MobileMusicDetailSeed(listen: listen))
    }

    public func pin(_ seed: MobileMusicDetailSeed, blurb: String? = nil) async -> Bool {
        guard hasStoredToken else {
            listenActionStatus = String(localized: "Connect ListenBrainz to pin recordings")
            return false
        }

        let recordingMBID = Self.nonBlank(seed.recordingMBID)
        let recordingMSID = Self.nonBlank(seed.recordingMSID)
        guard recordingMBID != nil || recordingMSID != nil else {
            listenActionStatus = String(localized: "Missing recording identity for pin")
            return false
        }

        isUpdatingListenAction = true
        listenActionStatus = String.localizedStringWithFormat(String(localized: "Pinning %@"), seed.displayTitle)
        defer { isUpdatingListenAction = false }

        do {
            if currentPin != nil {
                try await listenBrainz.unpinCurrentRecording()
            }
            if let recordingMBID {
                try await listenBrainz.pinRecording(recordingMbid: recordingMBID, blurb: blurb, pinnedUntil: nil)
            } else if let recordingMSID {
                try await listenBrainz.pinRecording(recordingMsid: recordingMSID, blurb: blurb, pinnedUntil: nil)
            }
            await refresh()
            listenActionStatus = String.localizedStringWithFormat(String(localized: "Pinned %@"), seed.displayTitle)
            return true
        } catch {
            logger.error("ListenBrainz pin failed: \(error.localizedDescription, privacy: .public)")
            listenActionStatus = String.localizedStringWithFormat(String(localized: "Could not pin %@"), seed.displayTitle)
            return false
        }
    }

    public func pinListen(_ listen: MobileListenSummary) async -> Bool {
        await pin(MobileMusicDetailSeed(listen: listen))
    }

    public func unpinCurrent() async -> Bool {
        guard hasStoredToken else {
            listenActionStatus = String(localized: "Connect ListenBrainz to remove pins")
            return false
        }

        isUpdatingListenAction = true
        listenActionStatus = String(localized: "Removing current pin")
        defer { isUpdatingListenAction = false }

        do {
            try await listenBrainz.unpinCurrentRecording()
            currentPin = nil
            persistWidgetSnapshot()
            listenActionStatus = String(localized: "Current pin removed")
            return true
        } catch {
            logger.error("ListenBrainz unpin failed: \(error.localizedDescription, privacy: .public)")
            listenActionStatus = String(localized: "Could not remove current pin")
            return false
        }
    }

    public func isCurrentPin(_ seed: MobileMusicDetailSeed) -> Bool {
        guard let currentPin else { return false }
        if let recordingMBID = Self.nonBlank(seed.recordingMBID),
           let pinMBID = Self.nonBlank(currentPin.recordingMBID) {
            return recordingMBID.caseInsensitiveCompare(pinMBID) == .orderedSame
        }
        if let recordingMSID = Self.nonBlank(seed.recordingMSID),
           let pinMSID = Self.nonBlank(currentPin.recordingMSID) {
            return recordingMSID.caseInsensitiveCompare(pinMSID) == .orderedSame
        }
        return currentPin.trackName.localizedCaseInsensitiveCompare(seed.trackName ?? seed.displayTitle) == .orderedSame &&
            currentPin.artistName.localizedCaseInsensitiveCompare(seed.artistName) == .orderedSame
    }

    public func isCurrentPin(_ listen: MobileListenSummary) -> Bool {
        isCurrentPin(MobileMusicDetailSeed(listen: listen))
    }

    public func refreshStats(range: MobileStatsRange = .week) async {
        guard case let .connected(username) = connectionState else {
            statsStatus = String(localized: "Connect ListenBrainz to load stats")
            statsSnapshot = nil
            return
        }

        logger.info("ListenBrainz mobile stats refresh started for user \(username, privacy: .public)")
        isRefreshingStats = true
        statsStatus = String.localizedStringWithFormat(String(localized: "Loading %@ stats"), range.title.lowercased())
        defer { isRefreshingStats = false }

        do {
            let snapshot = try await listenBrainz.fetchStatsSnapshot(
                username: username,
                range: ListenBrainzStatsRange(mobile: range),
                count: 8
            )
            statsSnapshot = MobileStatsSnapshot(snapshot: snapshot, range: range)
            statsStatus = String.localizedStringWithFormat(String(localized: "Loaded %@ stats"), range.title.lowercased())
            logger.info("ListenBrainz mobile stats refresh succeeded with \(self.statsSnapshot?.topArtists.count ?? 0, privacy: .public) artists")
        } catch {
            logger.error("ListenBrainz mobile stats refresh failed: \(error.localizedDescription, privacy: .public)")
            statsStatus = String.localizedStringWithFormat(String(localized: "Failed to load stats: %@"), error.localizedDescription)
        }
    }

    public func refreshRecommendations() async {
        guard case let .connected(username) = connectionState else {
            recommendationsStatus = String(localized: "Connect ListenBrainz to load recommendations")
            recommendedRecordings = []
            return
        }

        logger.info("ListenBrainz mobile recommendations refresh started for user \(username, privacy: .public)")
        isRefreshingRecommendations = true
        recommendationsStatus = String(localized: "Loading recommendations")
        defer { isRefreshingRecommendations = false }

        do {
            let recommendations = try await listenBrainz.fetchRecommendedRecordings(
                username: username,
                count: 12,
                offset: 0
            )
            recommendedRecordings = recommendations.map(MobileRecommendedRecording.init(recommendation:))
            recommendationsStatus = recommendedRecordings.isEmpty
                ? String(localized: "No recommendations returned")
                : String.localizedStringWithFormat(String(localized: "%d recommendations loaded"), recommendedRecordings.count)
            persistWidgetSnapshot()
            logger.info("ListenBrainz mobile recommendations refresh succeeded with \(self.recommendedRecordings.count, privacy: .public) recordings")
        } catch {
            logger.error("ListenBrainz mobile recommendations refresh failed: \(error.localizedDescription, privacy: .public)")
            recommendationsStatus = String.localizedStringWithFormat(String(localized: "Failed to load recommendations: %@"), error.localizedDescription)
            persistWidgetSnapshot()
        }
    }

    public func searchDiscovery(query: String, scope: MobileDiscoverySearchScope) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            searchStatus = String(localized: "Search MusicBrainz for songs, artists, and releases")
            return
        }

        logger.info("Mobile discovery search started for scope \(scope.rawValue, privacy: .public)")
        isSearching = true
        searchStatus = String.localizedStringWithFormat(String(localized: "Searching %@"), trimmed)
        defer { isSearching = false }

        do {
            let results = try await openMetadata.search(
                query: trimmed,
                kind: OpenMusicSearchKind(scope: scope),
                limit: 15
            )
            searchResults = results.map { MobileDiscoverySearchResult(result: $0, scope: scope) }
            searchStatus = searchResults.isEmpty
                ? String(localized: "No open music results found")
                : String.localizedStringWithFormat(String(localized: "%d open music results found"), searchResults.count)
        } catch {
            logger.error("Mobile discovery search failed: \(error.localizedDescription, privacy: .public)")
            searchResults = []
            searchStatus = String.localizedStringWithFormat(String(localized: "Search failed: %@"), error.localizedDescription)
        }
    }

    public func loadDetail(for seed: MobileMusicDetailSeed) async throws -> MobileMusicDetail {
        logger.info("Mobile open metadata detail started for \(seed.displayTitle, privacy: .public)")
        let details = try await openMetadata.lookup(
            track: seed.kind == .track ? seed.trackName : nil,
            artist: seed.artistName,
            release: seed.kind == .release ? (seed.releaseName ?? seed.trackName) : seed.releaseName
        )
        return MobileMusicDetail(seed: seed, details: details)
    }

    public func refreshRadio(seed: MobileRadioSeed? = nil) async {
        guard case let .connected(username) = connectionState else {
            radioStatus = String(localized: "Connect ListenBrainz to load radio")
            radioQueue = []
            radioArtists = []
            return
        }

        logger.info("Mobile radio refresh started for user \(username, privacy: .public)")
        isRefreshingRadio = true
        radioStatus = seed.map {
            String.localizedStringWithFormat(String(localized: "Loading %@ radio"), $0.artistName)
        } ?? String(localized: "Loading recommendation radio")
        defer { isRefreshingRadio = false }

        do {
            async let recommendations = listenBrainz.fetchRecommendedRecordings(
                username: username,
                count: 18,
                offset: 0
            )
            let similarArtists: [ListenBrainzSimilarArtist]
            if let artistMBID = seed?.artistMBID.flatMap(Self.nonBlank) {
                similarArtists = try await listenBrainz.fetchSimilarArtists(
                    seedArtistMBID: artistMBID,
                    mode: .easy,
                    maxSimilarArtists: 12,
                    maxRecordingsPerArtist: 3,
                    popularityRange: 0...100
                )
            } else {
                similarArtists = []
            }

            let resolvedRecommendations = try await recommendations
            radioQueue = resolvedRecommendations.map(MobileRadioQueueItem.init(recommendation:))
            radioArtists = similarArtists.map(MobileRadioArtist.init(artist:))
            radioStatus = seed.map {
                String.localizedStringWithFormat(
                    String(localized: "%d queued recordings and %d related artists for %@"),
                    radioQueue.count,
                    radioArtists.count,
                    $0.artistName
                )
            } ?? String.localizedStringWithFormat(
                String(localized: "%d recommendation radio recordings loaded"),
                radioQueue.count
            )
        } catch {
            logger.error("Mobile radio refresh failed: \(error.localizedDescription, privacy: .public)")
            radioQueue = []
            radioArtists = []
            radioStatus = String.localizedStringWithFormat(String(localized: "Radio failed: %@"), error.localizedDescription)
        }
    }

    public func refreshSocial() async {
        guard case let .connected(username) = connectionState else {
            socialStatus = String(localized: "Connect ListenBrainz to load social activity")
            socialSnapshot = nil
            return
        }

        logger.info("ListenBrainz mobile social refresh started for user \(username, privacy: .public)")
        isRefreshingSocial = true
        socialStatus = String(localized: "Loading social activity")
        defer { isRefreshingSocial = false }

        do {
            async let followers = listenBrainz.fetchFollowers(username: username)
            async let following = listenBrainz.fetchFollowing(username: username)
            async let similarUsers = listenBrainz.fetchSimilarUsers(username: username, count: 8)

            let resolvedFollowers = try await followers.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            let resolvedFollowing = try await following.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            let resolvedSimilarUsers = try await similarUsers
            let neighbors = Self.socialNeighbors(
                followers: resolvedFollowers,
                following: resolvedFollowing,
                similarUsers: resolvedSimilarUsers
            )
            let listens = try await listenBrainz.fetchSocialListenActivity(
                usernames: neighbors,
                countPerUser: 2
            )

            socialSnapshot = MobileSocialSnapshot(
                followers: resolvedFollowers,
                following: resolvedFollowing,
                similarUsers: resolvedSimilarUsers.map(MobileSimilarUser.init(user:)),
                neighborListens: listens.map(MobileSocialListen.init(listen:)),
                fetchedAt: .now
            )
            socialStatus = String.localizedStringWithFormat(
                String(localized: "%d followers, %d following, and %d neighbor listens loaded"),
                resolvedFollowers.count,
                resolvedFollowing.count,
                listens.count
            )
            logger.info("ListenBrainz mobile social refresh succeeded with \(listens.count, privacy: .public) neighbor listens")
        } catch {
            logger.error("ListenBrainz mobile social refresh failed: \(error.localizedDescription, privacy: .public)")
            socialStatus = String.localizedStringWithFormat(String(localized: "Failed to load social activity: %@"), error.localizedDescription)
        }
    }

    public func submitScrobble(_ candidate: MobileScrobbleCandidate) async throws {
        guard case .connected = connectionState else {
            logger.warning("Mobile scrobble rejected because ListenBrainz is disconnected")
            throw MobileListeningError.listenBrainzDisconnected
        }

        logger.info("Mobile scrobble submit started from source \(candidate.source, privacy: .public)")
        let startedAt = approximateStartDate(listenedAt: candidate.listenedAt, duration: candidate.duration)
        let track = Track(
            title: candidate.title,
            artist: candidate.artist,
            album: candidate.album,
            duration: candidate.duration,
            startedAt: startedAt,
            sourceApp: candidate.source,
            sourceMetadata: candidate.sourceMetadata.map(TrackSourceMetadata.init(mobile:))
        )
        try await listenBrainz.submitListen(track)
        persistWidgetSnapshot()
        logger.info("Mobile scrobble submit succeeded from source \(candidate.source, privacy: .public)")
    }

    public var radioSeeds: [MobileRadioSeed] {
        var seeds: [MobileRadioSeed] = []
        var seen = Set<String>()

        func append(name: String, mbid: String?) {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { return }
            let normalizedMBID = mbid?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
            let key = normalizedMBID?.lowercased() ?? normalizedName.lowercased()
            guard seen.insert(key).inserted else { return }
            seeds.append(
                MobileRadioSeed(
                    id: key,
                    artistName: normalizedName,
                    artistMBID: normalizedMBID
                )
            )
        }

        statsSnapshot?.topArtists.forEach { append(name: $0.name, mbid: $0.artistMBID) }
        recentListens.forEach { append(name: $0.artistName, mbid: $0.artistMBID) }
        return seeds
    }

    public func widgetSnapshot(updatedAt: Date = .now) -> MobileWidgetSnapshot {
        let username: String?
        switch connectionState {
        case let .connected(resolvedUsername):
            username = resolvedUsername
        default:
            username = Self.nonBlank(settingsStore.load().username)
        }

        return MobileWidgetSnapshot(
            connectionStatus: connectionState.statusText,
            username: username,
            recentListen: recentListens.first.map {
                MobileWidgetListen(
                    trackName: $0.trackName,
                    artistName: $0.artistName,
                    releaseName: $0.releaseName,
                    listenedAt: $0.listenedAt
                )
            },
            currentPin: currentPin.map {
                MobileWidgetPin(
                    trackName: $0.trackName,
                    artistName: $0.artistName,
                    blurb: $0.blurb
                )
            },
            recommendation: recommendedRecordings.first.map {
                MobileWidgetRecommendation(
                    title: $0.title,
                    artistName: $0.artistName,
                    releaseName: $0.releaseName
                )
            },
            pendingCount: MobilePendingScrobbleStore().load().count,
            updatedAt: updatedAt
        )
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func persistWidgetSnapshot() {
        widgetSnapshotStore.save(widgetSnapshot())
    }

    private func approximateStartDate(listenedAt: Date, duration: TimeInterval) -> Date {
        guard duration > 0 else { return listenedAt }
        return listenedAt.addingTimeInterval(-min(duration, 4 * 60))
    }

    private func submitFeedback(seed: MobileMusicDetailSeed, love: Bool) async -> Bool {
        guard hasStoredToken else {
            listenActionStatus = String(localized: "Connect ListenBrainz to update feedback")
            return false
        }

        let recordingMBID = Self.nonBlank(seed.recordingMBID)
        let recordingMSID = Self.nonBlank(seed.recordingMSID)
        guard recordingMBID != nil || recordingMSID != nil else {
            listenActionStatus = String(localized: "Missing recording identity for feedback")
            return false
        }

        isUpdatingListenAction = true
        listenActionStatus = love
            ? String.localizedStringWithFormat(String(localized: "Loving %@"), seed.displayTitle)
            : String.localizedStringWithFormat(String(localized: "Removing love from %@"), seed.displayTitle)
        defer { isUpdatingListenAction = false }

        do {
            if let recordingMBID {
                if love {
                    try await listenBrainz.loveRecording(recordingMbid: recordingMBID)
                } else {
                    try await listenBrainz.unloveRecording(recordingMbid: recordingMBID)
                }
            } else if let recordingMSID {
                if love {
                    try await listenBrainz.loveRecording(recordingMsid: recordingMSID)
                } else {
                    try await listenBrainz.unloveRecording(recordingMsid: recordingMSID)
                }
            }
            listenActionStatus = love
                ? String.localizedStringWithFormat(String(localized: "Loved %@"), seed.displayTitle)
                : String.localizedStringWithFormat(String(localized: "Unloved %@"), seed.displayTitle)
            return true
        } catch {
            logger.error("ListenBrainz feedback failed: \(error.localizedDescription, privacy: .public)")
            listenActionStatus = String.localizedStringWithFormat(String(localized: "Could not update %@"), seed.displayTitle)
            return false
        }
    }

    private static func socialNeighbors(
        followers: [String],
        following: [String],
        similarUsers: [ListenBrainzSimilarUser]
    ) -> [String] {
        var seenUsers = Set<String>()
        return (following + followers + similarUsers.map(\.userName))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seenUsers.insert($0.lowercased()).inserted }
    }
}

public enum MobileListeningError: LocalizedError, Equatable {
    case listenBrainzDisconnected

    public var errorDescription: String? {
        switch self {
        case .listenBrainzDisconnected:
            return String(localized: "Connect ListenBrainz before submitting listens.")
        }
    }
}

private extension ListenBrainzStatsRange {
    init(mobile range: MobileStatsRange) {
        switch range {
        case .week:
            self = .week
        case .month:
            self = .month
        case .year:
            self = .year
        case .allTime:
            self = .allTime
        }
    }
}

private extension MobileListenSummary {
    init(listen: ListenBrainzListen) {
        self.init(
            id: listen.id,
            trackName: listen.trackName,
            artistName: listen.artistName,
            releaseName: listen.releaseName,
            listenedAt: listen.listenedAt,
            imageURL: listen.imageURL,
            recordingMBID: listen.recordingMBID,
            recordingMSID: listen.recordingMSID,
            artistMBID: listen.artistMBID,
            releaseMBID: listen.releaseMBID
        )
    }
}

private extension MobilePinnedRecording {
    init(pin: ListenBrainzPinnedRecording) {
        self.init(
            id: pin.id,
            recordingMBID: pin.recordingMbid,
            recordingMSID: pin.recordingMsid,
            trackName: pin.trackName,
            artistName: pin.artistName,
            blurb: pin.blurb
        )
    }
}

private extension MobileStatsSnapshot {
    init(snapshot: ListenBrainzStatsSnapshot, range: MobileStatsRange) {
        self.init(
            username: snapshot.username,
            range: range,
            totalListenCount: snapshot.totalListenCount,
            topArtists: snapshot.topArtists.map(MobileArtistStat.init(stat:)),
            topReleases: snapshot.topReleases.map(MobileReleaseStat.init(stat:)),
            topRecordings: snapshot.topRecordings.map(MobileRecordingStat.init(stat:)),
            fetchedAt: snapshot.fetchedAt
        )
    }
}

private extension MobileArtistStat {
    init(stat: ListenBrainzArtistStat) {
        self.init(id: stat.id, name: stat.name, listenCount: stat.listenCount, artistMBID: stat.mbid)
    }
}

private extension MobileReleaseStat {
    init(stat: ListenBrainzReleaseStat) {
        self.init(
            id: stat.id,
            name: stat.name,
            artistName: stat.artistName,
            listenCount: stat.listenCount
        )
    }
}

private extension MobileRecordingStat {
    init(stat: ListenBrainzRecordingStat) {
        self.init(
            id: stat.id,
            trackName: stat.trackName,
            artistName: stat.artistName,
            releaseName: stat.releaseName,
            listenCount: stat.listenCount
        )
    }
}

private extension MobileRecommendedRecording {
    init(recommendation: ListenBrainzRecommendedRecording) {
        self.init(
            id: recommendation.id,
            recordingMBID: recommendation.recordingMbid,
            title: recommendation.title,
            artistName: recommendation.artistName,
            releaseName: recommendation.releaseName,
            score: recommendation.score
        )
    }
}

private extension MobileSimilarUser {
    init(user: ListenBrainzSimilarUser) {
        self.init(
            id: user.id,
            userName: user.userName,
            similarityScore: user.similarityScore
        )
    }
}

private extension MobileSocialListen {
    init(listen: ListenBrainzSocialListen) {
        self.init(
            id: listen.id,
            userName: listen.userName,
            trackName: listen.listen.trackName,
            artistName: listen.listen.artistName,
            releaseName: listen.listen.releaseName,
            listenedAt: listen.listen.listenedAt
        )
    }
}

private extension MobileMusicDetailSeed {
    init(listen: MobileListenSummary) {
        self.init(
            kind: .track,
            trackName: listen.trackName,
            artistName: listen.artistName,
            releaseName: listen.releaseName,
            recordingMBID: listen.recordingMBID,
            recordingMSID: listen.recordingMSID,
            artistMBID: listen.artistMBID,
            releaseMBID: listen.releaseMBID,
            imageURL: listen.imageURL
        )
    }

    init(recommendation: MobileRecommendedRecording) {
        self.init(
            kind: .track,
            trackName: recommendation.title,
            artistName: recommendation.artistName ?? String(localized: "Unknown artist"),
            releaseName: recommendation.releaseName,
            recordingMBID: recommendation.recordingMBID
        )
    }
}

private extension MobileMusicDetail {
    init(seed: MobileMusicDetailSeed, details: OpenMusicEntityDetails) {
        self.init(
            seed: seed,
            trackName: details.trackName ?? seed.trackName,
            artistName: details.artistName.nilIfBlank ?? seed.artistName,
            releaseName: details.releaseName ?? seed.releaseName,
            recordingMBID: details.recordingMBID ?? seed.recordingMBID,
            recordingMSID: seed.recordingMSID,
            artistMBID: details.artistMBID ?? seed.artistMBID,
            releaseMBID: details.releaseMBID ?? seed.releaseMBID,
            imageURL: details.imageURL ?? seed.imageURL,
            artistImageURL: details.artistImageURL,
            artistSummary: details.artistSummary,
            artistSummaryURL: details.artistSummaryURL,
            artistSummaryLanguageCode: details.artistSummaryLanguageCode,
            disambiguation: details.disambiguation,
            country: details.country,
            type: details.type,
            tags: details.tags,
            links: details.links.map {
                MobileOpenMusicLink(id: $0.id, title: $0.title, url: $0.url)
            },
            fetchedAt: .now
        )
    }
}

private extension MobileDiscoverySearchResult {
    init(result: OpenMusicSearchResult, scope: MobileDiscoverySearchScope) {
        let seedKind: MobileMusicEntityKind
        switch result.kind {
        case .recording:
            seedKind = .track
        case .artist:
            seedKind = .artist
        case .release:
            seedKind = .release
        }

        let seed = MobileMusicDetailSeed(
            kind: seedKind,
            trackName: result.kind == .recording ? result.title : nil,
            artistName: result.kind == .artist ? result.title : (result.subtitle ?? String(localized: "Unknown artist")),
            releaseName: result.kind == .release ? result.title : result.detail,
            recordingMBID: result.recordingMBID,
            artistMBID: result.artistMBID,
            releaseMBID: result.releaseMBID,
            imageURL: result.imageURL
        )

        self.init(
            id: result.id,
            scope: scope,
            title: result.title,
            subtitle: result.subtitle,
            detail: result.detail,
            seed: seed
        )
    }
}

private extension MobileRadioQueueItem {
    init(recommendation: ListenBrainzRecommendedRecording) {
        let seed = MobileMusicDetailSeed(
            kind: .track,
            trackName: recommendation.title,
            artistName: recommendation.artistName ?? String(localized: "Unknown artist"),
            releaseName: recommendation.releaseName,
            recordingMBID: recommendation.recordingMbid
        )
        self.init(
            id: recommendation.id,
            title: recommendation.title,
            artistName: recommendation.artistName,
            releaseName: recommendation.releaseName,
            score: recommendation.score,
            seed: seed
        )
    }
}

private extension MobileRadioArtist {
    init(artist: ListenBrainzSimilarArtist) {
        self.init(
            id: artist.id,
            name: artist.name,
            totalListenCount: artist.totalListenCount
        )
    }
}

private extension OpenMusicSearchKind {
    init(scope: MobileDiscoverySearchScope) {
        switch scope {
        case .tracks:
            self = .recording
        case .artists:
            self = .artist
        case .releases:
            self = .release
        }
    }
}

private extension TrackSourceMetadata {
    init(mobile: MobileScrobbleSourceMetadata) {
        self.init(
            mediaPlayer: mobile.mediaPlayer,
            musicService: mobile.musicService,
            musicServiceName: mobile.musicServiceName,
            originURL: mobile.originURL,
            spotifyID: mobile.spotifyID,
            durationPlayed: mobile.durationPlayed,
            originalSubmissionClient: mobile.originalSubmissionClient
        )
    }
}
