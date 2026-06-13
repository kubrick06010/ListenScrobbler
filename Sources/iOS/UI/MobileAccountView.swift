import OpenScrobblerCore
import SwiftUI

struct MobileAccountView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @EnvironmentObject private var musicLibraryScanner: MusicLibraryScrobbleScanner
    @State private var token = ""
    @State private var isPendingQueuePresented = false

    var body: some View {
        Form {
            Section {
                MobileListenBrainzSetupGuide(connectionState: listeningStore.connectionState)
            }

            Section("ListenBrainz") {
                Text(listeningStore.connectionState.statusText)
                    .foregroundStyle(.secondary)

                SecureField("User token", text: $token)
                    .textContentType(.password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                Button {
                    Task {
                        await listeningStore.connect(token: token)
                        token = ""
                    }
                } label: {
                    Label("Connect", systemImage: "person.badge.key")
                }
                .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if listeningStore.hasStoredToken {
                    Button(role: .destructive) {
                        listeningStore.disconnect()
                    } label: {
                        Label("Disconnect", systemImage: "xmark.circle")
                    }
                }
            }

            Section("Music Library Scrobbling") {
                HStack(spacing: 12) {
                    Image("LibraryScan")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .accessibilityHidden(true)

                    Text(musicLibraryScanner.authorizationState.statusText)
                        .foregroundStyle(.secondary)
                }

                if let summary = musicLibraryScanner.lastSummary {
                    Text(summary.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    LabeledContent("Detected", value: "\(summary.detected)")
                    LabeledContent("Submitted", value: "\(summary.submitted + summary.retrySubmitted)")
                    LabeledContent("Failed", value: "\(summary.failed)")
                }

                if let lastScanAt = musicLibraryScanner.lastScanAt {
                    LabeledContent("Last Scan", value: lastScanAt.formatted(date: .abbreviated, time: .shortened))
                }

                LabeledContent("Pending Retry", value: "\(musicLibraryScanner.pendingRetryCount)")

                if musicLibraryScanner.pendingRetryCount > 0 {
                    Button {
                        musicLibraryScanner.refreshPendingScrobbles()
                        isPendingQueuePresented = true
                    } label: {
                        Label("Pending Queue", systemImage: "tray.full")
                    }
                }

                if let error = musicLibraryScanner.lastError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Button {
                    Task {
                        await musicLibraryScanner.scan(using: listeningStore)
                    }
                } label: {
                    if musicLibraryScanner.isScanning {
                        Label("Scanning", systemImage: "hourglass")
                    } else {
                        Label("Scan Music Library", systemImage: "music.note.list")
                    }
                }
                .disabled(musicLibraryScanner.isScanning || !listeningStore.hasStoredToken)

                Button(role: .destructive) {
                    musicLibraryScanner.resetBaseline()
                } label: {
                    Label("Reset Scan Baseline", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Mobile Scope") {
                Text("Music library scanning compares local play counts with a saved baseline. The first scan does not submit old history; later scans submit detected new plays to ListenBrainz. Failed submissions stay pending for the next scan.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Open Music Data") {
                Text("OpenScrobbler submits listens to ListenBrainz and uses official ListenBrainz logo assets from the MetaBrainz Design System.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Link(destination: URL(string: "https://listenbrainz.org/")!) {
                    Label("ListenBrainz", systemImage: "link")
                }
            }
        }
        .navigationTitle("Account")
        .sheet(isPresented: $isPendingQueuePresented) {
            MobilePendingQueueView()
                .environmentObject(musicLibraryScanner)
        }
    }
}

private struct MobilePendingQueueView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var musicLibraryScanner: MusicLibraryScrobbleScanner

    var body: some View {
        NavigationStack {
            List {
                ForEach(musicLibraryScanner.pendingScrobbles) { item in
                    MobilePendingScrobbleRow(item: item)
                }
            }
            .navigationTitle("Pending Queue")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if !musicLibraryScanner.pendingScrobbles.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Clear", role: .destructive) {
                            musicLibraryScanner.clearPendingRetries()
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                musicLibraryScanner.refreshPendingScrobbles()
            }
        }
    }
}

private struct MobileListenBrainzSetupGuide: View {
    let connectionState: MobileListeningStore.ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image("ListenPulse")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Guided Setup")
                        .font(.headline)
                    Label(statusText, systemImage: statusSymbol)
                        .font(.subheadline)
                        .foregroundStyle(statusTint)
                }
            }

            ForEach(ListenBrainzSetupGuide.steps) { step in
                MobileSetupStepRow(step: step)
            }

            VStack(alignment: .leading, spacing: 8) {
                Link(destination: ListenBrainzSetupGuide.musicBrainzSignupURL) {
                    Label("Create Account", systemImage: "person.crop.circle.badge.plus")
                }

                Link(destination: ListenBrainzSetupGuide.tokenURL) {
                    Label("Open User Token", systemImage: "key")
                }

                Link(destination: ListenBrainzSetupGuide.importersURL) {
                    Label("Connect Music Services", systemImage: "point.3.connected.trianglepath.dotted")
                }
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 4)
    }

    private var statusText: String {
        connectionState.statusText
    }

    private var statusSymbol: String {
        switch connectionState {
        case .connected:
            return "checkmark.seal"
        case .failed:
            return "exclamationmark.triangle"
        case .loading:
            return "hourglass"
        case .disconnected:
            return "person.badge.key"
        }
    }

    private var statusTint: Color {
        switch connectionState {
        case .connected:
            return .green
        case .failed:
            return .red
        default:
            return .secondary
        }
    }
}

private struct MobileSetupStepRow: View {
    let step: ListenBrainzSetupStep

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(step.title)
                    .font(.subheadline.weight(.semibold))
                Text(step.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct MobilePendingScrobbleRow: View {
    let item: MobilePendingScrobble

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.candidate.title)
                    .font(.headline)
                Text(item.candidate.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let album = item.candidate.album, !album.isEmpty {
                Label(album, systemImage: "opticaldisc")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow {
                    Text("Attempts")
                        .foregroundStyle(.secondary)
                    Text("\(item.attempts)")
                }
                GridRow {
                    Text("Listened")
                        .foregroundStyle(.secondary)
                    Text(item.candidate.listenedAt.formatted(date: .abbreviated, time: .shortened))
                }
                GridRow {
                    Text("Updated")
                        .foregroundStyle(.secondary)
                    Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
            .font(.caption)

            if let lastError = item.lastError, !lastError.isEmpty {
                Text(lastError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}
