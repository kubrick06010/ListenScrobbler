import XCTest
@testable import OpenScrobbler

final class MobileLibraryScrobbleDifferTests: XCTestCase {
    func testFirstScanCreatesNoCandidatesWhenThereIsNoPreviousBaseline() {
        let current = [
            "1": snapshot(playCount: 5, lastPlayedAt: Date(timeIntervalSince1970: 100))
        ]

        let candidates = MobileLibraryScrobbleDiffer.candidates(previous: [:], current: current)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testIncreasedPlayCountWithNewerLastPlayedDateCreatesCandidate() throws {
        let previousDate = Date(timeIntervalSince1970: 100)
        let currentDate = Date(timeIntervalSince1970: 200)
        let previous = [
            "1": snapshot(playCount: 5, lastPlayedAt: previousDate)
        ]
        let current = [
            "1": snapshot(
                playCount: 6,
                lastPlayedAt: currentDate,
                title: "Sketch for Summer",
                artist: "The Durutti Column",
                album: "The Return of the Durutti Column",
                duration: 180
            )
        ]

        let candidate = try XCTUnwrap(MobileLibraryScrobbleDiffer.candidates(previous: previous, current: current).first)

        XCTAssertEqual(candidate.id, "1")
        XCTAssertEqual(candidate.candidate.title, "Sketch for Summer")
        XCTAssertEqual(candidate.candidate.artist, "The Durutti Column")
        XCTAssertEqual(candidate.candidate.album, "The Return of the Durutti Column")
        XCTAssertEqual(candidate.candidate.duration, 180)
        XCTAssertEqual(candidate.candidate.listenedAt, currentDate)
        XCTAssertEqual(candidate.candidate.source, "Music Library")
    }

    func testPlayCountIncreaseWithoutNewerDateDoesNotCreateCandidate() {
        let date = Date(timeIntervalSince1970: 100)
        let previous = [
            "1": snapshot(playCount: 5, lastPlayedAt: date)
        ]
        let current = [
            "1": snapshot(playCount: 6, lastPlayedAt: date)
        ]

        let candidates = MobileLibraryScrobbleDiffer.candidates(previous: previous, current: current)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testMissingTitleOrArtistDoesNotCreateCandidate() {
        let previous = [
            "1": snapshot(playCount: 5, lastPlayedAt: Date(timeIntervalSince1970: 100)),
            "2": snapshot(playCount: 5, lastPlayedAt: Date(timeIntervalSince1970: 100))
        ]
        let current = [
            "1": snapshot(playCount: 6, lastPlayedAt: Date(timeIntervalSince1970: 200), title: "", artist: "Artist"),
            "2": snapshot(playCount: 6, lastPlayedAt: Date(timeIntervalSince1970: 200), title: "Track", artist: " ")
        ]

        let candidates = MobileLibraryScrobbleDiffer.candidates(previous: previous, current: current)

        XCTAssertTrue(candidates.isEmpty)
    }

    func testUnchangedPlayCountDoesNotCreateCandidate() {
        let previous = [
            "1": snapshot(playCount: 5, lastPlayedAt: Date(timeIntervalSince1970: 100))
        ]
        let current = [
            "1": snapshot(playCount: 5, lastPlayedAt: Date(timeIntervalSince1970: 200))
        ]

        let candidates = MobileLibraryScrobbleDiffer.candidates(previous: previous, current: current)

        XCTAssertTrue(candidates.isEmpty)
    }

    private func snapshot(
        playCount: Int,
        lastPlayedAt: Date?,
        title: String? = "Track",
        artist: String? = "Artist",
        album: String? = "Album",
        duration: TimeInterval = 120
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
