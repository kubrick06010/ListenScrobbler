import XCTest
@testable import OpenScrobbler

final class ScrobbleServiceTests: XCTestCase {
    @MainActor
    func testManualQueueAvoidsDuplicates() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        service.queueCurrentTrack()
        service.queueCurrentTrack()

        XCTAssertEqual(service.queuedScrobbles.count, 1)
    }

    @MainActor
    func testShortTrackIsRejectedByRules() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 10)))
        await Task.yield()
        service.queueCurrentTrack()

        XCTAssertTrue(service.queuedScrobbles.isEmpty)
    }

    @MainActor
    func testSubmitQueuedRemovesOnSuccess() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        service.queueCurrentTrack()
        await service.submitQueued()

        XCTAssertTrue(service.queuedScrobbles.isEmpty)
        XCTAssertEqual(api.scrobbledTracks.count, 1)
    }

    @MainActor
    func testNowPlayingWaitsForResumeAfterPause() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        let sleepLatch = SleepLatch()
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore(),
            retryJitter: { 1.0 },
            sleepFunction: { _ in await sleepLatch.wait() }
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        monitor.emit(.paused)
        await Task.yield()

        await sleepLatch.release(1)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(api.nowPlayingTracks.count, 0)

        monitor.emit(.resumed)
        await Task.yield()
        await sleepLatch.release(1)
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(api.nowPlayingTracks.count, 1)
        withExtendedLifetime(service) {}
    }

    @MainActor
    func testFailedSubmitSchedulesRetryAndBackoff() async {
        let api = MockAPI(scrobbleFailuresRemaining: 1)
        let monitor = TestMonitor()
        let sleepLatch = SleepLatch()
        let queueStore = InMemoryQueueStore(
            initialTracks: [makeTrack(duration: 180)]
        )

        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: queueStore,
            retryJitter: { 1.0 },
            sleepFunction: { _ in await sleepLatch.wait() }
        )

        XCTAssertTrue(service.isRetryScheduled)
        XCTAssertEqual(service.retryDelaySeconds, 4)

        await service.submitQueued()

        XCTAssertEqual(api.scrobbleAttempts, 1)
        XCTAssertEqual(service.queuedScrobbles.count, 1)
        XCTAssertTrue(service.isRetryScheduled)
        XCTAssertEqual(service.retryDelaySeconds, 8)
        XCTAssertNotNil(service.lastAPIError)
        XCTAssertNotNil(service.lastRecoveryHint)
    }

    @MainActor
    func testRetryableCompatibilityFailureDoesNotBlockListenBrainzSubmission() async throws {
        let api = MockAPI(scrobbleFailuresRemaining: 1)
        let monitor = TestMonitor()
        let urlSession = makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            return (response, Data(#"{"status":"ok"}"#.utf8))
        }
        let listenBrainz = configuredListenBrainzService(urlSession: urlSession)
        let service = ScrobbleService(
            api: api,
            listenBrainz: listenBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        await Task.yield()
        service.queueCurrentTrack()
        await service.submitQueued()

        XCTAssertEqual(api.scrobbleAttempts, 1)
        XCTAssertEqual(MockURLProtocol.requests.filter { $0.url?.path == "/1/submit-listens" }.count, 1)
        XCTAssertEqual(service.queuedSubmissionJobs.count, 1)
        XCTAssertEqual(service.queuedSubmissionJobs.first?.backend, .compatibility)
        XCTAssertEqual(service.listenBrainzStatus, "Submitted listen")
        XCTAssertTrue(service.isRetryScheduled)
    }

    @MainActor
    func testCurrentTrackDetailsLoadFromConfiguredAPIWhenSignedOut() async {
        let api = MockAPI()
        api.isAuthenticated = false
        let monitor = TestMonitor()
        let musicBrainz = MusicBrainzService(urlSession: makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(#"{"recordings":[]}"#.utf8))
            case "/ws/2/artist":
                return (response, Data(#"{"artists":[]}"#.utf8))
            case "/ws/2/release":
                return (response, Data(#"{"releases":[]}"#.utf8))
            default:
                return (response, Data(#"{"images":[]}"#.utf8))
            }
        })
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            musicBrainz: musicBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(duration: 180)))
        try? await Task.sleep(nanoseconds: 40_000_000)

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.currentTrackDetails?.name, "Track")
        XCTAssertEqual(service.currentArtistDetails?.name, "Artist")
        XCTAssertEqual(service.currentOpenEntityDetails?.artistName, "Artist")
        XCTAssertEqual(api.trackDetailRequests.count, 1)
        XCTAssertEqual(api.artistDetailRequests.count, 1)
        withExtendedLifetime(service) {}
    }

    @MainActor
    func testRecentListensLoadFromListenBrainzWhenCompatibilitySignedOut() async throws {
        let api = MockAPI()
        api.isAuthenticated = false
        let monitor = TestMonitor()
        let listenBrainz = configuredListenBrainzService(urlSession: makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            XCTAssertEqual(request.url?.path, "/1/user/tester/listens")
            return (response, Data(#"{"payload":{"listens":[{"listened_at":1700000100,"track_metadata":{"artist_name":"Soda Stereo","track_name":"Zoom","release_name":"Sueño Stereo","additional_info":{"recording_mbid":"recording-1","artist_mbids":["artist-1"],"release_mbid":"release-1"}}}]}}"#.utf8))
        })
        let service = ScrobbleService(
            api: api,
            listenBrainz: listenBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        await service.refreshScrobbles()

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.scrobblesStatus, "Loaded ListenBrainz listens")
        XCTAssertEqual(service.latestScrobbles.count, 1)
        XCTAssertEqual(service.latestScrobbles.first?.track, "Zoom")
        XCTAssertEqual(service.latestScrobbles.first?.artist, "Soda Stereo")
        XCTAssertEqual(service.latestScrobbles.first?.album, "Sueño Stereo")
        XCTAssertEqual(service.latestScrobbles.first?.url, "https://listenbrainz.org/player/?recording_mbids=recording-1")
        withExtendedLifetime(service) {}
    }

    @MainActor
    func testPinningANewListenBrainzTrackUnpinsThePreviousCurrentPinFirst() async {
        // Given ListenBrainz already has Julia Holter as the current pin.
        let api = MockAPI()
        let monitor = TestMonitor()
        var currentPinFetchCount = 0
        let listenBrainz = configuredListenBrainzService(urlSession: makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/1/tester/pins/current"):
                currentPinFetchCount += 1
                if currentPinFetchCount == 1 {
                    return (response, Data(#"{"pinned_recording":{"row_id":10,"recording_mbid":"julia-mbid","track_metadata":{"artist_name":"Julia Holter","track_name":"Underneath the Moon"}}}"#.utf8))
                }
                return (response, Data(#"{"pinned_recording":{"row_id":11,"recording_mbid":"bochum-mbid","track_metadata":{"artist_name":"Bochum Welt","track_name":"New Pin"}}}"#.utf8))
            case ("GET", "/1/user/tester/listens"):
                return (response, Data(#"{"payload":{"listens":[]}}"#.utf8))
            case ("GET", "/1/tester/pins"), ("GET", "/1/tester/pins/following"):
                return (response, Data(#"{"pinned_recordings":[]}"#.utf8))
            case ("POST", "/1/pin/unpin"):
                return (response, Data(#"{"status":"ok"}"#.utf8))
            case ("POST", "/1/pin"):
                return (response, Data(#"{"status":"ok"}"#.utf8))
            default:
                XCTFail("Unexpected ListenBrainz request \(request.httpMethod ?? "") \(request.url?.path ?? "")")
                return (response, Data(#"{}"#.utf8))
            }
        })
        let service = ScrobbleService(
            api: api,
            listenBrainz: listenBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        // When the user pins a different recording from OpenScrobbler.
        await service.refreshListenBrainzPins()
        let didPin = await service.pinListenBrainzRecording(recordingMbid: "bochum-mbid", title: "New Pin")

        // Then OpenScrobbler must remove the old remote pin before creating the new one.
        XCTAssertTrue(didPin, "The pin action should report success after replacing the old ListenBrainz pin.")
        let paths = MockURLProtocol.requests.map { "\($0.httpMethod ?? "") \($0.url?.path ?? "")" }
        XCTAssertLessThan(
            paths.firstIndex(of: "POST /1/pin/unpin") ?? Int.max,
            paths.firstIndex(of: "POST /1/pin") ?? Int.max,
            "ListenBrainz only allows one active pin, so unpin must happen before the new pin is posted."
        )
        XCTAssertEqual(service.listenBrainzCurrentPin?.recordingMbid, "bochum-mbid", "The UI should now reflect the new remote pin.")
    }

    @MainActor
    func testPinningATrackWithoutMusicBrainzIDUsesRecentListenBrainzMSID() async {
        // Given MusicBrainz cannot resolve the track, but ListenBrainz recently heard it and has an MSID.
        let api = MockAPI()
        let monitor = TestMonitor()
        var pinPostCount = 0
        let urlSession = makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/ws/2/recording"):
                return (response, Data(#"{"recordings":[]}"#.utf8))
            case ("GET", "/ws/2/artist"):
                return (response, Data(#"{"artists":[]}"#.utf8))
            case ("GET", "/ws/2/release"):
                return (response, Data(#"{"releases":[]}"#.utf8))
            case ("GET", "/1/user/tester/listens"):
                return (response, Data(#"{"payload":{"listens":[{"listened_at":1781040000,"track_metadata":{"artist_name":"The Durutti Column","track_name":"If You Were Me (XFM Session 2006)","additional_info":{"recording_msid":"durutti-msid"}}}]}}"#.utf8))
            case ("GET", "/1/tester/pins/current"):
                if pinPostCount > 0 {
                    return (response, Data(#"{"pinned_recording":{"row_id":12,"recording_msid":"durutti-msid","track_metadata":{"artist_name":"The Durutti Column","track_name":"If You Were Me (XFM Session 2006)"}}}"#.utf8))
                }
                return (response, Data(#"{"pinned_recording":null}"#.utf8))
            case ("GET", "/1/tester/pins"), ("GET", "/1/tester/pins/following"):
                return (response, Data(#"{"pinned_recordings":[]}"#.utf8))
            case ("POST", "/1/pin"):
                pinPostCount += 1
                return (response, Data(#"{"status":"ok"}"#.utf8))
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "") \(request.url?.path ?? "")")
                return (response, Data(#"{}"#.utf8))
            }
        }
        let listenBrainz = configuredListenBrainzService(urlSession: urlSession)
        let musicBrainz = MusicBrainzService(urlSession: urlSession)
        let service = ScrobbleService(
            api: api,
            listenBrainz: listenBrainz,
            musicBrainz: musicBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        // When the user presses Pin on that track.
        let didPin = await service.pinListenBrainzTrack(
            title: "If You Were Me (XFM Session 2006)",
            artist: "The Durutti Column",
            album: nil,
            recordingMbid: nil
        )

        // Then the pin still succeeds by posting the ListenBrainz recording MSID.
        XCTAssertTrue(didPin, "Tracks missing a MusicBrainz recording ID should still be pinnable when ListenBrainz provides an MSID.")
        XCTAssertEqual(service.listenBrainzCurrentPin?.recordingMsid, "durutti-msid", "The refreshed current pin should be matched by MSID.")
        XCTAssertEqual(pinPostCount, 1, "Only one remote pin request should be sent.")
    }

    @MainActor
    func testLoveToggleUsesRecentListenBrainzMSID() async {
        let api = MockAPI()
        let monitor = TestMonitor()
        var feedbackScores: [Int] = []
        let urlSession = makeMockedSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.httpMethod, request.url?.path) {
            case ("GET", "/ws/2/recording"):
                return (response, Data(#"{"recordings":[]}"#.utf8))
            case ("GET", "/ws/2/artist"):
                return (response, Data(#"{"artists":[]}"#.utf8))
            case ("GET", "/ws/2/release"):
                return (response, Data(#"{"releases":[]}"#.utf8))
            case ("GET", "/1/user/tester/listens"):
                return (response, Data(#"{"payload":{"listens":[{"listened_at":1781040000,"track_metadata":{"artist_name":"The Durutti Column","track_name":"Sketch for Summer","additional_info":{"recording_msid":"summer-msid"}}}]}}"#.utf8))
            case ("GET", "/1/stats/user/tester/artists"):
                return (response, Data(#"{"payload":{"artists":[]}}"#.utf8))
            case ("GET", "/1/stats/user/tester/recordings"):
                return (response, Data(#"{"payload":{"recordings":[]}}"#.utf8))
            case ("GET", "/1/stats/user/tester/releases"):
                return (response, Data(#"{"payload":{"releases":[]}}"#.utf8))
            case ("POST", "/1/feedback/recording-feedback"):
                let body = try XCTUnwrap(request.httpBodyData)
                let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
                XCTAssertEqual(json["recording_msid"] as? String, "summer-msid")
                feedbackScores.append(try XCTUnwrap(json["score"] as? Int))
                return (response, Data(#"{"status":"ok"}"#.utf8))
            default:
                XCTFail("Unexpected request \(request.httpMethod ?? "") \(request.url?.path ?? "")")
                return (response, Data(#"{}"#.utf8))
            }
        }
        let listenBrainz = configuredListenBrainzService(urlSession: urlSession)
        let musicBrainz = MusicBrainzService(urlSession: urlSession)
        let service = ScrobbleService(
            api: api,
            listenBrainz: listenBrainz,
            musicBrainz: musicBrainz,
            monitor: monitor,
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        monitor.emit(.trackStarted(makeTrack(title: "Sketch for Summer", artist: "The Durutti Column", duration: 180)))
        await Task.yield()
        await service.toggleCurrentTrackLove()
        await service.toggleCurrentTrackLove()

        XCTAssertEqual(feedbackScores, [1, 0])
        XCTAssertFalse(service.listenBrainzCurrentTrackLoved)
        XCTAssertEqual(service.listenBrainzFeedbackStatus, "Removed love for Sketch for Summer")
    }

    @MainActor
    func testAccountFooterPrefersListenBrainzIdentity() async {
        let api = MockAPI()
        api.isAuthenticated = false
        let service = ScrobbleService(
            api: api,
            listenBrainz: configuredListenBrainzService(urlSession: .shared),
            monitor: TestMonitor(),
            sessionStore: InMemorySessionStore(),
            queueStore: InMemoryQueueStore()
        )

        XCTAssertEqual(service.accountFooterText, "tester (ListenBrainz)")
        withExtendedLifetime(service) {}
    }

    @MainActor
    func testStartupValidationInvalidatesStoredSession() async {
        let api = MockAPI()
        api.isAuthenticated = true
        api.sessionValidationResult = .success(
            CompatibilitySessionValidation(
                isValid: false,
                checkedAt: .now,
                fromCache: false,
                capabilities: .unknown
            )
        )
        let monitor = TestMonitor()
        let sessionStore = InMemorySessionStore()
        sessionStore.save(CompatibilitySession(name: "tester", key: "session"))
        let service = ScrobbleService(
            api: api,
            listenBrainz: isolatedListenBrainzService(),
            monitor: monitor,
            sessionStore: sessionStore,
            queueStore: InMemoryQueueStore()
        )

        await Task.yield()
        try? await Task.sleep(nanoseconds: 20_000_000)

        XCTAssertFalse(service.isAuthenticated)
        XCTAssertEqual(service.sessionStatus, "Session invalid")
        XCTAssertEqual(sessionStore.load(), nil)
        XCTAssertGreaterThanOrEqual(api.validateSessionCalls, 1)
        withExtendedLifetime(service) {}
    }

    private func makeTrack(title: String = "Track", artist: String = "Artist", duration: TimeInterval) -> Track {
        Track(
            title: title,
            artist: artist,
            album: "Album",
            duration: duration,
            startedAt: .now,
            sourceApp: "Test"
        )
    }

    private func isolatedListenBrainzService() -> ListenBrainzService {
        let defaults = UserDefaults(suiteName: "OpenScrobblerTests-\(UUID().uuidString)")!
        let settingsStore = ListenBrainzSettingsStore(
            defaults: defaults,
            tokenStore: InMemoryListenBrainzTokenStore()
        )
        return ListenBrainzService(settingsStore: settingsStore)
    }

    private func configuredListenBrainzService(urlSession: URLSession) -> ListenBrainzService {
        let defaults = UserDefaults(suiteName: "OpenScrobblerTests-ListenBrainz-\(UUID().uuidString)")!
        let tokenStore = InMemoryListenBrainzTokenStore()
        let settingsStore = ListenBrainzSettingsStore(defaults: defaults, tokenStore: tokenStore)
        settingsStore.save(
            ListenBrainzSettings(
                isEnabled: true,
                submitNowPlaying: true,
                submitListens: true,
                baseURL: URL(string: "https://api.listenbrainz.org")!,
                username: "tester"
            )
        )
        try? settingsStore.saveToken("test-token")
        return ListenBrainzService(settingsStore: settingsStore, urlSession: urlSession)
    }

    private func makeMockedSession(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> URLSession {
        MockURLProtocol.handler = handler
        MockURLProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class InMemoryListenBrainzTokenStore: ListenBrainzTokenStoring {
    private var storedToken: String?

    init(token: String? = nil) {
        storedToken = token
    }

    func readToken() throws -> String? {
        storedToken
    }

    func saveToken(_ token: String) throws {
        storedToken = token
    }

    func deleteToken() throws {
        storedToken = nil
    }
}

private final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            Self.requests.append(request)
            guard let handler = Self.handler else {
                throw URLError(.badServerResponse)
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class MockAPI: CompatibilityAPI {
    var nowPlayingTracks: [Track] = []
    var isConfigured: Bool = true
    var isAuthenticated: Bool = true
    var sessionUsername: String?
    var scrobbledTracks: [Track] = []
    var trackDetailRequests: [(artist: String, track: String)] = []
    var artistDetailRequests: [String] = []
    var scrobbleFailuresRemaining: Int
    var scrobbleAttempts = 0
    var validateSessionCalls = 0
    var sessionValidationResult: Result<CompatibilitySessionValidation, Error> = .success(
        CompatibilitySessionValidation(
            isValid: true,
            checkedAt: .now,
            fromCache: false,
            capabilities: .unknown
        )
    )

    init(scrobbleFailuresRemaining: Int = 0) {
        self.scrobbleFailuresRemaining = scrobbleFailuresRemaining
    }

    func authenticate(username: String, password: String) async throws -> CompatibilitySession {
        _ = password
        sessionUsername = username
        isAuthenticated = true
        return CompatibilitySession(name: "tester", key: "session")
    }

    func restoreSession(_ session: CompatibilitySession) {
        sessionUsername = session.name
        isAuthenticated = true
    }

    func clearSession() {
        isAuthenticated = false
        sessionUsername = nil
    }

    func validateSession() async throws -> CompatibilitySessionValidation {
        validateSessionCalls += 1
        return try sessionValidationResult.get()
    }

    func nowPlaying(_ track: Track) async throws {
        nowPlayingTracks.append(track)
    }

    func scrobble(_ track: Track) async throws {
        scrobbleAttempts += 1
        if scrobbleFailuresRemaining > 0 {
            scrobbleFailuresRemaining -= 1
            throw URLError(.notConnectedToInternet)
        }
        scrobbledTracks.append(track)
    }

    func love(track: String, artist: String) async throws {
        _ = track
        _ = artist
    }

    func unlove(track: String, artist: String) async throws {
        _ = track
        _ = artist
    }

    func fetchTrackDetails(artist: String, track: String) async throws -> CompatibilityTrackDetails {
        trackDetailRequests.append((artist: artist, track: track))
        return CompatibilityTrackDetails(
            name: track,
            artist: artist,
            album: "Album",
            imageURL: nil,
            listeners: 1,
            playcount: 1,
            userPlaycount: 1,
            url: nil,
            summary: nil,
            tags: []
        )
    }

    func fetchArtistDetails(artist: String) async throws -> CompatibilityArtistDetails {
        artistDetailRequests.append(artist)
        return CompatibilityArtistDetails(
            name: artist,
            imageURL: nil,
            listeners: 1,
            playcount: 1,
            userPlaycount: 1,
            url: nil,
            summary: nil,
            tags: [],
            similarArtists: []
        )
    }

    func fetchSimilarTracks(artist: String, track: String, limit: Int) async throws -> [CompatibilitySimilarTrack] {
        _ = limit
        return [CompatibilitySimilarTrack(id: "similar-track", name: track, artist: artist, imageURL: nil, url: nil)]
    }

    func fetchSimilarAlbums(artist: String, album: String, limit: Int) async throws -> [CompatibilitySimilarAlbum] {
        _ = limit
        return [CompatibilitySimilarAlbum(id: "similar-album", name: album, artist: artist, imageURL: nil, url: nil)]
    }

    func fetchUserProfile() async throws -> CompatibilityUserProfile {
        CompatibilityUserProfile(
            name: "tester",
            realname: nil,
            playcount: 1,
            artistCount: 1,
            trackCount: 1,
            albumCount: 1,
            country: nil,
            url: nil,
            imageURL: nil,
            registeredAt: nil,
            accountType: nil
        )
    }

    func fetchRecentScrobbles(limit: Int) async throws -> [CompatibilityRecentScrobble] {
        [CompatibilityRecentScrobble(
            id: "test",
            track: "Track",
            artist: "Artist",
            album: "Album",
            imageURL: nil,
            url: nil,
            loved: false,
            playedAt: .now,
            nowPlaying: false
        )]
    }

    func fetchFriendsListening(limit: Int) async throws -> [CompatibilityFriendListening] {
        [CompatibilityFriendListening(
            id: "friend",
            user: "friend",
            realname: nil,
            country: nil,
            isSubscriber: false,
            accountType: nil,
            avatarURL: nil,
            track: "Track",
            artist: "Artist",
            imageURL: nil,
            playedAt: .now,
            nowPlaying: true
        )]
    }

    func fetchNeighbours(limit: Int) async throws -> [CompatibilityNeighbour] {
        _ = limit
        return [CompatibilityNeighbour(
            id: "neighbour",
            user: "neighbour",
            realname: nil,
            country: nil,
            isSubscriber: false,
            accountType: nil,
            avatarURL: nil,
            profileURL: nil,
            matchScore: nil
        )]
    }

    func fetchFriendUsernames(user: String, limit: Int) async throws -> [String] {
        _ = user
        _ = limit
        return ["friend"]
    }

    func fetchTopArtists(period: CompatibilityTopArtistPeriod, limit: Int) async throws -> [CompatibilityTopArtist] {
        _ = period
        _ = limit
        return [CompatibilityTopArtist(id: "artist", name: "Artist", playcount: 10, imageURL: nil, url: nil)]
    }

    func fetchGlobalTopArtists(limit: Int) async throws -> [String] {
        _ = limit
        return ["Artist", "Another Artist"]
    }

    func fetchLovedTracksCount() async throws -> Int? {
        0
    }
}

private final class TestMonitor: PlayerMonitor {
    var onEvent: ((PlayerEvent) -> Void)?
    var statusDescription: String = "Test monitor"

    func start() {}
    func stop() {}

    func emit(_ event: PlayerEvent) {
        onEvent?(event)
    }
}

private final class InMemorySessionStore: CompatibilityAccountsStoring {
    private var session: CompatibilitySession?
    private var sessions: [CompatibilitySession] = []
    private var activeUsername: String?

    func save(_ session: CompatibilitySession) {
        self.session = session
        sessions.removeAll { $0.name.caseInsensitiveCompare(session.name) == .orderedSame }
        sessions.append(session)
        activeUsername = session.name
    }

    func load() -> CompatibilitySession? {
        if let activeUsername {
            return sessions.first { $0.name.caseInsensitiveCompare(activeUsername) == .orderedSame }
        }
        return session
    }

    func clear() {
        session = nil
        activeUsername = nil
    }

    func allSessions() -> [CompatibilitySession] {
        sessions
    }

    func setActive(username: String?) {
        activeUsername = username
        session = load()
    }

    func remove(username: String) {
        sessions.removeAll { $0.name.caseInsensitiveCompare(username) == .orderedSame }
        if activeUsername?.caseInsensitiveCompare(username) == .orderedSame {
            activeUsername = sessions.first?.name
            session = load()
        }
    }
}

private final class InMemoryQueueStore: ScrobbleQueueStoring {
    let queueFileURL = URL(fileURLWithPath: "/tmp/openscrobbler-test-queue.json")
    private var tracks: [Track] = []

    init(initialTracks: [Track] = []) {
        tracks = initialTracks
    }

    func load() -> [Track] {
        tracks
    }

    func save(_ tracks: [Track]) {
        self.tracks = tracks
    }
}

private actor SleepLatch {
    private var permits = 0

    func wait() async {
        while true {
            if Task.isCancelled {
                return
            }
            if permits > 0 {
                permits -= 1
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000)
        }
    }

    func release(_ count: Int) {
        permits += count
    }
}
