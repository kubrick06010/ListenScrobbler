import XCTest
@testable import ListenScrobbler

final class ArtworkResolutionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ArtworkResolverURLProtocol.reset()
    }

    override func tearDown() {
        ArtworkResolverURLProtocol.reset()
        super.tearDown()
    }

    func testResolutionFixturesFollowTheSharedFallbackPolicy() throws {
        let bundle = Bundle(for: Self.self)
        let url = bundle.url(
            forResource: "artwork-resolution-fixtures",
            withExtension: "json",
            subdirectory: "Artwork"
        ) ?? bundle.url(forResource: "artwork-resolution-fixtures", withExtension: "json")
        let fixtureURL = try XCTUnwrap(url)
        let fixtures = try JSONDecoder().decode([ArtworkResolutionFixture].self, from: Data(contentsOf: fixtureURL))

        for fixture in fixtures {
            let resolution = ArtworkResolutionPolicy.resolve(
                candidates: fixture.candidates,
                target: fixture.target
            )
            XCTAssertEqual(resolution?.url, fixture.expected, fixture.name)
        }
    }

    private enum Fixture {
        static let album = ArtworkResolution(
            url: "https://coverartarchive.org/release/release/front-500",
            level: .album,
            provider: .coverArtArchive
        )
        static let artist = ArtworkResolution(
            url: "https://commons.wikimedia.org/wiki/Special:FilePath/artist.jpg",
            level: .artist,
            provider: .wikipediaWikidata
        )
    }

    func testArtworkLevelsKeepArtistPortraitSeparateFromReleaseArtwork() {
        let release = ArtworkResolution(
            url: "https://coverartarchive.org/release/release/front-500",
            level: .album,
            provider: .coverArtArchive
        )
        let artist = ArtworkResolution(
            url: "https://commons.wikimedia.org/wiki/Special:FilePath/artist.jpg",
            level: .artist,
            provider: .wikipediaWikidata
        )

        XCTAssertNotEqual(release.level, artist.level)
        XCTAssertNotEqual(release.provider, artist.provider)
    }

    func testEPArtworkIsRepresentedAsItsOwnFallbackLevel() {
        let ep = ArtworkResolution(
            url: "https://coverartarchive.org/release-group/ep/front-500",
            level: .ep,
            provider: .coverArtArchive
        )

        XCTAssertEqual(ep.level, .ep)
    }

    func testProviderCatalogContainsOnlyDistributedSafeArtworkProviders() {
        let providers = Set(ArtworkProviderCatalog.options.map(\.provider))

        XCTAssertTrue(providers.contains(.discogs))
        XCTAssertTrue(providers.contains(.deezer))
        XCTAssertFalse(providers.contains(.appleMusic))
        XCTAssertFalse(providers.contains(.spotify))
        XCTAssertFalse(providers.contains(.compatibilityAPI))
        XCTAssertFalse(providers.contains(.theAudioDB))
        XCTAssertFalse(providers.contains(.fanartTV))
        XCTAssertFalse(providers.contains(.lastFM))
        XCTAssertTrue(ArtworkProviderCatalog.options.allSatisfy { !$0.requiresAuthentication })
        XCTAssertTrue(ArtworkProviderCatalog.options.allSatisfy { $0.status == .active })
    }

    func testAutomaticPolicyRejectsEveryCredentialedAndUnknownLegacyProvider() {
        let forbidden: [ArtworkProvider] = [
            .compatibilityAPI,
            .appleMusic,
            .spotify,
            .allMusic,
            .lastFM,
            .theAudioDB,
            .fanartTV,
            .legacy
        ]
        let candidates = forbidden.enumerated().map { index, provider in
            ArtworkResolutionCandidate(
                url: "https://forbidden.example/\(index).jpg",
                level: .track,
                provider: provider
            )
        }

        XCTAssertNil(ArtworkResolutionPolicy.resolve(candidates: candidates, target: .track))
        XCTAssertTrue(forbidden.allSatisfy { !$0.isCredentialFreeArtworkSource })
    }

    func testSurfaceTargetsCannotCrossEntityBoundaries() {
        let track = ArtworkResolutionCandidate(
            url: "https://cdn.example/track.jpg",
            level: .track,
            provider: .player
        )
        let album = ArtworkResolutionCandidate(
            url: "https://cdn.example/album.jpg",
            level: .album,
            provider: .coverArtArchive
        )
        let ep = ArtworkResolutionCandidate(
            url: "https://cdn.example/ep.jpg",
            level: .ep,
            provider: .coverArtArchive
        )
        let artist = ArtworkResolutionCandidate(
            url: "https://cdn.example/artist.jpg",
            level: .artist,
            provider: .wikipediaWikidata
        )
        let candidates = [track, album, ep, artist]

        XCTAssertEqual(
            ArtworkResolutionPolicy.resolve(candidates: candidates, target: .track)?.url,
            track.url
        )
        XCTAssertEqual(
            ArtworkResolutionPolicy.resolve(candidates: candidates, target: .album)?.url,
            album.url
        )
        XCTAssertEqual(
            ArtworkResolutionPolicy.resolve(candidates: [track, ep, artist], target: .album)?.url,
            ep.url
        )
        XCTAssertEqual(
            ArtworkResolutionPolicy.resolve(candidates: candidates, target: .artist)?.url,
            artist.url
        )
    }

    func testLegacyAndCredentialedTypedValuesAreNeverAutomaticallyDisplayed() {
        let legacy = ArtworkResolution(
            url: "https://legacy.example/art.jpg",
            level: .track,
            provider: .legacy
        )
        let credentialed = ArtworkResolution(
            url: "https://credentialed.example/art.jpg",
            level: .artist,
            provider: .spotify
        )
        let allowed = ArtworkResolution(
            url: "https://commons.example/artist.jpg",
            level: .artist,
            provider: .wikipediaWikidata
        )

        XCTAssertNil(legacy.automaticArtworkResolution)
        XCTAssertNil(credentialed.automaticArtworkResolution)
        XCTAssertEqual(allowed.automaticArtworkResolution, allowed)
    }

    func testArtworkResolutionRoundTripsWithProvenance() throws {
        let encoded = try JSONEncoder().encode(Fixture.album)
        let decoded = try JSONDecoder().decode(ArtworkResolution.self, from: encoded)

        XCTAssertEqual(decoded, Fixture.album)
        XCTAssertEqual(decoded.imageURL, Fixture.album.url)
    }

    func testTrackReadsLegacyArtworkURLIntoTypedResolution() throws {
        struct LegacyTrack: Encodable {
            let id: UUID
            let title: String
            let artist: String
            let album: String?
            let duration: TimeInterval
            let startedAt: Date
            let sourceApp: String?
            let sourceMetadata: TrackSourceMetadata?
            let artworkURL: String
        }

        let legacy = LegacyTrack(
            id: UUID(),
            title: "Cherry-coloured Funk",
            artist: "Cocteau Twins",
            album: "Heaven or Las Vegas",
            duration: 215,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceApp: "Apple Music",
            sourceMetadata: nil,
            artworkURL: "https://example.com/legacy-cover.jpg"
        )

        let track = try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(legacy))

        XCTAssertEqual(track.artworkURL, legacy.artworkURL)
        XCTAssertEqual(track.artworkResolution?.level, .track)
        XCTAssertEqual(track.artworkResolution?.provider, .player)
    }

    func testArtworkAdaptersKeepEntityLevelsAcrossHistoryDetailsSimilarAndProfileModels() {
        let history = CompatibilityRecentScrobble(
            id: "listen-1",
            track: "Track",
            artist: "Artist",
            album: "Album",
            imageURL: Fixture.album.url,
            url: nil,
            loved: false,
            playedAt: nil,
            nowPlaying: false,
            recordingMbid: nil,
            recordingMsid: nil
        )
        let similarAlbum = CompatibilitySimilarAlbum(
            id: "album-1",
            name: "Album",
            artist: "Artist",
            imageURL: Fixture.album.url,
            url: nil
        )
        let similarArtist = CompatibilitySimilarArtist(
            id: "artist-1",
            name: "Artist",
            imageURL: Fixture.artist.url,
            url: nil
        )
        let topArtist = CompatibilityTopArtist(
            id: "top-1",
            name: "Artist",
            playcount: 10,
            imageURL: Fixture.artist.url,
            url: nil
        )

        XCTAssertEqual(history.artworkResolution?.level, .track)
        XCTAssertNil(history.imageURL)
        XCTAssertEqual(similarAlbum.artworkResolution?.level, .album)
        XCTAssertNil(similarAlbum.artworkResolution?.automaticArtworkResolution)
        XCTAssertEqual(similarArtist.artworkResolution?.level, .artist)
        XCTAssertNil(similarArtist.artworkResolution?.automaticArtworkResolution)
        XCTAssertEqual(topArtist.artworkResolution?.provider, .compatibilityAPI)
    }

    func testAnonymousResolverUsesCorrelatedDeezerArtistWithoutCredentials() async throws {
        ArtworkResolverURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "api.deezer.test")
            XCTAssertEqual(request.url?.path, "/artist/466634")
            XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
            XCTAssertNil(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { ["api_key", "token", "access_token"].contains($0.name) }))
            return (200, Data(#"{"picture_xl":"https://cdn.example/peaking-lights.jpg"}"#.utf8))
        }

        let resolver = makeAnonymousResolver()
        let source = try XCTUnwrap(URL(string: "https://www.deezer.com/artist/466634"))
        let reference = try XCTUnwrap(ArtworkProviderReference.correlated(url: source, level: .artist))
        let result = await resolver.resolve(
            primaryCandidates: [],
            references: [reference],
            target: .artist
        )

        XCTAssertEqual(result.selected?.url, "https://cdn.example/peaking-lights.jpg")
        XCTAssertEqual(result.selected?.provider, .deezer)
        XCTAssertEqual(result.selected?.level, .artist)
        XCTAssertEqual(result.selected?.sourceURL, source.absoluteString)
        XCTAssertEqual(ArtworkResolverURLProtocol.capturedRequests().count, 1)
    }

    func testAnonymousResolverDoesNotSearchByNameOrGuessProviderIDs() async {
        ArtworkResolverURLProtocol.handler = { request in
            XCTFail("No provider request was expected, got \(request.url?.absoluteString ?? "nil")")
            return (500, Data())
        }

        let result = await makeAnonymousResolver().resolve(
            primaryCandidates: [],
            references: [],
            target: .artist
        )

        XCTAssertNil(result.selected)
        XCTAssertTrue(ArtworkResolverURLProtocol.capturedRequests().isEmpty)
        XCTAssertNil(ArtworkProviderReference.correlated(
            url: URL(string: "https://open.spotify.com/artist/credentialed")!,
            level: .artist
        ))
    }

    func testAnonymousResolverFallsBackFromDeezer404ToDiscogs() async throws {
        ArtworkResolverURLProtocol.handler = { request in
            switch request.url?.host {
            case "api.deezer.test":
                return (404, Data())
            case "api.discogs.test":
                return (200, Data(#"{"images":[{"type":"primary","uri":"https://cdn.example/discogs-artist.jpg"}]}"#.utf8))
            default:
                XCTFail("Unexpected host \(request.url?.host ?? "nil")")
                return (500, Data())
            }
        }

        let deezer = try XCTUnwrap(ArtworkProviderReference.correlated(
            url: URL(string: "https://www.deezer.com/artist/466634")!,
            level: .artist
        ))
        let discogs = try XCTUnwrap(ArtworkProviderReference.correlated(
            url: URL(string: "https://www.discogs.com/artist/1128524-Peaking-Lights")!,
            level: .artist
        ))
        let result = await makeAnonymousResolver().resolve(
            primaryCandidates: [],
            references: [discogs, deezer],
            target: .artist
        )

        XCTAssertEqual(result.selected?.provider, .discogs)
        XCTAssertEqual(result.selected?.url, "https://cdn.example/discogs-artist.jpg")
        XCTAssertTrue(result.trace.contains { $0.provider == .deezer && $0.outcome == .notFound })
        XCTAssertTrue(result.trace.contains { $0.provider == .discogs && $0.outcome == .candidate })
    }

    func testAnonymousResolverSurvivesRateLimitAndUsesNextProvider() async throws {
        ArtworkResolverURLProtocol.handler = { request in
            if request.url?.host == "api.deezer.test" {
                return (429, Data())
            }
            return (200, Data(#"{"images":[{"type":"primary","uri":"https://cdn.example/fallback.jpg"}]}"#.utf8))
        }

        let references = try [
            XCTUnwrap(ArtworkProviderReference.correlated(
                url: URL(string: "https://www.deezer.com/artist/466634")!,
                level: .artist
            )),
            XCTUnwrap(ArtworkProviderReference.correlated(
                url: URL(string: "https://www.discogs.com/artist/1128524")!,
                level: .artist
            ))
        ]
        let result = await makeAnonymousResolver().resolve(
            primaryCandidates: [],
            references: references,
            target: .artist
        )

        XCTAssertEqual(result.selected?.provider, .discogs)
        XCTAssertTrue(result.trace.contains { $0.provider == .deezer && $0.outcome == .rateLimited })
    }

    func testAnonymousResolverCachesAndDeduplicatesProviderRequests() async throws {
        ArtworkResolverURLProtocol.handler = { _ in
            (200, Data(#"{"picture_xl":"https://cdn.example/cached.jpg"}"#.utf8))
        }
        let resolver = makeAnonymousResolver()
        let reference = try XCTUnwrap(ArtworkProviderReference.correlated(
            url: URL(string: "https://www.deezer.com/artist/466634")!,
            level: .artist
        ))

        async let first = resolver.resolve(
            primaryCandidates: [],
            references: [reference, reference],
            target: .artist
        )
        async let second = resolver.resolve(
            primaryCandidates: [],
            references: [reference],
            target: .artist
        )
        let results = await (first, second)

        XCTAssertEqual(results.0.selected, results.1.selected)
        XCTAssertEqual(ArtworkResolverURLProtocol.capturedRequests().count, 1)
        XCTAssertTrue(
            results.0.trace.contains(where: { $0.outcome == .cacheHit })
                || results.1.trace.contains(where: { $0.outcome == .cacheHit })
        )
    }

    func testArtistResolutionIgnoresAlbumCoverAndStillFetchesPortrait() async throws {
        ArtworkResolverURLProtocol.handler = { _ in
            (200, Data(#"{"picture_xl":"https://cdn.example/artist.jpg"}"#.utf8))
        }
        let reference = try XCTUnwrap(ArtworkProviderReference.correlated(
            url: URL(string: "https://www.deezer.com/artist/466634")!,
            level: .artist
        ))
        let album = ArtworkResolutionCandidate(
            url: "https://cover.example/album.jpg",
            level: .album,
            provider: .coverArtArchive
        )

        let result = await makeAnonymousResolver().resolve(
            primaryCandidates: [album],
            references: [reference],
            target: .artist
        )

        XCTAssertEqual(result.selected?.url, "https://cdn.example/artist.jpg")
        XCTAssertEqual(result.selected?.level, .artist)
    }

    private func makeAnonymousResolver() -> AnonymousArtworkResolver {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ArtworkResolverURLProtocol.self]
        return AnonymousArtworkResolver(
            urlSession: URLSession(configuration: configuration),
            deezerBaseURL: URL(string: "https://api.deezer.test")!,
            discogsBaseURL: URL(string: "https://api.discogs.test")!
        )
    }
}

private struct ArtworkResolutionFixture: Decodable {
    let name: String
    let target: ArtworkLevel
    let candidates: [ArtworkResolutionCandidate]
    let expected: String
}

private final class ArtworkResolverURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    private static var requests: [URLRequest] = []
    private static let lock = NSLock()

    static func reset() {
        lock.lock()
        handler = nil
        requests = []
        lock.unlock()
    }

    static func capturedRequests() -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requests
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self.requests.append(request)
        let handler = Self.handler
        Self.lock.unlock()

        do {
            guard let handler else {
                throw URLError(.badServerResponse)
            }
            let (statusCode, data) = try handler(request)
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "application/json"]
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
