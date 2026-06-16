import XCTest
@testable import ListenScrobbler

@MainActor
final class MobileListeningStoreTests: XCTestCase {
    func testConnectStoresResolvedUsernameAndRefreshesListens() async {
        let settingsStore = makeSettingsStore()
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.validation = ListenBrainzValidation(isValid: true, username: "open-user", message: "ok")
        client.recentListens = [
            ListenBrainzListen(
                id: "listen-1",
                trackName: "Sketch for Summer",
                artistName: "The Durutti Column",
                releaseName: "The Return of the Durutti Column",
                listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                recordingMBID: nil,
                recordingMSID: "msid-1",
                artistMBID: nil,
                releaseMBID: nil,
                imageURL: nil
            )
        ]
        client.currentPin = ListenBrainzPinnedRecording(
            id: 42,
            recordingMbid: nil,
            recordingMsid: "pin-msid",
            trackName: "Otis",
            artistName: "Durutti",
            blurb: "Pinned from ListenBrainz",
            createdAt: nil,
            pinnedUntil: nil,
            userName: "open-user"
        )
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.connect(token: " token ", baseURL: URL(string: "https://lb.example")!)

        XCTAssertEqual(store.connectionState, .connected(username: "open-user"))
        XCTAssertEqual(settingsStore.load().username, "open-user")
        XCTAssertTrue(store.hasStoredToken)
        XCTAssertEqual(store.recentListens.map(\.trackName), ["Sketch for Summer"])
        XCTAssertEqual(store.recentListens.first?.recordingMSID, "msid-1")
        XCTAssertEqual(store.currentPin?.trackName, "Otis")
        XCTAssertEqual(client.updatedTokens, ["token", "token"])
        XCTAssertEqual(client.recentListenRefreshUsernames, ["open-user"])
        XCTAssertEqual(client.pinRefreshUsernames, ["open-user"])
    }

    func testDeleteListenPostsToListenBrainzAndRemovesRecentListen() async {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let listenedAt = Date(timeIntervalSince1970: 1_781_635_646)
        client.recentListens = [
            ListenBrainzListen(
                id: "listen-1",
                trackName: "Come Home",
                artistName: "Croatian Amor & Varg²™",
                releaseName: nil,
                listenedAt: listenedAt,
                recordingMBID: "recording-1",
                recordingMSID: "msid-come-home",
                artistMBID: nil,
                releaseMBID: nil,
                imageURL: nil
            )
        ]
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.refresh()
        let listen = try! XCTUnwrap(store.recentListens.first)
        let didDelete = await store.deleteListen(listen)

        XCTAssertTrue(didDelete)
        XCTAssertTrue(store.recentListens.isEmpty)
        XCTAssertEqual(client.deletedListens.first?.listenedAt, listenedAt)
        XCTAssertEqual(client.deletedListens.first?.recordingMsid, "msid-come-home")
    }

