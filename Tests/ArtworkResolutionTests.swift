import XCTest
@testable import ListenScrobbler

final class ArtworkResolutionTests: XCTestCase {
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

    func testProviderCatalogIncludesNonMusicBrainzCandidates() {
        let providers = Set(ArtworkProviderCatalog.options.map(\.provider))

        XCTAssertTrue(providers.contains(.discogs))
        XCTAssertTrue(providers.contains(.allMusic))
        XCTAssertTrue(providers.contains(.appleMusic))
        XCTAssertTrue(providers.contains(.spotify))
        XCTAssertTrue(providers.contains(.theAudioDB))
        XCTAssertTrue(providers.contains(.fanartTV))
    }
}
