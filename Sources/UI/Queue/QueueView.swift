import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct QueueView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Submission Queue")
                    .font(.custom("Avenir Next Demi Bold", size: 28))
                    .accessibilityIdentifier("queue.title")
                Spacer()
                Text("\(scrobbleService.queuedSubmissionJobs.count) jobs")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }

            if scrobbleService.queuedSubmissionJobs.isEmpty {
                Text("Queue is empty. Tracks that pass threshold rules will appear here for each enabled backend.")
                    .font(.custom("Avenir Next Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .appPanelStyle()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(scrobbleService.queuedSubmissionJobs) { job in
                            QueueSubmissionRow(job: job)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct QueueSubmissionRow: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let job: ScrobbleSubmissionJob
    @State private var resolvedArtworkURL: String?

    var body: some View {
        HStack(spacing: 10) {
            artwork

            VStack(alignment: .leading, spacing: 2) {
                Text(job.track.title).font(.custom("Avenir Next Medium", size: 14))
                Text(job.track.artist).font(.custom("Avenir Next Regular", size: 13)).foregroundStyle(.secondary)
                if let album = job.track.album, !album.isEmpty {
                    Text(album).font(.custom("Avenir Next Regular", size: 12)).foregroundStyle(.secondary)
                }
                if let lastError = job.lastError {
                    Text(lastError)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(job.backend.displayName)
                    .font(.custom("Avenir Next Demi Bold", size: 11))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
                Text(AppLocalization.date(job.track.startedAt, date: .omitted, time: .shortened))
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
                if job.attempts > 0 {
                    Text("\(job.attempts) tries")
                        .font(.custom("Avenir Next Regular", size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .appPanelStyle()
        .task(id: artworkTaskID) {
            guard job.track.artworkURL?.nilIfBlank == nil else { return }
            resolvedArtworkURL = await scrobbleService.artworkURL(for: recentScrobble)
        }
    }

    @ViewBuilder
    private var artwork: some View {
        if let urlString = job.track.artworkURL?.nilIfBlank ?? resolvedArtworkURL,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                artworkPlaceholder
            }
            .frame(width: 44, height: 44)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            artworkPlaceholder
        }
    }

    private var artworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.07))
            Image(systemName: "music.note")
                .foregroundStyle(.orange)
        }
        .frame(width: 44, height: 44)
    }

    private var artworkTaskID: String? {
        guard job.track.artworkURL?.nilIfBlank == nil else { return nil }
        return "\(job.track.artist)::\(job.track.title)::\(job.track.album ?? "")"
    }

    private var recentScrobble: CompatibilityRecentScrobble {
        CompatibilityRecentScrobble(
            id: "queue-\(job.id.uuidString)",
            track: job.track.title,
            artist: job.track.artist,
            album: job.track.album,
            imageURL: job.track.artworkURL,
            url: nil,
            loved: false,
            playedAt: job.track.startedAt,
            nowPlaying: false,
            recordingMbid: nil,
            recordingMsid: nil
        )
    }
}
