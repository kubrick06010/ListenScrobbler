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
        XCTAssertEqual(ListenBrainzSetupGuide.lastFMImportURL.host, "listenbrainz.org")
    }

    func testOnboardingKeepsLastFMModernStoryAndActions() {
        XCTAssertEqual(ListenBrainzSetupGuide.eyebrow, "Last.fm Modern")
        XCTAssertFalse(ListenBrainzSetupGuide.headline.isEmpty)
        XCTAssertFalse(ListenBrainzSetupGuide.summary.isEmpty)
        XCTAssertEqual(
            ListenBrainzSetupGuide.onboardingFeatures.map(\.id),
            ["timeline", "identity", "discovery"]
        )
        XCTAssertEqual(
            ListenBrainzSetupGuide.onboardingActions.map(\.id),
            ["create", "token", "import"]
        )
        XCTAssertTrue(ListenBrainzSetupGuide.onboardingFeatures.allSatisfy { !$0.symbolName.isEmpty })
        XCTAssertTrue(ListenBrainzSetupGuide.onboardingActions.allSatisfy { !$0.url.absoluteString.isEmpty })
    }
}
