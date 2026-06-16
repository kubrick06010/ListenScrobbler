import ListenScrobblerCore
import SwiftUI

struct MobileListensView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    let openManualScrobble: () -> Void
    @State private var listenPendingDeletion: MobileListenSummary?

    var body: some View {
        List {
            if listeningStore.recentListens.isEmpty {
                ContentUnavailableView(
                    "No listens loaded",
                    systemImage: "music.note.list",
                    description: Text("Connect ListenBrainz or pull to refresh.")
                )
            } else {
                ForEach(listeningStore.recentListens) { listen in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(listen.trackName)
                            .font(.headline)
                        Text(listen.artistName)
                            .foregroundStyle(.secondary)
                        if let releaseName = listen.releaseName, !releaseName.isEmpty {
                            Text(releaseName)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding(.vertical, 4)
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            listenPendingDeletion = listen
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(!canDelete(listen))
                    }
                }
            }
        }
        .navigationTitle("Listens")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    openManualScrobble()
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!listeningStore.hasStoredToken)
                .accessibilityLabel("Manual Scrobble")
            }
        }
        .overlay {
            if listeningStore.isRefreshing {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .refreshable {
            await listeningStore.refresh()
        }
        .confirmationDialog(
            "Delete this ListenBrainz listen?",
            isPresented: Binding(
                get: { listenPendingDeletion != nil },
                set: { isPresented in
                    if !isPresented {
                        listenPendingDeletion = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            if let listen = listenPendingDeletion {
                Button("Delete Listen", role: .destructive) {
                    Task { _ = await listeningStore.deleteListen(listen) }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("ListenBrainz schedules deletions, so counts may update after the next hourly cleanup.")
        }
    }

    private func canDelete(_ listen: MobileListenSummary) -> Bool {
        listen.listenedAt != nil && listen.recordingMSID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
