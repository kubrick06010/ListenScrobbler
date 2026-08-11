import XCTest
@testable import ListenScrobbler

final class ArtistExperienceDataTests: XCTestCase {
    func testConstellationCombinesOpenConnectionsWithCompatibilitySimilarity() {
        let compatibilityArtist = CompatibilityArtistDetails(
            name: "Richard H. Kirk",
            imageURL: nil,
            listeners: nil,
            playcount: nil,
            userPlaycount: 12,
            url: nil,
            summary: nil,
            tags: [],
            similarArtists: [
                .init(id: "duplicate", name: "Cabaret Voltaire", imageURL: nil, url: nil),
                .init(id: "aphex", name: "Aphex Twin", imageURL: "https://example.com/aphex.jpg", url: nil)
            ]
        )
        let openDetails = OpenMusicEntityDetails(
            trackName: nil,
            artistName: "Richard H. Kirk",
            releaseName: nil,
            recordingMBID: nil,
            artistMBID: "artist-id",
            releaseMBID: nil,
            imageURL: nil,
            artistImageURL: nil,
            artworkResolution: nil,
            artistArtworkResolution: nil,
            artistSummary: nil,
            artistSummaryURL: nil,
            artistSummaryLanguageCode: nil,
            editorialInformation: nil,
            artistBeginDate: "1956-03-21",
            artistEndDate: "2021-09-21",
            artistEnded: true,
            artistArea: "United Kingdom",
            disambiguation: nil,
            country: "GB",
            type: "Person",
            tags: [],
            links: [],
            artistConnections: [
                .init(id: "member-cabaret", name: "Cabaret Voltaire", relationship: "Member of"),
                .init(id: "alias-sandoz", name: "Sandoz", relationship: "Alias")
            ]
        )

        let data = ArtistExperienceData(artist: compatibilityArtist, openDetails: openDetails, enrichment: nil)

        XCTAssertEqual(data.lifeSpan, "1956–2021")
        XCTAssertEqual(data.constellationNodes.map(\.name), ["Cabaret Voltaire", "Aphex Twin", "Sandoz"])
        XCTAssertEqual(data.constellationNodes.map(\.kind), [.connection, .similarity, .alias])
        XCTAssertEqual(data.constellationNodes[1].imageURL, "https://example.com/aphex.jpg")
    }
}
