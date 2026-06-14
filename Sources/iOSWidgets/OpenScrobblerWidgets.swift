import OpenScrobblerCore
import SwiftUI
import WidgetKit

private enum OpenScrobblerWidgetKind {
    static let status = "OpenScrobblerStatusWidget"
    static let recentListen = "OpenScrobblerRecentListenWidget"
    static let discovery = "OpenScrobblerDiscoveryWidget"
}

private struct OpenScrobblerWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: MobileWidgetSnapshot
}

private struct OpenScrobblerWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> OpenScrobblerWidgetEntry {
        OpenScrobblerWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (OpenScrobblerWidgetEntry) -> Void) {
        completion(OpenScrobblerWidgetEntry(date: .now, snapshot: MobileWidgetSnapshotStore().load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<OpenScrobblerWidgetEntry>) -> Void) {
        let entry = OpenScrobblerWidgetEntry(date: .now, snapshot: MobileWidgetSnapshotStore().load())
        completion(Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(15 * 60))))
    }
}

struct OpenScrobblerStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: OpenScrobblerWidgetKind.status,
            provider: OpenScrobblerWidgetProvider()
        ) { entry in
            OpenScrobblerStatusWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("OpenScrobbler Status")
        .description("Show ListenBrainz connection state and queued mobile listens.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OpenScrobblerRecentListenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: OpenScrobblerWidgetKind.recentListen,
            provider: OpenScrobblerWidgetProvider()
        ) { entry in
            OpenScrobblerRecentListenWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Recent Listen")
        .description("Show the latest ListenBrainz listen captured by OpenScrobbler.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct OpenScrobblerDiscoveryWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(
            kind: OpenScrobblerWidgetKind.discovery,
            provider: OpenScrobblerWidgetProvider()
        ) { entry in
            OpenScrobblerDiscoveryWidgetView(snapshot: entry.snapshot)
        }
        .configurationDisplayName("Open Discovery")
        .description("Show the current pin or first ListenBrainz recommendation.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct OpenScrobblerWidgets: WidgetBundle {
    var body: some Widget {
        OpenScrobblerStatusWidget()
        OpenScrobblerRecentListenWidget()
        OpenScrobblerDiscoveryWidget()
    }
}

private struct OpenScrobblerStatusWidgetView: View {
    let snapshot: MobileWidgetSnapshot

    var body: some View {
        WidgetPanel {
            WidgetHeader(title: "OpenScrobbler", imageName: "ListenPulse")

            Spacer(minLength: 6)

            Text(snapshot.username ?? "ListenBrainz")
                .font(.headline)
                .lineLimit(1)

            Text(snapshot.connectionStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            Spacer(minLength: 6)

            Label("\(snapshot.pendingCount) pending", systemImage: pendingSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(snapshot.pendingCount > 0 ? .orange : .secondary)
                .lineLimit(1)

            WidgetUpdatedFooter(updatedAt: snapshot.updatedAt)
        }
    }

    private var pendingSymbol: String {
        snapshot.pendingCount > 0 ? "tray.full" : "checkmark.circle"
    }
}

private struct OpenScrobblerRecentListenWidgetView: View {
    let snapshot: MobileWidgetSnapshot

    var body: some View {
        WidgetPanel {
            WidgetHeader(title: "Recent Listen", imageName: "OpenGraph")

            Spacer(minLength: 6)

            if let listen = snapshot.recentListen {
                Text(listen.trackName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                Text(listen.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let listenedAt = listen.listenedAt {
                    Text(listenedAt, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            } else {
                EmptyWidgetState(
                    title: "No recent listen",
                    detail: "Refresh OpenScrobbler to update ListenBrainz."
                )
            }

            WidgetUpdatedFooter(updatedAt: snapshot.updatedAt)
        }
    }
}

private struct OpenScrobblerDiscoveryWidgetView: View {
    let snapshot: MobileWidgetSnapshot

    var body: some View {
        WidgetPanel {
            WidgetHeader(title: "Discovery", imageName: "DiscoveryRadio")

            Spacer(minLength: 6)

            if let pin = snapshot.currentPin {
                Text("Pinned")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(pin.trackName)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(pin.artistName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else if let recommendation = snapshot.recommendation {
                Text("Recommended")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(recommendation.title)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                if let artistName = recommendation.artistName {
                    Text(artistName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            } else {
                EmptyWidgetState(
                    title: "No discovery yet",
                    detail: "Refresh recommendations in OpenScrobbler."
                )
            }

            WidgetUpdatedFooter(updatedAt: snapshot.updatedAt)
        }
    }
}

private struct WidgetPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color(red: 1.0, green: 0.996, blue: 0.86)
        }
    }
}

private struct WidgetHeader: View {
    let title: String
    let imageName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 24, height: 24)
                .accessibilityHidden(true)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct EmptyWidgetState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .lineLimit(2)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
    }
}

private struct WidgetUpdatedFooter: View {
    let updatedAt: Date

    var body: some View {
        if updatedAt > .distantPast {
            Spacer(minLength: 4)

            Text("Updated \(updatedAt, style: .relative)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }
}

#Preview("Recent Listen", as: .systemSmall) {
    OpenScrobblerRecentListenWidget()
} timeline: {
    OpenScrobblerWidgetEntry(
        date: .now,
        snapshot: MobileWidgetSnapshot(
            connectionStatus: "open-user on ListenBrainz",
            username: "open-user",
            recentListen: MobileWidgetListen(
                trackName: "Sketch for Summer",
                artistName: "The Durutti Column",
                releaseName: "The Return of the Durutti Column",
                listenedAt: .now.addingTimeInterval(-600)
            ),
            currentPin: nil,
            recommendation: nil,
            pendingCount: 0,
            updatedAt: .now
        )
    )
}
