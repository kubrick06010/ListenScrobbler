import ListenScrobblerCore
import AppIntents
import SwiftUI
import WidgetKit

@main
struct ListenScrobbleriOSApp: App {
    @StateObject private var localizationController = LocalizationController()
    @StateObject private var listeningStore = MobileListeningStore()
    @StateObject private var musicLibraryScanner = MusicLibraryScrobbleScanner()
    @StateObject private var appIntentRouter = MobileAppIntentRouter.shared

    init() {
        ListenScrobblerAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(localizationController)
                .environmentObject(listeningStore)
                .environmentObject(musicLibraryScanner)
                .environmentObject(appIntentRouter)
                .environment(\.locale, localizationController.effectiveLocale)
                .onChange(of: localizationController.selectedLanguage) {
                    WidgetCenter.shared.reloadAllTimelines()
                }
        }
        .environment(\.locale, localizationController.effectiveLocale)
    }
}
