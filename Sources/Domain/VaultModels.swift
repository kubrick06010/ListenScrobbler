import Foundation

struct SharedMusicEntry: Codable, Identifiable, Equatable {
    enum EntityKind: String, Codable, CaseIterable, Identifiable {
        case track
        case artist
        case album

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .track: return "Track"
            case .artist: return "Artist"
            case .album: return "Album"
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
            case .sent: return "Sent"
            case .received: return "Received"
            case .imported: return "Imported"
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
            case .appLocal: return "Local"
            case .legacyServiceImport: return "Legacy import"
            case .webImport: return "Web import"
            case .fileImport: return "File import"
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
    var imageURL: String?
    var createdAt: Date
    var sentAt: Date?
    var receivedAt: Date?
    var apiStatus: String?

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
            case .userCaptured: return "Local"
            case .webImport: return "Web import"
            case .manualImport: return "File import"
            case .listenBrainzPin: return "ListenBrainz pin"
            }
        }
    }

    var id: UUID
    var ownerUsername: String
    var artist: String
    var track: String
    var album: String?
    var note: String?
    var imageURL: String?
    var compatibilityURL: String?
    var musicBrainzArtistID: String?
    var musicBrainzRecordingID: String?
    var musicBrainzReleaseID: String?
    var firstSeenAt: Date
    var setAt: Date?
    var endedAt: Date?
    var rankMarker: String?
    var source: Source

    var sourceURL: String? {
        compatibilityURL?.nilIfBlank
    }
}

struct SharedMusicVaultBundle: Codable, Equatable {
    static let schemaName = "org.openmusic.openscrobbler.shared"
    static let legacySchemaName = "org.openscrobbler.shared"

    var schema: String
    var schemaVersion: Int
    var exportedBy: String
    var ownerUsername: String
    var exportedAt: Date
    var records: [SharedMusicEntry]

    init(ownerUsername: String, records: [SharedMusicEntry]) {
        self.schema = Self.schemaName
        self.schemaVersion = 1
        self.exportedBy = "OpenScrobbler"
        self.ownerUsername = ownerUsername
        self.exportedAt = Date()
        self.records = records
    }
}

struct ObsessionVaultBundle: Codable, Equatable {
    static let schemaName = "org.openmusic.openscrobbler.obsessions"
    static let legacySchemaName = "org.openscrobbler.obsessions"

    var schema: String
    var schemaVersion: Int
    var exportedBy: String
    var ownerUsername: String
    var exportedAt: Date
    var records: [ObsessionEntry]

    init(ownerUsername: String, records: [ObsessionEntry]) {
        self.schema = Self.schemaName
        self.schemaVersion = 1
        self.exportedBy = "OpenScrobbler"
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
