import Foundation

protocol ListenBrainzTokenStoring {
    func readToken() throws -> String?
    func saveToken(_ token: String) throws
    func deleteToken() throws
}

struct ListenBrainzSettings: Codable, Equatable {
    var isEnabled: Bool
    var submitNowPlaying: Bool
    var submitListens: Bool
    var baseURL: URL
    var username: String?

    static let `default` = ListenBrainzSettings(
        isEnabled: false,
        submitNowPlaying: true,
        submitListens: true,
        baseURL: URL(string: "https://api.listenbrainz.org")!,
        username: nil
    )
}

struct ListenBrainzValidation: Equatable {
    let isValid: Bool
    let username: String?
    let message: String
}

enum ListenBrainzStatsRange: String, CaseIterable, Identifiable {
    case week
    case month
    case year
    case allTime = "all_time"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .year: return "Year"
        case .allTime: return "All Time"
        }
    }
}

struct ListenBrainzStatsSnapshot: Equatable {
    let username: String
    let range: ListenBrainzStatsRange
    let totalListenCount: Int?
    let listeningActivity: [ListenBrainzListeningActivity]
    let topArtists: [ListenBrainzArtistStat]
    let topReleases: [ListenBrainzReleaseStat]
    let topRecordings: [ListenBrainzRecordingStat]
    let recentListens: [ListenBrainzListen]
    let fetchedAt: Date
}

// ListenBrainz models are intentionally small and app-shaped. Keep raw API
// payload structs private near the decoder layer, then expose stable values
// that SwiftUI and tests can reason about without knowing endpoint quirks.
struct ListenBrainzListeningActivity: Identifiable, Equatable {
    let id: String
    let label: String
    let listenCount: Int
    let from: Date?
    let to: Date?
}

struct ListenBrainzArtistStat: Identifiable, Equatable {
    let id: String
    let name: String
    let listenCount: Int
    let mbid: String?
}

struct ListenBrainzReleaseStat: Identifiable, Equatable {
    let id: String
    let name: String
    let artistName: String
    let listenCount: Int
    let mbid: String?
}

struct ListenBrainzRecordingStat: Identifiable, Equatable {
    let id: String
    let trackName: String
    let artistName: String
    let releaseName: String?
    let listenCount: Int
    let mbid: String?
}

struct ListenBrainzListen: Identifiable, Equatable {
    let id: String
    let trackName: String
    let artistName: String
    let releaseName: String?
    let listenedAt: Date?
    let recordingMBID: String?
    let recordingMSID: String?
    let artistMBID: String?
    let releaseMBID: String?
    let imageURL: String?
}

struct ListenBrainzSocialListen: Identifiable, Equatable {
    let id: String
    let userName: String
    let listen: ListenBrainzListen
}

struct ListenBrainzArtistMapEntry: Identifiable, Equatable {
    let id: String
    let countryCode: String
    let artistCount: Int
}

enum ListenBrainzSimilarityMode: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }
}

struct ListenBrainzSimilarArtist: Identifiable, Equatable {
    let id: String
    let artistMbid: String
    let name: String
    let totalListenCount: Int
    let isSeedArtist: Bool
    let imageURL: String?
}

struct ListenBrainzRecommendedRecording: Identifiable, Equatable {
    let id: String
    let recordingMbid: String
    let title: String
    let artistName: String?
    let releaseName: String?
    let score: Double
}

struct ListenBrainzPopularityCounts: Equatable {
    let mbid: String
    let totalListenCount: Int?
    let totalUserCount: Int?
}

struct ListenBrainzArtistTag: Identifiable, Equatable {
    let id: String
    let name: String
    let count: Int
}

struct ListenBrainzArtistLink: Identifiable, Equatable {
    let id: String
    let title: String
    let url: URL
}

struct ListenBrainzArtistProfile: Equatable {
    let mbid: String
    let name: String
    let area: String?
    let beginYear: Int?
    let type: String?
    let tags: [ListenBrainzArtistTag]
    let links: [ListenBrainzArtistLink]
}

struct ListenBrainzPopularRecording: Identifiable, Equatable {
    let id: String
    let recordingMbid: String
    let title: String
    let artistName: String
    let releaseName: String?
    let totalListenCount: Int?
    let totalUserCount: Int?
    let imageURL: String?
}

struct ListenBrainzSimilarUser: Identifiable, Equatable {
    let id: String
    let userName: String
    let similarityScore: Double
}

struct ListenBrainzSharedArtist: Identifiable, Equatable {
    let id: String
    let name: String
    let mbid: String?
    let yourListenCount: Int
    let otherListenCount: Int
}

struct ListenBrainzUserCompatibility: Equatable {
    let sourceUserName: String
    let targetUserName: String
    let similarityScore: Double
    let sharedArtists: [ListenBrainzSharedArtist]
}

struct ListenBrainzPinnedRecording: Identifiable, Equatable {
    let id: Int
    let recordingMbid: String?
    let recordingMsid: String?
    let trackName: String
    let artistName: String
    let blurb: String?
    let createdAt: Date?
    let pinnedUntil: Date?
    let userName: String?
}

struct ListenBrainzPlaylistSummary: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let creator: String?
    let trackCount: Int?
    let isPublic: Bool?
}

enum ListenBrainzError: LocalizedError, Equatable {
    case missingToken
    case invalidToken
    case invalidResponse
    case rateLimited(retryAfter: TimeInterval?)
    case api(message: String)
    case transport(message: String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "ListenBrainz token is missing."
        case .invalidToken:
            return "ListenBrainz token is invalid."
        case .invalidResponse:
            return "Unexpected response from ListenBrainz."
        case let .rateLimited(retryAfter):
            if let retryAfter {
                return "ListenBrainz rate limited the request. Retry after \(Int(retryAfter.rounded())) seconds."
            }
            return "ListenBrainz rate limited the request."
        case let .api(message):
            return message
        case let .transport(message):
            return message
        }
    }
}

final class ListenBrainzSettingsStore {
    private let defaults: UserDefaults
    private let tokenStore: ListenBrainzTokenStoring
    private let settingsKey = "listenbrainz.settings"
    private let tokenAvailableKey = "listenbrainz.token-available"

    init(defaults: UserDefaults = .standard, tokenStore: ListenBrainzTokenStoring = ListenBrainzTokenStore()) {
        self.defaults = defaults
        self.tokenStore = tokenStore
    }

    func load() -> ListenBrainzSettings {
        guard let data = defaults.data(forKey: settingsKey),
              let settings = try? JSONDecoder().decode(ListenBrainzSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save(_ settings: ListenBrainzSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: settingsKey)
    }

    func token() -> String? {
        try? tokenStore.readToken()
    }

    func hasStoredToken() -> Bool {
        defaults.bool(forKey: tokenAvailableKey) || token() != nil
    }

    func saveToken(_ token: String) throws {
        try tokenStore.saveToken(token)
        defaults.set(true, forKey: tokenAvailableKey)
    }

    func clearToken() {
        try? tokenStore.deleteToken()
        defaults.set(false, forKey: tokenAvailableKey)
    }
}

final class ListenBrainzTokenStore: ListenBrainzTokenStoring {
    private let fileManager: FileManager
    private let tokenFileURL: URL

