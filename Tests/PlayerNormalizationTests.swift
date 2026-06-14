import XCTest
@testable import ListenScrobbler

final class PlayerNormalizationTests: XCTestCase {
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

private struct StaticMetadataProvider: PlayerMetadataProviding {
    let metadata: PlayerMetadata

    func fetchMetadata(for sourceApp: String) -> PlayerMetadata? {
        _ = sourceApp
        return metadata
    }
}
