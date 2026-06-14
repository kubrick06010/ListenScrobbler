import ListenScrobblerCore
import SwiftUI

struct MobileListensView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    let openManualScrobble: () -> Void

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
    }
}