    init(fileManager: FileManager = .default, appSupportRoot: URL? = nil) {
        self.fileManager = fileManager
        let appSupport = appSupportRoot ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        // Keep tokens out of UserDefaults. The boolean flag below is only for
        // UI state; the token itself lives in an app-support file with narrow
        // POSIX permissions so contributors can swap in Keychain later.
        let dir = appSupport.appendingPathComponent("OpenScrobbler", isDirectory: true)
            .appendingPathComponent("Secrets", isDirectory: true)
        try? fileManager.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dir.path)
        self.tokenFileURL = dir.appendingPathComponent("listenbrainz-token")
    }

    func readToken() throws -> String? {
        guard fileManager.fileExists(atPath: tokenFileURL.path) else {
            return nil
        }
        let data: Data
        do {
            data = try Data(contentsOf: tokenFileURL)
        } catch {
            throw ListenBrainzError.invalidResponse
        }
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    func saveToken(_ token: String) throws {
        let data = Data(token.utf8)
        do {
            try data.write(to: tokenFileURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: tokenFileURL.path)
        } catch {
            throw ListenBrainzError.invalidResponse
        }
    }

    func deleteToken() throws {
        guard fileManager.fileExists(atPath: tokenFileURL.path) else {
            return
        }
        do {
            try fileManager.removeItem(at: tokenFileURL)
        } catch {
            throw ListenBrainzError.invalidResponse
        }
    }
}

final class ListenBrainzService {
    // This client speaks ListenBrainz directly. It should stay free of UI state:
    // ScrobbleService composes these calls into app workflows and fallbacks.
    private let settingsStore: ListenBrainzSettingsStore
    private let urlSession: URLSession
    private let sleep: @Sendable (UInt64) async -> Void

    init(
        settingsStore: ListenBrainzSettingsStore = ListenBrainzSettingsStore(),
        urlSession: URLSession = .shared,
        sleep: @escaping @Sendable (UInt64) async -> Void = { nanos in
            try? await Task.sleep(nanoseconds: nanos)
        }
    ) {
        self.settingsStore = settingsStore
        self.urlSession = urlSession
        self.sleep = sleep
    }

    var settings: ListenBrainzSettings {
        settingsStore.load()
    }

    var token: String? {
        settingsStore.token()?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var hasStoredToken: Bool {
        settingsStore.hasStoredToken()
    }

    var isReadyForNowPlaying: Bool {
        let settings = settings
        return settings.isEnabled && settings.submitNowPlaying && token != nil
    }

    var isReadyForListenSubmission: Bool {
        let settings = settings
        return settings.isEnabled && settings.submitListens && token != nil
    }

    func update(settings: ListenBrainzSettings, token: String?) throws {
        settingsStore.save(settings)
        if let token = token?.trimmingCharacters(in: .whitespacesAndNewlines), !token.isEmpty {
            try settingsStore.saveToken(token)
        }
    }

    func clear() {
        var settings = settingsStore.load()
        settings.isEnabled = false
        settings.username = nil
        settingsStore.save(settings)
        settingsStore.clearToken()
    }

    func validate() async throws -> ListenBrainzValidation {
        guard let token else { throw ListenBrainzError.missingToken }
        let url = settings.baseURL.appendingPathComponent("1/validate-token")
        var request = URLRequest(url: url)
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await urlSession.data(for: request)
        try validateHTTP(response: response, data: data)
        let decoded = try JSONDecoder().decode(ValidateTokenResponse.self, from: data)
        guard decoded.valid else {
            throw ListenBrainzError.invalidToken
        }
        var updated = settings
        updated.username = decoded.userName
        settingsStore.save(updated)
        return ListenBrainzValidation(
            isValid: true,
            username: decoded.userName,
            message: decoded.message ?? "Token valid."
        )
    }

    func nowPlaying(_ track: Track) async throws {
        guard isReadyForNowPlaying else { return }
        try await submit(listenType: "playing_now", track: track, includeTimestamp: false)
    }

    func submitListen(_ track: Track) async throws {
        guard isReadyForListenSubmission else { return }
        try await submit(listenType: "single", track: track, includeTimestamp: true)
    }

    func fetchStatsSnapshot(username: String, range: ListenBrainzStatsRange, count: Int = 25) async throws -> ListenBrainzStatsSnapshot {
        async let listenCount = fetchListenCount(username: username)
        async let artists = fetchTopArtists(username: username, range: range, count: count)
        async let releases = fetchTopReleases(username: username, range: range, count: count)
        async let recordings = fetchTopRecordings(username: username, range: range, count: count)
        async let listens = fetchRecentListens(username: username, count: min(count, 50))
        async let activity = fetchListeningActivity(username: username, range: range)

        return try await ListenBrainzStatsSnapshot(
            username: username,
            range: range,
            totalListenCount: listenCount,
            listeningActivity: activity,
            topArtists: artists,
            topReleases: releases,
            topRecordings: recordings,
            recentListens: listens,
            fetchedAt: .now
        )
    }

    func fetchListeningActivity(username: String, range: ListenBrainzStatsRange) async throws -> [ListenBrainzListeningActivity] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/stats/user")
                .appendingPathComponent(username)
                .appendingPathComponent("listening-activity"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "range", value: range.rawValue)]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzListeningActivityResponse = try await getJSON(url: url, allowNoContent: true)
        return (response.payload?.listeningActivity ?? []).map { entry in
            ListenBrainzListeningActivity(
                id: "\(entry.fromTS)-\(entry.toTS)-\(entry.timeRange)",
                label: entry.timeRange,
                listenCount: entry.listenCount,
                from: Date(timeIntervalSince1970: TimeInterval(entry.fromTS)),
                to: Date(timeIntervalSince1970: TimeInterval(entry.toTS))
            )
        }
    }

    func fetchListenCount(username: String) async throws -> Int? {
        let url = settings.baseURL
            .appendingPathComponent("1/user")
            .appendingPathComponent(username)
            .appendingPathComponent("listen-count")
        let response: ListenBrainzListenCountResponse = try await getJSON(url: url, allowNoContent: true)
        return response.payload?.count
    }

