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
}

private struct ArtworkResolutionFixture: Decodable {
    let name: String
    let target: ArtworkLevel
    let candidates: [ArtworkResolutionCandidate]
    let expected: String
}
