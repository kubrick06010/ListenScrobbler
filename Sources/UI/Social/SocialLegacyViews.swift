import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct FriendsView: View {
    private enum ActivityFilter: String, CaseIterable, Identifiable {
        case nowPlaying = "Now Playing"
        case hybrid = "Hybrid"
        case all = "All"

        var id: String { rawValue }
    }

    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Binding var query: String
    let onOpenFriendTrack: (CompatibilityFriendListening) -> Void
    let onOpenGraph: (CompatibilityFriendListening) -> Void
    @State private var activityFilter: ActivityFilter = .hybrid
    private let recentNowPlayingWindow: TimeInterval = 30 * 60

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("People Listening Now")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshFriends() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter people", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.friendsStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Picker("Activity", selection: $activityFilter) {
                    ForEach(ActivityFilter.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .appPanelStyle()

                Text("Showing \(filteredFriends.count) of \(scrobbleService.friendsListening.count) people")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredFriends.isEmpty {
                    Text("No public listening activity available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if activityFilter == .hybrid {
                            sectionHeader("Now Playing", count: nowPlayingFriends.count)
                            ForEach(nowPlayingFriends) { friend in
                                friendRow(friend)
                            }

                            sectionHeader("Recently Active", count: recentFriends.count)
                            ForEach(recentFriends) { friend in
                                friendRow(friend)
                            }
                        } else {
                            ForEach(filteredFriends) { friend in
                                friendRow(friend)
                            }
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private func time(_ value: Date?) -> String {
        value?.formatted(date: .omitted, time: .shortened) ?? "-"
    }

    @ViewBuilder
    private func friendAvatar(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackFriendAvatar(isNowPlaying: isNowPlaying)
            }
            .frame(width: 28, height: 28)
            .clipShape(Circle())
        } else {
            fallbackFriendAvatar(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendAvatar(isNowPlaying: Bool) -> some View {
        Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(isNowPlaying ? .green : .orange)
            .frame(width: 22, height: 22)
    }

    @ViewBuilder
    private func friendTrackArtwork(_ urlString: String?, isNowPlaying: Bool) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
            }
            .frame(width: 26, height: 26)
            .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
        } else {
            fallbackFriendTrackArtwork(isNowPlaying: isNowPlaying)
        }
    }

    private func fallbackFriendTrackArtwork(isNowPlaying: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: isNowPlaying ? "dot.radiowaves.left.and.right" : "music.note")
                .foregroundStyle(isNowPlaying ? .green : .secondary)
                .font(.system(size: 11))
        }
        .frame(width: 26, height: 26)
    }

    private var filteredFriends: [CompatibilityFriendListening] {
        let activityFiltered: [CompatibilityFriendListening]
        switch activityFilter {
        case .nowPlaying:
            activityFiltered = scrobbleService.friendsListening.filter(isNowPlaying)
        case .hybrid:
            let cutoff = Date().addingTimeInterval(-6 * 60 * 60)
            activityFiltered = scrobbleService.friendsListening.filter { friend in
                isNowPlaying(friend) || (friend.playedAt ?? .distantPast) >= cutoff
            }
        case .all:
            activityFiltered = scrobbleService.friendsListening
        }

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return activityFiltered }
        return activityFiltered.filter { friend in
            friend.user.localizedCaseInsensitiveContains(trimmed) ||
            (friend.track?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (friend.artist?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private var nowPlayingFriends: [CompatibilityFriendListening] {
        filteredFriends.filter(isNowPlaying)
    }

    private var recentFriends: [CompatibilityFriendListening] {
        filteredFriends.filter { !isNowPlaying($0) }
    }

    private func isNowPlaying(_ friend: CompatibilityFriendListening) -> Bool {
        if friend.nowPlaying {
            return true
        }
        guard let playedAt = friend.playedAt else {
            return false
        }
        let age = Date().timeIntervalSince(playedAt)
        return age >= 0 && age <= recentNowPlayingWindow
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            Text("\(count)")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 2)
        .padding(.bottom, 4)
    }

    private func friendRow(_ friend: CompatibilityFriendListening) -> some View {
        let nowPlaying = isNowPlaying(friend)
        return HStack(spacing: 10) {
            friendAvatar(friend.avatarURL, isNowPlaying: nowPlaying)
            friendTrackArtwork(friend.imageURL, isNowPlaying: nowPlaying)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(friend.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = friendBadgeType(friend) {
                        badgeView(badge, fontSize: 9, horizontal: 6, vertical: 2)
                    }
                }
                Text(friend.country ?? "Unknown location")
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
                if let track = friend.track, let artist = friend.artist {
                    Text("\(track) - \(artist)")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.primary)
                } else {
                    Text("No current track")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button {
                onOpenGraph(friend)
            } label: {
                separationChip(for: friend.user)
            }
            .buttonStyle(.plain)
            Text(nowPlaying ? "Now" : time(friend.playedAt))
                .font(.custom("Avenir Next Regular", size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .padding(8)
        .background(nowPlaying ? Color.yellow.opacity(0.24) : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            onOpenFriendTrack(friend)
        }
    }

    private func friendBadgeType(_ friend: CompatibilityFriendListening) -> String? {
        if let raw = friend.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return friend.isSubscriber ? "subscriber" : nil
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.4)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

struct NeighboursView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    @Binding var query: String
    let onOpenGraph: (CompatibilityNeighbour) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Related Listeners")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshNeighbours() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                TextField("Filter related listeners", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .appPanelStyle()

                Text(scrobbleService.neighboursStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                Text("Separation: \(scrobbleService.separationStatus)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if filteredNeighbours.isEmpty {
                    Text("No related listeners available.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                } else {
                    Text("Showing \(filteredNeighbours.count) of \(scrobbleService.neighbours.count) related listeners")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)

                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(filteredNeighbours) { neighbour in
                            neighbourRow(neighbour)
                        }
                    }
                    .appPanelStyle()
                }
            }
            .padding(24)
        }
    }

    private var filteredNeighbours: [CompatibilityNeighbour] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return scrobbleService.neighbours }
        return scrobbleService.neighbours.filter { item in
            item.user.localizedCaseInsensitiveContains(trimmed) ||
            (item.realname?.localizedCaseInsensitiveContains(trimmed) ?? false) ||
            (item.country?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    private func neighbourRow(_ neighbour: CompatibilityNeighbour) -> some View {
        HStack(spacing: 10) {
            Button {
                onOpenGraph(neighbour)
            } label: {
                avatar(neighbour.avatarURL)
            }
            .buttonStyle(.plain)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(neighbour.user)
                        .font(.custom("Avenir Next Medium", size: 13))
                    if let badge = badgeType(neighbour) {
                        badgeView(badge)
                    }
                }
                if let realname = neighbour.realname, !realname.isEmpty {
                    Text(realname)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                } else if let country = neighbour.country, !country.isEmpty {
                    Text(country)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Compatibility")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.secondary)
                    Text(matchLabel(neighbour.matchScore))
                        .font(.custom("Avenir Next Medium", size: 11))
                }
                matchBar(neighbour.matchScore)
            }
            Spacer()
            Button {
                onOpenGraph(neighbour)
            } label: {
                separationChip(for: neighbour.user)
            }
            .buttonStyle(.plain)
            Button {
                if let raw = neighbour.profileURL, let url = URL(string: raw) {
                    openURL(url)
                } else if let url = URL(string: "https://listenbrainz.org/user/\(neighbour.user)") {
                    openURL(url)
                }
            } label: {
                Image(systemName: "arrow.up.right.square")
                    .font(.system(size: 13))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private func avatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                fallbackAvatar()
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            fallbackAvatar()
        }
    }

    private func fallbackAvatar() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "person.crop.circle.fill")
                .foregroundStyle(.secondary)
        }
        .frame(width: 40, height: 40)
    }

    private func matchLabel(_ score: Double?) -> String {
        guard let score else { return "-" }
        return "\(Int((score * 100).rounded()))%"
    }

    private func matchBar(_ score: Double?) -> some View {
        let ratio = min(1, max(0, score ?? 0))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 8)
            .frame(width: 180)
    }

    private func badgeType(_ neighbour: CompatibilityNeighbour) -> String? {
        if let raw = neighbour.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return neighbour.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)
        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 9))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private func separationChip(for user: String) -> some View {
        let lower = user.lowercased()
        let degree = scrobbleService.separationByUser[lower]
        let isComputing = scrobbleService.separationStatus.localizedCaseInsensitiveContains("Calculating")
        let label: String
        if let degree {
            label = "\(degree)°"
        } else if isComputing {
            label = "..."
        } else {
            label = "?"
        }

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: 10))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
