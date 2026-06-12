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
                            trackArt(track.imageURL)
                            VStack(alignment: .leading, spacing: 5) {
                                detailRow("Track", track.name)
                                detailRow("Artist", track.artist)
                                if let album = track.album {
                                    detailRow("Album", album)
                                }
                                detailRow("Listeners", formatCount(track.listeners))
                                detailRow("Playcount", formatCount(track.playcount))
                                if let user = track.userPlaycount {
                                    detailRow("Your Plays", "\(user)")
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
                            trackArt(artist.imageURL)
                            VStack(alignment: .leading, spacing: 4) {
                                detailRow("Artist", artist.name)
                                detailRow("Listeners", formatCount(artist.listeners))
                                detailRow("Playcount", formatCount(artist.playcount))
                                if let user = artist.userPlaycount {
                                    detailRow("In your library", "\(user)")
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
                                        trackArt(similar.imageURL, size: 54)
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

    private func detailRow(_ key: String, _ value: String) -> some View {
        HStack {
            Text(key).foregroundStyle(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
        .font(.custom("Avenir Next Medium", size: 12))
    }

    private func formatCount(_ value: Int?) -> String {
        guard let value else { return "Unknown" }
        return value.formatted()
    }

    @ViewBuilder
    private func trackArt(_ urlString: String?, size: CGFloat = 110) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }
}