    func testRefreshStatsPublishesMobileStatsSummary() async {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.statsSnapshot = ListenBrainzStatsSnapshot(
            username: "open-user",
            range: .month,
            totalListenCount: 1234,
            listeningActivity: [],
            topArtists: [
                ListenBrainzArtistStat(id: "artist-1", name: "Stereolab", listenCount: 42, mbid: nil)
            ],
            topReleases: [
                ListenBrainzReleaseStat(id: "release-1", name: "Dots and Loops", artistName: "Stereolab", listenCount: 21, mbid: nil)
            ],
            topRecordings: [
                ListenBrainzRecordingStat(
                    id: "recording-1",
                    trackName: "French Disko",
                    artistName: "Stereolab",
                    releaseName: "Jenny Ondioline",
                    listenCount: 9,
                    mbid: nil
                )
            ],
            recentListens: [],
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.refreshStats(range: .month)

        XCTAssertEqual(store.statsSnapshot?.username, "open-user")
        XCTAssertEqual(store.statsSnapshot?.range, .month)
        XCTAssertEqual(store.statsSnapshot?.totalListenCount, 1234)
        XCTAssertEqual(store.statsSnapshot?.topArtists.map(\.name), ["Stereolab"])
        XCTAssertEqual(store.statsSnapshot?.topReleases.map(\.name), ["Dots and Loops"])
        XCTAssertEqual(store.statsSnapshot?.topRecordings.map(\.trackName), ["French Disko"])
        XCTAssertEqual(store.statsStatus, "Loaded month stats")
        XCTAssertEqual(client.statsRefreshes.map(\.username), ["open-user"])
        XCTAssertEqual(client.statsRefreshes.map(\.range), [.month])
    }

    func testRefreshRecommendationsPublishesMobileRecommendations() async {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.recommendations = [
            ListenBrainzRecommendedRecording(
                id: "rec-1",
                recordingMbid: "mbid-1",
                title: "Pack Yr Romantic Mind",
                artistName: "Stereolab",
                releaseName: "Transient Random-Noise Bursts",
                score: 0.98
            )
        ]
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.refreshRecommendations()

        XCTAssertEqual(store.recommendedRecordings.map(\.title), ["Pack Yr Romantic Mind"])
        XCTAssertEqual(store.recommendedRecordings.map(\.recordingMBID), ["mbid-1"])
        XCTAssertEqual(store.recommendationsStatus, "Loaded 1 recommendations")
        XCTAssertEqual(client.recommendationRefreshes.map(\.username), ["open-user"])
        XCTAssertEqual(client.recommendationRefreshes.map(\.count), [12])
        XCTAssertEqual(client.recommendationRefreshes.map(\.offset), [0])
    }

    func testWidgetSnapshotCapturesConnectionListenPinAndRecommendation() async {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.recentListens = [
            ListenBrainzListen(
                id: "listen-1",
                trackName: "Sketch for Summer",
                artistName: "The Durutti Column",
                releaseName: "The Return of the Durutti Column",
                listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                recordingMBID: nil,
                recordingMSID: nil,
                artistMBID: nil,
                releaseMBID: nil,
                imageURL: nil
            )
        ]
        client.currentPin = ListenBrainzPinnedRecording(
            id: 42,
            recordingMbid: nil,
            recordingMsid: nil,
            trackName: "Otis",
            artistName: "Durutti",
            blurb: "Pinned from ListenBrainz",
            createdAt: nil,
            pinnedUntil: nil,
            userName: "open-user"
        )
        client.recommendations = [
            ListenBrainzRecommendedRecording(
                id: "rec-1",
                recordingMbid: "mbid-1",
                title: "Pack Yr Romantic Mind",
                artistName: "Stereolab",
                releaseName: "Transient Random-Noise Bursts",
                score: 0.98
            )
        ]
        let snapshotDefaults = UserDefaults(suiteName: "ListenScrobblerTests-Widget-\(UUID().uuidString)")!
        let snapshotStore = MobileWidgetSnapshotStore(defaults: snapshotDefaults)
        let store = MobileListeningStore(
            settingsStore: settingsStore,
            listenBrainz: client,
            widgetSnapshotStore: snapshotStore
        )

        await store.refresh()
        await store.refreshRecommendations()

        let snapshot = store.widgetSnapshot(updatedAt: Date(timeIntervalSince1970: 1_700_000_111))
        XCTAssertEqual(snapshot.username, "open-user")
        XCTAssertEqual(snapshot.connectionStatus, "open-user on ListenBrainz")
        XCTAssertEqual(snapshot.recentListen?.trackName, "Sketch for Summer")
        XCTAssertEqual(snapshot.currentPin?.trackName, "Otis")
        XCTAssertEqual(snapshot.recommendation?.title, "Pack Yr Romantic Mind")

        let savedSnapshot = snapshotStore.load()
        XCTAssertEqual(savedSnapshot.recentListen?.trackName, "Sketch for Summer")
        XCTAssertEqual(savedSnapshot.currentPin?.artistName, "Durutti")
        XCTAssertEqual(savedSnapshot.recommendation?.artistName, "Stereolab")
    }

    func testRefreshSocialPublishesMobileSocialSnapshot() async {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.followers = ["zephyr", "alice"]
        client.following = ["bob", "alice"]
        client.similarUsers = [
            ListenBrainzSimilarUser(id: "carol", userName: "carol", similarityScore: 0.72)
        ]
        client.socialListens = [
            ListenBrainzSocialListen(
                id: "bob|listen-1",
                userName: "bob",
                listen: ListenBrainzListen(
                    id: "listen-1",
                    trackName: "Outdoor Miner",
                    artistName: "Wire",
                    releaseName: "Chairs Missing",
                    listenedAt: Date(timeIntervalSince1970: 1_700_000_100),
                    recordingMBID: nil,
                    recordingMSID: nil,
                    artistMBID: nil,
                    releaseMBID: nil,
                    imageURL: nil
                )
            )
        ]
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.refreshSocial()

        XCTAssertEqual(store.socialSnapshot?.followers, ["alice", "zephyr"])
        XCTAssertEqual(store.socialSnapshot?.following, ["alice", "bob"])
        XCTAssertEqual(store.socialSnapshot?.similarUsers.map(\.userName), ["carol"])
        XCTAssertEqual(store.socialSnapshot?.neighborListens.map(\.trackName), ["Outdoor Miner"])
        XCTAssertEqual(store.socialStatus, "Loaded 2 followers, 2 following, and 1 neighbor listens")
        XCTAssertEqual(client.followerRefreshes, ["open-user"])
        XCTAssertEqual(client.followingRefreshes, ["open-user"])
        XCTAssertEqual(client.similarUserRefreshes.map(\.username), ["open-user"])
        XCTAssertEqual(client.similarUserRefreshes.map(\.count), [8])
        XCTAssertEqual(client.socialListenRefreshes.first?.usernames, ["alice", "bob", "zephyr", "carol"])
        XCTAssertEqual(client.socialListenRefreshes.first?.countPerUser, 2)
    }

    func testConnectWithInvalidTokenShowsValidationMessage() async {
        let settingsStore = makeSettingsStore()
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        client.validation = ListenBrainzValidation(isValid: false, username: nil, message: "Invalid token")
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        await store.connect(token: "bad-token", baseURL: URL(string: "https://lb.example")!)

        XCTAssertEqual(store.connectionState, .failed("Invalid token"))
        XCTAssertTrue(store.recentListens.isEmpty)
        XCTAssertNil(store.currentPin)
    }

    func testSubmitScrobbleBuildsListenBrainzTrackFromCandidate() async throws {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)
        let listenedAt = Date(timeIntervalSince1970: 1_700_000_000)

        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: "Future Days",
                artist: "Can",
                album: "Future Days",
                duration: 360,
                listenedAt: listenedAt,
                source: "ListenScrobbler iOS Manual"
            )
        )

        let submitted = try XCTUnwrap(client.submittedTracks.first)
        XCTAssertEqual(submitted.title, "Future Days")
        XCTAssertEqual(submitted.artist, "Can")
        XCTAssertEqual(submitted.album, "Future Days")
        XCTAssertEqual(submitted.duration, 360)
        XCTAssertEqual(submitted.sourceApp, "ListenScrobbler iOS Manual")
        XCTAssertEqual(submitted.startedAt, listenedAt.addingTimeInterval(-240))
    }

    func testSubmitScrobblePreservesSourceMetadata() async throws {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: "Inssegh Inssegh",
                artist: "Les Filles de Illighadad",
                album: "Eghass Malan",
                duration: 320,
                listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                source: "Spotify Import",
                sourceMetadata: MobileScrobbleSourceMetadata(
                    mediaPlayer: "Spotify",
                    musicService: "spotify.com",
                    musicServiceName: "Spotify",
                    originURL: "https://open.spotify.com/track/5fEjp2F0Sqr9fMuLSaDqz0",
                    spotifyID: "https://open.spotify.com/track/5fEjp2F0Sqr9fMuLSaDqz0",
                    durationPlayed: 300,
                    originalSubmissionClient: "Spotify Recently Played"
                )
            )
        )

        let metadata = try XCTUnwrap(client.submittedTracks.first?.sourceMetadata)
        XCTAssertEqual(metadata.mediaPlayer, "Spotify")
        XCTAssertEqual(metadata.musicService, "spotify.com")
        XCTAssertEqual(metadata.musicServiceName, "Spotify")
        XCTAssertEqual(metadata.originURL, "https://open.spotify.com/track/5fEjp2F0Sqr9fMuLSaDqz0")
        XCTAssertEqual(metadata.spotifyID, "https://open.spotify.com/track/5fEjp2F0Sqr9fMuLSaDqz0")
        XCTAssertEqual(metadata.durationPlayed, 300)
        XCTAssertEqual(metadata.originalSubmissionClient, "Spotify Recently Played")
    }

    func testSubmitScrobblePreservesAppleMusicSourceMetadata() async throws {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: "Future Days",
                artist: "Can",
                album: "Future Days",
                duration: 360,
                listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                source: "Apple Music Import",
                sourceMetadata: MobileScrobbleSourceMetadata(
                    mediaPlayer: "Apple Music",
                    musicService: "music.apple.com",
                    musicServiceName: "Apple Music",
                    originURL: "https://music.apple.com/us/album/future-days/1440844939?i=1440844944",
                    durationPlayed: 240,
                    originalSubmissionClient: "MusicKit Import"
                )
            )
        )

        let metadata = try XCTUnwrap(client.submittedTracks.first?.sourceMetadata)
        XCTAssertEqual(metadata.mediaPlayer, "Apple Music")
        XCTAssertEqual(metadata.musicService, "music.apple.com")
        XCTAssertEqual(metadata.musicServiceName, "Apple Music")
        XCTAssertEqual(metadata.originURL, "https://music.apple.com/us/album/future-days/1440844939?i=1440844944")
        XCTAssertNil(metadata.spotifyID)
        XCTAssertEqual(metadata.durationPlayed, 240)
        XCTAssertEqual(metadata.originalSubmissionClient, "MusicKit Import")
    }

    func testSubmitScrobblePreservesYouTubeMusicSourceMetadata() async throws {
        let settingsStore = makeSettingsStore(username: "open-user", token: "token")
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: "Sweet",
                artist: "Little Dragon",
                album: "Season High",
                duration: 226,
                listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                source: "YouTube Music Import",
                sourceMetadata: MobileScrobbleSourceMetadata(
                    mediaPlayer: "YouTube Music",
                    musicService: "music.youtube.com",
                    musicServiceName: "YouTube Music",
                    originURL: "https://music.youtube.com/watch?v=qQ0zxuWFxrY",
                    durationPlayed: 210,
                    originalSubmissionClient: "YouTube Music Export Import"
                )
            )
        )

        let metadata = try XCTUnwrap(client.submittedTracks.first?.sourceMetadata)
        XCTAssertEqual(metadata.mediaPlayer, "YouTube Music")
        XCTAssertEqual(metadata.musicService, "music.youtube.com")
        XCTAssertEqual(metadata.musicServiceName, "YouTube Music")
        XCTAssertEqual(metadata.originURL, "https://music.youtube.com/watch?v=qQ0zxuWFxrY")
        XCTAssertNil(metadata.spotifyID)
        XCTAssertEqual(metadata.durationPlayed, 210)
        XCTAssertEqual(metadata.originalSubmissionClient, "YouTube Music Export Import")
    }

    func testSubmitScrobbleRejectsDisconnectedStore() async {
        let settingsStore = makeSettingsStore()
        let client = FakeMobileListenBrainzClient(settingsStore: settingsStore)
        let store = MobileListeningStore(settingsStore: settingsStore, listenBrainz: client)

        do {
            try await store.submitScrobble(
                MobileScrobbleCandidate(
                    title: "Track",
                    artist: "Artist",
                    album: nil,
                    duration: 180,
                    listenedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    source: "Test"
                )
            )
            XCTFail("Expected disconnected submit to throw")
        } catch {
            XCTAssertEqual(error as? MobileListeningError, .listenBrainzDisconnected)
        }
        XCTAssertTrue(client.submittedTracks.isEmpty)
    }

    private func makeSettingsStore(username: String? = nil, token: String? = nil) -> ListenBrainzSettingsStore {
        let defaults = UserDefaults(suiteName: "ListenScrobblerTests-MobileListening-\(UUID().uuidString)")!
        let tokenStore = MobileListeningTestTokenStore(token: token)
        let store = ListenBrainzSettingsStore(defaults: defaults, tokenStore: tokenStore)
        store.save(
            ListenBrainzSettings(
                isEnabled: username != nil,
                submitNowPlaying: true,
                submitListens: true,
                baseURL: URL(string: "https://lb.example")!,
                username: username
            )
        )
        return store
    }
}

