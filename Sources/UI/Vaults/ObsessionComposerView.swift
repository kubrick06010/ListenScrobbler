import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ObsessionComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @ObservedObject var store: ObsessionVaultStore
    var currentTrack: Track? = nil
    let draft: ObsessionDraft?
    let onSave: (ObsessionEntry) -> Void
    @State private var track = ""
    @State private var artist = ""
    @State private var album = ""
    @State private var note = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture Obsession")
                .font(.custom("Avenir Next Demi Bold", size: 24))
            TextField("Track", text: $track)
                .textFieldStyle(.roundedBorder)
            TextField("Artist", text: $artist)
                .textFieldStyle(.roundedBorder)
            TextField("Album", text: $album)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $note)
                .font(.custom("Avenir Next Regular", size: 13))
                .frame(minHeight: 160)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
            HStack {
                Button {
                    if let url = store.makeEntry(
                        artist: artist,
                        track: track,
                        album: album,
                        note: note,
                        sourceURL: resolvedSourceURL,
                        imageURL: resolvedImageURL,
                        artistMBID: resolvedArtistMBID,
                        recordingMBID: resolvedRecordingMBID,
                        releaseMBID: resolvedReleaseMBID
                    ).sourceURL.flatMap(URL.init(string:)) {
                        openURL(url)
                    }
                } label: {
                    Label("Open Source Link", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.bordered)
                .disabled(track.isBlank || artist.isBlank)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save Memory") {
                    let entry = store.makeEntry(
                        artist: artist,
                        track: track,
                        album: album,
                        note: note,
                        sourceURL: resolvedSourceURL,
                        imageURL: resolvedImageURL,
                        artistMBID: resolvedArtistMBID,
                        recordingMBID: resolvedRecordingMBID,
                        releaseMBID: resolvedReleaseMBID
                    )
                    store.add(entry)
                    onSave(entry)
                    pinObsessionIfPossible(entry)
                    dismiss()
                }
                    .buttonStyle(.borderedProminent)
                    .disabled(track.isBlank || artist.isBlank)
            }
        }
        .onAppear {
            if let draft {
                track = draft.track
                artist = draft.artist
                album = draft.album ?? ""
                return
            }
            guard track.isBlank, artist.isBlank, let currentTrack else { return }
            track = currentTrack.title
            artist = currentTrack.artist
            album = currentTrack.album ?? ""
        }
    }

    private var resolvedSourceURL: String? {
        draft?.sourceURL ?? scrobbleService.currentTrackDetails?.url
    }

    private var resolvedImageURL: String? {
        draft?.imageURL ?? scrobbleService.currentOpenEntityDetails?.imageURL ?? scrobbleService.currentTrackDetails?.imageURL
    }

    private var resolvedArtistMBID: String? {
        draft?.artistMBID ?? scrobbleService.currentOpenEntityDetails?.artistMBID
    }

    private var resolvedRecordingMBID: String? {
        draft?.recordingMBID ?? scrobbleService.currentOpenEntityDetails?.recordingMBID
    }

    private var resolvedReleaseMBID: String? {
        draft?.releaseMBID ?? scrobbleService.currentOpenEntityDetails?.releaseMBID
    }

    private func pinObsessionIfPossible(_ entry: ObsessionEntry) {
        Task {
            _ = await scrobbleService.pinListenBrainzTrack(
                title: entry.track,
                artist: entry.artist,
                album: entry.album,
                recordingMbid: entry.musicBrainzRecordingID?.nilIfBlank,
                blurb: entry.note
            )
        }
    }
}
