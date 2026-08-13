import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ScrobblesView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var query: String
    let onOpenDetail: (CompatibilityRecentScrobble) -> Void
    let onShare: (ShareDraft) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Your Listens")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshScrobbles() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter listens", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.scrobblesStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredScrobbles.isEmpty {
                    Text("No recent listens available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredScrobbles) { item in
                            ListenActionRow(
                                title: item.track,
                                artist: item.artist,
                                album: item.album,
                                artworkResolution: item.artworkResolution,
                                url: item.url,
                                loved: item.loved,
                                playedAt: item.playedAt,
                                nowPlaying: item.nowPlaying,
                                recordingMBID: item.recordingMbid,
                                recordingMSID: item.recordingMsid,
                                sourceScrobbleID: item.id,
                                onDelete: { Task { _ = await scrobbleService.deleteListenBrainzListen(item) } },
                                onOpen: { onOpenDetail(item) },
                                onShare: onShare
                            )
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private var filteredScrobbles: [CompatibilityRecentScrobble] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.latestScrobbles }
        return scrobbleService.latestScrobbles.filter { item in
            item.track.localizedCaseInsensitiveContains(trimmed) ||
            item.artist.localizedCaseInsensitiveContains(trimmed)
        }
    }

}

struct ListenActionRow: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let title: String
    let artist: String
    let album: String?
    let artworkResolution: ArtworkResolution?
    let url: String?
    let loved: Bool
    let playedAt: Date?
    let nowPlaying: Bool
    var recordingMBID: String?
    var recordingMSID: String?
    var artistMBID: String?
    var releaseMBID: String?
    var sourceScrobbleID: String?
    let onDelete: () -> Void
    let onOpen: () -> Void
    let onShare: (ShareDraft) -> Void
    @State private var isConfirmingDelete = false
    @State private var resolvedArtworkResolution: ArtworkResolution?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                scrobbleArtwork(effectiveArtworkResolution?.url, nowPlaying: nowPlaying)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .lineLimit(1)
                    Text(artist)
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onOpen)

            Spacer(minLength: 10)

            HStack(spacing: 12) {
                Button {
                    Task {
                        await scrobbleService.toggleListenBrainzLove(
                            title: title,
                            artist: artist,
                            album: album,
                            recordingMbid: recordingMBID,
                            recordingMsid: recordingMSID,
                            currentlyLoved: loved,
                            sourceScrobbleID: sourceScrobbleID
                        )
                    }
                } label: {
                    Image(systemName: loved ? "heart.fill" : "heart")
                }
                .help(loved
                    ? AppLocalization.string("Unlove on ListenBrainz")
                    : AppLocalization.string("Love on ListenBrainz"))
                .disabled(!scrobbleService.listenBrainzEnabled || scrobbleService.isUpdatingListenBrainzFeedback)

                Button {
                    Task {
                        if isPinned {
                            _ = await scrobbleService.unpinListenBrainzCurrent()
                        } else {
                            _ = await scrobbleService.pinListenBrainzTrack(
                                title: title,
                                artist: artist,
                                album: album,
                                recordingMbid: recordingMBID
                            )
                        }
                    }
                } label: {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                }
                .help(isPinned
                    ? AppLocalization.string("Unpin from ListenBrainz")
                    : AppLocalization.string("Pin on ListenBrainz"))
                .disabled(!scrobbleService.listenBrainzEnabled)

                Button {
                    onShare(shareDraft)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .help("Archive share")

                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    Image(systemName: "trash")
                }
                .help(canDeleteListen
                    ? AppLocalization.string("Delete from ListenBrainz")
                    : AppLocalization.string("ListenBrainz deletion needs a listen timestamp and recording MSID"))
                .disabled(!canDeleteListen)

                Text(nowPlaying
                    ? AppLocalization.string("Now")
                    : (playedAt.map { AppLocalization.date($0, date: .omitted, time: .shortened) } ?? "-"))
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 42, alignment: .trailing)
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(nowPlaying ? Color.yellow.opacity(0.25) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: artworkTaskID) {
            guard effectiveArtworkResolution == nil else { return }
            resolvedArtworkResolution = await scrobbleService.artworkResolution(for: CompatibilityRecentScrobble(
                id: sourceScrobbleID ?? "listen-row",
                track: title,
                artist: artist,
                album: album,
                artworkResolution: artworkResolution,
                url: url,
                loved: loved,
                playedAt: playedAt,
                nowPlaying: nowPlaying,
                recordingMbid: recordingMBID,
                recordingMsid: recordingMSID
            ))
        }
        .confirmationDialog("Delete this ListenBrainz listen?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete Listen", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("ListenBrainz schedules deletions, so counts may update after the next hourly cleanup.")
        }
    }

    private var isPinned: Bool {
        scrobbleService.isCurrentListenBrainzPin(
            title: title,
            artist: artist,
            recordingMbid: recordingMBID,
            recordingMsid: recordingMSID
        )
    }

    private var artworkTaskID: String? {
        guard effectiveArtworkResolution == nil else { return nil }
        return "\(artist)::\(title)::\(album ?? "")"
    }

    private var effectiveArtworkResolution: ArtworkResolution? {
        artworkResolution?.automaticArtworkResolution
            ?? resolvedArtworkResolution?.automaticArtworkResolution
    }

    private var canDeleteListen: Bool {
        scrobbleService.listenBrainzEnabled && playedAt != nil && recordingMSID?.nilIfBlank != nil
    }

    private var shareDraft: ShareDraft {
        ShareDraft(
            kind: .track,
            artist: artist,
            track: title,
            album: album,
            sourceURL: url,
            artworkResolution: effectiveArtworkResolution,
            artistMBID: artistMBID,
            recordingMBID: recordingMBID,
            releaseMBID: releaseMBID
        )
    }

    @ViewBuilder
    private func scrobbleArtwork(_ urlString: String?, nowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackScrobbleArtwork(nowPlaying: nowPlaying)
            }
            .frame(width: 32, height: 32)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackScrobbleArtwork(nowPlaying: nowPlaying)
        }
    }

    private func fallbackScrobbleArtwork(nowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: nowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(nowPlaying ? .green : .orange)
        }
        .frame(width: 32, height: 32)
    }
}
