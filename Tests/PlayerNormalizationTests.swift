import XCTest
@testable import ListenScrobbler

final class PlayerNormalizationTests: XCTestCase {
    func testMonitorDetectsAlreadyPlayingTrackAtStartup() {
        let provider = StaticMetadataProvider(
            metadata: PlayerMetadata(
                title: "Startup Track",
                artist: "Startup Artist",
                album: "Startup Album",
                duration: 240,
                playbackPosition: 75
            )
        )
        let monitor = DistributedPlayerMonitor(
            notificationName: "org.listenscrobbler.tests.startup.\(UUID().uuidString)",
            sourceApp: "Spotify",
            metadataProvider: provider,
            isSourceRunning: { _ in true }
        )
        var detectedTrack: Track?
        monitor.onEvent = { event in
            if case let .trackStarted(track) = event {
                detectedTrack = track
            }
        }

        monitor.start()
        monitor.stop()

        XCTAssertEqual(detectedTrack?.title, "Startup Track")
        XCTAssertEqual(detectedTrack?.sourceApp, "Spotify")
        XCTAssertEqual(
            detectedTrack.map { Date().timeIntervalSince($0.startedAt) } ?? 0,
            75,
            accuracy: 1
        )
    }

    func testMonitorDoesNotQueryAPlayerThatIsNotRunning() {
        let provider = CountingMetadataProvider()
        let monitor = DistributedPlayerMonitor(
            notificationName: "org.listenscrobbler.tests.stopped.\(UUID().uuidString)",
            sourceApp: "Spotify",
            metadataProvider: provider,
            isSourceRunning: { _ in false }
        )

        monitor.start()
        monitor.stop()

        XCTAssertEqual(provider.fetchCount, 0)
    }

    func testPausedPayloadMapsToPausedEvent() {
        let payload: [AnyHashable: Any] = ["Player State": "Paused"]
        let event = PlayerNotificationNormalizer.event(
            from: payload,
            sourceApp: "Spotify",
            metadataProvider: nil
        )

        guard case .paused? = event else {
            return XCTFail("Expected paused event")
        }
    }

    func testPlayingPayloadWithMetadataCreatesTrackEvent() {
        let payload: [AnyHashable: Any] = [
            "Player State": "Playing",
            "Name": "Everlong",
            "Artist": "Foo Fighters",
            "Album": "The Colour and the Shape",
            "Duration": 250_000
        ]
        let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let event = PlayerNotificationNormalizer.event(
            from: payload,
            sourceApp: "Spotify",
            metadataProvider: nil,
            now: { fixedDate }
        )

        guard case let .trackStarted(track)? = event else {
            return XCTFail("Expected trackStarted event")
        }
        XCTAssertEqual(track.title, "Everlong")
        XCTAssertEqual(track.artist, "Foo Fighters")
        XCTAssertEqual(track.album, "The Colour and the Shape")
        XCTAssertEqual(Int(track.duration), 250)
        XCTAssertEqual(track.startedAt, fixedDate)
        XCTAssertEqual(track.sourceApp, "Spotify")
    }

    func testMissingFieldsUseFallbackMetadata() {
        let payload: [AnyHashable: Any] = ["Player State": "Playing"]
        let fallback = StaticMetadataProvider(
            metadata: PlayerMetadata(
                title: "Fallback Track",
                artist: "Fallback Artist",
                album: "Fallback Album",
                duration: 180
            )
        )

        let event = PlayerNotificationNormalizer.event(
            from: payload,
            sourceApp: "Apple Music",
            metadataProvider: fallback
        )

        guard case let .trackStarted(track)? = event else {
            return XCTFail("Expected fallback trackStarted event")
        }
        XCTAssertEqual(track.title, "Fallback Track")
        XCTAssertEqual(track.artist, "Fallback Artist")
        XCTAssertEqual(Int(track.duration), 180)
    }

    func testStoppedPayloadMapsToStoppedEvent() {
        let payload: [AnyHashable: Any] = ["Player State": "Stopped"]
        let event = PlayerNotificationNormalizer.event(
            from: payload,
            sourceApp: "iTunes",
            metadataProvider: nil
        )

        guard case .stopped? = event else {
            return XCTFail("Expected stopped event")
        }
    }
}

private final class CountingMetadataProvider: PlayerMetadataProviding {
    private(set) var fetchCount = 0

    func fetchMetadata(for sourceApp: String) -> PlayerMetadata? {
        _ = sourceApp
        fetchCount += 1
        return nil
    }
}

private struct StaticMetadataProvider: PlayerMetadataProviding {
    let metadata: PlayerMetadata

    func fetchMetadata(for sourceApp: String) -> PlayerMetadata? {
        _ = sourceApp
        return metadata
    }
}
