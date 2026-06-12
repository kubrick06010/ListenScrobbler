import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct SharedVaultView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: SharedMusicVaultStore
    @State private var query = ""
    @State private var selectedEntry: SharedMusicEntry?
    @State private var isShareComposerPresented = false

    private var filteredEntries: [SharedMusicEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return store.entries }
        return store.entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(trimmed) ||
            entry.artist.localizedCaseInsensitiveContains(trimmed) ||
            entry.participantSummary.localizedCaseInsensitiveContains(trimmed) ||
            (entry.message?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                sharedHeader
                sharedToolbar
                sharedMetrics
                sharedTimeline
            }
            .padding(24)
        }
        .onAppear {
            store.configure(username: scrobbleService.sessionUsername)
            selectedEntry = selectedEntry ?? store.entries.first
        }
        .onChange(of: scrobbleService.sessionUsername ?? "local") { username in
            store.configure(username: username)
            selectedEntry = store.entries.first
        }
        .sheet(isPresented: $isShareComposerPresented) {
            ShareComposerView(store: store, draft: nil) { entry in
                selectedEntry = entry
            }
            .frame(width: 560, height: 560)
            .padding()
        }
    }

    private var sharedHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Shared")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                Text("Local-first")
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color(red: 0.83, green: 0.06, blue: 0.09), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                Spacer()
                Button { importSharedBundle() } label: {
                    Label("Import", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)
                Button { importSharedJSPF() } label: {
                    Label("Import JSPF", systemImage: "music.note.house")
                }
                .buttonStyle(.bordered)
                Button { exportSharedBundle() } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.isEmpty)
                Button { exportSharedJSPF() } label: {
                    Label("Export JSPF", systemImage: "square.and.arrow.up.on.square")
                }
                .buttonStyle(.bordered)
                .disabled(store.entries.filter { $0.entityKind == .track }.isEmpty)
            }

            Text("Share with another app user by exporting a `.openscrobbler-shared.json` bundle, or move track-based shares into portable `.jspf` playlists with MusicBrainz identifiers when available.")
                .font(.custom("Avenir Next Regular", size: 13))
                .foregroundStyle(.secondary)
        }
        .appPanelStyle()
    }

    private var sharedToolbar: some View {
        HStack(spacing: 10) {
            Label("People, messages, and imported bundles", systemImage: "person.2.wave.2.fill")
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            Spacer()
            Text(store.status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            TextField("Search people, notes, music", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 320)
        }
        .appPanelStyle()
    }

    private var sharedMetrics: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10),
            GridItem(.flexible(minimum: 220), spacing: 10)
        ], spacing: 10) {
            VaultMetricCard(title: "Archived shares", value: "\(store.entries.count)", detail: "\(sentCount) sent, \(receivedCount) received, \(importedCount) imported")
            VaultMetricCard(title: "People", value: "\(peopleCount)", detail: topPerson.map { "Most shared with \($0)" } ?? "No shared history yet")
            VaultMetricCard(title: "Formats", value: "JSON + JSPF", detail: "\(jspfReadyCount) track shares ready for open playlist export")
        }
    }

    private var sharedTimeline: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Shared Music Timeline", systemImage: "square.and.arrow.up.on.square")
                        .font(.custom("Avenir Next Demi Bold", size: 16))
                    Spacer()
                    Button {
                        isShareComposerPresented = true
                    } label: {
                        Label("Share", systemImage: "paperplane.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }

                if filteredEntries.isEmpty {
                    VaultEmptyState(title: "No shared music archived", detail: "Create a share or import a bundle from another OpenScrobbler user.")
                } else {
                    ForEach(filteredEntries) { entry in
                        SharedTimelineRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                            .onTapGesture { selectedEntry = entry }
                    }
                }
            }
            .appPanelStyle()

            SharedDetailView(entry: selectedEntry ?? filteredEntries.first) { entry in
                store.delete(entry)
                selectedEntry = store.entries.first
            }
            .frame(minWidth: 300, maxWidth: 420)
            .appPanelStyle()
        }
    }

    private var sentCount: Int { store.entries.filter { $0.direction == .sent }.count }
    private var receivedCount: Int { store.entries.filter { $0.direction == .received }.count }
    private var importedCount: Int { store.entries.filter { $0.direction == .imported }.count }
    private var jspfReadyCount: Int { store.entries.filter { $0.entityKind == .track }.count }
    private var peopleCount: Int { Set(store.entries.flatMap(\.recipients) + store.entries.compactMap(\.sender)).count }

    private var topPerson: String? {
        let people = store.entries.flatMap(\.recipients) + store.entries.compactMap(\.sender)
        return Dictionary(grouping: people, by: { $0 }).max { $0.value.count < $1.value.count }?.key
    }

    private func exportSharedBundle() {
        guard let url = savePanelURL(defaultName: "openscrobbler-shared.openscrobbler-shared.json") else { return }
        do {
            try store.export(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importSharedBundle() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importBundle(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }

    private func exportSharedJSPF() {
        guard let url = savePanelURL(defaultName: "openscrobbler-shared.jspf") else { return }
        do {
            try store.exportJSPF(to: url)
        } catch {
            presentVaultError(error)
        }
    }

    private func importSharedJSPF() {
        guard let url = openPanelURL() else { return }
        do {
            try store.importJSPF(from: url)
            selectedEntry = store.entries.first
        } catch {
            presentVaultError(error)
        }
    }
}
