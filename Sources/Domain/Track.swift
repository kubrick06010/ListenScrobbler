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
    let artworkURL: String?

    init(
        id: UUID = UUID(),
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        startedAt: Date,
        sourceApp: String? = nil,
        sourceMetadata: TrackSourceMetadata? = nil,
        artworkURL: String? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.startedAt = startedAt
        self.sourceApp = sourceApp
        self.sourceMetadata = sourceMetadata
        self.artworkURL = artworkURL
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
}
