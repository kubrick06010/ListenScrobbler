import Foundation

struct TrackSourceMetadata: Hashable, Codable {
    let mediaPlayer: String?
    let musicService: String?
    let musicServiceName: String?
    let originURL: String?
    let spotifyID: String?
    let durationPlayed: TimeInterval?
    let originalSubmissionClient: String?

    init(
        mediaPlayer: String? = nil,
        musicService: String? = nil,
        musicServiceName: String? = nil,
        originURL: String? = nil,
        spotifyID: String? = nil,
        durationPlayed: TimeInterval? = nil,
        originalSubmissionClient: String? = nil
    ) {
        self.mediaPlayer = mediaPlayer
        self.musicService = musicService
        self.musicServiceName = musicServiceName
        self.originURL = originURL
        self.spotifyID = spotifyID
        self.durationPlayed = durationPlayed
        self.originalSubmissionClient = originalSubmissionClient
    }
}

struct Track: Identifiable, Hashable, Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let startedAt: Date
    let sourceApp: String?
    let sourceMetadata: TrackSourceMetadata?
    let artworkResolution: ArtworkResolution?

    /// Compatibility accessor for older call sites. New consumers should use
    /// `artworkResolution` so the URL cannot lose its level or provenance.
    var artworkURL: String? {
        artworkResolution?.automaticArtworkResolution?.url
    }

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        startedAt: Date,
        sourceApp: String? = nil,
        sourceMetadata: TrackSourceMetadata? = nil,
        artworkURL: String? = nil,
        artworkResolution: ArtworkResolution? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.startedAt = startedAt
        self.sourceApp = sourceApp
        self.sourceMetadata = sourceMetadata
        self.artworkResolution = artworkResolution
            ?? .legacy(url: artworkURL, level: .track, provider: .player)
    }

    var fingerprint: String {
        "\(artist.lowercased())|\(title.lowercased())|\(Int(startedAt.timeIntervalSince1970))"
    }

    static let preview = Track(
        title: "Instant Crush",
        artist: "Daft Punk",
        album: "Random Access Memories",
        duration: 337,
        startedAt: .now,
        sourceApp: "Preview"
    )

    private enum CodingKeys: String, CodingKey {
        case id, title, artist, album, duration, startedAt, sourceApp, sourceMetadata
        case artworkURL
        case artworkResolution
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        sourceMetadata = try container.decodeIfPresent(TrackSourceMetadata.self, forKey: .sourceMetadata)
        artworkResolution = try container.decodeIfPresent(ArtworkResolution.self, forKey: .artworkResolution)
            ?? .legacy(
                url: try container.decodeIfPresent(String.self, forKey: .artworkURL),
                level: .track,
                provider: .player
            )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encode(duration, forKey: .duration)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
        try container.encodeIfPresent(sourceMetadata, forKey: .sourceMetadata)
        try container.encodeIfPresent(artworkResolution, forKey: .artworkResolution)
        // Keep the old key for queue files and integrations that have not yet
        // migrated to the typed result.
        try container.encodeIfPresent(artworkURL, forKey: .artworkURL)
    }
}
