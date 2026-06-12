import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

@MainActor
func isPinnedOnListenBrainz(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    guard let entryRecordingMBID = pinRecordingMBID(for: entry, scrobbleService: scrobbleService),
          let currentPinMBID = scrobbleService.listenBrainzCurrentPin?.recordingMbid?.nilIfBlank else {
        return false
    }
    return entryRecordingMBID.caseInsensitiveCompare(currentPinMBID) == .orderedSame
}

@MainActor
func listenBrainzPinRowID(for entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Int? {
    if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
        return scrobbleService.listenBrainzCurrentPin?.id
    }
    guard entry.source == .listenBrainzPin else { return nil }
    return listenBrainzPinRowID(from: entry.id)
}

@MainActor
func canToggleListenBrainzPin(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    if listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) != nil {
        return true
    }
    guard scrobbleService.listenBrainzEnabled else { return false }
    guard !entry.track.isBlank, !entry.artist.isBlank else { return false }
    return entry.source != .listenBrainzPin || pinRecordingMBID(for: entry, scrobbleService: scrobbleService) != nil
}

@MainActor
func pinRecordingMBID(for entry: ObsessionEntry, scrobbleService: ScrobbleService) -> String? {
    if let recordingMBID = entry.musicBrainzRecordingID?.nilIfBlank {
        return recordingMBID
    }
    guard currentTrackMatches(entry, scrobbleService: scrobbleService) else { return nil }
    return scrobbleService.currentOpenEntityDetails?.recordingMBID?.nilIfBlank
}

@MainActor
func currentTrackMatches(_ entry: ObsessionEntry, scrobbleService: ScrobbleService) -> Bool {
    let currentTrack = scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title
    let currentArtist = scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist
    return currentTrack?.caseInsensitiveCompare(entry.track) == .orderedSame &&
        currentArtist?.caseInsensitiveCompare(entry.artist) == .orderedSame
}

func listenBrainzPinObsessionID(rowID: Int) -> UUID {
    let suffixValue = UInt64(max(rowID, 0)) % 0x1_0000_0000_0000
    let suffix = String(format: "%012llx", suffixValue)
    return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
}

func listenBrainzPinRowID(from id: UUID) -> Int? {
    let uuid = id.uuidString.lowercased()
    guard uuid.hasPrefix("00000000-0000-0000-0000-") else { return nil }
    guard let suffix = uuid.split(separator: "-").last,
          let value = UInt64(suffix, radix: 16),
          value <= UInt64(Int.max) else {
        return nil
    }
    return Int(value)
}

func vaultDate(_ date: Date) -> String {
    date.formatted(date: .abbreviated, time: .omitted)
}

func savePanelURL(defaultName: String) -> URL? {
    let panel = NSSavePanel()
    panel.nameFieldStringValue = defaultName
    panel.canCreateDirectories = true
    panel.allowedContentTypes = [.json]
    return panel.runModal() == .OK ? panel.url : nil
}

func openPanelURL() -> URL? {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = false
    panel.allowedContentTypes = [.json]
    return panel.runModal() == .OK ? panel.url : nil
}

func presentVaultError(_ error: Error) {
    let alert = NSAlert()
    alert.messageText = "Vault operation failed"
    alert.informativeText = error.localizedDescription
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}
