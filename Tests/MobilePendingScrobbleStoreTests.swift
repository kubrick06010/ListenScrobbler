import XCTest
@testable import ListenScrobbler

final class MobilePendingScrobbleStoreTests: XCTestCase {
    func testStorePersistsPendingScrobbles() {
        let suiteName = "ListenScrobblerTests-Pending-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = MobilePendingScrobbleStore(defaults: defaults)
        let pending = MobilePendingScrobble(libraryItemID: "library-1", candidate: candidate())

        store.save([pending])

        XCTAssertEqual(store.load(), [pending])
    }

    func testUpsertFailureAddsAndThenUpdatesExistingPendingScrobble() {
        let now = Date(timeIntervalSince1970: 100)
        let later = Date(timeIntervalSince1970: 200)
        let candidate = candidate()

        let first = MobilePendingScrobbleQueue.upsertFailure(
            libraryItemID: "library-1",
            candidate: candidate,
            errorMessage: "Network unavailable",
            into: [],
            now: now
        )
        let second = MobilePendingScrobbleQueue.upsertFailure(
            libraryItemID: "library-1",
            candidate: candidate,
            errorMessage: "Still offline",
            into: first,
            now: later
        )

        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].attempts, 2)
        XCTAssertEqual(second[0].lastError, "Still offline")
        XCTAssertEqual(second[0].createdAt, now)
        XCTAssertEqual(second[0].updatedAt, later)
    }

    func testRemovingPendingScrobbleKeepsOtherItems() {
        let first = MobilePendingScrobble(libraryItemID: "library-1", candidate: candidate(title: "One"))
        let second = MobilePendingScrobble(libraryItemID: "library-2", candidate: candidate(title: "Two"))

        let remaining = MobilePendingScrobbleQueue.removing(first, from: [first, second])

        XCTAssertEqual(remaining, [second])
    }

    private func candidate(title: String = "Sketch for Summer") -> MobileScrobbleCandidate {
        MobileScrobbleCandidate(
            title: title,
            artist: "The Durutti Column",
            album: "The Return of the Durutti Column",
            duration: 180,
            listenedAt: Date(timeIntervalSince1970: 200),
            source: "Music Library"
        )
    }

}