private final class FakeMobileListenBrainzClient: MobileListenBrainzClient {
    private let settingsStore: ListenBrainzSettingsStore

    var validation = ListenBrainzValidation(isValid: true, username: "tester", message: "ok")
    var recentListens: [ListenBrainzListen] = []
    var currentPin: ListenBrainzPinnedRecording?
    var submittedTracks: [Track] = []
    var updatedSettings: [ListenBrainzSettings] = []
    var updatedTokens: [String?] = []
    var statsSnapshot: ListenBrainzStatsSnapshot?
    var recommendations: [ListenBrainzRecommendedRecording] = []
    var followers: [String] = []
    var following: [String] = []
    var similarUsers: [ListenBrainzSimilarUser] = []
    var socialListens: [ListenBrainzSocialListen] = []
    var recentListenRefreshUsernames: [String] = []
    var pinRefreshUsernames: [String] = []
    var statsRefreshes: [(username: String, range: ListenBrainzStatsRange)] = []
    var recommendationRefreshes: [(username: String, count: Int, offset: Int)] = []
    var followerRefreshes: [String] = []
    var followingRefreshes: [String] = []
    var similarUserRefreshes: [(username: String, count: Int)] = []
    var socialListenRefreshes: [(usernames: [String], countPerUser: Int)] = []
    var deletedListens: [(listenedAt: Date, recordingMsid: String)] = []
    var didClear = false

