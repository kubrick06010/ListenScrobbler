import OpenScrobblerCore
import SwiftUI

struct MobileListensView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @State private var isManualScrobblePresented = false

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
                    isManualScrobblePresented = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!listeningStore.hasStoredToken)
                .accessibilityLabel("Manual Scrobble")
            }
        }
        .sheet(isPresented: $isManualScrobblePresented) {
            MobileManualScrobbleView()
                .environmentObject(listeningStore)
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