    func fetchRecentListens(username: String, count: Int = 25) async throws -> [ListenBrainzListen] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/user")
                .appendingPathComponent(username)
                .appendingPathComponent("listens"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzListensResponse = try await getJSON(url: url, allowNoContent: true)
        return (response.payload?.listens ?? []).map { listen in
            let metadata = listen.trackMetadata
            let additional = metadata.additionalInfo
            return ListenBrainzListen(
                id: "\(listen.listenedAt ?? 0)|\(metadata.artistName)|\(metadata.trackName)",
                trackName: metadata.trackName,
                artistName: metadata.artistName,
                releaseName: metadata.releaseName,
                listenedAt: listen.listenedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) },
                recordingMBID: additional?.recordingMBID?.nilIfBlank,
                recordingMSID: additional?.recordingMSID?.nilIfBlank,
                artistMBID: additional?.artistMBIDs?.first?.nilIfBlank,
                releaseMBID: additional?.releaseMBID?.nilIfBlank,
                imageURL: coverArtURL(releaseMBID: additional?.releaseMBID)
            )
        }
    }

    func fetchSocialListenActivity(usernames: [String], countPerUser: Int = 3) async throws -> [ListenBrainzSocialListen] {
        var seenUsers = Set<String>()
        let uniqueUsers = usernames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seenUsers.insert($0.lowercased()).inserted }
            .prefix(12)

        var output: [ListenBrainzSocialListen] = []
        for username in uniqueUsers {
            let listens = try await fetchRecentListens(username: username, count: countPerUser)
            output.append(contentsOf: listens.map { listen in
                ListenBrainzSocialListen(
                    id: "\(username)|\(listen.id)",
                    userName: username,
                    listen: listen
                )
            })
        }

        return output.sorted { lhs, rhs in
            switch (lhs.listen.listenedAt, rhs.listen.listenedAt) {
            case let (left?, right?):
                return left > right
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.userName.localizedCaseInsensitiveCompare(rhs.userName) == .orderedAscending
            }
        }
    }

    func fetchTopArtists(username: String, range: ListenBrainzStatsRange, count: Int = 25) async throws -> [ListenBrainzArtistStat] {
        let response: ListenBrainzArtistsStatsResponse = try await getStats(
            username: username,
            endpoint: "artists",
            range: range,
            count: count
        )
        return (response.payload?.artists ?? []).map {
            ListenBrainzArtistStat(
                id: $0.artistMbid?.nilIfBlank ?? $0.artistName,
                name: $0.artistName,
                listenCount: $0.listenCount,
                mbid: $0.artistMbid?.nilIfBlank
            )
        }
    }

    func fetchArtistMap(username: String, range: ListenBrainzStatsRange) async throws -> [ListenBrainzArtistMapEntry] {
        let response: ListenBrainzArtistMapResponse = try await getStats(
            username: username,
            endpoint: "artist-map",
            range: range,
            count: 200
        )
        return (response.payload?.artistMap ?? [])
            .filter { !$0.country.isEmpty && $0.artistCount > 0 }
            .map {
                ListenBrainzArtistMapEntry(
                    id: $0.country,
                    countryCode: $0.country,
                    artistCount: $0.artistCount
                )
            }
            .sorted { lhs, rhs in
                if lhs.artistCount == rhs.artistCount {
                    return lhs.countryCode < rhs.countryCode
                }
                return lhs.artistCount > rhs.artistCount
            }
    }

    func fetchTopReleases(username: String, range: ListenBrainzStatsRange, count: Int = 25) async throws -> [ListenBrainzReleaseStat] {
        let response: ListenBrainzReleasesStatsResponse = try await getStats(
            username: username,
            endpoint: "releases",
            range: range,
            count: count
        )
        return (response.payload?.releases ?? []).map {
            ListenBrainzReleaseStat(
                id: $0.releaseMbid ?? "\($0.artistName)|\($0.releaseName)",
                name: $0.releaseName,
                artistName: $0.artistName,
                listenCount: $0.listenCount,
                mbid: $0.releaseMbid?.nilIfBlank
            )
        }
    }

    func fetchTopRecordings(username: String, range: ListenBrainzStatsRange, count: Int = 25) async throws -> [ListenBrainzRecordingStat] {
        let response: ListenBrainzRecordingsStatsResponse = try await getStats(
            username: username,
            endpoint: "recordings",
            range: range,
            count: count
        )
        return (response.payload?.recordings ?? []).map {
            ListenBrainzRecordingStat(
                id: $0.recordingMbid ?? "\($0.artistName)|\($0.trackName)",
                trackName: $0.trackName,
                artistName: $0.artistName,
                releaseName: $0.releaseName?.nilIfBlank,
                listenCount: $0.listenCount,
                mbid: $0.recordingMbid?.nilIfBlank
            )
        }
    }

    func fetchSimilarArtists(
        seedArtistMBID: String,
        mode: ListenBrainzSimilarityMode = .easy,
        maxSimilarArtists: Int = 8,
        maxRecordingsPerArtist: Int = 3,
        popularityRange: ClosedRange<Int> = 0...100
    ) async throws -> [ListenBrainzSimilarArtist] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/lb-radio/artist")
                .appendingPathComponent(seedArtistMBID),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "mode", value: mode.rawValue),
            URLQueryItem(name: "max_similar_artists", value: "\(maxSimilarArtists)"),
            URLQueryItem(name: "max_recordings_per_artist", value: "\(maxRecordingsPerArtist)"),
            URLQueryItem(name: "pop_begin", value: "\(popularityRange.lowerBound)"),
            URLQueryItem(name: "pop_end", value: "\(popularityRange.upperBound)")
        ]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await urlSession.data(for: request)
        try validateHTTP(response: response, data: data)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ListenBrainzError.invalidResponse
        }

        let payload = (object["payload"] as? [String: Any]) ?? object
        var results: [ListenBrainzSimilarArtist] = []
        for (artistMbid, rawEntries) in payload {
            guard let entries = rawEntries as? [[String: Any]], let sample = entries.first else { continue }
            let name = (sample["similar_artist_name"] as? String)?.nilIfBlank ?? artistMbid
            let score = entries.compactMap { $0["total_listen_count"] as? Int }.max() ?? 0
            results.append(
                ListenBrainzSimilarArtist(
                    id: artistMbid,
                    artistMbid: artistMbid,
                    name: name,
                    totalListenCount: score,
                    isSeedArtist: artistMbid == seedArtistMBID,
                    imageURL: nil
                )
            )
        }

        return results.sorted { lhs, rhs in
            if lhs.totalListenCount == rhs.totalListenCount {
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            return lhs.totalListenCount > rhs.totalListenCount
        }
    }

    func fetchFollowers(username: String) async throws -> [String] {
        let response: ListenBrainzSocialUsersResponse = try await get(
            pathComponents: ["1", "user", username, "followers"],
            allowNoContent: true
        )
        return (response.followers ?? []).map(\.trimmedUsername).filter { !$0.isEmpty }
    }

    func fetchFollowing(username: String) async throws -> [String] {
        let response: ListenBrainzSocialUsersResponse = try await get(
            pathComponents: ["1", "user", username, "following"],
            allowNoContent: true
        )
        return (response.following ?? []).map(\.trimmedUsername).filter { !$0.isEmpty }
    }

    func fetchSimilarUsers(username: String, count: Int = 12) async throws -> [ListenBrainzSimilarUser] {
        var components = URLComponents(
            url: pathURL(["1", "user", username, "similar-users"]),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzSimilarUsersResponse = try await getJSON(url: url, allowNoContent: true)
        return response.payload
            .map {
                ListenBrainzSimilarUser(
                    id: $0.userName,
                    userName: $0.userName,
                    similarityScore: $0.normalizedSimilarity
                )
            }
            .sorted { lhs, rhs in
                if lhs.similarityScore == rhs.similarityScore {
                    return lhs.userName.localizedCaseInsensitiveCompare(rhs.userName) == .orderedAscending
                }
                return lhs.similarityScore > rhs.similarityScore
            }
    }

    func fetchCompatibility(
        sourceUsername: String,
        targetUsername: String,
        artistLimit: Int = 100
    ) async throws -> ListenBrainzUserCompatibility {
        async let similarity = fetchSimilarity(sourceUsername: sourceUsername, targetUsername: targetUsername)
        async let sourceArtists = fetchTopArtists(username: sourceUsername, range: .allTime, count: artistLimit)
        async let targetArtists = fetchTopArtists(username: targetUsername, range: .allTime, count: artistLimit)

        let sourceTopArtists = try await sourceArtists
        let targetTopArtists = try await targetArtists
        let sourceMap = Dictionary(
            uniqueKeysWithValues: sourceTopArtists.map { (sharedArtistKey(name: $0.name, mbid: $0.mbid), $0) }
        )
        let targetMap = Dictionary(
            uniqueKeysWithValues: targetTopArtists.map { (sharedArtistKey(name: $0.name, mbid: $0.mbid), $0) }
        )

        let sharedArtists = Set(sourceMap.keys)
            .intersection(Set(targetMap.keys))
            .compactMap { key -> ListenBrainzSharedArtist? in
                guard let lhs = sourceMap[key], let rhs = targetMap[key] else { return nil }
                let sharedID = lhs.mbid?.nilIfBlank ?? rhs.mbid?.nilIfBlank ?? key
                return ListenBrainzSharedArtist(
                    id: sharedID,
                    name: lhs.name,
                    mbid: lhs.mbid?.nilIfBlank ?? rhs.mbid?.nilIfBlank,
                    yourListenCount: lhs.listenCount,
                    otherListenCount: rhs.listenCount
                )
            }
            .sorted { lhs, rhs in
                let lhsTotal = lhs.yourListenCount + lhs.otherListenCount
                let rhsTotal = rhs.yourListenCount + rhs.otherListenCount
                if lhsTotal == rhsTotal {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhsTotal > rhsTotal
            }

        return ListenBrainzUserCompatibility(
            sourceUserName: sourceUsername,
            targetUserName: targetUsername,
            similarityScore: try await similarity,
            sharedArtists: sharedArtists
        )
    }

    func follow(username: String) async throws {
        try await postAuthorized(
            pathComponents: ["1", "user", username, "follow"],
            body: EmptyRequestBody()
        )
    }

    func unfollow(username: String) async throws {
        try await postAuthorized(
            pathComponents: ["1", "user", username, "unfollow"],
            body: EmptyRequestBody()
        )
    }

    func fetchRecommendedRecordings(username: String, count: Int = 24, offset: Int = 0) async throws -> [ListenBrainzRecommendedRecording] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/cf/recommendation/user")
                .appendingPathComponent(username)
                .appendingPathComponent("recording"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "count", value: "\(count)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzRecommendationsResponse = try await getJSON(url: url, allowNoContent: true)
        let baseItems = response.payload?.mbids ?? []
        let mbids = baseItems.map(\.recordingMbid)
        let metadata = try await fetchRecordingMetadata(recordingMBIDs: mbids)

        return baseItems.map { item in
            let details = metadata[item.recordingMbid]
            return ListenBrainzRecommendedRecording(
                id: item.recordingMbid,
                recordingMbid: item.recordingMbid,
                title: details?.recordingName ?? "Unknown track",
                artistName: details?.artistCreditName,
                releaseName: details?.releaseName,
                score: item.score
            )
        }
    }

    func fetchRecordingPopularity(recordingMBIDs: [String]) async throws -> [ListenBrainzPopularityCounts] {
        let normalized = normalizedMBIDs(recordingMBIDs)
        guard !normalized.isEmpty else { return [] }
        let payload = ListenBrainzRecordingPopularityRequest(recordingMBIDs: normalized)
        let response: [ListenBrainzRecordingPopularityResponse] = try await postPublicJSON(
            pathComponents: ["1", "popularity", "recording"],
            body: payload
        )
        return response.map {
            ListenBrainzPopularityCounts(
                mbid: $0.recordingMbid,
                totalListenCount: $0.totalListenCount,
                totalUserCount: $0.totalUserCount
            )
        }
    }

    func fetchArtistPopularity(artistMBIDs: [String]) async throws -> [ListenBrainzPopularityCounts] {
        let normalized = normalizedMBIDs(artistMBIDs)
        guard !normalized.isEmpty else { return [] }
        let payload = ListenBrainzArtistPopularityRequest(artistMBIDs: normalized)
        let response: [ListenBrainzArtistPopularityResponse] = try await postPublicJSON(
            pathComponents: ["1", "popularity", "artist"],
            body: payload
        )
        return response.map {
            ListenBrainzPopularityCounts(
                mbid: $0.artistMbid,
                totalListenCount: $0.totalListenCount,
                totalUserCount: $0.totalUserCount
            )
        }
    }

    func fetchReleasePopularity(releaseMBIDs: [String]) async throws -> [ListenBrainzPopularityCounts] {
        let normalized = normalizedMBIDs(releaseMBIDs)
        guard !normalized.isEmpty else { return [] }
        let payload = ListenBrainzReleasePopularityRequest(releaseMBIDs: normalized)
        let response: [ListenBrainzReleasePopularityResponse] = try await postPublicJSON(
            pathComponents: ["1", "popularity", "release"],
            body: payload
        )
        return response.map {
            ListenBrainzPopularityCounts(
                mbid: $0.releaseMbid,
                totalListenCount: $0.totalListenCount,
                totalUserCount: $0.totalUserCount
            )
        }
    }

    func fetchArtistProfile(artistMBID: String) async throws -> ListenBrainzArtistProfile? {
        let trimmed = artistMBID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var components = URLComponents(
            url: settings.baseURL.appendingPathComponent("1/metadata/artist/"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "artist_mbids", value: trimmed),
            URLQueryItem(name: "inc", value: "artist tag release")
        ]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: [ListenBrainzArtistMetadataResponse] = try await getJSON(url: url, allowNoContent: true)
        return response.first.map(artistProfile)
    }

    func fetchPopularRecordingsForArtist(artistMBID: String, count: Int = 8) async throws -> [ListenBrainzPopularRecording] {
        let trimmed = artistMBID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/popularity/top-recordings-for-artist")
                .appendingPathComponent(trimmed),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: [ListenBrainzPopularRecordingResponse] = try await getJSON(url: url, allowNoContent: true)
        return response.map {
            ListenBrainzPopularRecording(
                id: $0.recordingMbid,
                recordingMbid: $0.recordingMbid,
                title: $0.recordingName,
                artistName: $0.artistName,
                releaseName: $0.releaseName?.nilIfBlank,
                totalListenCount: $0.totalListenCount,
                totalUserCount: $0.totalUserCount,
                imageURL: coverArtURL(releaseMBID: $0.caaReleaseMbid ?? $0.releaseMbid)
            )
        }
    }

    func recommendRecording(
        recordingMbid: String,
        to users: [String],
        blurb: String?,
        from username: String
    ) async throws {
        try await postAuthorized(
            pathComponents: ["1", "user", username, "timeline-event", "create", "recommend-personal"],
            body: ListenBrainzPersonalRecommendationRequest(
                metadata: .init(
                    recordingMbid: recordingMbid,
                    users: users,
                    blurbContent: blurb?.nilIfBlank
                )
            )
        )
    }

    func fetchCurrentPin(username: String) async throws -> ListenBrainzPinnedRecording? {
        let url = settings.baseURL
            .appendingPathComponent("1")
            .appendingPathComponent(username)
            .appendingPathComponent("pins")
            .appendingPathComponent("current")
        let response: ListenBrainzCurrentPinResponse = try await getJSON(url: url, allowNoContent: true)
        return response.pinnedRecording?.asPinnedRecording()
    }

    func fetchPins(username: String, count: Int = 12) async throws -> [ListenBrainzPinnedRecording] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1")
                .appendingPathComponent(username)
                .appendingPathComponent("pins"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzPinsResponse = try await getJSON(url: url, allowNoContent: true)
        return response.pinnedRecordings.map { $0.asPinnedRecording() }
    }

    func fetchFollowingPins(username: String, count: Int = 12) async throws -> [ListenBrainzPinnedRecording] {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1")
                .appendingPathComponent(username)
                .appendingPathComponent("pins")
                .appendingPathComponent("following"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        let response: ListenBrainzPinsResponse = try await getJSON(url: url, allowNoContent: true)
        return response.pinnedRecordings.map { $0.asPinnedRecording() }
    }

    func pinRecording(recordingMbid: String, blurb: String? = nil, pinnedUntil: Date? = nil) async throws {
        try await postAuthorized(
            pathComponents: ["1", "pin"],
            body: ListenBrainzPinRequest(
                recordingMsid: nil,
                recordingMbid: recordingMbid,
                blurbContent: blurb?.nilIfBlank,
                pinnedUntil: pinnedUntil.map { Int($0.timeIntervalSince1970) }
            )
        )
    }

    func pinRecording(recordingMsid: String, blurb: String? = nil, pinnedUntil: Date? = nil) async throws {
        try await postAuthorized(
            pathComponents: ["1", "pin"],
            body: ListenBrainzPinRequest(
                recordingMsid: recordingMsid,
                recordingMbid: nil,
                blurbContent: blurb?.nilIfBlank,
                pinnedUntil: pinnedUntil.map { Int($0.timeIntervalSince1970) }
            )
        )
    }

    func unpinCurrentRecording() async throws {
        try await postAuthorized(
            pathComponents: ["1", "pin", "unpin"],
            body: EmptyRequestBody()
        )
    }

    func deletePin(rowID: Int) async throws {
        try await postAuthorized(
            pathComponents: ["1", "pin", "delete", "\(rowID)"],
            body: EmptyRequestBody()
        )
    }

    func fetchPlaylists(username: String, count: Int = 20) async throws -> [ListenBrainzPlaylistSummary] {
        try await fetchPlaylistSummaries(pathComponents: ["1", "user", username, "playlists"], count: count)
    }

    func fetchRecommendationPlaylists(username: String, count: Int = 12) async throws -> [ListenBrainzPlaylistSummary] {
        try await fetchPlaylistSummaries(pathComponents: ["1", "user", username, "playlists", "recommendations"], count: count)
    }

    func createPlaylist(title: String, recordingMBIDs: [String]) async throws {
        let tracks = recordingMBIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { mbid in
                ListenBrainzPlaylistTrack(identifier: "https://musicbrainz.org/recording/\(mbid)")
            }

        try await postAuthorized(
            pathComponents: ["1", "playlist", "create"],
            body: ListenBrainzPlaylistCreateRequest(
                playlist: .init(
                    title: title,
                    track: tracks
                )
            )
        )
    }

    private func submit(listenType: String, track: Track, includeTimestamp: Bool) async throws {
        let payload = ListenBrainzSubmitRequest(
            listenType: listenType,
            payload: [
                ListenBrainzListenPayload(
                    listenedAt: includeTimestamp ? Int(track.startedAt.timeIntervalSince1970) : nil,
                    trackMetadata: ListenBrainzTrackMetadata(
                        artistName: track.artist,
                        trackName: track.title,
                        releaseName: track.album,
                        additionalInfo: ListenBrainzAdditionalInfo(
                            mediaPlayer: track.sourceApp,
                            submissionClient: "OpenScrobbler",
                            submissionClientVersion: "0.1.0"
                        )
                    )
                )
            ]
        )
        try await postAuthorized(pathComponents: ["1", "submit-listens"], body: payload)
    }

    private func postAuthorized<T: Encodable>(pathComponents: [String], body: T) async throws {
        guard let token else { throw ListenBrainzError.missingToken }
        var request = URLRequest(url: pathURL(pathComponents))
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        _ = try await send(request, allowNoContent: false)
    }

    private func postPublicJSON<Body: Encodable, Response: Decodable>(
        pathComponents: [String],
        body: Body
    ) async throws -> Response {
        var request = URLRequest(url: pathURL(pathComponents))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let data = try await send(request, allowNoContent: false)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func normalizedMBIDs(_ values: [String]) -> [String] {
        Array(Set(values.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
    }

    private func coverArtURL(releaseMBID: String?) -> String? {
        guard let releaseMBID = releaseMBID?.nilIfBlank else { return nil }
        return "https://coverartarchive.org/release/\(releaseMBID)/front-250"
    }

    private func fetchRecordingMetadata(recordingMBIDs: [String]) async throws -> [String: ListenBrainzRecordingMetadata] {
        let normalized = Array(Set(recordingMBIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }))
        guard !normalized.isEmpty else { return [:] }

        guard let token else { throw ListenBrainzError.missingToken }
        let url = settings.baseURL.appendingPathComponent("1/metadata/recording")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(
            ListenBrainzRecordingMetadataRequest(
                recordingMBIDs: normalized,
                inc: "artist release"
            )
        )

        let data = try await send(request, allowNoContent: false)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ListenBrainzError.invalidResponse
        }

        var output: [String: ListenBrainzRecordingMetadata] = [:]
        for mbid in normalized {
            guard let entry = object[mbid] as? [String: Any] else { continue }
            let recording = entry["recording"] as? [String: Any]
            let artist = entry["artist"] as? [String: Any]
            let release = entry["release"] as? [String: Any]
            let releaseList = entry["releases"] as? [[String: Any]]
            let firstRelease = releaseList?.first
            let artistList = artist?["artists"] as? [[String: Any]]
            let firstArtist = artistList?.first

            let releaseName = firstNonBlankString([
                entry["release_name"] as? String,
                release?["release_name"] as? String,
                release?["name"] as? String,
                firstRelease?["release_name"] as? String,
                firstRelease?["name"] as? String
            ])
            let recordingName = firstNonBlankString([
                entry["recording_name"] as? String,
                entry["track_name"] as? String,
                recording?["recording_name"] as? String,
                recording?["track_name"] as? String,
                recording?["name"] as? String,
                recording?["title"] as? String
            ])
            let artistCreditName = firstNonBlankString([
                entry["artist_credit_name"] as? String,
                entry["artist_name"] as? String,
                artist?["artist_credit_name"] as? String,
                artist?["artist_name"] as? String,
                artist?["name"] as? String,
                firstArtist?["name"] as? String,
                release?["album_artist_name"] as? String
            ])

            output[mbid] = ListenBrainzRecordingMetadata(
                recordingName: recordingName,
                artistCreditName: artistCreditName,
                releaseName: releaseName
            )
        }
        return output
    }

    private func firstNonBlankString(_ values: [String?]) -> String? {
        for value in values {
            if let normalized = value?.nilIfBlank {
                return normalized
            }
        }
        return nil
    }

    private func artistProfile(from response: ListenBrainzArtistMetadataResponse) -> ListenBrainzArtistProfile {
        let tags = (response.tag?.artist ?? [])
            .compactMap { tag -> ListenBrainzArtistTag? in
                guard let name = tag.tag.nilIfBlank else { return nil }
                return ListenBrainzArtistTag(
                    id: tag.genreMbid?.nilIfBlank ?? name.lowercased(),
                    name: name,
                    count: tag.count
                )
            }
            .sorted { lhs, rhs in
                if lhs.count == rhs.count {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.count > rhs.count
            }

        let links = (response.rels ?? [:])
            .sorted { $0.key < $1.key }
            .compactMap { relation, rawURL -> ListenBrainzArtistLink? in
                guard let url = URL(string: rawURL), url.scheme != nil else { return nil }
                return ListenBrainzArtistLink(
                    id: "\(relation)-\(rawURL)",
                    title: relation.capitalized,
                    url: url
                )
            }

        return ListenBrainzArtistProfile(
            mbid: response.artistMbid.nilIfBlank ?? response.mbid,
            name: response.name,
            area: response.area?.nilIfBlank,
            beginYear: response.beginYear,
            type: response.type?.nilIfBlank,
            tags: tags,
            links: links
        )
    }

    private func fetchPlaylistSummaries(pathComponents: [String], count: Int) async throws -> [ListenBrainzPlaylistSummary] {
        var components = URLComponents(
            url: pathURL(pathComponents),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "count", value: "\(count)")]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }

        var request = URLRequest(url: url)
        if let token {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        let data = try await send(request, allowNoContent: false)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ListenBrainzError.invalidResponse
        }

        let rawPlaylists = (object["playlists"] as? [[String: Any]])
            ?? ((object["playlist"] as? [String: Any]).map { [$0] })
            ?? []

        return rawPlaylists.compactMap { payload in
            let title = (payload["title"] as? String)?.nilIfBlank
                ?? ((payload["playlist"] as? [String: Any])?["title"] as? String)?.nilIfBlank
            let identifier = (payload["identifier"] as? String)?.nilIfBlank
                ?? ((payload["playlist"] as? [String: Any])?["identifier"] as? String)?.nilIfBlank
            guard let title else { return nil }
            let resolvedID = playlistIdentifier(from: identifier) ?? title
            let nested = (payload["playlist"] as? [String: Any]) ?? payload
            let description = (nested["annotation"] as? String)?.nilIfBlank
                ?? (nested["description"] as? String)?.nilIfBlank
            let creator = (nested["creator"] as? String)?.nilIfBlank
            let nestedExtension = (nested["extension"] as? [String: Any]) ?? [:]
            let rootExtension = (payload["extension"] as? [String: Any]) ?? [:]
            let nestedMBExtension = (nestedExtension["https://musicbrainz.org/doc/jspf#playlist"] as? [String: Any]) ?? [:]
            let rootMBExtension = (rootExtension["https://musicbrainz.org/doc/jspf#playlist"] as? [String: Any]) ?? [:]
            let trackCount = (nested["track"] as? [[String: Any]])?.count
                ?? (nestedMBExtension["track_count"] as? Int)
                ?? (rootMBExtension["track_count"] as? Int)
                ?? (nestedExtension["track_count"] as? Int)
                ?? (rootExtension["track_count"] as? Int)
            let isPublic = (nestedMBExtension["public"] as? Bool)
                ?? (rootMBExtension["public"] as? Bool)
                ?? (nestedExtension["public"] as? Bool)
                ?? (rootExtension["public"] as? Bool)

            return ListenBrainzPlaylistSummary(
                id: resolvedID,
                title: title,
                description: description,
                creator: creator,
                trackCount: trackCount,
                isPublic: isPublic
            )
        }
    }

    private func playlistIdentifier(from raw: String?) -> String? {
        guard let raw = raw?.nilIfBlank else { return nil }
        if let url = URL(string: raw) {
            return url.lastPathComponent.nilIfBlank ?? raw
        }
        return raw
    }

    private func getStats<T: Decodable>(
        username: String,
        endpoint: String,
        range: ListenBrainzStatsRange,
        count: Int
    ) async throws -> T {
        var components = URLComponents(
            url: settings.baseURL
                .appendingPathComponent("1/stats/user")
                .appendingPathComponent(username)
                .appendingPathComponent(endpoint),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "range", value: range.rawValue),
            URLQueryItem(name: "count", value: "\(count)")
        ]
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        return try await getJSON(url: url, allowNoContent: true)
    }

    private func fetchSimilarity(sourceUsername: String, targetUsername: String) async throws -> Double {
        let response: ListenBrainzSimilarityResponse = try await get(
            pathComponents: ["1", "user", sourceUsername, "similar-to", targetUsername],
            allowNoContent: true
        )
        return response.payload?.normalizedSimilarity ?? 0
    }

    private func sharedArtistKey(name: String, mbid: String?) -> String {
        if let mbid = mbid?.nilIfBlank {
            return mbid.lowercased()
        }
        return name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func pathURL(_ pathComponents: [String]) -> URL {
        pathComponents.reduce(settings.baseURL) { partial, component in
            partial.appendingPathComponent(component)
        }
    }

    private func get<T: Decodable>(
        pathComponents: [String],
        queryItems: [URLQueryItem] = [],
        allowNoContent: Bool
    ) async throws -> T {
        var components = URLComponents(url: pathURL(pathComponents), resolvingAgainstBaseURL: false)
        components?.queryItems = queryItems.isEmpty ? nil : queryItems
        guard let url = components?.url else { throw ListenBrainzError.invalidResponse }
        return try await getJSON(url: url, allowNoContent: allowNoContent)
    }

    private func getJSON<T: Decodable>(url: URL, allowNoContent: Bool) async throws -> T {
        var request = URLRequest(url: url)
        if let token {
            request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
        }
        let data = try await send(request, allowNoContent: allowNoContent)
        if allowNoContent, data.isEmpty {
            return try JSONDecoder().decode(T.self, from: Data("{}".utf8))
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func send(_ request: URLRequest, allowNoContent: Bool, maxRetries: Int = 2) async throws -> Data {
        var attempt = 0

        while true {
            do {
                let (data, response) = try await urlSession.data(for: request)
                if allowNoContent, let http = response as? HTTPURLResponse, http.statusCode == 204 {
                    return Data()
                }
                try validateHTTP(response: response, data: data)
                return data
            } catch {
                let mapped = mapTransportError(error)
                let delay = retryDelay(for: mapped, attempt: attempt)
                guard let delay, attempt < maxRetries else {
                    throw mapped
                }
                attempt += 1
                await sleep(UInt64(delay * 1_000_000_000))
            }
        }
    }

    private func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        switch error {
        case let ListenBrainzError.rateLimited(retryAfter):
            return retryAfter ?? exponentialBackoffDelay(for: attempt)
        case let ListenBrainzError.api(message):
            return message.contains("HTTP 5") ? exponentialBackoffDelay(for: attempt) : nil
        default:
            return nil
        }
    }

    private func exponentialBackoffDelay(for attempt: Int) -> TimeInterval {
        [0.35, 0.8, 1.6][min(attempt, 2)]
    }

    private func mapTransportError(_ error: Error) -> Error {
        if let listenBrainzError = error as? ListenBrainzError {
            return listenBrainzError
        }
        if let urlError = error as? URLError {
            return ListenBrainzError.transport(message: urlError.localizedDescription)
        }
        return error
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ListenBrainzError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            if http.statusCode == 429 {
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw ListenBrainzError.rateLimited(retryAfter: retryAfter)
            }
            if let decoded = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               let message = decoded.error ?? decoded.message {
                throw ListenBrainzError.api(message: message)
            }
            if http.statusCode == 401 {
                throw ListenBrainzError.invalidToken
            }
            throw ListenBrainzError.api(message: "ListenBrainz returned HTTP \(http.statusCode).")
        }
    }
}

private struct ValidateTokenResponse: Decodable {
    let code: Int?
    let message: String?
    let valid: Bool
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case code
        case message
        case valid
        case userName = "user_name"
    }
}

private struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}

