import Foundation

enum ScrobbleBackend: String, Codable, CaseIterable, Hashable, Identifiable {
    case compatibility
    case listenBrainz

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compatibility:
            return "Compatibility Adapter"
        case .listenBrainz:
            return "ListenBrainz"
        }
    }
}

struct ScrobbleSubmissionJob: Identifiable, Codable, Hashable {
    let id: UUID
    let backend: ScrobbleBackend
    let track: Track
    let createdAt: Date
    var attempts: Int
    var lastError: String?

    init(
        id: UUID = UUID(),
        backend: ScrobbleBackend,
        track: Track,
        createdAt: Date = .now,
        attempts: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.backend = backend
        self.track = track
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastError = lastError
    }

    var fingerprint: String {
        "\(backend.rawValue)|\(track.fingerprint)"
    }
}

protocol ScrobbleQueueStoring {
    var queueFileURL: URL { get }
    func load() -> [Track]
    func save(_ tracks: [Track])
    func loadJobs() -> [ScrobbleSubmissionJob]
    func saveJobs(_ jobs: [ScrobbleSubmissionJob])
}

extension ScrobbleQueueStoring {
    func loadJobs() -> [ScrobbleSubmissionJob] {
        load().map { ScrobbleSubmissionJob(backend: .compatibility, track: $0) }
    }

    func saveJobs(_ jobs: [ScrobbleSubmissionJob]) {
        var seen: Set<String> = []
        let tracks = jobs.compactMap { job -> Track? in
            guard !seen.contains(job.track.fingerprint) else { return nil }
            seen.insert(job.track.fingerprint)
            return job.track
        }
        save(tracks)
    }
}

final class ScrobbleQueueStore: ScrobbleQueueStoring {
    let queueFileURL: URL
    private let legacyQueueFileURLs: [URL]
    private let fileManager: FileManager

    init(fileManager: FileManager = .default, appSupportRoot: URL? = nil) {
        self.fileManager = fileManager
        let appSupport = appSupportRoot ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("ListenScrobbler", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        queueFileURL = dir.appendingPathComponent("scrobble-queue.json")
        legacyQueueFileURLs = [
            appSupport
                .appendingPathComponent("OpenScrobbler", isDirectory: true)
                .appendingPathComponent("scrobble-queue.json"),
            appSupport
                .appendingPathComponent("LegacyOpenScrobbler", isDirectory: true)
                .appendingPathComponent("scrobble-queue.json"),
            appSupport
                .appendingPathComponent("LegacyListenScrobbler", isDirectory: true)
                .appendingPathComponent("scrobble-queue.json")
        ]
        migrateLegacyQueueIfNeeded()
    }

    func load() -> [Track] {
        guard let data = try? Data(contentsOf: queueFileURL) else { return [] }
        return (try? JSONDecoder().decode([Track].self, from: data)) ?? []
    }

    func save(_ tracks: [Track]) {
        guard let data = try? JSONEncoder().encode(tracks) else { return }
        try? data.write(to: queueFileURL, options: .atomic)
    }

    func loadJobs() -> [ScrobbleSubmissionJob] {
        guard let data = try? Data(contentsOf: queueFileURL) else { return [] }
        if let jobs = try? JSONDecoder().decode([ScrobbleSubmissionJob].self, from: data) {
            return jobs
        }
        let legacyTracks = (try? JSONDecoder().decode([Track].self, from: data)) ?? []
        return legacyTracks.map { ScrobbleSubmissionJob(backend: .compatibility, track: $0) }
    }

    func saveJobs(_ jobs: [ScrobbleSubmissionJob]) {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: queueFileURL, options: .atomic)
    }

    private func migrateLegacyQueueIfNeeded() {
        guard !fileManager.fileExists(atPath: queueFileURL.path) else { return }
        for legacyQueueFileURL in legacyQueueFileURLs {
            guard fileManager.fileExists(atPath: legacyQueueFileURL.path) else { continue }
            guard let data = try? Data(contentsOf: legacyQueueFileURL), !data.isEmpty else { continue }
            do {
                try data.write(to: queueFileURL, options: .atomic)
                try? fileManager.removeItem(at: legacyQueueFileURL)
                return
            } catch {
                // Leave the legacy queue untouched if migration fails; loadJobs()
                // can still decode the old format from the migrated copy path later.
            }
        }
    }
}
