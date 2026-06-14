import XCTest
@testable import ListenScrobbler

final class ScrobbleQueueStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ListenScrobblerQueueTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testStoreUsesListenScrobblerPath() {
        let store = ScrobbleQueueStore(fileManager: .default, appSupportRoot: tempRoot)

        XCTAssertTrue(store.queueFileURL.path.contains("/ListenScrobbler/"))
        XCTAssertFalse(store.queueFileURL.path.contains("/LegacyListenScrobbler/"))
    }

    func testMigratesLegacyTrackQueueIntoNewPath() throws {
        let legacyURL = try makeLegacyQueueURL("LegacyOpenScrobbler")
        let track = makeTrack()
        let data = try JSONEncoder().encode([track])
        try data.write(to: legacyURL, options: .atomic)

        let store = ScrobbleQueueStore(fileManager: .default, appSupportRoot: tempRoot)

        XCTAssertEqual(store.loadJobs().count, 1)
        XCTAssertEqual(store.loadJobs().first?.backend, .compatibility)
        XCTAssertEqual(store.loadJobs().first?.track, track)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.queueFileURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    func testMigratesLegacyJobQueueIntoNewPath() throws {
        let legacyURL = try makeLegacyQueueURL("OpenScrobbler")
        let job = ScrobbleSubmissionJob(backend: .listenBrainz, track: makeTrack())
        let data = try JSONEncoder().encode([job])
        try data.write(to: legacyURL, options: .atomic)

        let store = ScrobbleQueueStore(fileManager: .default, appSupportRoot: tempRoot)

        XCTAssertEqual(store.loadJobs(), [job])
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyURL.path))
    }

    private func makeLegacyQueueURL(_ directoryName: String) throws -> URL {
        let legacyDir = tempRoot.appendingPathComponent(directoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: legacyDir, withIntermediateDirectories: true)
        return legacyDir.appendingPathComponent("scrobble-queue.json")
    }

    private func makeTrack() -> Track {
        Track(
            title: "Track",
            artist: "Artist",
            album: "Album",
            duration: 180,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            sourceApp: "Test"
        )
    }
}
