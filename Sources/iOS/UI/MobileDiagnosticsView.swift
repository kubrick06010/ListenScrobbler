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
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppLocalization.string("unknown"),
            buildVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? AppLocalization.string("unknown"),
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
        let unknown = AppLocalization.string("unknown")
        let yes = AppLocalization.string("yes")
        let no = AppLocalization.string("no")
        let never = AppLocalization.string("never")
        let none = AppLocalization.string("none")
        var lines: [String] = [
            AppLocalization.string("ListenScrobbler iOS Diagnostics"),
            AppLocalization.string("Generated: \(Self.isoDate(generatedAt))"),
            AppLocalization.string("App: \(appVersion) (\(buildVersion))"),
            AppLocalization.string("OS: \(osVersion)"),
            AppLocalization.string("Device: \(deviceModel)"),
            "",
            "ListenBrainz",
            AppLocalization.string("- State: \(connectionState)"),
            AppLocalization.string("- Username: \(configuredUsername.isEmpty ? unknown : configuredUsername)"),
            AppLocalization.string("- Stored token present: \(hasStoredToken ? yes : no)"),
            "",
            AppLocalization.string("Music Library Scanner"),
            AppLocalization.string("- Authorization: \(musicAuthorization)"),
            AppLocalization.string("- Scanning: \(isScanning ? yes : no)"),
            AppLocalization.string("- Last scan: \(lastScanAt.map(Self.isoDate) ?? never)"),
            AppLocalization.string("- Last error: \(lastError?.nilIfBlank ?? none)"),
            AppLocalization.string("- Pending retry count: \(pendingScrobbles.count)")
        ]

        if let lastSummary {
            lines.append(contentsOf: [
                AppLocalization.string("- Summary detected: \(lastSummary.detected)"),
                AppLocalization.string("- Summary submitted: \(lastSummary.submitted)"),
                AppLocalization.string("- Summary failed: \(lastSummary.failed)"),
                AppLocalization.string("- Summary retried: \(lastSummary.retried)"),
                AppLocalization.string("- Summary retry submitted: \(lastSummary.retrySubmitted)"),
                AppLocalization.string("- Summary retry failed: \(lastSummary.retryFailed)"),
                AppLocalization.string("- Summary pending: \(lastSummary.pending)"),
                AppLocalization.string("- Baseline created: \(lastSummary.baselineCreated ? yes : no)"),
                AppLocalization.string("- Message: \(lastSummary.message)")
            ])
        }

        if pendingScrobbles.isEmpty {
            lines.append(contentsOf: ["", AppLocalization.string("Pending Queue"), AppLocalization.string("- empty")])
        } else {
            lines.append(contentsOf: ["", AppLocalization.string("Pending Queue")])
            for item in pendingScrobbles.prefix(25) {
                lines.append(contentsOf: Self.pendingLines(item))
            }
            if pendingScrobbles.count > 25 {
                lines.append(AppLocalization.string("- \(pendingScrobbles.count - 25) additional pending item(s) omitted"))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func pendingLines(_ item: MobilePendingScrobble) -> [String] {
        let unknown = AppLocalization.string("unknown")
        let none = AppLocalization.string("none")
        var lines = [
            "- \(item.candidate.title) / \(item.candidate.artist)",
            AppLocalization.string("  library item: \(item.libraryItemID)"),
            AppLocalization.string("  source: \(item.candidate.source)"),
            AppLocalization.string("  album: \(item.candidate.album?.nilIfBlank ?? unknown)"),
            AppLocalization.string("  listened: \(isoDate(item.candidate.listenedAt))"),
            AppLocalization.string("  duration: \(Int(item.candidate.duration.rounded()))s"),
            AppLocalization.string("  attempts: \(item.attempts)"),
            AppLocalization.string("  last error: \(item.lastError?.nilIfBlank ?? none)"),
            AppLocalization.string("  updated: \(isoDate(item.updatedAt))")
        ]

        if let metadata = item.candidate.sourceMetadata {
            lines.append(AppLocalization.string("  media player: \(metadata.mediaPlayer?.nilIfBlank ?? unknown)"))
            lines.append(AppLocalization.string("  music service: \(metadata.musicService?.nilIfBlank ?? unknown)"))
            lines.append(AppLocalization.string("  music service name: \(metadata.musicServiceName?.nilIfBlank ?? unknown)"))
            lines.append(AppLocalization.string("  origin url: \(metadata.originURL?.nilIfBlank ?? none)"))
            lines.append(AppLocalization.string("  spotify id: \(metadata.spotifyID?.nilIfBlank ?? none)"))
            lines.append(AppLocalization.string("  duration played: \(metadata.durationPlayed.map { "\(Int($0.rounded()))s" } ?? unknown)"))
            lines.append(AppLocalization.string("  original client: \(metadata.originalSubmissionClient?.nilIfBlank ?? unknown)"))
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
