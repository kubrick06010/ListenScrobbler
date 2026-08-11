import Foundation

/// A deliberately data-only registry so new artwork providers can be added
/// without changing the resolution policy or leaking provider SDK models into
/// SwiftUI. The first implementation uses the open providers and existing
/// player/compatibility data; the remaining entries are integration candidates.
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
            provider: .compatibilityAPI,
            displayName: "Configured compatibility provider",
            supportedLevels: [.track, .album, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .active,
            documentationURL: URL(string: "https://www.last.fm/api")!
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
            status: .candidate,
            documentationURL: URL(string: "https://developers.deezer.com/api")!
        ),
        .init(
            provider: .discogs,
            displayName: "Discogs API",
            supportedLevels: [.album, .ep, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://www.discogs.com/developers")!
        ),
        .init(
            provider: .allMusic,
            displayName: "AllMusic",
            supportedLevels: [.track, .album, .ep, .artist],
            requiresAuthentication: false,
            requiresAttribution: true,
            status: .manualOnly,
            documentationURL: URL(string: "https://www.allmusic.com")!
        ),
        .init(
            provider: .lastFM,
            displayName: "Last.fm API",
            supportedLevels: [.track, .album, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://www.last.fm/api/show/track.getInfo")!
        ),
        .init(
            provider: .theAudioDB,
            displayName: "TheAudioDB",
            supportedLevels: [.track, .album, .ep, .artist],
            requiresAuthentication: false,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://www.theaudiodb.com/free_music_api")!
        ),
        .init(
            provider: .fanartTV,
            displayName: "Fanart.tv",
            supportedLevels: [.album, .ep, .artist],
            requiresAuthentication: true,
            requiresAttribution: true,
            status: .candidate,
            documentationURL: URL(string: "https://api.fanart.tv/")!
        )
    ]
}
