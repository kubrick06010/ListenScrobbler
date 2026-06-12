import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct VaultMetricCard: View {
    let title: String
    let value: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 28))
            Text(detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}

struct SharedTimelineRow: View {
    let entry: SharedMusicEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(tint.opacity(0.20))
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.title)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .lineLimit(1)
                    Text(entry.direction.displayName)
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text(entry.artist)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
                Text(entry.message ?? entry.participantSummary)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(vaultDate(entry.createdAt))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                Text(entry.source.displayName)
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(tint)
            }
        }
        .padding(10)
        .background(isSelected ? tint.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? tint.opacity(0.42) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: String {
        switch entry.entityKind {
        case .track: return "music.note"
        case .album: return "rectangle.stack.fill"
        case .artist: return "person.wave.2.fill"
        }
    }

    private var tint: Color {
        switch entry.direction {
        case .sent: return .cyan
        case .received: return .pink
        case .imported: return .orange
        }
    }
}

struct ObsessionTimelineRow: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let entry: ObsessionEntry
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.purple.opacity(0.20))
                Image(systemName: "heart.text.square")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.purple)
            }
            .frame(width: 52, height: 52)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.track)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                        .lineLimit(1)
                    Text(entry.source.displayName)
                        .font(.custom("Avenir Next Demi Bold", size: 9))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
                        Label("Pinned", systemImage: "pin.fill")
                            .font(.custom("Avenir Next Demi Bold", size: 9))
                            .foregroundStyle(.white)
                            .labelStyle(.titleAndIcon)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.82), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                }
                Text(entry.artist)
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                Text(entry.note ?? "No note captured.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 5) {
                Text(vaultDate(entry.setAt ?? entry.firstSeenAt))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                if let rank = entry.rankMarker {
                    Text(rank)
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.purple)
                }
            }
        }
        .padding(10)
        .background(isSelected ? Color.purple.opacity(0.14) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? Color.purple.opacity(0.42) : Color.white.opacity(0.06), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SharedDetailView: View {
    let entry: SharedMusicEntry?
    let onDelete: (SharedMusicEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared Card")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            if let entry {
                VaultHeroCard(title: entry.title, subtitle: entry.artist, label: entry.entityKind.displayName, tint: .cyan)
                Label(entry.participantSummary, systemImage: "person.2.fill")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(vaultDate(entry.createdAt), systemImage: "calendar")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(entry.apiStatus ?? entry.source.displayName, systemImage: "checkmark.seal")
                    .font(.custom("Avenir Next Medium", size: 13))
                Divider()
                Text(entry.message ?? "No message attached.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    if let urlString = entry.sourceURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Open Source Link", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button(role: .destructive) {
                        onDelete(entry)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                Text("Select a shared entry.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ObsessionDetailView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    let entry: ObsessionEntry?
    let onDelete: (ObsessionEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Obsession Card")
                .font(.custom("Avenir Next Demi Bold", size: 16))

            if let entry {
                VaultHeroCard(title: entry.track, subtitle: entry.artist, label: "Track", tint: .purple)
                Label(vaultDate(entry.setAt ?? entry.firstSeenAt), systemImage: "calendar")
                    .font(.custom("Avenir Next Medium", size: 13))
                Label(entry.source.displayName, systemImage: "archivebox")
                    .font(.custom("Avenir Next Medium", size: 13))
                if isPinnedOnListenBrainz(entry, scrobbleService: scrobbleService) {
                    Label("Pinned on ListenBrainz", systemImage: "pin.fill")
                        .font(.custom("Avenir Next Demi Bold", size: 13))
                        .foregroundStyle(.green)
                }
                Divider()
                Text(entry.note ?? "No note captured.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack {
                    if let urlString = entry.sourceURL, let url = URL(string: urlString) {
                        Link(destination: url) {
                            Label("Open Source Link", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        toggleListenBrainzPin(entry)
                    } label: {
                        Label(
                            listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) == nil ? "Pin on ListenBrainz" : "Delete ListenBrainz Pin",
                            systemImage: listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) == nil ? "pin" : "pin.slash"
                        )
                    }
                    .buttonStyle(.bordered)
                    .disabled(!canToggleListenBrainzPin(entry, scrobbleService: scrobbleService))
                    if entry.source != .listenBrainzPin {
                        Button(role: .destructive) {
                            onDelete(entry)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            } else {
                Text("Select an obsession.")
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func toggleListenBrainzPin(_ entry: ObsessionEntry) {
        if let rowID = listenBrainzPinRowID(for: entry, scrobbleService: scrobbleService) {
            Task { _ = await scrobbleService.deleteListenBrainzPin(rowID: rowID, title: entry.track) }
            return
        }

        Task {
            _ = await scrobbleService.pinListenBrainzTrack(
                title: entry.track,
                artist: entry.artist,
                album: entry.album,
                recordingMbid: pinRecordingMBID(for: entry, scrobbleService: scrobbleService),
                blurb: entry.note
            )
        }
    }
}

struct VaultHeroCard: View {
    let title: String
    let subtitle: String
    let label: String
    let tint: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(tint.opacity(0.22))
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(.custom("Avenir Next Demi Bold", size: 10))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.custom("Avenir Next Demi Bold", size: 22))
                    .lineLimit(2)
                Text(subtitle)
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
        }
        .frame(height: 170)
    }
}

struct VaultEmptyState: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 14))
            Text(detail)
                .font(.custom("Avenir Next Regular", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
