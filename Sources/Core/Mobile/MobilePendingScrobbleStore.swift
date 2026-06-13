import Foundation

public struct MobilePendingScrobble: Codable, Equatable, Identifiable {
    public let id: String
    public let libraryItemID: String
    public let candidate: MobileScrobbleCandidate
    public var attempts: Int
    public var lastError: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        libraryItemID: String,
        candidate: MobileScrobbleCandidate,
        attempts: Int = 0,
        lastError: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.libraryItemID = libraryItemID
        self.candidate = candidate
        self.attempts = attempts
        self.lastError = lastError
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.id = Self.makeID(libraryItemID: libraryItemID, candidate: candidate)
    }

    public var fingerprint: String {
        id
    }

    public static func makeID(libraryItemID: String, candidate: MobileScrobbleCandidate) -> String {
        [
            libraryItemID,
            candidate.title,
            candidate.artist,
            candidate.album ?? "",
            String(Int(candidate.listenedAt.timeIntervalSince1970)),
            String(Int(candidate.duration.rounded())),
            candidate.source,
            candidate.sourceMetadata?.musicService ?? "",
            candidate.sourceMetadata?.originURL ?? "",
            candidate.sourceMetadata?.spotifyID ?? ""
        ].joined(separator: "\u{1f}")
    }

    public mutating func recordFailure(_ message: String, at date: Date = Date()) {
        attempts += 1
        lastError = message
        updatedAt = date
    }
}

public protocol MobilePendingScrobbleStoring {
    func load() -> [MobilePendingScrobble]
    func save(_ pending: [MobilePendingScrobble])
    func removeAll()
}

public final class MobilePendingScrobbleStore: MobilePendingScrobbleStoring {
    public static let defaultKey = "ios.music-library-scrobbler.pending"

    private let defaults: UserDefaults
    private let key: String

    public init(defaults: UserDefaults = .standard, key: String = defaultKey) {
        self.defaults = defaults
        self.key = key
    }

    public func load() -> [MobilePendingScrobble] {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([MobilePendingScrobble].self, from: data) else {
            return []
        }

        return decoded
    }

    public func save(_ pending: [MobilePendingScrobble]) {
        guard let data = try? JSONEncoder().encode(pending) else { return }
        defaults.set(data, forKey: key)
    }

    public func removeAll() {
        defaults.removeObject(forKey: key)
    }
}

public enum MobilePendingScrobbleQueue {
    public static func upsertFailure(
        libraryItemID: String,
        candidate: MobileScrobbleCandidate,
        errorMessage: String,
        into pending: [MobilePendingScrobble],
        now: Date = Date()
    ) -> [MobilePendingScrobble] {
        let id = MobilePendingScrobble.makeID(libraryItemID: libraryItemID, candidate: candidate)
        var next = pending

        if let index = next.firstIndex(where: { $0.id == id }) {
            next[index].recordFailure(errorMessage, at: now)
        } else {
            var item = MobilePendingScrobble(
                libraryItemID: libraryItemID,
                candidate: candidate,
                createdAt: now,
                updatedAt: now
            )
            item.recordFailure(errorMessage, at: now)
            next.append(item)
        }

        return next.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id < rhs.id
            }
            return lhs.createdAt < rhs.createdAt
        }
    }

    public static func removing(
        _ item: MobilePendingScrobble,
        from pending: [MobilePendingScrobble]
    ) -> [MobilePendingScrobble] {
        pending.filter { $0.id != item.id }
    }
}
