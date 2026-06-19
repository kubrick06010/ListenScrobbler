import Combine
import Foundation

enum MobileTab: String, CaseIterable, Hashable, Identifiable {
    case home
    case listens
    case discover
    case account

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home:
            return String(localized: "Home")
        case .listens:
            return String(localized: "Listens")
        case .discover:
            return String(localized: "Discover")
        case .account:
            return String(localized: "Account")
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
