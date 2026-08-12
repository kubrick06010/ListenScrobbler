import Foundation

/// Data-only registry of providers safe to call from a distributed build.
/// Credentialed services are intentionally excluded from the runtime catalog.
struct ArtworkProviderOption: Identifiable, Equatable {
    let provider: ArtworkProvider
    let displayName: String
    let supportedLevels: Set<ArtworkLevel>
    let requiresAuthentication: Bool
    let requiresAttribution: Bool
    let status: Status
    let documentationURL: URL

    enum Status: String, Equatable {
        case active
        case candidate
        case manualOnly
    }

    var id: String { provider.rawValue }
}

enum ArtworkProviderCatalog {
    static let options: [ArtworkProviderOption] = [
        .init(
            provider: .player,
            displayName: "Current player",
            supportedLevels: [.track],
            requiresAuthentication: false,
            requiresAttribution: false,
            status: .active,
            documentationURL: URL(string: "https://developer.apple.com/documentation/mediaplayer")!
        ),
        .init(
            provider: .coverArtArchive,
            displayName: "MusicBrainz Cover Art Archive",
            supportedLevels: [.album, .ep],
            requiresAuthentication: false,
            requiresAttribution: false,
            status: .active,
            documentationURL: URL(string: "https://musicbrainz.org/doc/Cover_Art_Archive/API")!
        ),
        .init(
            provider: .wikipediaWikidata,
            displayName: "Wikidata / Wikimedia Commons",
            supportedLevels: [.artist],
            requiresAuthentication: false,
            requiresAttribution: true,
            status: .active,
            documentationURL: URL(string: "https://www.wikidata.org/wiki/Help:Wikimedia_Commons")!
        ),
        .init(
            provider: .appleMusic,
            displayName: "Apple Music API",
            supportedLevels: [.track, .album, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://developer.apple.com/documentation/applemusicapi")!
        ),
        .init(
            provider: .spotify,
            displayName: "Spotify Web API",
            supportedLevels: [.track, .album, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://developer.spotify.com/documentation/web-api/reference/get-an-album")!
        ),
        .init(
            provider: .deezer,
            displayName: "Deezer API",
            supportedLevels: [.track, .album, .artist],
            requiresAuthentication: false,
            requiresAttribution: true,
            status: .active,
            documentationURL: URL(string: "https://developers.deezer.com/api")!
        ),
        .init(
            provider: .discogs,
            displayName: "Discogs API",
            supportedLevels: [.album, .ep, .artist],
            requiresAuthentication: false,
            requiresAttribution: true,
            status: .active,
            documentationURL: URL(string: "https://www.discogs.com/developers")!
        )
    ]
}
