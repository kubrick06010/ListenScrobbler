import Foundation

public struct MobileLibraryScanSummary: Equatable {
    public var detected: Int
    public var submitted: Int
    public var failed: Int
    public var retried: Int
    public var retrySubmitted: Int
    public var retryFailed: Int
    public var pending: Int
    public var baselineCreated: Bool

    public init(
        detected: Int = 0,
        submitted: Int = 0,
        failed: Int = 0,
        retried: Int = 0,
        retrySubmitted: Int = 0,
        retryFailed: Int = 0,
        pending: Int = 0,
        baselineCreated: Bool = false
    ) {
        self.detected = detected
        self.submitted = submitted
        self.failed = failed
        self.retried = retried
        self.retrySubmitted = retrySubmitted
        self.retryFailed = retryFailed
        self.pending = pending
        self.baselineCreated = baselineCreated
    }

    public var message: String {
        if baselineCreated {
            return String(localized: "Baseline created. Future scans will submit new plays.")
        }
        if retried > 0, detected == 0 {
            if retryFailed > 0 {
                return String.localizedStringWithFormat(
                    String(localized: "Submitted %d pending plays. %d still pending retry."),
                    retrySubmitted,
                    pending
                )
            }
            return String.localizedStringWithFormat(String(localized: "Submitted %d pending plays."), retrySubmitted)
        }
        if detected == 0 {
            return String(localized: "No new Music library plays detected.")
        }
        if failed > 0 {
            return String.localizedStringWithFormat(
                String(localized: "Submitted %d of %d detected plays. %d pending retry."),
                submitted,
                detected,
                pending
            )
        }
        return String.localizedStringWithFormat(String(localized: "Submitted %d new plays."), submitted)
    }
}

public struct MobileLibraryScanResult: Equatable {
    public let summary: MobileLibraryScanSummary
    public let snapshots: [String: MobileLibraryItemSnapshot]
    public let pending: [MobilePendingScrobble]
    public let lastError: String?
    public let shouldRefreshListens: Bool
}

public enum MobileLibraryScanEngine {
    public static func scan(
        previous: [String: MobileLibraryItemSnapshot],
        current: [String: MobileLibraryItemSnapshot],
        pending initialPending: [MobilePendingScrobble],
        submit: (MobileScrobbleCandidate) async throws -> Void
    ) async -> MobileLibraryScanResult {
        guard !previous.isEmpty else {
            return MobileLibraryScanResult(
                summary: MobileLibraryScanSummary(pending: initialPending.count, baselineCreated: true),
                snapshots: current,
                pending: initialPending,
                lastError: nil,
                shouldRefreshListens: false
            )
        }

        var snapshots = previous
        var pending = initialPending
        var lastError: String?
        var summary = MobileLibraryScanSummary(retried: pending.count)

        for item in initialPending {
            do {
                try await submit(item.candidate)
                summary.retrySubmitted += 1
                pending = MobilePendingScrobbleQueue.removing(item, from: pending)
            } catch {
                summary.retryFailed += 1
                lastError = error.localizedDescription
                pending = MobilePendingScrobbleQueue.upsertFailure(
                    libraryItemID: item.libraryItemID,
                    candidate: item.candidate,
                    errorMessage: error.localizedDescription,
                    into: pending
                )
            }
        }

        let candidates = MobileLibraryScrobbleDiffer.candidates(previous: snapshots, current: current)
            .filter { entry in
                let id = MobilePendingScrobble.makeID(libraryItemID: entry.id, candidate: entry.candidate)
                return !pending.contains(where: { $0.id == id })
            }

        summary.detected = candidates.count
        for entry in candidates {
            do {
                try await submit(entry.candidate)
                summary.submitted += 1
                snapshots[entry.id] = current[entry.id]
            } catch {
                summary.failed += 1
                lastError = error.localizedDescription
                pending = MobilePendingScrobbleQueue.upsertFailure(
                    libraryItemID: entry.id,
                    candidate: entry.candidate,
                    errorMessage: error.localizedDescription,
                    into: pending
                )
                snapshots[entry.id] = current[entry.id]
            }
        }

        for (id, snapshot) in current where snapshots[id] == nil {
            snapshots[id] = snapshot
        }

        summary.pending = pending.count
        return MobileLibraryScanResult(
            summary: summary,
            snapshots: snapshots,
            pending: pending,
            lastError: lastError,
            shouldRefreshListens: summary.submitted > 0 || summary.retrySubmitted > 0
        )
    }
}
