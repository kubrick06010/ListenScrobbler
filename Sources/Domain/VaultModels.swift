import Foundation

extension Track {
    var persistableArtworkResolution: ArtworkResolution? {
        artworkResolution?.persistableArtworkResolution
    }

    func replacingArtworkResolution(_ resolution: ArtworkResolution?) -> Track {
        Track(
            id: id,
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            startedAt: startedAt,
            sourceApp: sourceApp,
            sourceMetadata: sourceMetadata,
            artworkResolution: resolution?.persistableArtworkResolution
        )
    }
}

struct SharedMusicEntry: Codable, Identifiable, Equatable {
    enum EntityKind: String, Codable, CaseIterable, Identifiable {
        case track
        case artist
        case album

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .track: return AppLocalization.string("Track")
            case .artist: return AppLocalization.string("Artist")
            case .album: return AppLocalization.string("Album")
            }
        }
    }

    enum Direction: String, Codable, CaseIterable, Identifiable {
        case sent
        case received
        case imported

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .sent: return AppLocalization.string("Sent")
            case .received: return AppLocalization.string("Received")
            case .imported: return AppLocalization.string("Imported")
            }
        }
    }

    enum Source: String, Codable {
        case appLocal
        case legacyServiceImport = "legacyCompatibilityAttempt"
        case webImport
        case fileImport

        var displayName: String {
            switch self {
            case .appLocal: return AppLocalization.string("Local")
            case .legacyServiceImport: return AppLocalization.string("Legacy import")
            case .webImport: return AppLocalization.string("Web import")
            case .fileImport: return AppLocalization.string("File import")
            }
        }
    }

    var id: UUID
    var ownerUsername: String
    var direction: Direction
    var source: Source
    var entityKind: EntityKind
    var artist: String
    var track: String?
    var album: String?
    var recipients: [String]
    var sender: String?
    var message: String?
    var isPublic: Bool
    var compatibilityURL: String?
    var musicBrainzArtistID: String?
    var musicBrainzRecordingID: String?
    var musicBrainzReleaseID: String?
    var artworkResolution: ArtworkResolution?
    var createdAt: Date
    var sentAt: Date?
    var receivedAt: Date?
    var apiStatus: String?

    /// Compatibility accessor for existing vault UI and JSPF export. The
    /// persisted source of truth is the typed resolution above.
    var imageURL: String? {
        artworkResolution?.automaticArtworkResolution?.url
    }

    init(
        id: UUID,
        ownerUsername: String,
        direction: Direction,
        source: Source,
        entityKind: EntityKind,
        artist: String,
        track: String?,
        album: String?,
        recipients: [String],
        sender: String?,
        message: String?,
        isPublic: Bool,
        compatibilityURL: String?,
        musicBrainzArtistID: String?,
        musicBrainzRecordingID: String?,
        musicBrainzReleaseID: String?,
        imageURL: String? = nil,
        artworkResolution: ArtworkResolution? = nil,
        createdAt: Date,
        sentAt: Date?,
        receivedAt: Date?,
        apiStatus: String?
    ) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.direction = direction
        self.source = source
        self.entityKind = entityKind
        self.artist = artist
        self.track = track
        self.album = album
        self.recipients = recipients
        self.sender = sender
        self.message = message
        self.isPublic = isPublic
        self.compatibilityURL = compatibilityURL
        self.musicBrainzArtistID = musicBrainzArtistID
        self.musicBrainzRecordingID = musicBrainzRecordingID
        self.musicBrainzReleaseID = musicBrainzReleaseID
        let hasTypedResolution = artworkResolution != nil
        self.artworkResolution = artworkResolution?.automaticArtworkResolution
            ?? (hasTypedResolution ? nil : .legacy(
                url: imageURL,
                level: entityKind == .artist ? .artist : (entityKind == .album ? .album : .track)
            ))
        self.createdAt = createdAt
        self.sentAt = sentAt
        self.receivedAt = receivedAt
        self.apiStatus = apiStatus
    }

    private enum CodingKeys: String, CodingKey {
        case id, ownerUsername, direction, source, entityKind, artist, track, album
        case recipients, sender, message, isPublic, compatibilityURL
        case musicBrainzArtistID, musicBrainzRecordingID, musicBrainzReleaseID
        case imageURL, artworkResolution, createdAt, sentAt, receivedAt, apiStatus
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerUsername = try container.decode(String.self, forKey: .ownerUsername)
        direction = try container.decode(Direction.self, forKey: .direction)
        source = try container.decode(Source.self, forKey: .source)
        entityKind = try container.decode(EntityKind.self, forKey: .entityKind)
        artist = try container.decode(String.self, forKey: .artist)
        track = try container.decodeIfPresent(String.self, forKey: .track)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        recipients = try container.decode([String].self, forKey: .recipients)
        sender = try container.decodeIfPresent(String.self, forKey: .sender)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        isPublic = try container.decode(Bool.self, forKey: .isPublic)
        compatibilityURL = try container.decodeIfPresent(String.self, forKey: .compatibilityURL)
        musicBrainzArtistID = try container.decodeIfPresent(String.self, forKey: .musicBrainzArtistID)
        musicBrainzRecordingID = try container.decodeIfPresent(String.self, forKey: .musicBrainzRecordingID)
        musicBrainzReleaseID = try container.decodeIfPresent(String.self, forKey: .musicBrainzReleaseID)
        let hasTypedResolution = container.contains(.artworkResolution)
        artworkResolution = try container.decodeIfPresent(ArtworkResolution.self, forKey: .artworkResolution)?.persistableArtworkResolution
            ?? (hasTypedResolution ? nil : .legacy(
                url: try container.decodeIfPresent(String.self, forKey: .imageURL),
                level: entityKind == .artist ? .artist : (entityKind == .album ? .album : .track)
            ))
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        sentAt = try container.decodeIfPresent(Date.self, forKey: .sentAt)
        receivedAt = try container.decodeIfPresent(Date.self, forKey: .receivedAt)
        apiStatus = try container.decodeIfPresent(String.self, forKey: .apiStatus)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerUsername, forKey: .ownerUsername)
        try container.encode(direction, forKey: .direction)
        try container.encode(source, forKey: .source)
        try container.encode(entityKind, forKey: .entityKind)
        try container.encode(artist, forKey: .artist)
        try container.encodeIfPresent(track, forKey: .track)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encode(recipients, forKey: .recipients)
        try container.encodeIfPresent(sender, forKey: .sender)
        try container.encodeIfPresent(message, forKey: .message)
        try container.encode(isPublic, forKey: .isPublic)
        try container.encodeIfPresent(compatibilityURL, forKey: .compatibilityURL)
        try container.encodeIfPresent(musicBrainzArtistID, forKey: .musicBrainzArtistID)
        try container.encodeIfPresent(musicBrainzRecordingID, forKey: .musicBrainzRecordingID)
        try container.encodeIfPresent(musicBrainzReleaseID, forKey: .musicBrainzReleaseID)
        try container.encodeIfPresent(artworkResolution, forKey: .artworkResolution)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(sentAt, forKey: .sentAt)
        try container.encodeIfPresent(receivedAt, forKey: .receivedAt)
        try container.encodeIfPresent(apiStatus, forKey: .apiStatus)
    }

    var title: String {
        switch entityKind {
        case .track:
            return track?.nilIfBlank ?? artist
        case .artist:
            return artist
        case .album:
            return album?.nilIfBlank ?? artist
        }
    }

    var participantSummary: String {
        let joined = recipients.filter { !$0.isBlank }.joined(separator: ", ")
        if let sender = sender?.nilIfBlank, direction != .sent {
            return joined.isEmpty ? sender : "\(sender) -> \(joined)"
        }
        return joined.isEmpty ? ownerUsername : joined
    }

    var sourceURL: String? {
        compatibilityURL?.nilIfBlank
    }
}

