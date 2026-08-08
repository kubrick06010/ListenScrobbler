import ListenScrobblerCore
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
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? String(localized: "unknown"),
            buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? String(localized: "unknown"),
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
        let unknown = String(localized: "unknown")
        let yes = String(localized: "yes")
        let no = String(localized: "no")
        let never = String(localized: "never")
        let none = String(localized: "none")
        var lines: [String] = [
            String(localized: "ListenScrobbler iOS Diagnostics"),
            String(localized: "Generated: \(Self.isoDate(generatedAt))"),
            String(localized: "App: \(appVersion) (\(buildVersion))"),
            String(localized: "OS: \(osVersion)"),
            String(localized: "Device: \(deviceModel)"),
            "",
            "ListenBrainz",
            String(localized: "- State: \(connectionState)"),
            String(localized: "- Username: \(configuredUsername.isEmpty ? unknown : configuredUsername)"),
            String(localized: "- Stored token present: \(hasStoredToken ? yes : no)"),
            "",
            String(localized: "Music Library Scanner"),
            String(localized: "- Authorization: \(musicAuthorization)"),
            String(localized: "- Scanning: \(isScanning ? yes : no)"),
            String(localized: "- Last scan: \(lastScanAt.map(Self.isoDate) ?? never)"),
            String(localized: "- Last error: \(lastError?.nilIfBlank ?? none)"),
            String(localized: "- Pending retry count: \(pendingScrobbles.count)")
        ]

        if let lastSummary {
            lines.append(contentsOf: [
                String(localized: "- Summary detected: \(lastSummary.detected)"),
                String(localized: "- Summary submitted: \(lastSummary.submitted)"),
                String(localized: "- Summary failed: \(lastSummary.failed)"),
                String(localized: "- Summary retried: \(lastSummary.retried)"),
                String(localized: "- Summary retry submitted: \(lastSummary.retrySubmitted)"),
                String(localized: "- Summary retry failed: \(lastSummary.retryFailed)"),
                String(localized: "- Summary pending: \(lastSummary.pending)"),
                String(localized: "- Baseline created: \(lastSummary.baselineCreated ? yes : no)"),
                String(localized: "- Message: \(lastSummary.message)")
            ])
        }

        if pendingScrobbles.isEmpty {
            lines.append(contentsOf: ["", String(localized: "Pending Queue"), String(localized: "- empty")])
        } else {
            lines.append(contentsOf: ["", String(localized: "Pending Queue")])
            for item in pendingScrobbles.prefix(25) {
                lines.append(contentsOf: Self.pendingLines(item))
            }
            if pendingScrobbles.count > 25 {
                lines.append(String(localized: "- \(pendingScrobbles.count - 25) additional pending item(s) omitted"))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func pendingLines(_ item: MobilePendingScrobble) -> [String] {
        let unknown = String(localized: "unknown")
        let none = String(localized: "none")
        var lines = [
            "- \(item.candidate.title) / \(item.candidate.artist)",
            String(localized: "  library item: \(item.libraryItemID)"),
            String(localized: "  source: \(item.candidate.source)"),
            String(localized: "  album: \(item.candidate.album?.nilIfBlank ?? unknown)"),
            String(localized: "  listened: \(isoDate(item.candidate.listenedAt))"),
            String(localized: "  duration: \(Int(item.candidate.duration.rounded()))s"),
            String(localized: "  attempts: \(item.attempts)"),
            String(localized: "  last error: \(item.lastError?.nilIfBlank ?? none)"),
            String(localized: "  updated: \(isoDate(item.updatedAt))")
        ]

        if let metadata = item.candidate.sourceMetadata {
            lines.append(String(localized: "  media player: \(metadata.mediaPlayer?.nilIfBlank ?? unknown)"))
            lines.append(String(localized: "  music service: \(metadata.musicService?.nilIfBlank ?? unknown)"))
            lines.append(String(localized: "  music service name: \(metadata.musicServiceName?.nilIfBlank ?? unknown)"))
            lines.append(String(localized: "  origin url: \(metadata.originURL?.nilIfBlank ?? none)"))
            lines.append(String(localized: "  spotify id: \(metadata.spotifyID?.nilIfBlank ?? none)"))
            lines.append(String(localized: "  duration played: \(metadata.durationPlayed.map { "\(Int($0.rounded()))s" } ?? unknown)"))
            lines.append(String(localized: "  original client: \(metadata.originalSubmissionClient?.nilIfBlank ?? unknown)"))
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
