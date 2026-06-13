import Foundation

public struct MobileLibraryItemSnapshot: Codable, Equatable {
    public let playCount: Int
    public let lastPlayedAt: Date?
    public let title: String?
    public let artist: String?
    public let album: String?
    public let duration: TimeInterval

    public init(
        playCount: Int,
        lastPlayedAt: Date?,
        title: String?,
        artist: String?,
        album: String?,
        duration: TimeInterval
    ) {
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }
}

public struct MobileLibraryScrobbleDelta: Equatable {
    public let id: String
    public let candidate: MobileScrobbleCandidate
}

public enum MobileLibraryScrobbleDiffer {
    public static func candidates(
        previous: [String: MobileLibraryItemSnapshot],
        current: [String: MobileLibraryItemSnapshot],
        source: String = "Music Library"
    ) -> [MobileLibraryScrobbleDelta] {
        current.keys.sorted().compactMap { id in
            guard let currentSnapshot = current[id],
                  let previousSnapshot = previous[id],
                  let candidate = candidate(
                    previous: previousSnapshot,
                    current: currentSnapshot,
                    source: source
                  ) else {
                return nil
            }

            return MobileLibraryScrobbleDelta(id: id, candidate: candidate)
        }
    }

    private static func candidate(
        previous: MobileLibraryItemSnapshot,
        current: MobileLibraryItemSnapshot,
        source: String
    ) -> MobileScrobbleCandidate? {
        guard current.playCount > previous.playCount else { return nil }
        guard let listenedAt = current.lastPlayedAt else { return nil }
        if let previousDate = previous.lastPlayedAt, listenedAt <= previousDate {
            return nil
        }
        guard let title = nonBlank(current.title), let artist = nonBlank(current.artist) else {
            return nil
        }

        return MobileScrobbleCandidate(
            title: title,
            artist: artist,
            album: nonBlank(current.album),
            duration: current.duration,
            listenedAt: listenedAt,
            source: source
        )
    }

    private static func nonBlank(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }
}