private struct ListenBrainzListenCountResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let count: Int?
    }
}

private struct ListenBrainzListeningActivityResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let listeningActivity: [Entry]

        enum CodingKeys: String, CodingKey {
            case listeningActivity = "listening_activity"
        }
    }

    struct Entry: Decodable {
        let fromTS: Int
        let listenCount: Int
        let timeRange: String
        let toTS: Int

        enum CodingKeys: String, CodingKey {
            case fromTS = "from_ts"
            case listenCount = "listen_count"
            case timeRange = "time_range"
            case toTS = "to_ts"
        }
    }
}

private struct ListenBrainzListensResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let listens: [Listen]
    }

    struct Listen: Decodable {
        let listenedAt: Int?
        let trackMetadata: ListenBrainzTrackMetadataResponse

        enum CodingKeys: String, CodingKey {
            case listenedAt = "listened_at"
            case trackMetadata = "track_metadata"
        }
    }
}

private struct ListenBrainzSocialUsersResponse: Decodable {
    let user: String?
    let followers: [String]?
    let following: [String]?
}

private struct ListenBrainzSimilarUsersResponse: Decodable {
    let payload: [Entry]

    struct Entry: Decodable {
        let userName: String
        let similarity: Double

        enum CodingKeys: String, CodingKey {
            case userName = "user_name"
            case similarity
        }

