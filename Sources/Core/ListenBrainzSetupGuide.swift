import Foundation

public struct ListenBrainzSetupStep: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let detail: String
    public let symbolName: String
    public let actionTitle: String?
    public let actionURL: URL?

    public init(
        id: String,
        title: String,
        detail: String,
        symbolName: String,
        actionTitle: String? = nil,
        actionURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.symbolName = symbolName
        self.actionTitle = actionTitle
        self.actionURL = actionURL
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
    public static let addDataURL = URL(string: "https://listenbrainz.org/add-data/")!
    public static let musicBrainzSignupURL = URL(string: "https://musicbrainz.org/register")!
    public static let tokenURL = URL(string: "https://listenbrainz.org/profile/")!
    public static let importersURL = addDataURL

    public static let eyebrow = "Open Music Setup"
    public static let headline = "Connect ListenBrainz in a few deliberate steps."
    public static let summary = "Create or sign in with MusicBrainz, copy your ListenBrainz user token, validate it in ListenScrobbler, then run one test submission or library scan. No password is stored in the app."

    public static let steps: [ListenBrainzSetupStep] = [
        ListenBrainzSetupStep(
            id: "account",
            title: "Create or sign in to MusicBrainz",
            detail: "ListenBrainz uses your MusicBrainz account. Sign in on the web first so the token page can show your account token.",
            symbolName: "person.crop.circle.badge.plus",
            actionTitle: "Create Account",
            actionURL: musicBrainzSignupURL
        ),
        ListenBrainzSetupStep(
            id: "token",
            title: "Copy your user token",
            detail: "Open your ListenBrainz profile, copy the user token, paste it into the User token field, then choose Save & Validate.",
            symbolName: "key",
            actionTitle: "Open Token Page",
            actionURL: tokenURL
        ),
        ListenBrainzSetupStep(
            id: "enable",
            title: "Enable submissions",
            detail: "Keep ListenBrainz enabled, choose whether to send now playing and completed listens, then save the settings.",
            symbolName: "switch.2"
        ),
        ListenBrainzSetupStep(
            id: "verify",
            title: "Verify with one listen",
            detail: "After validation shows your username, submit a manual listen or run a Music library scan. The first scan builds a baseline instead of importing old history.",
            symbolName: "checkmark.seal"
        ),
        ListenBrainzSetupStep(
            id: "imports",
            title: "Optional: import older history",
            detail: "Use ListenBrainz's Add Data page for supported imports. ListenScrobbler does not require web music-service settings to submit local or manual listens.",
            symbolName: "arrow.down.doc",
            actionTitle: "Open Add Data",
            actionURL: addDataURL
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
            title: "Add Existing Data",
            detail: "Open ListenBrainz import options for older listening history.",
            symbolName: "arrow.down.doc",
            url: addDataURL
        )
    ]
}
