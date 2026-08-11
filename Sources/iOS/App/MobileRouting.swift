import Combine
import Foundation
import ListenScrobblerCore

enum MobileTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case listens
    case discover
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return AppLocalization.string("Home")
        case .listens:
            return AppLocalization.string("Listens")
        case .discover:
            return AppLocalization.string("Discover")
        case .account:
            return AppLocalization.string("Account")
        }
    }

    var symbolName: String {
        switch self {
        case .home:
            return "music.note.house"
        case .listens:
            return "music.note.list"
        case .discover:
            return "sparkle.magnifyingglass"
        case .account:
            return "person.crop.circle"
        }
    }
}

struct MobileManualScrobbleDraft: Identifiable, Equatable {
    let id = UUID()
    var title: String
    var artist: String
    var album: String

    static let empty = MobileManualScrobbleDraft(title: "", artist: "", album: "")
}

enum MobileAppRoute {
    case tab(MobileTab)
    case manualScrobble(MobileManualScrobbleDraft)
    case refreshListenBrainz
}

@MainActor
final class MobileAppIntentRouter: ObservableObject {
    static let shared = MobileAppIntentRouter()

    @Published private(set) var pendingRoute: MobileAppRoute?

    private init() {}

    func request(_ route: MobileAppRoute) {
        pendingRoute = route
    }

    func clear() {
        pendingRoute = nil
    }
}
