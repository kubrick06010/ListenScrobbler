import ListenScrobblerCore
import AppIntents
import SwiftUI

@main
struct ListenScrobbleriOSApp: App {
    @StateObject private var listeningStore = MobileListeningStore()
    @StateObject private var musicLibraryScanner = MusicLibraryScrobbleScanner()
    @StateObject private var appIntentRouter = MobileAppIntentRouter.shared

    init() {
        ListenScrobblerAppShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(listeningStore)
                .environmentObject(musicLibraryScanner)
                .environmentObject(appIntentRouter)
        }
    }
}
