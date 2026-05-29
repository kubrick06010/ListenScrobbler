import Foundation

enum PlayerEvent {
    case trackStarted(Track)
    case paused
    case resumed
    case stopped
}

protocol PlayerMonitor: AnyObject {
    var onEvent: ((PlayerEvent) -> Void)? { get set }
    var statusDescription: String { get }
    func start()
    func stop()
}

// Player monitors produce normalized playback events; they should not decide
// scrobble timing or submission policy. That keeps new adapters easy to add:
// emit track/paused/resumed/stopped and let ScrobbleService handle the rest.
final class MultiPlayerMonitor: PlayerMonitor {
    var onEvent: ((PlayerEvent) -> Void)?
    var statusDescription: String {
        adapters.map(\.statusDescription).joined(separator: ", ")
    }

    private let adapters: [PlayerMonitor]

    init(adapters: [PlayerMonitor]) {
        self.adapters = adapters
    }

    func start() {
        for adapter in adapters {
            adapter.onEvent = { [weak self] event in
                self?.onEvent?(event)
            }
            adapter.start()
        }
    }

    func stop() {
        adapters.forEach { $0.stop() }
    }
}

#if os(macOS)
final class DistributedPlayerMonitor: PlayerMonitor {
    var onEvent: ((PlayerEvent) -> Void)?
    var statusDescription: String { "\(sourceApp) notifications + AppleScript fallback" }

    private let notificationName: String
    private let sourceApp: String
    private let metadataProvider: PlayerMetadataProviding?
    private let center = DistributedNotificationCenter.default()

    init(notificationName: String, sourceApp: String, metadataProvider: PlayerMetadataProviding?) {
        self.notificationName = notificationName
        self.sourceApp = sourceApp
        self.metadataProvider = metadataProvider
    }

    func start() {
        center.addObserver(
            self,
            selector: #selector(onNotification(_:)),
            name: NSNotification.Name(notificationName),
            object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    func stop() {
        center.removeObserver(self)
    }

    @objc
    private func onNotification(_ notification: Notification) {
        let info = notification.userInfo ?? [:]
        if let event = PlayerNotificationNormalizer.event(
            from: info,
            sourceApp: sourceApp,
            metadataProvider: metadataProvider
        ) {
            onEvent?(event)
        }
    }
}

final class AppleScriptMetadataProvider: PlayerMetadataProviding {
    func fetchMetadata(for sourceApp: String) -> PlayerMetadata? {
        let script: String
        switch sourceApp {
        case "Spotify":
            script = """
            tell application "Spotify"
                if player state is playing then
                    return (name of current track) & "||" & (artist of current track) & "||" & (album of current track) & "||" & (duration of current track) & "||" & (artwork url of current track)
                end if
            end tell
            """
        case "Apple Music":
            script = """
            tell application "Music"
                if player state is playing then
                    set t to current track
                    return (name of t) & "||" & (artist of t) & "||" & (album of t) & "||" & (duration of t)
                end if
            end tell
            """
        case "iTunes":
            script = """
            tell application "iTunes"
                if player state is playing then
                    set t to current track
                    return (name of t) & "||" & (artist of t) & "||" & (album of t) & "||" & (duration of t)
                end if
            end tell
            """
        default:
            return nil
        }

        // Distributed notifications are fast but sometimes omit album/artwork.
        // AppleScript is slower, so keep it as a metadata fallback instead of
        // the primary playback signal.
        guard
            let appleScript = NSAppleScript(source: script),
            let result = appleScript.executeAndReturnError(nil).stringValue
        else {
            return nil
        }

        let components = result.components(separatedBy: "||")
        guard components.count >= 4 else { return nil }

        let durationRaw = Double(components[3]) ?? 0
        let duration = durationRaw > 1000 ? durationRaw / 1000.0 : durationRaw
        return PlayerMetadata(
            title: components[0],
            artist: components[1],
            album: components[2].isEmpty ? nil : components[2],
            duration: duration,
            artworkURL: components.indices.contains(4) ? components[4].nilIfBlank : nil
        )
    }
}
#endif

final class PlayerMonitorStub: PlayerMonitor {
    var onEvent: ((PlayerEvent) -> Void)?
    let statusDescription = "Stub monitor"

    func start() {
        onEvent?(.trackStarted(Track.preview))
    }

    func stop() {}
}

func makeDefaultPlayerMonitor() -> PlayerMonitor {
#if os(macOS)
    let provider = AppleScriptMetadataProvider()
    return MultiPlayerMonitor(
        adapters: [
            DistributedPlayerMonitor(notificationName: "com.apple.Music.playerInfo", sourceApp: "Apple Music", metadataProvider: provider),
            DistributedPlayerMonitor(notificationName: "com.apple.iTunes.playerInfo", sourceApp: "iTunes", metadataProvider: provider),
            DistributedPlayerMonitor(notificationName: "com.spotify.client.PlaybackStateChanged", sourceApp: "Spotify", metadataProvider: provider)
        ]
    )
#else
    return PlayerMonitorStub()
#endif
}