        var normalizedSimilarity: Double {
            similarity > 1 ? (similarity / 100) : similarity
        }
    }
}

private struct ListenBrainzSimilarityResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let userName: String
        let similarity: Double

        enum CodingKeys: String, CodingKey {
            case userName = "user_name"
            case similarity
        }

        var normalizedSimilarity: Double {
            similarity > 1 ? (similarity / 100) : similarity
        }
    }
}

private struct ListenBrainzArtistMapResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let artistMap: [Entry]

        enum CodingKeys: String, CodingKey {
            case artistMap = "artist_map"
        }
    }

    struct Entry: Decodable {
        let country: String
        let artistCount: Int

        enum CodingKeys: String, CodingKey {
            case country
            case artistCount = "artist_count"
        }
    }
}

private struct ListenBrainzRecommendationsResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let mbids: [Recommendation]
    }

    struct Recommendation: Decodable {
        let recordingMbid: String
        let score: Double

        enum CodingKeys: String, CodingKey {
            case recordingMbid = "recording_mbid"
            case score
        }
    }
}

private struct ListenBrainzRecordingPopularityRequest: Encodable {
    let recordingMBIDs: [String]

    enum CodingKeys: String, CodingKey {
        case recordingMBIDs = "recording_mbids"
    }
}

