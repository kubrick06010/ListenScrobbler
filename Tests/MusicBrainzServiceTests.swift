import XCTest
@testable import ListenScrobbler

final class MusicBrainzServiceTests: XCTestCase {
    override func tearDown() {
        MusicBrainzURLProtocol.handler = nil
        MusicBrainzURLProtocol.requests = []
        super.tearDown()
    }

    func testLookupCombinesRecordingArtistAndReleaseMetadata() async throws {
        let service = makeService(preferredAppLanguageCodes: ["en"]) { request in
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
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
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

    func testCoverArtArchiveArtworkUsesHTTPSForAppTransportSecurity() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.recordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.releasePayload.utf8))
            case "/release/release-id":
                return (response, Data(#"{"images":[{"front":true,"thumbnails":{"500":"http://cover.example/large.jpg"}}]}"#.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: "Track", artist: "Artist", release: "Album")

        XCTAssertEqual(details.imageURL, "https://cover.example/large.jpg")
        XCTAssertEqual(details.artworkResolution?.url, "https://cover.example/large.jpg")
    }

    func testCoverArtArchiveFailureDoesNotPublishAnUnverifiedFrontURL() async throws {
        let service = makeService { request in
            let statusCode = request.url!.path == "/release/release-id" ? 503 : 200
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.recordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.releasePayload.utf8))
            case "/release/release-id":
                return (response, Data())
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: "Track", artist: "Artist", release: "Album")

