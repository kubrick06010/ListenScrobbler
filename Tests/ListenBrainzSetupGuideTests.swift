import XCTest
@testable import ListenScrobbler

final class ListenBrainzSetupGuideTests: XCTestCase {
    func testSetupGuideKeepsModernAccountFlow() {
        XCTAssertEqual(
            ListenBrainzSetupGuide.steps.map(\.id),
            ["account", "token", "enable", "verify", "imports"]
        )
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.title.isEmpty })
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.detail.isEmpty })
        XCTAssertTrue(ListenBrainzSetupGuide.steps.allSatisfy { !$0.symbolName.isEmpty })
    }

    func testSetupGuideLinksToListenBrainzAndMusicBrainzSurfaces() {
        XCTAssertEqual(ListenBrainzSetupGuide.listenBrainzURL.host, "listenbrainz.org")
        XCTAssertEqual(ListenBrainzSetupGuide.tokenURL.host, "listenbrainz.org")
        XCTAssertEqual(ListenBrainzSetupGuide.importersURL.host, "listenbrainz.org")
        XCTAssertTrue(ListenBrainzSetupGuide.addDataURL.absoluteString.hasPrefix("https://listenbrainz.org/add-data"))
        XCTAssertEqual(ListenBrainzSetupGuide.musicBrainzSignupURL.host, "musicbrainz.org")
        XCTAssertFalse(ListenBrainzSetupGuide.importersURL.absoluteString.contains("music-services"))
    }

    func testOnboardingKeepsOpenMusicStoryAndActions() {
        XCTAssertEqual(ListenBrainzSetupGuide.eyebrow, String(localized: "Open Music Setup"))
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