private struct ListenBrainzArtistPopularityRequest: Encodable {
    let artistMBIDs: [String]

    enum CodingKeys: String, CodingKey {
        case artistMBIDs = "artist_mbids"
    }
}

private struct ListenBrainzReleasePopularityRequest: Encodable {
    let releaseMBIDs: [String]

    enum CodingKeys: String, CodingKey {
        case releaseMBIDs = "release_mbids"
    }
}

private struct ListenBrainzRecordingPopularityResponse: Decodable {
    let recordingMbid: String
    let totalListenCount: Int?
    let totalUserCount: Int?

    enum CodingKeys: String, CodingKey {
        case recordingMbid = "recording_mbid"
        case totalListenCount = "total_listen_count"
        case totalUserCount = "total_user_count"
    }
}

private struct ListenBrainzArtistPopularityResponse: Decodable {
    let artistMbid: String
    let totalListenCount: Int?
    let totalUserCount: Int?

    enum CodingKeys: String, CodingKey {
        case artistMbid = "artist_mbid"
        case totalListenCount = "total_listen_count"
        case totalUserCount = "total_user_count"
    }
}

private struct ListenBrainzReleasePopularityResponse: Decodable {
    let releaseMbid: String
    let totalListenCount: Int?
    let totalUserCount: Int?

