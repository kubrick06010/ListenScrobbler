import SwiftUI

struct MobileDiscoverView: View {
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
                        Text("Recommendations, search, radio prompts, and social graph routes.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Start Here") {
                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Recommendations",
                        symbol: "sparkles",
                        detail: "Use ListenBrainz recommendations and similar users as the mobile successor to Last.fm's recommendations tab."
                    )
                } label: {
                    Label("Recommendations", systemImage: "sparkles")
                }

                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Search",
                        symbol: "magnifyingglass",
                        detail: "Search should route to artist, release, recording, tag, and playlist detail screens instead of becoming a generic web view."
                    )
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    MobileDiscoveryPlaceholderView(
                        title: "Radio",
                        symbol: "dot.radiowaves.left.and.right",
                        detail: "Radio should be built on ListenBrainz recommendations, LB Radio prompts, and local queue export rather than legacy streaming assumptions."
                    )
                } label: {
                    Label("Radio", systemImage: "dot.radiowaves.left.and.right")
                }
            }

            Section("Mobile Pattern") {
                Text("Last.fm's iPhone app kept discovery one tap away with dedicated tabs. OpenScrobbler should keep that speed, but map it to open identifiers, pins, playlists, and ListenBrainz-compatible recommendations.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Discover")
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
