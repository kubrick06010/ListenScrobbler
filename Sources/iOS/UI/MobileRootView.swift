import OpenScrobblerCore
import SwiftUI

struct MobileRootView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @State private var selectedTab: MobileTab = .home

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
                MobileListensView()
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
        }
    }
}

private enum MobileTab: Hashable {
    case home
    case listens
    case discover
    case account
}
