import XCTest
@testable import ListenScrobbler

final class MusicBrainzServiceTests: XCTestCase {
    override func tearDown() {
        MusicBrainzURLProtocol.handler = nil
        MusicBrainzURLProtocol.requests = []
        super.tearDown()
    }

    func testLookupCombinesRecordingArtistAndReleaseMetadata() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
            XCTAssertNotNil(request.value(forHTTPHeaderField: "User-Agent"))

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.recordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.releasePayload.utf8))
            case "/release/release-id":
                return (response, Data(Self.coverArtPayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: "Track", artist: "Artist", release: "Album")

        XCTAssertEqual(details.trackName, "Track")
        XCTAssertEqual(details.artistName, "Artist")
        XCTAssertEqual(details.releaseName, "Album")
        XCTAssertEqual(details.recordingMBID, "recording-id")
        XCTAssertEqual(details.artistMBID, "artist-id")
        XCTAssertEqual(details.releaseMBID, "release-id")
        XCTAssertEqual(details.imageURL, "https://cover.example/large.jpg")
        XCTAssertEqual(details.country, "GB")
        XCTAssertTrue(details.tags.contains("trip hop"))
        XCTAssertTrue(details.links.contains { $0.url.absoluteString == "https://musicbrainz.org/recording/recording-id" })
    }

    func testLookupAvoidsAmbiguousSameNameRecordingFromDifferentArtist() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.ambiguousRecordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.emptyReleasePayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: "Track", artist: "Artist", release: nil)

        XCTAssertEqual(details.trackName, "Track")
        XCTAssertEqual(details.artistName, "Artist")
        XCTAssertNil(details.recordingMBID)
        XCTAssertEqual(details.artistMBID, "artist-id")
        XCTAssertNil(details.releaseName)
        XCTAssertNil(details.releaseMBID)
    }

    func testLookupFindsRecordingWhenAlbumSpecificMusicBrainzSearchMisses() async throws {
        // Given a track whose album-specific MusicBrainz recording search returns no results.
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "query" })?
                    .value ?? ""
                if query.contains("release:") {
                    return (response, Data(Self.emptyRecordingPayload.utf8))
                }
                return (response, Data(Self.arnosParkRecordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.bochumWeltArtistPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.emptyReleasePayload.utf8))
            case "/release/arnos-release-id":
                return (response, Data(Self.coverArtPayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        // When ListenScrobbler looks up the track with album metadata from the player.
        let details = try await service.lookup(
            track: "Arnos Park",
            artist: "Bochum Welt",
            release: "Module 2 / Desktop Robotics"
        )

        // Then it retries a broader recording search and still gets a pinnable MBID.
        XCTAssertEqual(
            details.recordingMBID,
            "648202d7-a5c7-4f2d-ae63-c72d6ed062cb",
            "A bad album match should not stop the track from being resolved for ListenBrainz pinning."
        )
        XCTAssertEqual(details.artistName, "Bochum Welt", "The broader retry must still keep the requested artist.")
    }

    func testLookupPrefersRecordingArtistIdentityOverAmbiguousArtistSearch() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.panRecordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.tygersArtistSearchPayload.utf8))
            case "/ws/2/artist/pan-artist-id":
                return (response, Data(Self.panArtistLookupPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.emptyReleasePayload.utf8))
            case "/release/pan-release-id":
                return (response, Data(Self.emptyCoverArtPayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(
            track: "Leonardo Montes",
            artist: "PAN",
            release: "En Vivo en El Teatro Nacional"
        )

        XCTAssertEqual(details.trackName, "Leonardo Montes")
        XCTAssertEqual(details.artistName, "PAN")
        XCTAssertEqual(details.artistMBID, "pan-artist-id")
        XCTAssertEqual(details.country, "VE")
        XCTAssertEqual(details.type, "Group")
        XCTAssertTrue(details.tags.contains("rap metal"))
        XCTAssertFalse(details.tags.contains("nwobhm"))
    }

    func testLookupFindsCompilationArtworkWhenReleaseIsNotCreditedToTrackArtist() async throws {
        // Given a compilation album where the release is not credited to the track artist.
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.emptyRecordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/release":
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "query" })?
                    .value ?? ""
                if query.contains("artist:") {
                    return (response, Data(Self.emptyReleasePayload.utf8))
                }
                return (response, Data(Self.compilationReleasePayload.utf8))
            case "/release/compilation-release-id":
                return (response, Data(Self.coverArtPayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        // When ListenScrobbler searches for the track and release from the now-playing metadata.
        let details = try await service.lookup(
            track: "My Silks And Fine Arrays",
            artist: "Julie Covington",
            release: "The Trip Created By Saint Etienne"
        )

        // Then it falls back to a release-title search and can still show album artwork.
        XCTAssertEqual(details.releaseMBID, "compilation-release-id", "Compilation releases should be found even without a track-artist credit match.")
        XCTAssertEqual(details.imageURL, "https://cover.example/large.jpg", "The resolved compilation release should provide cover art for the UI.")
    }

    private func makeService(
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MusicBrainzService {
        MusicBrainzURLProtocol.handler = handler
        MusicBrainzURLProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MusicBrainzURLProtocol.self]
        return MusicBrainzService(
            baseURL: URL(string: "https://musicbrainz.org/ws/2")!,
            urlSession: URLSession(configuration: configuration)
        )
    }

    private static let recordingPayload = """
    {
      "recordings": [
        {
          "id": "recording-id",
          "title": "Track",
          "disambiguation": "single edit",
          "artist-credit": [
            { "artist": { "id": "artist-id", "name": "Artist" } }
          ],
          "releases": [
            { "id": "release-id", "title": "Album", "status": "Official" }
          ],
          "tags": [
            { "count": 8, "name": "trip hop" }
          ]
        }
      ]
    }
    """

    private static let artistPayload = """
    {
      "artists": [
        {
          "id": "artist-id",
          "name": "Artist",
          "country": "GB",
          "type": "Group",
          "tags": [
            { "count": 5, "name": "electronic" }
          ]
        }
      ]
    }
    """

    private static let releasePayload = """
    {
      "releases": [
        {
          "id": "release-id",
          "title": "Album",
          "status": "Official",
          "tags": [
            { "count": 3, "name": "downtempo" }
          ]
        }
      ]
    }
    """

    private static let coverArtPayload = """
    {
      "images": [
        {
          "front": true,
          "image": "https://cover.example/full.jpg",
          "thumbnails": {
            "small": "https://cover.example/small.jpg",
            "large": "https://cover.example/large.jpg"
          }
        }
      ]
    }
    """

    private static let emptyCoverArtPayload = """
    {
      "images": []
    }
    """

    private static let ambiguousRecordingPayload = """
    {
      "recordings": [
        {
          "id": "wrong-recording-id",
          "title": "Track",
          "artist-credit": [
            { "artist": { "id": "different-artist-id", "name": "Artist" } }
          ],
          "releases": [
            { "id": "wrong-release-id", "title": "Wrong Compilation", "status": "Official" }
          ]
        }
      ]
    }
    """

    private static let emptyReleasePayload = """
    {
      "releases": []
    }
    """

    private static let compilationReleasePayload = """
    {
      "releases": [
        {
          "id": "compilation-release-id",
          "title": "The Trip Created By Saint Etienne",
          "status": "Official",
          "cover-art-archive": {
            "front": true
          }
        }
      ]
    }
    """

    private static let emptyRecordingPayload = """
    {
      "recordings": []
    }
    """

    private static let arnosParkRecordingPayload = """
    {
      "recordings": [
        {
          "id": "648202d7-a5c7-4f2d-ae63-c72d6ed062cb",
          "title": "Arnos Park",
          "artist-credit": [
            { "artist": { "id": "bochum-welt-id", "name": "Bochum Welt" } }
          ],
          "releases": [
            { "id": "arnos-release-id", "title": "Desktop Robotics", "status": "Official" }
          ]
        }
      ]
    }
    """

    private static let bochumWeltArtistPayload = """
    {
      "artists": [
        {
          "id": "bochum-welt-id",
          "name": "Bochum Welt",
          "type": "Person"
        }
      ]
    }
    """

    private static let panRecordingPayload = """
    {
      "recordings": [
        {
          "id": "pan-recording-id",
          "title": "Leonardo Montes",
          "artist-credit": [
            { "artist": { "id": "pan-artist-id", "name": "PAN" } }
          ],
          "releases": [
            { "id": "pan-release-id", "title": "En Vivo en El Teatro Nacional", "status": "Official" }
          ]
        }
      ]
    }
    """

    private static let tygersArtistSearchPayload = """
    {
      "artists": [
        {
          "id": "tygers-artist-id",
          "name": "Tygers of Pan Tang",
          "country": "GB",
          "type": "Group",
          "tags": [
            { "count": 2, "name": "nwobhm" }
          ]
        }
      ]
    }
    """

    private static let panArtistLookupPayload = """
    {
      "id": "pan-artist-id",
      "name": "PAN",
      "country": "VE",
      "type": "Group",
      "tags": [
        { "count": 4, "name": "rap metal" }
      ]
    }
    """
}

private final class MusicBrainzURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(request)
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
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
