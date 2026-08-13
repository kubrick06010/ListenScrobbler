import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ExploreView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Track And Artist Explore")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshExplore() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.exploreStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let track = scrobbleService.currentTrackDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Track Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            ResolvedArtworkImage(
                                artist: track.artist,
                                track: track.name,
                                album: track.album,
                                target: .track,
                                sourceResolution: track.artworkResolution
                            ) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                artworkPlaceholder(size: 110)
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 5) {
                                detailRow("Track", track.name)
                                detailRow("Artist", track.artist)
                                if let album = track.album {
                                    detailRow("Album", album)
                                }
                                detailRow("Listeners", formatCount(track.listeners))
                                detailRow("Playcount", formatCount(track.playcount))
                                if let user = track.userPlaycount {
                                    detailRow("Your Plays", AppLocalization.integer(user))
                                }
                                if !track.tags.isEmpty {
                                    Text("Tags: \(track.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = track.summary {
                            HTMLSummaryText(rawHTML: summary, fontSize: 12, lineLimit: 4)
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No track details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artist = scrobbleService.currentArtistDetails {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Artist Details")
                            .font(.custom("Avenir Next Medium", size: 14))
                        HStack(alignment: .top, spacing: 12) {
                            ResolvedArtworkImage(
                                artist: artist.name,
                                target: .artist,
                                sourceResolution: artist.artworkResolution
                            ) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                artworkPlaceholder(size: 110)
                            }
                            .frame(width: 110, height: 110)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            VStack(alignment: .leading, spacing: 4) {
                                detailRow("Artist", artist.name)
                                detailRow("Listeners", formatCount(artist.listeners))
                                detailRow("Playcount", formatCount(artist.playcount))
                                if let user = artist.userPlaycount {
                                    detailRow("In your library", AppLocalization.integer(user))
                                }
                                if !artist.tags.isEmpty {
                                    Text("Tags: \(artist.tags.prefix(8).joined(separator: " · "))")
                                        .font(.custom("Avenir Next Medium", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        if let summary = artist.summary {
                            HTMLSummaryText(rawHTML: summary, fontSize: 12, lineLimit: 5)
                        }
                        if !artist.similarArtists.isEmpty {
                            Text("Similar Artists")
                                .font(.custom("Avenir Next Medium", size: 12))
                            HStack(spacing: 12) {
                                ForEach(artist.similarArtists.prefix(4)) { similar in
                                    VStack(alignment: .leading, spacing: 3) {
                                        ResolvedArtworkImage(
                                            artist: similar.name,
                                            target: .artist,
                                            sourceResolution: similar.artworkResolution
                                        ) { image in
                                            image.resizable().scaledToFill()
                                        } placeholder: {
                                            artworkPlaceholder(size: 54)
                                        }
                                        .frame(width: 54, height: 54)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        Text(similar.name)
                                            .font(.custom("Avenir Next Regular", size: 11))
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No artist details yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func detailRow(_ key: LocalizedStringKey, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.custom("Avenir Next Medium", size: 12))
    }

    private func formatCount(_ value: Int?) -> String {
        guard let value else { return AppLocalization.string("Unknown") }
        return AppLocalization.integer(value)
    }

    private func artworkPlaceholder(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.white.opacity(0.06))
            .frame(width: size, height: size)
    }
}
