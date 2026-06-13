import XCTest
@testable import OpenScrobbler

final class ListenBrainzSetupGuideTests: XCTestCase {
    func testSetupGuideKeepsLastFMStyleAccountFlow() {
        XCTAssertEqual(
            ListenBrainzSetupGuide.steps.map(\.id),
            ["account", "token", "sources", "verify"]
        )
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.detail.isEmpty })
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.symbolName.isEmpty })
    }

    func testSetupGuideLinksToListenBrainzAndMusicBrainzSurfaces() {
        XCTAssertEqual(ListenBrainzSetupGuide.listenBrainzURL.host, "listenbrainz.org")
        XCTAssertEqual(ListenBrainzSetupGuide.tokenURL.host, "listenbrainz.org")
        XCTAssertEqual(ListenBrainzSetupGuide.importersURL.host, "listenbrainz.org")
        XCTAssertEqual(ListenBrainzSetupGuide.musicBrainzSignupURL.host, "musicbrainz.org")
    }
}
