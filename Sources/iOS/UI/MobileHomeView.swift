import OpenScrobblerCore
import SwiftUI

struct MobileHomeView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("ListenPulse")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 56)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenScrobbler")
                            .font(.largeTitle.bold())
                        Text(listeningStore.connectionState.statusText)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            if let pin = listeningStore.currentPin {
                Section("Current Pin") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pin.trackName)
                            .font(.headline)
                        Text(pin.artistName)
                            .foregroundStyle(.secondary)
                        if let blurb = pin.blurb, !blurb.isEmpty {
                            Text(blurb)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("iOS Foundation") {
                Label("ListenBrainz-first account and archive", systemImage: "checkmark.seal")
                Label("Shared core client, no duplicated API layer", systemImage: "arrow.triangle.2.circlepath")
                Label("Music library delta scanning for iOS plays", systemImage: "music.note.list")
            }

            Section("Last.fm Lessons") {
                Label("Keep Now Playing reachable from every stack", systemImage: "play.circle")
                Label("Use compact track, artist, and album detail routes", systemImage: "rectangle.stack")
                Label("Blend recommendations, search, and radio into discovery", systemImage: "sparkles")
            }
        }
        .navigationTitle("Home")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "play.circle")
                }
                .disabled(true)
                .accessibilityLabel("Now Playing")
            }
        }
        .refreshable {
            await listeningStore.refresh()
        }
    }
}
