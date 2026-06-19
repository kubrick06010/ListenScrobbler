import XCTest
@testable import ListenScrobbler

final class MobileLibraryScanEngineTests: XCTestCase {
    func testFirstScanCreatesBaselineWithoutSubmittingHistory() async {
        var submitted: [MobileScrobbleCandidate] = []
        let current = [
            "1": snapshot(playCount: 12, lastPlayedAt: Date(timeIntervalSince1970: 200))
        ]

        let result = await MobileLibraryScanEngine.scan(previous: [:], current: current, pending: []) { candidate in
            submitted.append(candidate)
        }

        XCTAssertTrue(result.summary.baselineCreated)
        XCTAssertEqual(result.snapshots, current)
        XCTAssertTrue(result.pending.isEmpty)
        XCTAssertTrue(submitted.isEmpty)
        XCTAssertFalse(result.shouldRefreshListens)
    }

    func testNewPlaySubmitsAndAdvancesSnapshot() async {
        var submitted: [MobileScrobbleCandidate] = []
        let previous = [
            "1": snapshot(playCount: 2, lastPlayedAt: Date(timeIntervalSince1970: 100))
        ]
        let current = [
            "1": snapshot(
                playCount: 3,
                lastPlayedAt: Date(timeIntervalSince1970: 200),
                title: "Sketch for Summer",
                artist: "The Durutti Column"
            )
        ]

        let result = await MobileLibraryScanEngine.scan(previous: previous, current: current, pending: []) { candidate in
            submitted.append(candidate)
        }

        XCTAssertEqual(result.summary.detected, 1)
        XCTAssertEqual(result.summary.submitted, 1)
        XCTAssertEqual(result.snapshots, current)
        XCTAssertTrue(result.pending.isEmpty)
        XCTAssertEqual(submitted.map(\.title), ["Sketch for Summer"])
        XCTAssertTrue(result.shouldRefreshListens)
    }

    func testFailedCandidateIsPersistedAndSnapshotAdvancesToAvoidDuplicateDetection() async {
        let previous = [
            "1": snapshot(playCount: 2, lastPlayedAt: Date(timeIntervalSince1970: 100))
        ]
        let current = [
            "1": snapshot(playCount: 3, lastPlayedAt: Date(timeIntervalSince1970: 200))
        ]

        let result = await MobileLibraryScanEngine.scan(previous: previous, current: current, pending: []) { _ in
            throw TestSubmitError.offline
        }

        XCTAssertEqual(result.summary.detected, 1)
        XCTAssertEqual(result.summary.failed, 1)
        XCTAssertEqual(result.summary.pending, 1)
        XCTAssertEqual(result.snapshots, current)
        XCTAssertEqual(result.pending.first?.attempts, 1)
        XCTAssertEqual(result.pending.first?.lastError, TestSubmitError.offline.localizedDescription)

        var submittedOnSecondScan: [MobileScrobbleCandidate] = []
        let second = await MobileLibraryScanEngine.scan(
            previous: result.snapshots,
            current: current,
            pending: result.pending
        ) { candidate in
            submittedOnSecondScan.append(candidate)
        }

        XCTAssertEqual(second.summary.detected, 0)
        XCTAssertEqual(second.summary.retried, 1)
        XCTAssertEqual(second.summary.retrySubmitted, 1)
        XCTAssertTrue(second.pending.isEmpty)
        XCTAssertEqual(submittedOnSecondScan.count, 1)
    }

    func testPendingRetryFailureUpdatesAttemptWithoutCreatingDuplicateCandidate() async {
        let listenedAt = Date(timeIntervalSince1970: 200)
        let candidate = MobileScrobbleCandidate(
            title: "Track",
            artist: "Artist",
            album: "Album",
            duration: 180,
            listenedAt: listenedAt,
            source: "Music Library"
        )
        let pending = [
            MobilePendingScrobbleQueue.upsertFailure(
                libraryItemID: "1",
                candidate: candidate,
                errorMessage: "First failure",
                into: [],
                now: Date(timeIntervalSince1970: 250)
            )[0]
        ]
        let previous = [
            "1": snapshot(playCount: 3, lastPlayedAt: listenedAt)
        ]
        let current = [
            "1": snapshot(playCount: 3, lastPlayedAt: listenedAt)
        ]

        let result = await MobileLibraryScanEngine.scan(previous: previous, current: current, pending: pending) { _ in
            throw TestSubmitError.offline
        }

        XCTAssertEqual(result.summary.detected, 0)
        XCTAssertEqual(result.summary.retried, 1)
        XCTAssertEqual(result.summary.retryFailed, 1)
        XCTAssertEqual(result.summary.pending, 1)
        XCTAssertEqual(result.pending.first?.attempts, 2)
        XCTAssertEqual(result.pending.first?.lastError, TestSubmitError.offline.localizedDescription)
        XCTAssertEqual(
            result.summary.message,
            String.localizedStringWithFormat(String(localized: "Submitted %d pending plays. %d still pending retry."), 0, 1)
        )
    }

    private func snapshot(
        playCount: Int,
        lastPlayedAt: Date?,
        title: String? = "Track",
        artist: String? = "Artist",
        album: String? = "Album",
        duration: TimeInterval = 180
    ) -> MobileLibraryItemSnapshot {
        MobileLibraryItemSnapshot(
            playCount: playCount,
            lastPlayedAt: lastPlayedAt,
            title: title,
            artist: artist,
            album: album,
            duration: duration
        )
    }
}

private enum TestSubmitError: LocalizedError {
    case offline

    var errorDescription: String? {
        "Network offline"
    }
}
