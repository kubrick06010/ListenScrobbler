import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ShareComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: SharedMusicVaultStore
    let draft: ShareDraft?
    let onSave: (SharedMusicEntry) -> Void
    @State private var kind: SharedMusicEntry.EntityKind = .track
    @State private var direction: SharedMusicEntry.Direction = .sent
    @State private var artist = ""
    @State private var track = ""
    @State private var album = ""
    @State private var recipients = ""
    @State private var sender = ""
    @State private var message = ""
    @State private var makePublic = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Share to Vault")
                .font(.custom("Avenir Next Demi Bold", size: 24))
            Picker("Kind", selection: $kind) {
                ForEach(SharedMusicEntry.EntityKind.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Picker("Direction", selection: $direction) {
                ForEach(SharedMusicEntry.Direction.allCases.filter { $0 != .imported }) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            TextField("Artist", text: $artist)
                .textFieldStyle(.roundedBorder)
            if kind == .track {
                TextField("Track", text: $track)
                    .textFieldStyle(.roundedBorder)
            }
            if kind == .album {
                TextField("Album", text: $album)
                    .textFieldStyle(.roundedBorder)
            }
            if direction == .sent {
                TextField("Recipients, comma-separated", text: $recipients)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("Sender", text: $sender)
                    .textFieldStyle(.roundedBorder)
            }
            Toggle("Mark as public for future open sharing integrations", isOn: $makePublic)
            TextEditor(text: $message)
                .font(.custom("Avenir Next Regular", size: 13))
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            Text("\(message.count)/1000 characters")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(message.count > 1000 ? .red : .secondary)
            Spacer()
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Archive Share") {
                    let entry = store.makeEntry(
                        kind: kind,
                        direction: direction,
                        artist: artist,
                        track: track,
                        album: album,
                        recipients: recipients.split(separator: ",").map(String.init),
                        sender: sender,
                        message: message,
                        isPublic: makePublic,
                        sourceURL: draft?.sourceURL,
                        imageURL: draft?.imageURL,
                        artworkResolution: resolvedArtworkResolution,
                        artistMBID: draft?.artistMBID,
                        recordingMBID: draft?.recordingMBID,
                        releaseMBID: draft?.releaseMBID
                    )
                    store.add(entry)
                    onSave(entry)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSaveShare)
            }
        }
        .onAppear {
            guard let draft else { return }
            kind = draft.kind
            artist = draft.artist
            track = draft.track ?? ""
            album = draft.album ?? ""
        }
    }

    private var canSaveShare: Bool {
        guard !artist.isBlank, message.count <= 1000 else { return false }
        if kind == .track, track.isBlank { return false }
        if kind == .album, album.isBlank { return false }
        if direction == .sent, recipients.isBlank { return false }
        if direction == .received, sender.isBlank { return false }
        return true
    }

    private var resolvedArtworkResolution: ArtworkResolution? {
        guard let draft else { return nil }
        if currentTrackMatches(artist: draft.artist, track: draft.track),
           let resolution = scrobbleService.currentTrackArtworkResolution?.automaticArtworkResolution {
            return resolution
        }
        return draft.artworkResolution?.automaticArtworkResolution
    }

    private func currentTrackMatches(artist: String, track: String?) -> Bool {
        let currentArtist = scrobbleService.currentTrackDetails?.artist ?? scrobbleService.currentTrack?.artist
        let currentTrack = scrobbleService.currentTrackDetails?.name ?? scrobbleService.currentTrack?.title
        guard currentArtist?.caseInsensitiveCompare(artist) == .orderedSame else { return false }
        guard let track else { return true }
        return currentTrack?.caseInsensitiveCompare(track) == .orderedSame
    }
}