    init(settingsStore: ListenBrainzSettingsStore) {
        self.settingsStore = settingsStore
    }

    func update(settings: ListenBrainzSettings, token: String?) throws {
        updatedSettings.append(settings)
        updatedTokens.append(token)
        settingsStore.save(settings)
        if let token {
            try settingsStore.saveToken(token)
        }
    }

    func clear() {
        didClear = true
        settingsStore.clearToken()
    }

    func validate() async throws -> ListenBrainzValidation {
        validation
    }

    func fetchRecentListens(username: String, count: Int) async throws -> [ListenBrainzListen] {
        recentListenRefreshUsernames.append(username)
        return Array(recentListens.prefix(count))
    }

    func fetchCurrentPin(username: String) async throws -> ListenBrainzPinnedRecording? {
        pinRefreshUsernames.append(username)
        return currentPin
    }

    func deleteListen(listenedAt: Date, recordingMsid: String) async throws {
        deletedListens.append((listenedAt: listenedAt, recordingMsid: recordingMsid))
    }

    func fetchStatsSnapshot(username: String, range: ListenBrainzStatsRange, count: Int) async throws -> ListenBrainzStatsSnapshot {
        statsRefreshes.append((username: username, range: range))
        if let statsSnapshot {
            return statsSnapshot
        }
        return ListenBrainzStatsSnapshot(
            username: username,
            range: range,
            totalListenCount: nil,
            listeningActivity: [],
            topArtists: [],
            topReleases: [],
            topRecordings: [],
            recentListens: [],
            fetchedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func fetchRecommendedRecordings(username: String, count: Int, offset: Int) async throws -> [ListenBrainzRecommendedRecording] {
        recommendationRefreshes.append((username: username, count: count, offset: offset))
        return recommendations
    }

    func fetchFollowers(username: String) async throws -> [String] {
        followerRefreshes.append(username)
        return followers
    }

    func fetchFollowing(username: String) async throws -> [String] {
        followingRefreshes.append(username)
        return following
    }

    func fetchSimilarUsers(username: String, count: Int) async throws -> [ListenBrainzSimilarUser] {
        similarUserRefreshes.append((username: username, count: count))
        return Array(similarUsers.prefix(count))
    }

    func fetchSocialListenActivity(usernames: [String], countPerUser: Int) async throws -> [ListenBrainzSocialListen] {
        socialListenRefreshes.append((usernames: usernames, countPerUser: countPerUser))
        return socialListens
    }

    func submitListen(_ track: Track) async throws {
        submittedTracks.append(track)
    }
}

private final class MobileListeningTestTokenStore: ListenBrainzTokenStoring {
    var token: String?

    init(token: String?) {
        self.token = token
    }

    func readToken() throws -> String? {
        token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func deleteToken() throws {
        token = nil
    }
}
