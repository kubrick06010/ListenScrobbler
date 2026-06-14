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

            Section("Explore") {
                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Search",
                        symbol: "magnifyingglass",
                        detail: "Search is queued for the next parity pass."
                    )
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Radio",
                        symbol: "dot.radiowaves.left.and.right",
                        detail: "Radio is queued for the next parity pass."
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
                        await listeningStore.refreshRecommendations()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(!canRefreshRecommendations)
                .accessibilityLabel("Refresh Recommendations")
            }
        }
        .refreshable {
            await listeningStore.refreshRecommendations()
        }
        .task {
            if listeningStore.recommendedRecordings.isEmpty {
                await listeningStore.refreshRecommendations()
            }
        }
    }

    private var canRefreshRecommendations: Bool {
        guard case .connected = listeningStore.connectionState else { return false }
        return !listeningStore.isRefreshingRecommendations
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
