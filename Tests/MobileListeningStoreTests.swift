import XCTest
@testable import OpenScrobbler

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
        XCTAssertEqual(store.currentPin?.trackName, "Otis")
        XCTAssertEqual(client.updatedTokens, ["token", "token"])
        XCTAssertEqual(client.recentListenRefreshUsernames, ["open-user"])
        XCTAssertEqual(client.pinRefreshUsernames, ["open-user"])
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
                source: "OpenScrobbler iOS Manual"
            )
        )

        let submitted = try XCTUnwrap(client.submittedTracks.first)
        XCTAssertEqual(submitted.title, "Future Days")
        XCTAssertEqual(submitted.artist, "Can")
        XCTAssertEqual(submitted.album, "Future Days")
        XCTAssertEqual(submitted.duration, 360)
        XCTAssertEqual(submitted.sourceApp, "OpenScrobbler iOS Manual")
        XCTAssertEqual(submitted.startedAt, listenedAt.addingTimeInterval(-240))
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
        let defaults = UserDefaults(suiteName: "OpenScrobblerTests-MobileListening-\(UUID().uuidString)")!
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
    var recentListenRefreshUsernames: [String] = []
    var pinRefreshUsernames: [String] = []
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
