import Foundation

public struct MobileWidgetListen: Codable, Equatable {
    public let trackName: String
    public let artistName: String
    public let releaseName: String?
    public let listenedAt: Date?

    public init(trackName: String, artistName: String, releaseName: String?, listenedAt: Date?) {
        self.trackName = trackName
        self.artistName = artistName
        self.releaseName = releaseName
        self.listenedAt = listenedAt
    }
}

public struct MobileWidgetPin: Codable, Equatable {
    public let trackName: String
    public let artistName: String
    public let blurb: String?

    public init(trackName: String, artistName: String, blurb: String?) {
        self.trackName = trackName
        self.artistName = artistName
        self.blurb = blurb
    }
}

public struct MobileWidgetRecommendation: Codable, Equatable {
    public let title: String
    public let artistName: String?
    public let releaseName: String?

    public init(title: String, artistName: String?, releaseName: String?) {
        self.title = title
        self.artistName = artistName
        self.releaseName = releaseName
    }
}

public struct MobileWidgetSnapshot: Codable, Equatable {
    public let connectionStatus: String
    public let username: String?
    public let recentListen: MobileWidgetListen?
    public let currentPin: MobileWidgetPin?
    public let recommendation: MobileWidgetRecommendation?
    public let pendingCount: Int
    public let updatedAt: Date

    public init(
        connectionStatus: String,
        username: String?,
        recentListen: MobileWidgetListen?,
        currentPin: MobileWidgetPin?,
        recommendation: MobileWidgetRecommendation?,
        pendingCount: Int,
        updatedAt: Date
    ) {
        self.connectionStatus = connectionStatus
        self.username = username
        self.recentListen = recentListen
        self.currentPin = currentPin
        self.recommendation = recommendation
        self.pendingCount = pendingCount
        self.updatedAt = updatedAt
    }

    public static var empty: MobileWidgetSnapshot {
        MobileWidgetSnapshot(
            connectionStatus: "Open OpenScrobbler to connect ListenBrainz",
            username: nil,
            recentListen: nil,
            currentPin: nil,
            recommendation: nil,
            pendingCount: 0,
            updatedAt: .distantPast
        )
    }
}

public struct MobileWidgetSnapshotStore {
    public static let defaultSuiteName = "group.org.openscrobbler.app"
    private static let snapshotKey = "OpenScrobbler.MobileWidgetSnapshot"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(defaults: UserDefaults? = UserDefaults(suiteName: defaultSuiteName)) {
        self.defaults = defaults ?? .standard
    }

    public func save(_ snapshot: MobileWidgetSnapshot) {
        guard let data = try? encoder.encode(snapshot) else { return }
        defaults.set(data, forKey: Self.snapshotKey)
    }

    public func load() -> MobileWidgetSnapshot {
        guard let data = defaults.data(forKey: Self.snapshotKey),
              let snapshot = try? decoder.decode(MobileWidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    public func clear() {
        defaults.removeObject(forKey: Self.snapshotKey)
    }
}
