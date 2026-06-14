import OpenScrobblerCore
import SwiftUI
import WidgetKit

struct MobileRootView: View {
    @EnvironmentObject private var listeningStore: MobileListeningStore
    @EnvironmentObject private var appIntentRouter: MobileAppIntentRouter
    @AppStorage("onboarding.lastFMModern.completed") private var didCompleteLastFMModernOnboarding = false
    @State private var selectedTab: MobileTab = .home
    @State private var manualScrobbleDraft: MobileManualScrobbleDraft?
    @State private var isLastFMModernOnboardingPresented = false

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
                MobileAccountView {
                    isLastFMModernOnboardingPresented = true
                }
            }
            .tabItem {
                Label("Account", systemImage: "person.crop.circle")
            }
            .tag(MobileTab.account)
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
        .sheet(isPresented: $isLastFMModernOnboardingPresented) {
            MobileLastFMModernOnboardingView {
                didCompleteLastFMModernOnboarding = true
                isLastFMModernOnboardingPresented = false
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .onReceive(appIntentRouter.$pendingRoute.compactMap { $0 }) { route in
            handle(route)
        }
    }

    private func presentOnboardingIfNeeded() {
        guard !didCompleteLastFMModernOnboarding else { return }
        guard case .disconnected = listeningStore.connectionState else { return }
        isLastFMModernOnboardingPresented = true
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
