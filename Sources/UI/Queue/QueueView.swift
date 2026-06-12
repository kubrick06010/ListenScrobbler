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
                            HStack(spacing: 10) {
                                Image(systemName: "music.note")
                                    .foregroundStyle(.orange)
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
                                    Text(job.track.startedAt.formatted(date: .omitted, time: .shortened))
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
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(24)
    }
}
