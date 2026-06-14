import OpenScrobblerCore
import SwiftUI

struct MobileDiscoverView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("DiscoveryRadio")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 54, height: 54)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Open Discovery")
                            .font(.headline)
                        Text(listeningStore.recommendationsStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(listeningStore.socialStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Recommendations") {
                if listeningStore.recommendedRecordings.isEmpty {
                    Label(listeningStore.recommendationsStatus, systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(listeningStore.recommendedRecordings) { recommendation in
                        MobileRecommendationRow(recommendation: recommendation)
                    }
                }

                Button {
                    Task {
                        await listeningStore.refreshRecommendations()
                    }
                } label: {
                    if listeningStore.isRefreshingRecommendations {
                        Label("Refreshing", systemImage: "hourglass")
                    } else {
                        Label("Refresh Recommendations", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!canRefreshRecommendations)
            }

            Section("Social Feed") {
                if let snapshot = listeningStore.socialSnapshot {
                    MobileSocialSummaryView(snapshot: snapshot)

                    if snapshot.neighborListens.isEmpty {
                        Label(listeningStore.socialStatus, systemImage: "person.2")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(snapshot.neighborListens.prefix(8)) { listen in
                            MobileSocialListenRow(listen: listen)
                        }
                    }
                } else {
                    Label(listeningStore.socialStatus, systemImage: "person.2")
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task {
                        await listeningStore.refreshSocial()
                    }
                } label: {
                    if listeningStore.isRefreshingSocial {
                        Label("Refreshing", systemImage: "hourglass")
                    } else {
                        Label("Refresh Social", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!canRefreshSocial)
            }

            Section("Explore") {
                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Search",
                        symbol: "magnifyingglass",
                        detail: "Available in a later build."
                    )
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Radio",
                        symbol: "dot.radiowaves.left.and.right",
                        detail: "Available in a later build."
                    )
                } label: {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
            }
        }
        .navigationTitle("Discover")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await refreshDiscovery()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!canRefreshDiscovery)
                .accessibilityLabel("Refresh Discover")
            }
        }
        .refreshable {
            await refreshDiscovery()
        }
        .task {
            if listeningStore.recommendedRecordings.isEmpty {
                await listeningStore.refreshRecommendations()
            }
            if listeningStore.socialSnapshot == nil {
                await listeningStore.refreshSocial()
            }
        }
    }

    private var canRefreshRecommendations: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingRecommendations
    }

    private var canRefreshSocial: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingSocial
    }

    private var canRefreshDiscovery: Bool {
        canRefreshRecommendations && canRefreshSocial
    }

    private func refreshDiscovery() async {
        await listeningStore.refreshRecommendations()
        await listeningStore.refreshSocial()
    }
}

private struct MobileRecommendationRow: View {
    let recommendation: MobileRecommendedRecording

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title)
                    .font(.headline)
                    .lineLimit(2)

                if let artistName = recommendation.artistName, !artistName.isEmpty {
                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if let releaseName = recommendation.releaseName, !releaseName.isEmpty {
                    Text(releaseName)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 10)

            Image(systemName: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
    }
}

private struct MobileSocialSummaryView: View {
    let snapshot: MobileSocialSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                MobileSocialMetric(title: "Followers", value: snapshot.followers.count)
                MobileSocialMetric(title: "Following", value: snapshot.following.count)
                MobileSocialMetric(title: "Similar", value: snapshot.similarUsers.count)
            }

            if !snapshot.similarUsers.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(snapshot.similarUsers.prefix(8)) { user in
                            Label(user.userName, systemImage: "person.crop.circle")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.thinMaterial, in: Capsule())
                        }
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

private struct MobileSocialMetric: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.formatted())
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct MobileSocialListenRow: View {
    let listen: MobileSocialListen

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: "person.crop.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 0.83, green: 0.06, blue: 0.09))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(listen.trackName)
                    .font(.headline)
                    .lineLimit(2)

                Text(listen.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(listen.userName)
                    if let listenedAt = listen.listenedAt {
                        Text(listenedAt.formatted(date: .omitted, time: .shortened))
                    }
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct MobileDiscoveryPlaceholderView: View {
    let title: String
    let symbol: String
    let detail: String

    var body: some View {
        VStack(spacing: 18) {
            Image(symbolImageName)
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .accessibilityHidden(true)

            ContentUnavailableView(
                title,
                systemImage: symbol,
                description: Text(detail)
            )
        }
        .navigationTitle(title)
    }

    private var symbolImageName: String {
        switch title {
        case "Recommendations":
            return "OpenGraph"
        case "Radio":
            return "DiscoveryRadio"
        default:
            return "ListenPulse"
        }
    }
}