struct ObsessionEntry: Codable, Identifiable, Equatable {
    enum Source: String, Codable {
        case userCaptured
        case webImport
        case manualImport
        case listenBrainzPin

        var displayName: String {
            switch self {
            case .userCaptured: return AppLocalization.string("Local")
            case .webImport: return AppLocalization.string("Web import")
            case .manualImport: return AppLocalization.string("File import")
            case .listenBrainzPin: return AppLocalization.string("ListenBrainz pin")
            }
        }
    }

    var id: UUID
    var ownerUsername: String
    var artist: String
    var track: String
    var album: String?
    var note: String?
    var artworkResolution: ArtworkResolution?
    var compatibilityURL: String?
    var musicBrainzArtistID: String?
    var musicBrainzRecordingID: String?
    var musicBrainzReleaseID: String?
    var firstSeenAt: Date
    var setAt: Date?
    var endedAt: Date?
    var rankMarker: String?
    var source: Source

    var imageURL: String? {
        artworkResolution?.automaticArtworkResolution?.url
    }

    init(
        id: UUID,
        ownerUsername: String,
        artist: String,
        track: String,
        album: String?,
        note: String?,
        imageURL: String? = nil,
        artworkResolution: ArtworkResolution? = nil,
        compatibilityURL: String?,
        musicBrainzArtistID: String?,
        musicBrainzRecordingID: String?,
        musicBrainzReleaseID: String?,
        firstSeenAt: Date,
        setAt: Date?,
        endedAt: Date?,
        rankMarker: String?,
        source: Source
    ) {
        self.id = id
        self.ownerUsername = ownerUsername
        self.artist = artist
        self.track = track
        self.album = album
        self.note = note
        let hasTypedResolution = artworkResolution != nil
        self.artworkResolution = artworkResolution?.persistableArtworkResolution
            ?? (hasTypedResolution ? nil : .legacy(url: imageURL, level: .track))
        self.compatibilityURL = compatibilityURL
        self.musicBrainzArtistID = musicBrainzArtistID
        self.musicBrainzRecordingID = musicBrainzRecordingID
        self.musicBrainzReleaseID = musicBrainzReleaseID
        self.firstSeenAt = firstSeenAt
        self.setAt = setAt
        self.endedAt = endedAt
        self.rankMarker = rankMarker
        self.source = source
    }

