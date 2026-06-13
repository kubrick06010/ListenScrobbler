import OpenScrobblerCore
import SwiftUI
import UIKit

struct MobileDiagnosticsSnapshot: Identifiable {
    let id = UUID()
    let generatedAt: Date
    let appVersion: String
    let buildVersion: String
    let osVersion: String
    let deviceModel: String
    let connectionState: String
    let configuredUsername: String
    let hasStoredToken: Bool
    let musicAuthorization: String
    let isScanning: Bool
    let lastScanAt: Date?
    let lastSummary: MusicLibraryScrobbleScanner.ScanSummary?
    let lastError: String?
    let pendingScrobbles: [MobilePendingScrobble]

    @MainActor
    static func make(
        listeningStore: MobileListeningStore,
        musicLibraryScanner: MusicLibraryScrobbleScanner
    ) -> MobileDiagnosticsSnapshot {
        MobileDiagnosticsSnapshot(
            generatedAt: Date(),
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown",
            buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown",
            osVersion: "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)",
            deviceModel: UIDevice.current.model,
            connectionState: listeningStore.connectionState.statusText,
            configuredUsername: listeningStore.configuredUsername,
            hasStoredToken: listeningStore.hasStoredToken,
            musicAuthorization: musicLibraryScanner.authorizationState.statusText,
            isScanning: musicLibraryScanner.isScanning,
            lastScanAt: musicLibraryScanner.lastScanAt,
            lastSummary: musicLibraryScanner.lastSummary,
            lastError: musicLibraryScanner.lastError,
            pendingScrobbles: musicLibraryScanner.pendingScrobbles
        )
    }

    var exportText: String {
        var lines: [String] = [
            "OpenScrobbler iOS Diagnostics",
            "Generated: \(Self.isoDate(generatedAt))",
            "App: \(appVersion) (\(buildVersion))",
            "OS: \(osVersion)",
            "Device: \(deviceModel)",
            "",
            "ListenBrainz",
            "- State: \(connectionState)",
            "- Username: \(configuredUsername.isEmpty ? "unknown" : configuredUsername)",
            "- Stored token present: \(hasStoredToken ? "yes" : "no")",
            "",
            "Music Library Scanner",
            "- Authorization: \(musicAuthorization)",
            "- Scanning: \(isScanning ? "yes" : "no")",
            "- Last scan: \(lastScanAt.map(Self.isoDate) ?? "never")",
            "- Last error: \(lastError?.nilIfBlank ?? "none")",
            "- Pending retry count: \(pendingScrobbles.count)"
        ]

        if let lastSummary {
            lines.append(contentsOf: [
                "- Summary detected: \(lastSummary.detected)",
                "- Summary submitted: \(lastSummary.submitted)",
                "- Summary failed: \(lastSummary.failed)",
                "- Summary retried: \(lastSummary.retried)",
                "- Summary retry submitted: \(lastSummary.retrySubmitted)",
                "- Summary retry failed: \(lastSummary.retryFailed)",
                "- Summary pending: \(lastSummary.pending)",
                "- Baseline created: \(lastSummary.baselineCreated ? "yes" : "no")",
                "- Message: \(lastSummary.message)"
            ])
        }

        if pendingScrobbles.isEmpty {
            lines.append(contentsOf: ["", "Pending Queue", "- empty"])
        } else {
            lines.append(contentsOf: ["", "Pending Queue"])
            for item in pendingScrobbles.prefix(25) {
                lines.append(contentsOf: Self.pendingLines(item))
            }
            if pendingScrobbles.count > 25 {
                lines.append("- \(pendingScrobbles.count - 25) additional pending item(s) omitted")
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func pendingLines(_ item: MobilePendingScrobble) -> [String] {
        var lines = [
            "- \(item.candidate.title) / \(item.candidate.artist)",
            "  library item: \(item.libraryItemID)",
            "  source: \(item.candidate.source)",
            "  album: \(item.candidate.album?.nilIfBlank ?? "unknown")",
            "  listened: \(isoDate(item.candidate.listenedAt))",
            "  duration: \(Int(item.candidate.duration.rounded()))s",
            "  attempts: \(item.attempts)",
            "  last error: \(item.lastError?.nilIfBlank ?? "none")",
            "  updated: \(isoDate(item.updatedAt))"
        ]

        if let metadata = item.candidate.sourceMetadata {
            lines.append("  media player: \(metadata.mediaPlayer?.nilIfBlank ?? "unknown")")
            lines.append("  music service: \(metadata.musicService?.nilIfBlank ?? "unknown")")
            lines.append("  music service name: \(metadata.musicServiceName?.nilIfBlank ?? "unknown")")
            lines.append("  origin url: \(metadata.originURL?.nilIfBlank ?? "none")")
            lines.append("  spotify id: \(metadata.spotifyID?.nilIfBlank ?? "none")")
            lines.append("  duration played: \(metadata.durationPlayed.map { "\(Int($0.rounded()))s" } ?? "unknown")")
            lines.append("  original client: \(metadata.originalSubmissionClient?.nilIfBlank ?? "unknown")")
        }

        return lines
    }

    private static func isoDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }
}

struct MobileDiagnosticsView: View {
    @Environment(\.dismiss) private var dismiss
    let snapshot: MobileDiagnosticsSnapshot

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(snapshot.exportText)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding()
            }
            .navigationTitle("Diagnostics")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    ShareLink(item: snapshot.exportText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
