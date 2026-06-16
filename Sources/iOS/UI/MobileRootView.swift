import ListenScrobblerCore
import SwiftUI
import WidgetKit

struct MobileRootView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @EnvironmentObject private var appIntentRouter: MobileAppIntentRouter
    @AppStorage("onboarding.openMusic.completed") private var didCompleteOpenMusicOnboarding = false
    @State private var selectedTab: MobileTab = .home
    @State private var manualScrobbleDraft: MobileManualScrobbleDraft?
    @State private var isOpenMusicOnboardingPresented = false

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                regularLayout
            } else {
                compactLayout
            }
        }
        .task {
            await listeningStore.refresh()
            WidgetCenter.shared.reloadAllTimelines()
            presentOnboardingIfNeeded()
        }
        .sheet(item: $manualScrobbleDraft) { draft in
            MobileManualScrobbleView(draft: draft)
                .environmentObject(listeningStore)
        }
        .fullScreenCover(isPresented: $isOpenMusicOnboardingPresented) {
            MobileOpenMusicOnboardingView {
                didCompleteOpenMusicOnboarding = true
                isOpenMusicOnboardingPresented = false
            }
        }
        .onReceive(appIntentRouter.$pendingRoute.compactMap { $0 }) { route in
            handle(route)
        }
    }

    private var compactLayout: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                tabContent(.home)
            }
            .tabItem {
                Label(MobileTab.home.title, systemImage: MobileTab.home.symbolName)
            }
            .tag(MobileTab.home)

            NavigationStack {
                tabContent(.listens)
            }
            .tabItem {
                Label(MobileTab.listens.title, systemImage: MobileTab.listens.symbolName)
            }
            .tag(MobileTab.listens)

            NavigationStack {
                tabContent(.discover)
            }
            .tabItem {
                Label(MobileTab.discover.title, systemImage: MobileTab.discover.symbolName)
            }
            .tag(MobileTab.discover)

            NavigationStack {
                tabContent(.account)
            }
            .tabItem {
                Label(MobileTab.account.title, systemImage: MobileTab.account.symbolName)
            }
            .tag(MobileTab.account)
        }
    }

    private var regularLayout: some View {
        NavigationSplitView {
            List {
                ForEach(MobileTab.allCases) { tab in
                    MobileSidebarTabRow(tab: tab, isSelected: selectedTab == tab) {
                        selectedTab = tab
                    }
                }
            }
            .navigationTitle("ListenScrobbler")
        } detail: {
            NavigationStack {
                tabContent(selectedTab)
            }
            .id(selectedTab)
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func tabContent(_ tab: MobileTab) -> some View {
        switch tab {
        case .home:
            MobileHomeView()
        case .listens:
            MobileListensView {
                manualScrobbleDraft = .empty
            }
        case .discover:
            MobileDiscoverView()
        case .account:
            MobileAccountView {
                isOpenMusicOnboardingPresented = true
            }
        }
    }

    private func presentOnboardingIfNeeded() {
        guard !didCompleteOpenMusicOnboarding else { return }
        guard case .disconnected = listeningStore.connectionState else { return }
        isOpenMusicOnboardingPresented = true
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

private struct MobileSidebarTabRow: View {
    let tab: MobileTab
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(tab.title, systemImage: tab.symbolName)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
        .listRowBackground(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
    }
}
