import AppIntents
import Foundation
import OpenScrobblerCore
import WidgetKit

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

struct RefreshOpenScrobblerWidgetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh OpenScrobbler Widgets"
    static let description = IntentDescription("Reload OpenScrobbler widgets with the latest saved ListenBrainz snapshot.")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        WidgetCenter.shared.reloadAllTimelines()
        return .result(dialog: "OpenScrobbler widgets are refreshing.")
    }
}

struct SubmitManualScrobbleIntent: AppIntent {
    static let title: LocalizedStringResource = "Submit Manual Scrobble"
    static let description = IntentDescription("Submit a manual listen directly to ListenBrainz.")
    static let openAppWhenRun = false

    @Parameter(title: "Track Title", inputConnectionBehavior: .connectToPreviousIntentResult)
    var trackTitle: String

    @Parameter(title: "Artist")
    var artist: String

    @Parameter(title: "Album")
    var album: String?

    @Parameter(title: "Duration Minutes")
    var durationMinutes: Int

    @Parameter(title: "Duration Seconds")
    var durationSeconds: Int

    @Parameter(title: "Listened At")
    var listenedAt: Date?

    init() {
        trackTitle = ""
        artist = ""
        album = nil
        durationMinutes = 3
        durationSeconds = 0
        listenedAt = nil
    }

    init(
        trackTitle: String,
        artist: String,
        album: String? = nil,
        durationMinutes: Int = 3,
        durationSeconds: Int = 0,
        listenedAt: Date? = nil
    ) {
        self.trackTitle = trackTitle
        self.artist = artist
        self.album = album
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
        self.listenedAt = listenedAt
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let title = normalized(trackTitle)
        let artistName = normalized(artist)
        let albumName = normalized(album).nilIfBlank
        let duration = TimeInterval((max(0, durationMinutes) * 60) + min(max(0, durationSeconds), 59))

        guard !title.isEmpty else { throw SubmitManualScrobbleIntentError.missingTitle }
        guard !artistName.isEmpty else { throw SubmitManualScrobbleIntentError.missingArtist }
        guard duration >= 30 else { throw SubmitManualScrobbleIntentError.shortDuration }

        let store = await MainActor.run { MobileListeningStore() }
        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: title,
                artist: artistName,
                album: albumName,
                duration: duration,
                listenedAt: listenedAt ?? Date(),
                source: "OpenScrobbler iOS Shortcut",
                sourceMetadata: MobileScrobbleSourceMetadata(
                    mediaPlayer: "Shortcuts",
                    musicServiceName: "OpenScrobbler",
                    originalSubmissionClient: "Submit Manual Scrobble Intent"
                )
            )
        )
        await store.refresh()

        return .result(dialog: "Submitted \(title) to ListenBrainz.")
    }

    private func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

struct RepeatRecentListenIntent: AppIntent {
    static let title: LocalizedStringResource = "Repeat Recent Listen"
    static let description = IntentDescription("Submit the latest ListenBrainz listen again with OpenScrobbler source metadata.")
    static let openAppWhenRun = false

    @Parameter(title: "Duration Minutes")
    var durationMinutes: Int

    @Parameter(title: "Duration Seconds")
    var durationSeconds: Int

    init() {
        durationMinutes = 3
        durationSeconds = 0
    }

    init(durationMinutes: Int = 3, durationSeconds: Int = 0) {
        self.durationMinutes = durationMinutes
        self.durationSeconds = durationSeconds
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let duration = TimeInterval((max(0, durationMinutes) * 60) + min(max(0, durationSeconds), 59))
        guard duration >= 30 else { throw RepeatRecentListenIntentError.shortDuration }

        let store = await MainActor.run { MobileListeningStore() }
        await store.refresh()

        guard let listen = await MainActor.run(body: { store.recentListens.first }) else {
            throw RepeatRecentListenIntentError.noRecentListen
        }

        try await store.submitScrobble(
            MobileScrobbleCandidate(
                title: listen.trackName,
                artist: listen.artistName,
                album: listen.releaseName,
                duration: duration,
                listenedAt: Date(),
                source: "OpenScrobbler iOS Repeat Shortcut",
                sourceMetadata: MobileScrobbleSourceMetadata(
                    mediaPlayer: "Shortcuts",
                    musicServiceName: "ListenBrainz",
                    originalSubmissionClient: "Repeat Recent Listen Intent"
                )
            )
        )
        await store.refresh()

        return .result(dialog: "Repeated \(listen.trackName) to ListenBrainz.")
    }
}

private enum SubmitManualScrobbleIntentError: LocalizedError {
    case missingTitle
    case missingArtist
    case shortDuration

    var errorDescription: String? {
        switch self {
        case .missingTitle:
            return "Add a track title before submitting."
        case .missingArtist:
            return "Add an artist before submitting."
        case .shortDuration:
            return "Use a duration of at least 30 seconds."
        }
    }
}

private enum RepeatRecentListenIntentError: LocalizedError {
    case noRecentListen
    case shortDuration

    var errorDescription: String? {
        switch self {
        case .noRecentListen:
            return "Connect ListenBrainz and refresh recent listens before repeating one."
        case .shortDuration:
            return "Use a duration of at least 30 seconds."
        }
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

        AppShortcut(
            intent: RefreshOpenScrobblerWidgetsIntent(),
            phrases: [
                "Refresh OpenScrobbler widgets with \(.applicationName)",
                "Update OpenScrobbler widgets with \(.applicationName)"
            ],
            shortTitle: "Refresh Widgets",
            systemImageName: "rectangle.3.group"
        )

        AppShortcut(
            intent: SubmitManualScrobbleIntent(),
            phrases: [
                "Submit a listen with \(.applicationName)",
                "Add a scrobble with \(.applicationName)"
            ],
            shortTitle: "Submit Listen",
            systemImageName: "checkmark.circle"
        )

        AppShortcut(
            intent: RepeatRecentListenIntent(),
            phrases: [
                "Repeat recent listen with \(.applicationName)",
                "Scrobble the last listen with \(.applicationName)"
            ],
            shortTitle: "Repeat Listen",
            systemImageName: "repeat"
        )
    }
}

private extension String {
    var nilIfBlank: String? {
        isEmpty ? nil : self
    }
}
