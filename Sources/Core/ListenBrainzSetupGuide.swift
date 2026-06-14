import Foundation

public struct ListenBrainzSetupStep: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String

    public init(id: String, title: String, detail: String, symbolName: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
    }
}

public struct ListenBrainzOnboardingFeature: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String

    public init(id: String, title: String, detail: String, symbolName: String) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
    }
}

public struct ListenBrainzOnboardingAction: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let url: URL

    public init(id: String, title: String, detail: String, symbolName: String, url: URL) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.url = url
    }
}

public enum ListenBrainzSetupGuide {
    public static let listenBrainzURL = URL(string: "https://listenbrainz.org/")!
    public static let musicBrainzSignupURL = URL(string: "https://musicbrainz.org/register")!
    public static let tokenURL = URL(string: "https://listenbrainz.org/profile/")!
    public static let importersURL = URL(string: "https://listenbrainz.org/settings/music-services/")!

    public static let eyebrow = "Open Music Setup"
    public static let headline = "Scrobbling, rebuilt around open music data."
    public static let summary = "ListenScrobbler keeps the fast account setup and familiar listening timeline of classic scrobblers, then connects it to ListenBrainz, MusicBrainz metadata, recommendations, social discovery, and portable exports."

    public static let steps: [ListenBrainzSetupStep] = [
        ListenBrainzSetupStep(
            id: "account",
            title: "Create or sign in",
            detail: "Use a MusicBrainz account to unlock ListenBrainz listens, charts, pins, and recommendations.",
            symbolName: "person.crop.circle.badge.plus"
        ),
        ListenBrainzSetupStep(
            id: "token",
            title: "Copy your user token",
            detail: "Open your ListenBrainz profile, copy the user token, and paste it here. ListenScrobbler never needs your password.",
            symbolName: "key"
        ),
        ListenBrainzSetupStep(
            id: "sources",
            title: "Connect listening sources",
            detail: "Set up ListenBrainz music services such as Spotify or imports on the web, then let ListenScrobbler submit local and manual listens with clear source metadata.",
            symbolName: "point.3.connected.trianglepath.dotted"
        ),
        ListenBrainzSetupStep(
            id: "verify",
            title: "Validate and scan",
            detail: "Validate the token, review the connected username, then run a library scan or submit a manual listen to confirm the pipeline.",
            symbolName: "checkmark.seal"
        )
    ]

    public static let onboardingFeatures: [ListenBrainzOnboardingFeature] = [
        ListenBrainzOnboardingFeature(
            id: "timeline",
            title: "A familiar listening timeline",
            detail: "Recent listens, now playing state, manual submissions, and library scans stay quick to reach.",
            symbolName: "music.note.list"
        ),
        ListenBrainzOnboardingFeature(
            id: "identity",
            title: "Your account stays portable",
            detail: "MusicBrainz sign-in and ListenBrainz tokens avoid password storage while keeping your listening identity open.",
            symbolName: "person.crop.circle.badge.checkmark"
        ),
        ListenBrainzOnboardingFeature(
            id: "discovery",
            title: "Discovery without a locked graph",
            detail: "Charts, pins, followers, similar users, and recommendations use open identifiers you can take elsewhere.",
            symbolName: "sparkle.magnifyingglass"
        )
    ]

    public static let onboardingActions: [ListenBrainzOnboardingAction] = [
        ListenBrainzOnboardingAction(
            id: "create",
            title: "Create MusicBrainz Account",
            detail: "Use it to sign in to ListenBrainz.",
            symbolName: "person.crop.circle.badge.plus",
            url: musicBrainzSignupURL
        ),
        ListenBrainzOnboardingAction(
            id: "token",
            title: "Copy ListenBrainz Token",
            detail: "Paste the token in ListenScrobbler.",
            symbolName: "key",
            url: tokenURL
        ),
        ListenBrainzOnboardingAction(
            id: "import",
            title: "Connect Music Services",
            detail: "Configure web imports and connected listening sources.",
            symbolName: "arrow.down.doc",
            url: importersURL
        )
    ]
}
