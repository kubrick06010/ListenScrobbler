import XCTest
@testable import ListenScrobbler

final class CompatibilityAPIErrorTests: XCTestCase {
    func testInvalidSessionHasReauthHint() {
        let error = CompatibilityAPIError.invalidSession
        XCTAssertEqual(error.recoverySuggestion, AppLocalization.string("Sign in again to refresh your compatibility session."))
    }

    func testNetworkUnavailableMentionsAutoRetry() {
        let error = CompatibilityAPIError.networkUnavailable
        XCTAssertEqual(
            error.recoverySuggestion,
            AppLocalization.string("Check network connectivity. Queued listens will retry automatically.")
        )
    }
}
