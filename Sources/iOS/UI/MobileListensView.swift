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
                    NavigationLink {
                        MobileMusicDetailView(seed: listenSeed(listen))
                    } label: {
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
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            Task { _ = await listeningStore.loveListen(listen) }
                        } label: {
                            Label("Love", systemImage: "heart.fill")
                        }
                        .tint(.pink)
                        .disabled(!canSendFeedback(listen))

                        Button {
                            Task { _ = await listeningStore.unloveListen(listen) }
                        } label: {
                            Label("Unlove", systemImage: "heart.slash")
                        }
                        .tint(.gray)
                        .disabled(!canSendFeedback(listen))

                        Button {
                            Task {
                                if listeningStore.isCurrentPin(listen) {
                                    _ = await listeningStore.unpinCurrent()
                                } else {
                                    _ = await listeningStore.pinListen(listen)
                                }
                            }
                        } label: {
                            Label(
                                listeningStore.isCurrentPin(listen) ? "Unpin" : "Pin",
                                systemImage: listeningStore.isCurrentPin(listen) ? "pin.slash" : "pin"
                            )
                        }
                        .tint(.orange)
                        .disabled(!canSendFeedback(listen))
                    }
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

    private func canSendFeedback(_ listen: MobileListenSummary) -> Bool {
        listeningStore.hasStoredToken &&
            (listen.recordingMBID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ||
                listen.recordingMSID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
    }

    private func listenSeed(_ listen: MobileListenSummary) -> MobileMusicDetailSeed {
        MobileMusicDetailSeed(
            kind: .track,
            trackName: listen.trackName,
            artistName: listen.artistName,
            releaseName: listen.releaseName,
            recordingMBID: listen.recordingMBID,
            recordingMSID: listen.recordingMSID,
            artistMBID: listen.artistMBID,
            releaseMBID: listen.releaseMBID,
            imageURL: listen.imageURL
        )
    }
}
