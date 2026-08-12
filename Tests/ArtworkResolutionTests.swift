import XCTest
@testable import ListenScrobbler

final class ArtworkResolutionTests: XCTestCase {
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
        XCTAssertFalse(providers.contains(.theAudioDB))
        XCTAssertFalse(providers.contains(.fanartTV))
        XCTAssertFalse(providers.contains(.lastFM))
        XCTAssertTrue(ArtworkProviderCatalog.options
            .filter { $0.status == .active }
            .allSatisfy { !$0.requiresAuthentication })
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
        XCTAssertEqual(similarAlbum.artworkResolution?.level, .album)
        XCTAssertEqual(similarArtist.artworkResolution?.level, .artist)
        XCTAssertEqual(topArtist.artworkResolution?.provider, .compatibilityAPI)
    }
}

private struct ArtworkResolutionFixture: Decodable {
    let name: String
    let target: ArtworkLevel
    let candidates: [ArtworkResolutionCandidate]
    let expected: String
}
