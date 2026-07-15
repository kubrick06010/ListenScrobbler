import Foundation

struct PlayerMetadata {
    let title: String
    let artist: String
    let album: String?
    let duration: TimeInterval
    let artworkURL: String?
    let playbackPosition: TimeInterval?

    init(
        title: String,
        artist: String,
        album: String?,
        duration: TimeInterval,
        artworkURL: String? = nil,
        playbackPosition: TimeInterval? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
        self.playbackPosition = playbackPosition
    }
}

protocol PlayerMetadataProviding {
    func fetchMetadata(for sourceApp: String) -> PlayerMetadata?
}

enum PlayerNotificationNormalizer {
    static func event(
        from info: [AnyHashable: Any],
        sourceApp: String,
        metadataProvider: PlayerMetadataProviding?,
        now: () -> Date = Date.init
    ) -> PlayerEvent? {
        let state = normalizedState(from: info)
        switch state {
        case .paused:
            return .paused
        case .stopped:
            return .stopped
        case .playing, .unknown:
            break
        }

        var title = firstString(in: info, keys: ["Name", "Track Name", "itemName", "title"]) ?? ""
        var artist = firstString(in: info, keys: ["Artist", "artist"]) ?? ""
        var album = firstString(in: info, keys: ["Album", "album"])
        var duration = durationSeconds(from: info) ?? 0
        var artworkURL = firstString(
            in: info,
            keys: ["Artwork URL", "ArtworkURL", "artworkURL", "artworkUrl", "Album Artwork URL"]
        )

        if (title.isEmpty || artist.isEmpty || artworkURL?.nilIfBlank == nil),
           let fallback = metadataProvider?.fetchMetadata(for: sourceApp) {
            if title.isEmpty { title = fallback.title }
            if artist.isEmpty { artist = fallback.artist }
            if album == nil || album?.isEmpty == true { album = fallback.album }
            if duration == 0 { duration = fallback.duration }
            if artworkURL?.nilIfBlank == nil { artworkURL = fallback.artworkURL }
        }

        guard !title.isEmpty, !artist.isEmpty else {
            return nil
        }

        return .trackStarted(
            Track(
                title: title,
                artist: artist,
                album: album,
                duration: duration,
                startedAt: now(),
                sourceApp: sourceApp,
                artworkURL: artworkURL?.nilIfBlank
            )
        )
    }

    private enum State {
        case playing
        case paused
        case stopped
        case unknown
    }

    private static func normalizedState(from info: [AnyHashable: Any]) -> State {
        let raw = firstString(in: info, keys: ["Player State", "player state", "state"])?.lowercased() ?? ""
        switch raw {
        case "playing":
            return .playing
        case "paused":
            return .paused
        case "stopped":
            return .stopped
        default:
            return .unknown
        }
    }

    private static func firstString(in info: [AnyHashable: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = info[key] as? String, !value.isEmpty {
                return value
            }
            if let number = info[key] as? NSNumber {
                return number.stringValue
            }
        }
        return nil
    }

    private static func durationSeconds(from info: [AnyHashable: Any]) -> TimeInterval? {
        let candidates = ["Total Time", "Duration", "duration"]
        for key in candidates {
            if let number = info[key] as? NSNumber {
                let v = number.doubleValue
                return v > 1000 ? v / 1000.0 : v
            }
            if let text = info[key] as? String, let v = Double(text) {
                return v > 1000 ? v / 1000.0 : v
            }
        }
        return nil
    }
}
