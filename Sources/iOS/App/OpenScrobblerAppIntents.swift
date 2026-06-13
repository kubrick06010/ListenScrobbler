import AppIntents
import Foundation

enum OpenScrobblerDestination: String, AppEnum {
    case home
    case listens
    case discover
    case account

    static var typeDisplayName: LocalizedStringResource { "Destination" }
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Destination"

    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .home: DisplayRepresentation(title: "Home", image: .init(systemName: "music.note.house")),
            .listens: DisplayRepresentation(title: "Listens", image: .init(systemName: "music.note.list")),
            .discover: DisplayRepresentation(title: "Discover", image: .init(systemName: "sparkle.magnifyingglass")),
            .account: DisplayRepresentation(title: "Account", image: .init(systemName: "person.crop.circle"))
        ]
    }

    var tab: MobileTab {
        switch self {
        case .home:
            return .home
        case .listens:
            return .listens
        case .discover:
            return .discover
        case .account:
            return .account
        }
    }
}

struct OpenOpenScrobblerDestinationIntent: AppIntent {
    static let title: LocalizedStringResource = "Open OpenScrobbler"
    static let description = IntentDescription("Open OpenScrobbler to a selected section.")
    static let openAppWhenRun = true

    @Parameter(title: "Destination")
    var destination: OpenScrobblerDestination

    init() {
        destination = .home
    }

    init(destination: OpenScrobblerDestination) {
        self.destination = destination
    }

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MobileAppIntentRouter.shared.request(.tab(destination.tab))
        }
        return .result()
    }
}

struct OpenManualScrobbleIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Manual Scrobble"
    static let description = IntentDescription("Open OpenScrobbler's manual listen form.")
    static let openAppWhenRun = true

    @Parameter(title: "Track Title", inputConnectionBehavior: .connectToPreviousIntentResult)
    var trackTitle: String?

    @Parameter(title: "Artist")
    var artist: String?

    @Parameter(title: "Album")
    var album: String?

    init() {}

    init(trackTitle: String? = nil, artist: String? = nil, album: String? = nil) {
        self.trackTitle = trackTitle
        self.artist = artist
        self.album = album
    }

    func perform() async throws -> some IntentResult {
        let draft = MobileManualScrobbleDraft(
            title: normalized(trackTitle),
            artist: normalized(artist),
            album: normalized(album)
        )
        await MainActor.run {
            MobileAppIntentRouter.shared.request(.manualScrobble(draft))
        }
        return .result()
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct RefreshListenBrainzIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh ListenBrainz"
    static let description = IntentDescription("Open OpenScrobbler and refresh the connected ListenBrainz account.")
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MobileAppIntentRouter.shared.request(.refreshListenBrainz)
        }
        return .result()
    }
}

struct OpenScrobblerAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenOpenScrobblerDestinationIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open \(\.$destination) in \(.applicationName)"
            ],
            shortTitle: "Open",
            systemImageName: "music.note.house"
        )

        AppShortcut(
            intent: OpenManualScrobbleIntent(),
            phrases: [
                "Manual scrobble with \(.applicationName)",
                "Add a listen with \(.applicationName)"
            ],
            shortTitle: "Manual Scrobble",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: RefreshListenBrainzIntent(),
            phrases: [
                "Refresh \(.applicationName)",
                "Refresh ListenBrainz with \(.applicationName)"
            ],
            shortTitle: "Refresh",
            systemImageName: "arrow.clockwise"
        )
    }
}
