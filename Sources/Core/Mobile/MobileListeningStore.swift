import Combine
import Foundation
import OSLog

protocol MobileListenBrainzClient {
    func update(settings: ListenBrainzSettings, token: String?) throws
    func clear()
    func validate() async throws -> ListenBrainzValidation
    func fetchRecentListens(username: String, count: Int) async throws -> [ListenBrainzListen]
    func fetchCurrentPin(username: String) async throws -> ListenBrainzPinnedRecording?
    func submitListen(_ track: Track) async throws
}

extension ListenBrainzService: MobileListenBrainzClient {}

public struct MobileListenSummary: Identifiable, Equatable {
    public let id: String
    public let trackName: String
    public let artistName: String
    public let releaseName: String?
    public let listenedAt: Date?
    public let imageURL: String?
}

public struct MobilePinnedRecording: Identifiable, Equatable {
    public let id: Int
    public let trackName: String
    public let artistName: String
    public let blurb: String?
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
                return "Connect ListenBrainz"
            case let .connected(username):
                return "\(username) on ListenBrainz"
            case .loading:
                return "Loading ListenBrainz"
            case let .failed(message):
                return message
            }
        }
    }

    @Published public private(set) var connectionState: ConnectionState
    @Published public private(set) var recentListens: [MobileListenSummary] = []
    @Published public private(set) var currentPin: MobilePinnedRecording?
    @Published public private(set) var isRefreshing = false

    private let settingsStore: ListenBrainzSettingsStore
    private let listenBrainz: MobileListenBrainzClient
    private let logger = Logger(subsystem: "org.openscrobbler.app.ios", category: "listenbrainz")

    public convenience init() {
        let settingsStore = ListenBrainzSettingsStore()
        self.init(
            settingsStore: settingsStore,
            listenBrainz: ListenBrainzService(settingsStore: settingsStore)
        )
    }

    init(
        settingsStore: ListenBrainzSettingsStore,
        listenBrainz: MobileListenBrainzClient
    ) {
        self.settingsStore = settingsStore
        self.listenBrainz = listenBrainz
        let settings = settingsStore.load()
        if let username = Self.nonBlank(settings.username), settingsStore.hasStoredToken() {
            self.connectionState = .connected(username: username)
            logger.info("Mobile listening store restored connected session for user \(username, privacy: .public)")
        } else {
            self.connectionState = .disconnected
            logger.info("Mobile listening store initialized disconnected")
        }
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
            connectionState = .failed("Paste a ListenBrainz token.")
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
        } catch {
            logger.error("ListenBrainz connect failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed(error.localizedDescription)
        }
    }

    public func disconnect() {
        logger.info("ListenBrainz disconnect requested")
        listenBrainz.clear()
        recentListens = []
        currentPin = nil
        connectionState = .disconnected
    }

    public func refresh() async {
        guard case let .connected(username) = connectionState else { return }

        logger.info("ListenBrainz refresh started for user \(username, privacy: .public)")
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            async let listens = listenBrainz.fetchRecentListens(username: username, count: 25)
            async let pin = listenBrainz.fetchCurrentPin(username: username)

            recentListens = try await listens.map(MobileListenSummary.init(listen:))
            currentPin = try await pin.map(MobilePinnedRecording.init(pin:))
            logger.info("ListenBrainz refresh succeeded with \(self.recentListens.count, privacy: .public) recent listens; pin present: \(self.currentPin != nil, privacy: .public)")
        } catch {
            logger.error("ListenBrainz refresh failed: \(error.localizedDescription, privacy: .public)")
            connectionState = .failed(error.localizedDescription)
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
        logger.info("Mobile scrobble submit succeeded from source \(candidate.source, privacy: .public)")
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func approximateStartDate(listenedAt: Date, duration: TimeInterval) -> Date {
        guard duration > 0 else { return listenedAt }
        return listenedAt.addingTimeInterval(-min(duration, 4 * 60))
    }
}

public enum MobileListeningError: LocalizedError, Equatable {
    case listenBrainzDisconnected

    public var errorDescription: String? {
        switch self {
        case .listenBrainzDisconnected:
            return "Connect ListenBrainz before submitting listens."
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
            imageURL: listen.imageURL
        )
    }
}

private extension MobilePinnedRecording {
    init(pin: ListenBrainzPinnedRecording) {
        self.init(
            id: pin.id,
            trackName: pin.trackName,
            artistName: pin.artistName,
            blurb: pin.blurb
        )
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
