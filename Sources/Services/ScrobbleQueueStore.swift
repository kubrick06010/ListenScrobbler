import Foundation

enum ScrobbleBackend: String, Codable, CaseIterable, Hashable, Identifiable {
    case compatibility
    case listenBrainz

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .compatibility:
            return AppLocalization.string("Compatibility Adapter")
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

extension ScrobbleSubmissionJob {
    /// Strips credentialed artwork that may have been written by an older
    /// build while retaining the queue job itself.
    var persistableJob: ScrobbleSubmissionJob {
        let sanitizedTrack = track.replacingArtworkResolution(track.persistableArtworkResolution)
        guard sanitizedTrack != track else { return self }
        return ScrobbleSubmissionJob(
            id: id,
            backend: backend,
            track: sanitizedTrack,
            createdAt: createdAt,
            attempts: attempts,
            lastError: lastError
        )
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
    /// Updates only the typed artwork value for an existing job. This default
    /// implementation keeps lightweight test stores source-compatible while
    /// allowing queue surfaces to persist a newly resolved result.
    func persistArtworkResolution(_ resolution: ArtworkResolution, for jobID: UUID) {
        let updatedJobs = loadJobs().map { job -> ScrobbleSubmissionJob in
            guard job.id == jobID else { return job }
            return ScrobbleSubmissionJob(
                id: job.id,
                backend: job.backend,
                track: job.track.replacingArtworkResolution(resolution.automaticArtworkResolution),
                createdAt: job.createdAt,
                attempts: job.attempts,
                lastError: job.lastError
            )
        }
        saveJobs(updatedJobs)
    }
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
            return job.persistableJob.track
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
        return ((try? JSONDecoder().decode([Track].self, from: data)) ?? [])
            .map { $0.replacingArtworkResolution($0.persistableArtworkResolution) }
    }

    func save(_ tracks: [Track]) {
        let sanitizedTracks = tracks.map { $0.replacingArtworkResolution($0.persistableArtworkResolution) }
        guard let data = try? JSONEncoder().encode(sanitizedTracks) else { return }
        try? data.write(to: queueFileURL, options: .atomic)
    }

    func loadJobs() -> [ScrobbleSubmissionJob] {
        guard let data = try? Data(contentsOf: queueFileURL) else { return [] }
        if let jobs = try? JSONDecoder().decode([ScrobbleSubmissionJob].self, from: data) {
            return jobs.map(\.persistableJob)
        }
        let legacyTracks = (try? JSONDecoder().decode([Track].self, from: data)) ?? []
        return legacyTracks.map { ScrobbleSubmissionJob(backend: .compatibility, track: $0.replacingArtworkResolution($0.persistableArtworkResolution)) }
    }

    func saveJobs(_ jobs: [ScrobbleSubmissionJob]) {
        guard let data = try? JSONEncoder().encode(jobs.map(\.persistableJob)) else { return }
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
