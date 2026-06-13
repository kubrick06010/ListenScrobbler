import OpenScrobblerCore
import AppIntents
import SwiftUI

@main
struct OpenScrobbleriOSApp: App {
    @StateObject private var listeningStore = MobileListeningStore()
    @StateObject private var musicLibraryScanner = MusicLibraryScrobbleScanner()
    @StateObject private var appIntentRouter = MobileAppIntentRouter.shared

    init() {
        OpenScrobblerAppShortcuts.updateAppShortcutParameters()
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