        XCTAssertNil(details.imageURL)
        XCTAssertNil(details.artworkResolution)
    }

    func testCoverArtArchiveBackImageIsNotPromotedToReleaseCover() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch request.url!.path {
            case "/ws/2/recording":
                return (response, Data(Self.recordingPayload.utf8))
            case "/ws/2/artist":
                return (response, Data(Self.artistPayload.utf8))
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
            case "/ws/2/release":
                return (response, Data(Self.releasePayload.utf8))
            case "/release/release-id":
                return (response, Data(#"{"images":[{"front":false,"back":true,"thumbnails":{"500":"https://cover.example/back.jpg"}}]}"#.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: "Track", artist: "Artist", release: "Album")

        XCTAssertNil(details.artworkResolution)
        XCTAssertNil(details.imageURL)
    }

    func testExactReleaseEnrichmentPreservesCorrelatedDiscogsArtwork() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MusicBrainzURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let resolver = AnonymousArtworkResolver(
            urlSession: session,
            deezerBaseURL: URL(string: "https://api.deezer.test")!,
            discogsBaseURL: URL(string: "https://api.discogs.test")!
        )
        MusicBrainzURLProtocol.requests = []
        MusicBrainzURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            switch (request.url?.host, request.url?.path) {
            case ("musicbrainz.org", "/ws/2/recording"):
                return (response, Data(#"{"recordings":[{"id":"recording-id","title":"Track","artist-credit":[{"artist":{"id":"artist-id","name":"Artist"}}],"releases":[{"id":"release-id","title":"Album","status":"Official"}]}]}"#.utf8))
            case ("musicbrainz.org", "/ws/2/artist"):
                return (response, Data(#"{"artists":[{"id":"artist-id","name":"Artist"}]}"#.utf8))
            case ("musicbrainz.org", "/ws/2/artist/artist-id"):
                return (response, Data(#"{"id":"artist-id","name":"Artist","relations":[]}"#.utf8))
            case ("musicbrainz.org", "/ws/2/release"):
                return (response, Data(#"{"releases":[{"id":"release-id","title":"Album","status":"Official","relations":[{"type":"discogs","url":{"resource":"https://www.discogs.com/release/249504-Album"}}]}]}"#.utf8))
            case ("coverartarchive.org", "/release/release-id"):
                return (response, Data(#"{"images":[]}"#.utf8))
            case ("api.discogs.test", "/releases/249504"):
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertNil(request.url?.query)
                return (response, Data(#"{"images":[{"type":"primary","uri":"https://cdn.example/discogs-release.jpg"}]}"#.utf8))
            default:
                XCTFail("Unexpected URL \(request.url?.absoluteString ?? "nil")")
                return (response, Data(#"{}"#.utf8))
            }
        }
        let service = MusicBrainzService(
            baseURL: URL(string: "https://musicbrainz.org/ws/2")!,
            urlSession: session,
            artworkResolver: resolver,
            preferredAppLanguageCodes: { ["en"] }
        )

        let details = try await service.lookup(track: "Track", artist: "Artist", release: "Album")

        XCTAssertEqual(details.releaseMBID, "release-id")
        XCTAssertEqual(details.artworkResolution?.url, "https://cdn.example/discogs-release.jpg")
        XCTAssertEqual(details.artworkResolution?.provider, .discogs)
        XCTAssertEqual(details.artworkResolution?.level, .album)
        XCTAssertEqual(details.artworkResolution?.sourceURL, "https://www.discogs.com/release/249504-Album")
    }

    func testLookupBuildsRichArtistProfileFromOpenMetadata() async throws {
        let service = makeService(preferredAppLanguageCodes: ["en"]) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.url!.host, request.url!.path) {
            case ("musicbrainz.org", "/ws/2/artist"):
                return (response, Data(Self.richArtistSearchPayload.utf8))
            case ("musicbrainz.org", "/ws/2/artist/39fe04bf-ba1a-481d-9836-b96beb549033"):
                return (response, Data(Self.richArtistLookupPayload.utf8))
            case ("www.wikidata.org", _):
                return (response, Data(Self.wikidataPayload.utf8))
            case ("en.wikipedia.org", _):
                return (response, Data(Self.wikipediaSummaryPayload.utf8))
            default:
                XCTFail("Unexpected URL \(request.url!.absoluteString)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: nil, artist: "Richard H. Kirk", release: nil)

        XCTAssertEqual(details.artistImageURL, "https://upload.example/richard.jpg")
        XCTAssertEqual(details.artistSummary, "English composer, musician and producer.")
        XCTAssertEqual(details.artistBeginDate, "1956-03-21")
        XCTAssertEqual(details.artistEndDate, "2021-09-21")
        XCTAssertEqual(details.artistEnded, true)
        XCTAssertEqual(details.artistArea, "Sheffield")
        XCTAssertEqual(details.artistSummary(forAppLanguageCode: "en"), "English composer, musician and producer.")
        XCTAssertNil(details.artistSummary(forAppLanguageCode: "es"))
        XCTAssertTrue(details.links.contains { $0.title == AppLocalization.string("Official website") })
        XCTAssertTrue(details.links.contains { $0.title == "Discogs" })
        XCTAssertEqual(details.artistConnections.first?.name, "Cabaret Voltaire")
        XCTAssertEqual(details.artistConnections.first?.relationship, "Member of")
        XCTAssertTrue(MusicBrainzURLProtocol.requests.contains {
            $0.url?.path == "/ws/2/artist/39fe04bf-ba1a-481d-9836-b96beb549033"
        })
        XCTAssertTrue(MusicBrainzURLProtocol.requests.contains { $0.url?.host == "en.wikipedia.org" })
        XCTAssertFalse(MusicBrainzURLProtocol.requests.contains { $0.url?.host == "es.wikipedia.org" })
    }

    func testLookupResolvesPeakingLightsPortraitFromExplicitDeezerRelationAnonymously() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MusicBrainzURLProtocol.self]
        let session = URLSession(configuration: configuration)
        let resolver = AnonymousArtworkResolver(
            urlSession: session,
            deezerBaseURL: URL(string: "https://api.deezer.test")!,
            discogsBaseURL: URL(string: "https://api.discogs.test")!
        )
        MusicBrainzURLProtocol.requests = []
        MusicBrainzURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            switch (request.url?.host, request.url?.path) {
            case ("musicbrainz.org", "/ws/2/artist"):
                return (response, Data(#"{"artists":[{"id":"peaking-lights-id","name":"Peaking Lights"}]}"#.utf8))
            case ("musicbrainz.org", "/ws/2/artist/peaking-lights-id"):
                return (response, Data(#"{"id":"peaking-lights-id","name":"Peaking Lights","relations":[{"type":"streaming music","url":{"resource":"https://www.deezer.com/artist/466634"}}]}"#.utf8))
            case ("api.deezer.test", "/artist/466634"):
                XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
                XCTAssertNil(request.url?.query)
                return (response, Data(#"{"picture_xl":"https://cdn.example/peaking-lights.jpg"}"#.utf8))
            default:
                XCTFail("Unexpected URL \(request.url?.absoluteString ?? "nil")")
                return (response, Data(#"{}"#.utf8))
            }
        }
        let service = MusicBrainzService(
            baseURL: URL(string: "https://musicbrainz.org/ws/2")!,
            urlSession: session,
            artworkResolver: resolver,
            preferredAppLanguageCodes: { ["en"] }
        )

        let details = try await service.lookup(track: nil, artist: "Peaking Lights", release: nil)

        XCTAssertEqual(details.artistArtworkResolution?.url, "https://cdn.example/peaking-lights.jpg")
        XCTAssertEqual(details.artistArtworkResolution?.provider, .deezer)
        XCTAssertEqual(details.artistArtworkResolution?.level, .artist)
        XCTAssertEqual(details.artistArtworkResolution?.sourceURL, "https://www.deezer.com/artist/466634")
        XCTAssertEqual(details.artworkResolution, details.artistArtworkResolution)
        XCTAssertEqual(
            MusicBrainzURLProtocol.requests.filter { $0.url?.host == "api.deezer.test" }.count,
            1,
            "Track fallback and artist portrait must share the same provider request."
        )
    }

    func testLookupNeverUsesAnUnrequestedBootlegAsArtworkFallback() async throws {
        let service = makeService { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!
            switch request.url?.path {
            case "/ws/2/recording":
                return (response, Data(#"{"recordings":[{"id":"wildlife-recording","title":"Wildlife Analysis","artist-credit":[{"artist":{"id":"boc-id","name":"Boards of Canada"}}],"releases":[{"id":"bootleg-release","title":"BOC Maxima","status":"Bootleg","cover-art-archive":{"front":true}}]}]}"#.utf8))
            case "/ws/2/artist":
                return (response, Data(#"{"artists":[{"id":"boc-id","name":"Boards of Canada"}]}"#.utf8))
            case "/ws/2/artist/boc-id":
                return (response, Data(#"{"id":"boc-id","name":"Boards of Canada","relations":[]}"#.utf8))
            default:
                XCTFail("The bootleg must not trigger a cover request: \(request.url?.absoluteString ?? "nil")")
                return (response, Data(#"{}"#.utf8))
            }
        }

        let details = try await service.lookup(
            track: "Wildlife Analysis",
            artist: "Boards of Canada",
            release: nil
        )

        XCTAssertEqual(details.recordingMBID, "wildlife-recording")
        XCTAssertNil(details.releaseMBID)
        XCTAssertNil(details.imageURL)
        XCTAssertFalse(MusicBrainzURLProtocol.requests.contains { $0.url?.path == "/release/bootleg-release" })
    }

    func testLookupUsesTheLanguageSelectedForTheAppForWikipedia() async throws {
        let service = makeService(preferredAppLanguageCodes: ["es"]) { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: ["Content-Type": "application/json"]
            )!

            switch (request.url!.host, request.url!.path) {
            case ("musicbrainz.org", "/ws/2/artist"):
                return (response, Data(Self.richArtistSearchPayload.utf8))
            case ("musicbrainz.org", "/ws/2/artist/39fe04bf-ba1a-481d-9836-b96beb549033"):
                return (response, Data(Self.richArtistLookupPayload.utf8))
            case ("www.wikidata.org", _):
                return (response, Data(Self.wikidataPayload.utf8))
            case ("es.wikipedia.org", _):
                return (response, Data(Self.spanishWikipediaSummaryPayload.utf8))
            default:
                XCTFail("Unexpected URL \(request.url!.absoluteString)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(track: nil, artist: "Richard H. Kirk", release: nil)

        XCTAssertEqual(details.artistSummary, "Compositor, músico y productor inglés.")
        XCTAssertEqual(details.artistSummaryLanguageCode, "es")
        XCTAssertTrue(MusicBrainzURLProtocol.requests.contains { $0.url?.host == "es.wikipedia.org" })
        XCTAssertFalse(MusicBrainzURLProtocol.requests.contains { $0.url?.host == "en.wikipedia.org" })
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
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
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
            case "/ws/2/artist/bochum-welt-id":
                return (response, Data(Self.bochumWeltArtistLookupPayload.utf8))
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

    func testLookupKeepsPlayerMetadataWhenArtistAndReleaseSearchesAreAmbiguous() async throws {
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
                return (response, Data(Self.ambiguousPanArtistSearchPayload.utf8))
            case "/ws/2/release":
                let query = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
                    .queryItems?
                    .first(where: { $0.name == "query" })?
                    .value ?? ""
                if query.contains("artist:") {
                    return (response, Data(Self.emptyReleasePayload.utf8))
                }
                return (response, Data(Self.ambiguousBSidesReleasePayload.utf8))
            default:
                XCTFail("Unexpected path \(request.url!.path)")
                return (response, Data())
            }
        }

        let details = try await service.lookup(
            track: "Jose Culebra",
            artist: "PAN",
            release: "B-Sides"
        )

        XCTAssertEqual(details.trackName, "Jose Culebra")
        XCTAssertEqual(details.artistName, "PAN")
        XCTAssertEqual(details.releaseName, "B-Sides")
        XCTAssertNil(details.recordingMBID)
        XCTAssertNil(details.artistMBID)
        XCTAssertNil(details.releaseMBID)
        XCTAssertNil(details.imageURL)
        XCTAssertNil(details.country)
        XCTAssertNil(details.type)
        XCTAssertTrue(details.tags.isEmpty)
        XCTAssertFalse(details.hasResolvedMusicBrainzEntity)
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
            case "/ws/2/artist/artist-id":
                return (response, Data(Self.artistLookupPayload.utf8))
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
        preferredAppLanguageCodes: [String] = ["en"],
        handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
    ) -> MusicBrainzService {
        MusicBrainzURLProtocol.handler = handler
        MusicBrainzURLProtocol.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MusicBrainzURLProtocol.self]
        return MusicBrainzService(
            baseURL: URL(string: "https://musicbrainz.org/ws/2")!,
            urlSession: URLSession(configuration: configuration),
            anonymousArtworkEnabled: false,
            preferredAppLanguageCodes: { preferredAppLanguageCodes }
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

    private static let artistLookupPayload = """
    {
      "id": "artist-id",
      "name": "Artist",
      "country": "GB",
      "type": "Group",
      "tags": [
        { "count": 5, "name": "electronic" }
      ],
      "relations": []
    }
    """

    private static let richArtistSearchPayload = """
    {
      "artists": [
        {
          "id": "39fe04bf-ba1a-481d-9836-b96beb549033",
          "name": "Richard H. Kirk",
          "country": "GB",
          "type": "Person"
        }
      ]
    }
    """

    private static let richArtistLookupPayload = """
    {
      "id": "39fe04bf-ba1a-481d-9836-b96beb549033",
      "name": "Richard H. Kirk",
      "country": "GB",
      "type": "Person",
      "area": { "name": "Sheffield" },
      "life-span": { "begin": "1956-03-21", "end": "2021-09-21", "ended": true },
      "relations": [
        { "type": "wikidata", "url": { "resource": "https://www.wikidata.org/wiki/Q547635" } },
        { "type": "official homepage", "url": { "resource": "https://example.com" } },
        { "type": "discogs", "url": { "resource": "https://discogs.com/artist/2238" } },
        {
          "type": "member of band",
          "direction": "forward",
          "artist": { "id": "cabaret-voltaire-id", "name": "Cabaret Voltaire" }
        }
      ],
      "tags": [{ "count": 2, "name": "electronic" }]
    }
    """

    private static let wikidataPayload = """
    {
      "entities": {
        "Q547635": {
          "sitelinks": {
            "enwiki": { "title": "Richard H. Kirk" },
            "eswiki": { "title": "Richard H. Kirk" }
          },
          "claims": { "P18": [{ "mainsnak": { "datavalue": { "value": "Richard.jpg" } } }] }
        }
      }
    }
    """

    private static let wikipediaSummaryPayload = """
    {
      "extract": "English composer, musician and producer.",
      "thumbnail": { "source": "https://upload.example/richard.jpg" }
    }
    """

    private static let spanishWikipediaSummaryPayload = """
    {
      "extract": "Compositor, músico y productor inglés.",
      "thumbnail": { "source": "https://upload.example/richard.jpg" }
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

    private static let bochumWeltArtistLookupPayload = """
    {
      "id": "bochum-welt-id",
      "name": "Bochum Welt",
      "type": "Person",
      "relations": []
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

    private static let ambiguousPanArtistSearchPayload = """
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
        },
        {
          "id": "pan-person-id",
          "name": "PAN",
          "type": "Person",
          "disambiguation": "video game music contributor"
        },
        {
          "id": "pan-group-id",
          "name": "Pan",
          "country": "DK",
          "type": "Group"
        }
      ]
    }
    """

    private static let ambiguousBSidesReleasePayload = """
    {
      "releases": [
        {
          "id": "shihad-b-sides-id",
          "title": "B-Sides",
          "status": "Official",
          "artist-credit": [
            { "artist": { "id": "shihad-id", "name": "Shihad" } }
          ]
        },
        {
          "id": "dark-new-day-b-sides-id",
          "title": "B-Sides",
          "status": "Official",
          "artist-credit": [
            { "artist": { "id": "dark-new-day-id", "name": "Dark New Day" } }
          ]
        }
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
