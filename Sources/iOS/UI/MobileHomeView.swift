import OpenScrobblerCore
import SwiftUI
import WidgetKit

struct MobileHomeView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @State private var statsRange: MobileStatsRange = .week

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

            Section("Stats") {
                Picker("Range", selection: $statsRange) {
                    ForEach(MobileStatsRange.allCases) { range in
                        Text(range.title)
                            .tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: statsRange) { _, newValue in
                    Task {
                        await listeningStore.refreshStats(range: newValue)
                        WidgetCenter.shared.reloadAllTimelines()
                    }
                }

                if let snapshot = listeningStore.statsSnapshot {
                    MobileStatsSummaryView(snapshot: snapshot)
                } else {
                    Label(listeningStore.statsStatus, systemImage: "chart.bar")
                        .foregroundStyle(.secondary)
                }
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
            await listeningStore.refreshStats(range: statsRange)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .task {
            await listeningStore.refreshStats(range: statsRange)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
}

private struct MobileStatsSummaryView: View {
    let snapshot: MobileStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(snapshot.range.title, systemImage: "chart.bar.xaxis")
                    .font(.headline)

                Spacer()

                if let totalListenCount = snapshot.totalListenCount {
                    Text("\(totalListenCount.formatted()) listens")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if !snapshot.topArtists.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists")
                        .font(.subheadline.weight(.semibold))
                    ForEach(snapshot.topArtists.prefix(5)) { artist in
                        MobileStatRow(
                            title: artist.name,
                            subtitle: nil,
                            value: artist.listenCount
                        )
                    }
                }
            }

            if !snapshot.topReleases.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Releases")
                        .font(.subheadline.weight(.semibold))
                    ForEach(snapshot.topReleases.prefix(5)) { release in
                        MobileStatRow(
                            title: release.name,
                            subtitle: release.artistName,
                            value: release.listenCount
                        )
                    }
                }
            }

            if !snapshot.topRecordings.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Tracks")
                        .font(.subheadline.weight(.semibold))
                    ForEach(snapshot.topRecordings.prefix(5)) { recording in
                        MobileStatRow(
                            title: recording.trackName,
                            subtitle: recording.artistName,
                            value: recording.listenCount
                        )
                    }
                }
            }

            Text("Updated \(snapshot.fetchedAt.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileStatRow: View {
    let title: String
    let subtitle: String?
    let value: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Text(value.formatted())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