    enum CodingKeys: String, CodingKey {
        case releaseMbid = "release_mbid"
        case totalListenCount = "total_listen_count"
        case totalUserCount = "total_user_count"
    }
}

private struct ListenBrainzPopularRecordingResponse: Decodable {
    let artistName: String
    let caaReleaseMbid: String?
    let recordingMbid: String
    let recordingName: String
    let releaseMbid: String?
    let releaseName: String?
    let totalListenCount: Int?
    let totalUserCount: Int?

    enum CodingKeys: String, CodingKey {
        case artistName = "artist_name"
        case caaReleaseMbid = "caa_release_mbid"
        case recordingMbid = "recording_mbid"
        case recordingName = "recording_name"
        case releaseMbid = "release_mbid"
        case releaseName = "release_name"
        case totalListenCount = "total_listen_count"
        case totalUserCount = "total_user_count"
    }
}

private struct ListenBrainzArtistMetadataResponse: Decodable {
    let area: String?
    let artistMbid: String
    let beginYear: Int?
    let mbid: String
    let name: String
    let rels: [String: String]?
    let tag: Tags?
    let type: String?

    struct Tags: Decodable {
        let artist: [ArtistTag]
    }

    struct ArtistTag: Decodable {
        let count: Int
        let genreMbid: String?
        let tag: String

