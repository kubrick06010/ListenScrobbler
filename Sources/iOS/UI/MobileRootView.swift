import OpenScrobblerCore
import SwiftUI
import WidgetKit

struct MobileRootView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @EnvironmentObject private var appIntentRouter: MobileAppIntentRouter
    @State private var selectedTab: MobileTab = .home
    @State private var manualScrobbleDraft: MobileManualScrobbleDraft?

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                MobileHomeView()
            }
            .tabItem {
                Label("Home", systemImage: "music.note.house")
            }
            .tag(MobileTab.home)

            NavigationStack {
                MobileListensView {
                    manualScrobbleDraft = .empty
                }
            }
            .tabItem {
                Label("Listens", systemImage: "music.note.list")
            }
            .tag(MobileTab.listens)

            NavigationStack {
                MobileDiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "sparkle.magnifyingglass")
            }
            .tag(MobileTab.discover)

            NavigationStack {
                MobileAccountView()
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle")
            }
            .tag(MobileTab.account)
        }
        .task {
            await listeningStore.refresh()
            WidgetCenter.shared.reloadAllTimelines()
        }
        .sheet(item: $manualScrobbleDraft) { draft in
            MobileManualScrobbleView(draft: draft)
                .environmentObject(listeningStore)
        }
        .onReceive(appIntentRouter.$pendingRoute.compactMap { $0 }) { route in
            handle(route)
        }
    }

    private func handle(_ route: MobileAppRoute) {
        switch route {
        case let .tab(tab):
            selectedTab = tab
        case let .manualScrobble(draft):
            selectedTab = .listens
            manualScrobbleDraft = draft
        case .refreshListenBrainz:
            selectedTab = .home
            Task {
                await listeningStore.refresh()
                WidgetCenter.shared.reloadAllTimelines()
            }
        }
        appIntentRouter.clear()
    }
}
