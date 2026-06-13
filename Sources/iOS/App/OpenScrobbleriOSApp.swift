import OpenScrobblerCore
import SwiftUI

@main
struct OpenScrobbleriOSApp: App {
    @StateObject private var listeningStore = MobileListeningStore()
    @StateObject private var musicLibraryScanner = MusicLibraryScrobbleScanner()

    var body: some Scene {
        WindowGroup {
            MobileRootView()
                .environmentObject(listeningStore)
                .environmentObject(musicLibraryScanner)
        }
    }
}
