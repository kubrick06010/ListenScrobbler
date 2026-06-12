import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let compact: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 8 : 10) {
            HStack {
                Text("Now Playing")
                    .font(.custom("Avenir Next Medium", size: compact ? 16 : 24))
                Spacer()
                StatusChip(
                    title: scrobbleService.playbackState,
                    color: scrobbleService.playbackState == "Playing" ? .green : .secondary
                )
            }

            if let track = scrobbleService.currentTrack {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(track.title)
                        .font(.custom("Avenir Next Medium", size: compact ? 15 : 20))
                        .lineLimit(compact ? 2 : 3)
                    Spacer(minLength: 8)
                    Button {
                        Task { await scrobbleService.toggleCurrentTrackLove() }
                    } label: {
                        Image(systemName: scrobbleService.listenBrainzCurrentTrackLoved ? "heart.fill" : "heart")
                            .foregroundStyle(scrobbleService.listenBrainzCurrentTrackLoved ? .pink : .secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(scrobbleService.isUpdatingListenBrainzFeedback)
                    .help(scrobbleService.listenBrainzCurrentTrackLoved ? "Unlove on ListenBrainz" : "Love on ListenBrainz")
                }
                Text(track.artist)
                    .font(.custom("Avenir Next Medium", size: compact ? 12 : 14))
                    .foregroundStyle(.secondary)
                if let album = track.album, !album.isEmpty {
                    Text(album)
                        .font(.custom("Avenir Next Medium", size: compact ? 11 : 13))
                        .foregroundStyle(.secondary)
                }
                if let sourceApp = track.sourceApp {
                    Text(sourceApp.uppercased())
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.orange)
                }
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: scrobbleService.scrobbleProgress, total: 1.0)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("\(Int(scrobbleService.elapsedForCurrentTrack))s")
                        Spacer()
                        Text("\(Int(scrobbleService.scrobbleThreshold))s listen mark")
                    }
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 2)
                Text(scrobbleService.listenBrainzFeedbackStatus)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("No track detected")
                    .font(.custom("Avenir Next Medium", size: compact ? 12 : 14))
                    .foregroundStyle(.secondary.opacity(0.95))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(compact ? 10 : 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

private struct StatusChip: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.custom("Avenir Next Medium", size: 11))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.12), in: Capsule())
    }
}
