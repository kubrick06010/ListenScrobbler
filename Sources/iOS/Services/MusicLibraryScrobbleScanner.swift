import MediaPlayer
import ListenScrobblerCore
import OSLog
import SwiftUI

@MainActor
final class MusicLibraryScrobbleScanner: ObservableObject {
    typealias ScanSummary = MobileLibraryScanSummary

    enum AuthorizationState: Equatable {
        case unknown
        case authorized
        case denied

        var statusText: String {
            switch self {
            case .unknown:
                return String(localized: "Music library permission has not been requested.")
            case .authorized:
                return String(localized: "Music library scanning is enabled.")
            case .denied:
                return String(localized: "Music library access is unavailable.")
            }
        }
    }

    @Published private(set) var authorizationState: AuthorizationState
    @Published private(set) var isScanning = false
    @Published private(set) var lastSummary: ScanSummary?
    @Published private(set) var lastError: String?
    @Published private(set) var lastScanAt: Date?
    @Published private(set) var pendingRetryCount = 0
    @Published private(set) var pendingScrobbles: [MobilePendingScrobble] = []

    private let defaults: UserDefaults
    private let pendingStore: MobilePendingScrobbleStoring
    private let snapshotsKey = "ios.music-library-scrobbler.snapshots"
    private let lastScanAtKey = "ios.music-library-scrobbler.last-scan-at"
    private let logger = Logger(subsystem: "org.listenscrobbler.app.ios", category: "music-library-scanner")

    init(
        defaults: UserDefaults = .standard,
        pendingStore: MobilePendingScrobbleStoring? = nil
    ) {
        self.defaults = defaults
        self.pendingStore = pendingStore ?? MobilePendingScrobbleStore(defaults: defaults)
        self.authorizationState = Self.authorizationState(from: MPMediaLibrary.authorizationStatus())
        self.lastScanAt = defaults.object(forKey: lastScanAtKey) as? Date
        let pending = self.pendingStore.load()
        self.pendingScrobbles = pending
        self.pendingRetryCount = pending.count
        logger.info("Music library scanner initialized with authorization \(String(describing: self.authorizationState), privacy: .public)")
    }

    func scan(using listeningStore: MobileListeningStore) async {
        logger.info("Music library scan started")
        isScanning = true
        lastError = nil
        defer { isScanning = false }

        let status = await requestAuthorizationIfNeeded()
        authorizationState = Self.authorizationState(from: status)
        guard status == .authorized else {
            logger.warning("Music library scan blocked by authorization status \(String(describing: status), privacy: .public)")
            lastError = String(localized: "Allow Media & Apple Music access in Settings to scan local plays.")
            return
        }

        let items = MPMediaQuery.songs().items ?? []
        logger.info("Music library query returned \(items.count, privacy: .public) songs")
        let current = currentSnapshots(from: items)
        let previous = loadSnapshots()
        logger.info("Music library snapshots current=\(current.count, privacy: .public) previous=\(previous.count, privacy: .public)")

        let pending = pendingStore.load()
        if !pending.isEmpty {
            logger.info("Retrying \(pending.count, privacy: .public) pending music library scrobbles")
        }

        let result = await MobileLibraryScanEngine.scan(previous: previous, current: current, pending: pending) { candidate in
            try await listeningStore.submitScrobble(candidate)
        }

        if result.summary.baselineCreated {
            logger.info("Music library baseline created with \(current.count, privacy: .public) snapshots")
        }
        logger.info("Music library scan detected \(result.summary.detected, privacy: .public) new scrobble candidates")

        lastError = result.lastError
        pendingStore.save(result.pending)
        refreshPendingScrobbles()
        saveSnapshots(result.snapshots)
        recordScanFinished()
        lastSummary = result.summary
        logger.info("Music library scan finished detected=\(result.summary.detected, privacy: .public) submitted=\(result.summary.submitted, privacy: .public) retrySubmitted=\(result.summary.retrySubmitted, privacy: .public) retryFailed=\(result.summary.retryFailed, privacy: .public) failed=\(result.summary.failed, privacy: .public) pending=\(result.summary.pending, privacy: .public)")

        if result.shouldRefreshListens {
            await listeningStore.refresh()
        }
    }

    func resetBaseline() {
        logger.info("Music library scan baseline reset")
        defaults.removeObject(forKey: snapshotsKey)
        defaults.removeObject(forKey: lastScanAtKey)
        pendingStore.removeAll()
        lastSummary = nil
        lastError = nil
        lastScanAt = nil
        refreshPendingScrobbles()
    }

    func clearPendingRetries() {
        logger.info("Music library pending retry queue cleared")
        pendingStore.removeAll()
        lastError = nil
        refreshPendingScrobbles()
    }

    func refreshPendingScrobbles() {
        let pending = pendingStore.load()
        pendingScrobbles = pending
        pendingRetryCount = pending.count
    }

    private func requestAuthorizationIfNeeded() async -> MPMediaLibraryAuthorizationStatus {
        let current = MPMediaLibrary.authorizationStatus()
        guard current == .notDetermined else { return current }

        logger.info("Requesting Media & Apple Music authorization")
        return await withCheckedContinuation { continuation in
            MPMediaLibrary.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func currentSnapshots(from items: [MPMediaItem]) -> [String: MobileLibraryItemSnapshot] {
        Dictionary(uniqueKeysWithValues: items.map { item in
            (
                String(item.persistentID),
                MobileLibraryItemSnapshot(
                    playCount: item.playCount,
                    lastPlayedAt: item.lastPlayedDate,
                    title: item.title,
                    artist: item.artist,
                    album: item.albumTitle,
                    duration: item.playbackDuration
                )
            )
        })
    }

    private func loadSnapshots() -> [String: MobileLibraryItemSnapshot] {
        guard let data = defaults.data(forKey: snapshotsKey),
              let decoded = try? JSONDecoder().decode([String: MobileLibraryItemSnapshot].self, from: data) else {
            logger.info("No saved music library baseline found")
            return [:]
        }

        logger.info("Loaded music library baseline with \(decoded.count, privacy: .public) snapshots")
        return decoded
    }

    private func saveSnapshots(_ snapshots: [String: MobileLibraryItemSnapshot]) {
        guard let data = try? JSONEncoder().encode(snapshots) else {
            logger.error("Failed to encode music library baseline with \(snapshots.count, privacy: .public) snapshots")
            return
        }
        defaults.set(data, forKey: snapshotsKey)
        logger.info("Saved music library baseline with \(snapshots.count, privacy: .public) snapshots")
    }

    private func recordScanFinished(date: Date = Date()) {
        lastScanAt = date
        defaults.set(date, forKey: lastScanAtKey)
    }

    private static func authorizationState(from status: MPMediaLibraryAuthorizationStatus) -> AuthorizationState {
        switch status {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .unknown
        default:
            return .denied
        }
    }
}
