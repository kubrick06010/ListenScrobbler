import Combine
import Foundation

enum MobileTab: String, CaseIterable, Hashable {
    case home
    case listens
    case discover
    case account
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
