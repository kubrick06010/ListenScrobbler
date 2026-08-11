import ListenScrobblerCore
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
                        Text("ListenScrobbler")
                            .font(.largeTitle.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.72)
                        Text(listeningStore.connectionState.statusText)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("ListenScrobbler, \(listeningStore.connectionState.statusText)")
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
                    MobileStatsOverviewRow(snapshot: snapshot)
                } else {
                    Label(listeningStore.statsStatus, systemImage: "chart.bar")
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot = listeningStore.statsSnapshot {
                if !snapshot.topArtists.isEmpty {
                    Section("Top Artists") {
                        ForEach(snapshot.topArtists.prefix(8)) { artist in
                            MobileStatRow(
                                title: artist.name,
                                subtitle: nil,
                                value: artist.listenCount
                            )
                        }
                    }
                }

                if !snapshot.topReleases.isEmpty {
                    Section("Top Releases") {
                        ForEach(snapshot.topReleases.prefix(8)) { release in
                            MobileStatRow(
                                title: release.name,
                                subtitle: release.artistName,
                                value: release.listenCount
                            )
                        }
                    }
                }

                if !snapshot.topRecordings.isEmpty {
                    Section("Top Tracks") {
                        ForEach(snapshot.topRecordings.prefix(8)) { recording in
                            MobileStatRow(
                                title: recording.trackName,
                                subtitle: recording.artistName,
                                value: recording.listenCount
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle("Home")
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

private struct MobileStatsOverviewRow: View {
    let snapshot: MobileStatsSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(snapshot.range.title, systemImage: "chart.bar.xaxis")
                    .font(.headline)

                Spacer()

                if let totalListenCount = snapshot.totalListenCount {
                    Text(AppLocalization.localizedStringWithFormat(
                        AppLocalization.string("%@ listens"),
                        AppLocalization.integer(totalListenCount)
                    ))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text("Updated \(AppLocalization.date(snapshot.fetchedAt, date: .omitted, time: .shortened))")
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

            Text(AppLocalization.integer(value))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }
}