        enum CodingKeys: String, CodingKey {
            case count
            case genreMbid = "genre_mbid"
            case tag
        }
    }

    enum CodingKeys: String, CodingKey {
        case area
        case artistMbid = "artist_mbid"
        case beginYear = "begin_year"
        case mbid
        case name
        case rels
        case tag
        case type
    }
}

private struct ListenBrainzCurrentPinResponse: Decodable {
    let pinnedRecording: ListenBrainzPinPayload?

    enum CodingKeys: String, CodingKey {
        case pinnedRecording = "pinned_recording"
    }
}

private struct ListenBrainzPinsResponse: Decodable {
    let pinnedRecordings: [ListenBrainzPinPayload]

    enum CodingKeys: String, CodingKey {
        case pinnedRecordings = "pinned_recordings"
    }
}

private struct ListenBrainzPinPayload: Decodable {
    let blurbContent: String?
    let created: Int?
    let rowID: Int
    let pinnedUntil: Int?
    let recordingMbid: String?
    let recordingMsid: String?
    let trackMetadata: ListenBrainzTrackMetadataResponse?
    let userName: String?

    enum CodingKeys: String, CodingKey {
        case blurbContent = "blurb_content"
        case created
        case rowID = "row_id"
        case pinnedUntil = "pinned_until"
        case recordingMbid = "recording_mbid"
        case recordingMsid = "recording_msid"
        case trackMetadata = "track_metadata"
        case userName = "user_name"
    }

    func asPinnedRecording() -> ListenBrainzPinnedRecording {
        ListenBrainzPinnedRecording(
            id: rowID,
            recordingMbid: recordingMbid?.nilIfBlank,
            recordingMsid: recordingMsid?.nilIfBlank,
            trackName: trackMetadata?.trackName ?? "Unknown track",
            artistName: trackMetadata?.artistName ?? "Unknown artist",
            blurb: blurbContent?.nilIfBlank,
            createdAt: created.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            pinnedUntil: pinnedUntil.map { Date(timeIntervalSince1970: TimeInterval($0)) },
            userName: userName?.nilIfBlank
        )
    }
}

private struct ListenBrainzRecordingMetadata {
    let recordingName: String?
    let artistCreditName: String?
    let releaseName: String?
}

private struct ListenBrainzArtistsStatsResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let artists: [Artist]
    }

    struct Artist: Decodable {
        let artistName: String
        let artistMbid: String?
        let listenCount: Int

        enum CodingKeys: String, CodingKey {
            case artistName = "artist_name"
            case artistMbid = "artist_mbid"
            case listenCount = "listen_count"
        }
    }
}

private struct ListenBrainzReleasesStatsResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let releases: [Release]
    }

    struct Release: Decodable {
        let artistName: String
        let releaseName: String
        let releaseMbid: String?
        let listenCount: Int

        enum CodingKeys: String, CodingKey {
            case artistName = "artist_name"
            case releaseName = "release_name"
            case releaseMbid = "release_mbid"
            case listenCount = "listen_count"
        }
    }
}

private struct ListenBrainzRecordingsStatsResponse: Decodable {
    let payload: Payload?

    struct Payload: Decodable {
        let recordings: [Recording]
    }

    struct Recording: Decodable {
        let artistName: String
        let trackName: String
        let releaseName: String?
        let recordingMbid: String?
        let listenCount: Int

        enum CodingKeys: String, CodingKey {
            case artistName = "artist_name"
            case trackName = "track_name"
            case releaseName = "release_name"
            case recordingMbid = "recording_mbid"
            case listenCount = "listen_count"
        }
    }
}

private struct ListenBrainzTrackMetadataResponse: Decodable {
    let artistName: String
    let trackName: String
    let releaseName: String?
    let additionalInfo: ListenBrainzAdditionalInfoResponse?

    enum CodingKeys: String, CodingKey {
        case artistName = "artist_name"
        case trackName = "track_name"
        case releaseName = "release_name"
        case additionalInfo = "additional_info"
    }
}

private struct ListenBrainzAdditionalInfoResponse: Decodable {
    let recordingMBID: String?
    let recordingMSID: String?
    let releaseMBID: String?
    let artistMBIDs: [String]?

    enum CodingKeys: String, CodingKey {
        case recordingMBID = "recording_mbid"
        case recordingMSID = "recording_msid"
        case releaseMBID = "release_mbid"
        case artistMBIDs = "artist_mbids"
    }
}

private struct ListenBrainzSubmitRequest: Encodable {
    let listenType: String
    let payload: [ListenBrainzListenPayload]

    enum CodingKeys: String, CodingKey {
        case listenType = "listen_type"
        case payload
    }
}

private struct ListenBrainzListenPayload: Encodable {
    let listenedAt: Int?
    let trackMetadata: ListenBrainzTrackMetadata

    enum CodingKeys: String, CodingKey {
        case listenedAt = "listened_at"
        case trackMetadata = "track_metadata"
    }
}

private struct ListenBrainzTrackMetadata: Encodable {
    let artistName: String
    let trackName: String
    let releaseName: String?
    let additionalInfo: ListenBrainzAdditionalInfo

    enum CodingKeys: String, CodingKey {
        case artistName = "artist_name"
        case trackName = "track_name"
        case releaseName = "release_name"
        case additionalInfo = "additional_info"
    }
}

private struct ListenBrainzAdditionalInfo: Encodable {
    let mediaPlayer: String?
    let submissionClient: String
    let submissionClientVersion: String

    enum CodingKeys: String, CodingKey {
        case mediaPlayer = "media_player"
        case submissionClient = "submission_client"
        case submissionClientVersion = "submission_client_version"
    }
}

private struct EmptyRequestBody: Encodable {}

private struct ListenBrainzRecordingMetadataRequest: Encodable {
    let recordingMBIDs: [String]
    let inc: String

    enum CodingKeys: String, CodingKey {
        case recordingMBIDs = "recording_mbids"
        case inc
    }
}

private struct ListenBrainzPersonalRecommendationRequest: Encodable {
    let metadata: Metadata

    struct Metadata: Encodable {
        let recordingMbid: String
        let users: [String]
        let blurbContent: String?

        enum CodingKeys: String, CodingKey {
            case recordingMbid = "recording_mbid"
            case users
            case blurbContent = "blurb_content"
        }
    }
}

private struct ListenBrainzPinRequest: Encodable {
    let recordingMsid: String?
    let recordingMbid: String?
    let blurbContent: String?
    let pinnedUntil: Int?

    enum CodingKeys: String, CodingKey {
        case recordingMsid = "recording_msid"
        case recordingMbid = "recording_mbid"
        case blurbContent = "blurb_content"
        case pinnedUntil = "pinned_until"
    }
}

private struct ListenBrainzPlaylistCreateRequest: Encodable {
    let playlist: Playlist

    struct Playlist: Encodable {
        let title: String
        let track: [ListenBrainzPlaylistTrack]
    }
}

private struct ListenBrainzPlaylistTrack: Encodable {
    let identifier: String
}

private extension String {
    var trimmedUsername: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
