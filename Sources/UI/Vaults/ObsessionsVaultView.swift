import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ObsessionsVaultView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: ObsessionVaultStore
    @State private var query = ""
    @State private var selectedEntry: ObsessionEntry?
    @State private var isObsessionComposerPresented = false

    private var mergedEntries: [ObsessionEntry] {
        let localRecordingMBIDs = Set(store.entries.compactMap { $0.musicBrainzRecordingID?.nilIfBlank?.lowercased() })
        let remoteEntries = listenBrainzPinEntries.filter { entry in
            guard let recordingMBID = entry.musicBrainzRecordingID?.nilIfBlank?.lowercased() else { return true }
            return !localRecordingMBIDs.contains(recordingMBID)
        }
        return (store.entries + remoteEntries).sorted {
            ($0.setAt ?? $0.firstSeenAt) > ($1.setAt ?? $1.firstSeenAt)
        }
    }

    private var filteredEntries: [ObsessionEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return mergedEntries }
        return mergedEntries.filter { entry in
            entry.track.localizedCaseInsensitiveContains(trimmed) ||
            entry.artist.localizedCaseInsensitiveContains(trimmed) ||
            (entry.note?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            entry.source.displayName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var listenBrainzPinEntries: [ObsessionEntry] {
        var seenRowIDs = Set<Int>()
        return ([scrobbleService.listenBrainzCurrentPin].compactMap { $0 } + scrobbleService.listenBrainzPinnedHistory)
            .filter { seenRowIDs.insert($0.id).inserted }
            .map { pin in
                let createdAt = pin.createdAt ?? Date()
                let recordingMBID = pin.recordingMbid?.nilIfBlank
                return ObsessionEntry(
                    id: listenBrainzPinObsessionID(rowID: pin.id),
                    ownerUsername: pin.userName?.nilIfBlank ?? scrobbleService.listenBrainzUsername ?? "listenbrainz",
                    artist: pin.artistName,
                    track: pin.trackName,
                    album: nil,
                    note: pin.blurb?.nilIfBlank,
                    imageURL: nil,
                    compatibilityURL: recordingMBID.map { "https://listenbrainz.org/player/?recording_mbids=\($0)" },
                    musicBrainzArtistID: nil,
                    musicBrainzRecordingID: recordingMBID,
                    musicBrainzReleaseID: nil,
                    firstSeenAt: createdAt,
                    setAt: createdAt,
                    endedAt: pin.pinnedUntil,
                    rankMarker: nil,
                    source: .listenBrainzPin
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                obsessionsHeader
                obsessionsToolbar
                obsessionsMetrics
                obsessionsTimeline
            }
            .padding(24)
        }
        .onAppear {
            store.configure(username: scrobbleService.sessionUsername)
            selectedEntry = selectedEntry ?? mergedEntries.first
        }
        .task(id: scrobbleService.listenBrainzUsername ?? "obsessions-listenbrainz-pins") {
            guard scrobbleService.listenBrainzEnabled else { return }
            if scrobbleService.listenBrainzCurrentPin == nil && scrobbleService.listenBrainzPinnedHistory.isEmpty {
                await scrobbleService.refreshListenBrainzPins()
            }
        }
        .onChange(of: scrobbleService.sessionUsername ?? "local") { username in
            store.configure(username: username)
            selectedEntry = mergedEntries.first
        }
        .sheet(isPresented: $isObsessionComposerPresented) {
            ObsessionComposerView(store: store, currentTrack: scrobbleService.currentTrack, draft: nil) { entry in
                selectedEntry = entry
            }
            .frame(width: 560, height: 460)
            .padding()
        }
    }

    private var obsessionsHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Obsessions")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Text("Local-first")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Spacer()
                Button { importObsessionBundle() } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                Button { exportObsessionBundle() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.isEmpty)
            }

            Text("Obsessions are recovered from this app's local per-account store and optional `.openscrobbler-obsessions.json` imports. They remain portable, private, and independent from any single platform.")
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
        .appPanelStyle()
    }

    private var obsessionsToolbar: some View {
        HStack(spacing: 10) {
            Label("Track intensity, notes, and official-page provenance", systemImage: "sparkles")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(store.status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            if scrobbleService.listenBrainzPinsStatus != "Not loaded" {
                Label(scrobbleService.listenBrainzPinsStatus, systemImage: "pin")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            TextField("Search obsessions", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
        }
        .appPanelStyle()
    }

    private var obsessionsMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10)
        ], spacing: 10) {
            VaultMetricCard(title: "Captured obsessions", value: "\(store.entries.count)", detail: "\(notesCount) with text memories")
            VaultMetricCard(title: "Imports", value: "\(importedCount)", detail: "Recovered from portable bundle files")
            VaultMetricCard(title: "ListenBrainz pins", value: "\(listenBrainzPinEntries.count)", detail: "Remote pins mixed into the timeline")
        }
    }

    private var obsessionsTimeline: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Obsession Timeline", systemImage: "heart.text.square")
                        .font(.custom("Avenir Next Demi Bold", size: 16))
                    Spacer()
                    Button {
                        isObsessionComposerPresented = true
                    } label: {
                        Label("Capture", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if filteredEntries.isEmpty {
                    VaultEmptyState(title: "No obsessions captured", detail: "Capture a track from Now Playing or import a bundle.")
                } else {
                    ForEach(filteredEntries) { entry in
                        ObsessionTimelineRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture { selectedEntry = entry }
                    }
                }
            }
            .appPanelStyle()

            ObsessionDetailView(entry: selectedEntry ?? filteredEntries.first) { entry in
                store.delete(entry)
                selectedEntry = mergedEntries.first
            }
            .frame(minWidth: 300, maxWidth: 420)
            .appPanelStyle()
        }
    }

    private var notesCount: Int { store.entries.filter { !($0.note?.isBlank ?? true) }.count }
    private var importedCount: Int { store.entries.filter { $0.source != .userCaptured }.count }

    private func exportObsessionBundle() {
        guard let url = savePanelURL(defaultName: "openscrobbler-obsessions.openscrobbler-obsessions.json") else { return }
        do {
            try store.export(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importObsessionBundle() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importBundle(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }
}
