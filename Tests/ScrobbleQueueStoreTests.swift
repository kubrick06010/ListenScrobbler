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

    func testQueueRoundTripPreservesTypedCredentialFreeArtwork() throws {
        let artwork = ArtworkResolution(
            url: "https://cdn.example.test/cover.jpg",
            level: .album,
            provider: .discogs,
            sourceURL: "https://www.discogs.com/release/release-1"
        )
        let track = makeTrack().replacingArtworkResolution(artwork)
        let job = ScrobbleSubmissionJob(backend: .listenBrainz, track: track)
        let store = ScrobbleQueueStore(fileManager: .default, appSupportRoot: tempRoot)

        store.saveJobs([job])

        XCTAssertEqual(store.loadJobs().first?.track.artworkResolution, artwork)
        XCTAssertEqual(store.loadJobs().first?.track.artworkResolution?.level, .album)
        XCTAssertEqual(store.loadJobs().first?.track.artworkResolution?.provider, .discogs)
        XCTAssertEqual(store.loadJobs().first?.track.artworkResolution?.sourceURL, artwork.sourceURL)
    }

    func testQueueDropsCredentialedArtworkWhenPersisting() throws {
        let artwork = ArtworkResolution(
            url: "https://api.example.test/private-cover.jpg",
            level: .track,
            provider: .spotify
        )
        let job = ScrobbleSubmissionJob(
            backend: .compatibility,
            track: makeTrack().replacingArtworkResolution(artwork)
        )
        let store = ScrobbleQueueStore(fileManager: .default, appSupportRoot: tempRoot)

        store.saveJobs([job])

        XCTAssertNil(store.loadJobs().first?.track.artworkResolution)
        let persistedData = try Data(contentsOf: store.queueFileURL)
        XCTAssertFalse(String(decoding: persistedData, as: UTF8.self).contains("private-cover.jpg"))
    }

    func testMigrationSkipsDamagedQueueAndRecoversNextValidQueue() throws {
        let damagedURL = try makeLegacyQueueURL("OpenScrobbler")
        let damagedData = Data("[{\"backend\":\"listenBrainz\"".utf8)
        try damagedData.write(to: damagedURL)
        let validURL = try makeLegacyQueueURL("LegacyOpenScrobbler")
        let job = ScrobbleSubmissionJob(backend: .listenBrainz, track: makeTrack(), attempts: 3, lastError: "Offline")
        try JSONEncoder().encode([job]).write(to: validURL)

        let store = ScrobbleQueueStore(appSupportRoot: tempRoot)

        XCTAssertEqual(store.loadJobs(), [job], "Recover the valid queue including retry state.")
        XCTAssertEqual(try Data(contentsOf: damagedURL), damagedData, "Keep damaged data available for recovery.")
        XCTAssertFalse(FileManager.default.fileExists(atPath: validURL.path))
    }

    func testMigrationLeavesUnrecognizedJSONUntouched() throws {
        let legacyURL = try makeLegacyQueueURL("OpenScrobbler")
        let data = Data("{\"unexpected\":[]}".utf8)
        try data.write(to: legacyURL)

        let store = ScrobbleQueueStore(appSupportRoot: tempRoot)

        XCTAssertTrue(store.loadJobs().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.queueFileURL.path))
        XCTAssertEqual(try Data(contentsOf: legacyURL), data)
    }

    func testMigrationNeverOverwritesAnExistingQueue() throws {
        let store = ScrobbleQueueStore(appSupportRoot: tempRoot)
        let currentJob = ScrobbleSubmissionJob(backend: .listenBrainz, track: makeTrack())
        store.saveJobs([currentJob])
        let legacyURL = try makeLegacyQueueURL("OpenScrobbler")
        let legacyData = try JSONEncoder().encode([makeTrack()])
        try legacyData.write(to: legacyURL)

        let reopenedStore = ScrobbleQueueStore(appSupportRoot: tempRoot)

        XCTAssertEqual(reopenedStore.loadJobs(), [currentJob])
        XCTAssertEqual(try Data(contentsOf: legacyURL), legacyData)
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