    private enum CodingKeys: String, CodingKey {
        case id, ownerUsername, artist, track, album, note, imageURL, artworkResolution
        case compatibilityURL, musicBrainzArtistID, musicBrainzRecordingID, musicBrainzReleaseID
        case firstSeenAt, setAt, endedAt, rankMarker, source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        ownerUsername = try container.decode(String.self, forKey: .ownerUsername)
        artist = try container.decode(String.self, forKey: .artist)
        track = try container.decode(String.self, forKey: .track)
        album = try container.decodeIfPresent(String.self, forKey: .album)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        let hasTypedResolution = container.contains(.artworkResolution)
        artworkResolution = try container.decodeIfPresent(ArtworkResolution.self, forKey: .artworkResolution)?.persistableArtworkResolution
            ?? (hasTypedResolution ? nil : .legacy(url: try container.decodeIfPresent(String.self, forKey: .imageURL), level: .track))
        compatibilityURL = try container.decodeIfPresent(String.self, forKey: .compatibilityURL)
        musicBrainzArtistID = try container.decodeIfPresent(String.self, forKey: .musicBrainzArtistID)
        musicBrainzRecordingID = try container.decodeIfPresent(String.self, forKey: .musicBrainzRecordingID)
        musicBrainzReleaseID = try container.decodeIfPresent(String.self, forKey: .musicBrainzReleaseID)
        firstSeenAt = try container.decode(Date.self, forKey: .firstSeenAt)
        setAt = try container.decodeIfPresent(Date.self, forKey: .setAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        rankMarker = try container.decodeIfPresent(String.self, forKey: .rankMarker)
        source = try container.decode(Source.self, forKey: .source)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(ownerUsername, forKey: .ownerUsername)
        try container.encode(artist, forKey: .artist)
        try container.encode(track, forKey: .track)
        try container.encodeIfPresent(album, forKey: .album)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(artworkResolution, forKey: .artworkResolution)
        try container.encodeIfPresent(imageURL, forKey: .imageURL)
        try container.encodeIfPresent(compatibilityURL, forKey: .compatibilityURL)
        try container.encodeIfPresent(musicBrainzArtistID, forKey: .musicBrainzArtistID)
        try container.encodeIfPresent(musicBrainzRecordingID, forKey: .musicBrainzRecordingID)
        try container.encodeIfPresent(musicBrainzReleaseID, forKey: .musicBrainzReleaseID)
        try container.encode(firstSeenAt, forKey: .firstSeenAt)
        try container.encodeIfPresent(setAt, forKey: .setAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(rankMarker, forKey: .rankMarker)
        try container.encode(source, forKey: .source)
    }

    var sourceURL: String? {
        compatibilityURL?.nilIfBlank
    }
}

struct SharedMusicVaultBundle: Codable, Equatable {
    static let schemaName = "org.openmusic.listenscrobbler.shared"
    static let legacySchemaName = "org.listenscrobbler.shared"

    var schema: String
    var schemaVersion: Int
    var exportedBy: String
    var ownerUsername: String
    var exportedAt: Date
    var records: [SharedMusicEntry]

    init(ownerUsername: String, records: [SharedMusicEntry]) {
        self.schema = Self.schemaName
        self.schemaVersion = 1
        self.exportedBy = "ListenScrobbler"
        self.ownerUsername = ownerUsername
        self.exportedAt = Date()
        self.records = records
    }
}

struct ObsessionVaultBundle: Codable, Equatable {
    static let schemaName = "org.openmusic.listenscrobbler.obsessions"
    static let legacySchemaName = "org.listenscrobbler.obsessions"

    var schema: String
    var schemaVersion: Int
    var exportedBy: String
    var ownerUsername: String
    var exportedAt: Date
    var records: [ObsessionEntry]

    init(ownerUsername: String, records: [ObsessionEntry]) {
        self.schema = Self.schemaName
        self.schemaVersion = 1
        self.exportedBy = "ListenScrobbler"
        self.ownerUsername = ownerUsername
        self.exportedAt = Date()
        self.records = records
    }
}

extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct OpenPlaylistBundle: Codable, Equatable {
    var playlist: OpenPlaylistJSPF
}

struct OpenPlaylistJSPF: Codable, Equatable {
    var title: String
    var creator: String
    var annotation: String?
    var identifier: String?
    var date: Date
    var track: [OpenPlaylistTrack]
    var `extension`: [String: OpenPlaylistExtensionPayload]?
}

struct OpenPlaylistTrack: Codable, Equatable {
    var identifier: String?
    var title: String?
    var creator: String?
    var album: String?
    var annotation: String?
    var image: String?
    var duration: Int?
    var `extension`: [String: OpenPlaylistExtensionPayload]?
}

struct OpenPlaylistExtensionPayload: Codable, Equatable {
    var artistMbid: String?
    var recordingMbid: String?
    var releaseMbid: String?
    var publicFlag: Bool?

    enum CodingKeys: String, CodingKey {
        case artistMbid = "artist_mbid"
        case recordingMbid = "recording_mbid"
        case releaseMbid = "release_mbid"
        case publicFlag = "public"
    }
}
