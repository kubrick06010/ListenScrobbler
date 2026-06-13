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

public enum ListenBrainzSetupGuide {
    public static let listenBrainzURL = URL(string: "https://listenbrainz.org/")!
    public static let musicBrainzSignupURL = URL(string: "https://musicbrainz.org/register")!
    public static let tokenURL = URL(string: "https://listenbrainz.org/profile/")!
    public static let importersURL = URL(string: "https://listenbrainz.org/settings/music-services/")!

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
            detail: "Open your ListenBrainz profile, copy the user token, and paste it here. OpenScrobbler never needs your password.",
            symbolName: "key"
        ),
        ListenBrainzSetupStep(
            id: "sources",
            title: "Connect listening sources",
            detail: "Set up ListenBrainz music services such as Spotify or imports on the web, then let OpenScrobbler submit local and manual listens with clear source metadata.",
            symbolName: "point.3.connected.trianglepath.dotted"
        ),
        ListenBrainzSetupStep(
            id: "verify",
            title: "Validate and scan",
            detail: "Validate the token, review the connected username, then run a library scan or submit a manual listen to confirm the pipeline.",
            symbolName: "checkmark.seal"
        )
    ]
}
