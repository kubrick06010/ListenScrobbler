import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ListenBrainzSocialView: View {
    private enum SocialSection: String, CaseIterable, Identifiable {
        case people = "People"
        case activity = "Activity"
        case recommendations = "Recommendations"
        case playlists = "Playlists"

        var id: String { rawValue }
    }

    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var usernameToFollow = ""
    @State private var usernameToCompare = ""
    @State private var playlistTitle = "OpenScrobbler Picks"
    @State private var selectedSection: SocialSection = .people
    let onOpenRecommendation: (ListenBrainzRecommendedRecording) -> Void
    let onShareRecommendation: (ListenBrainzRecommendedRecording) -> Void
    let onRecommendToFollowers: (ListenBrainzRecommendedRecording) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ListenBrainz Social")
                            .font(.custom("Avenir Next Demi Bold", size: 28))
                        Text(scrobbleService.listenBrainzUsername ?? "Connect your ListenBrainz account to unlock the social graph.")
                            .font(.custom("Avenir Next Medium", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh") {
                        Task {
                            await scrobbleService.refreshListenBrainzSocial()
                            await scrobbleService.refreshListenBrainzCompatibility()
                            await scrobbleService.refreshListenBrainzRecommendations()
                            await scrobbleService.refreshListenBrainzPins()
                            await scrobbleService.refreshListenBrainzPlaylists()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                socialOverview

                Picker("Social Section", selection: $selectedSection) {
                    ForEach(SocialSection.allCases) { section in
                        Text(section.rawValue).tag(section)
                    }
                }
                .pickerStyle(.segmented)

                selectedSocialSection
            }
            .padding(24)
        }
        .task(id: scrobbleService.listenBrainzUsername ?? "listenbrainz-social") {
            guard scrobbleService.listenBrainzEnabled else { return }
            if scrobbleService.listenBrainzFollowers.isEmpty && scrobbleService.listenBrainzFollowing.isEmpty {
                await scrobbleService.refreshListenBrainzSocial()
            }
            if scrobbleService.listenBrainzCompatibility == nil {
                await scrobbleService.refreshListenBrainzCompatibility()
            }
            if scrobbleService.listenBrainzRecommendations.isEmpty {
                await scrobbleService.refreshListenBrainzRecommendations()
            }
            if scrobbleService.listenBrainzPinnedHistory.isEmpty && scrobbleService.listenBrainzCurrentPin == nil {
                await scrobbleService.refreshListenBrainzPins()
            }
            if scrobbleService.listenBrainzPlaylists.isEmpty && scrobbleService.listenBrainzRecommendationPlaylists.isEmpty {
                await scrobbleService.refreshListenBrainzPlaylists()
            }
        }
    }

    private var socialOverview: some View {
        HStack(spacing: 10) {
            compactMetric("Followers", scrobbleService.listenBrainzFollowers.count)
            compactMetric("Following", scrobbleService.listenBrainzFollowing.count)
            compactMetric("Similar", scrobbleService.listenBrainzSimilarUsers.count)
            compactMetric("Recs", scrobbleService.listenBrainzRecommendations.count)
            compactMetric("Playlists", scrobbleService.listenBrainzPlaylists.count + scrobbleService.listenBrainzRecommendationPlaylists.count)
        }
        .appPanelStyle()
    }

    @ViewBuilder
    private var selectedSocialSection: some View {
        switch selectedSection {
        case .people:
            peopleSection
        case .activity:
            activitySection
        case .recommendations:
            recommendationsSection
        case .playlists:
            playlistsSection
        }
    }

    private var peopleSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                followCard
                compareCard
            }

            HStack(alignment: .top, spacing: 14) {
                socialColumn(
                    title: "Followers",
                    subtitle: "People who can receive your personal recommendations.",
                    users: scrobbleService.listenBrainzFollowers,
                    actionTitle: nil,
                    action: nil
                )

                socialColumn(
                    title: "Following",
                    subtitle: "People you follow on ListenBrainz.",
                    users: scrobbleService.listenBrainzFollowing,
                    actionTitle: "Unfollow",
                    action: { user in
                        Task { await scrobbleService.unfollowListenBrainz(user: user) }
                    }
                )
            }

            socialColumn(
                title: "Similar Users",
                subtitle: "Official ListenBrainz compatibility candidates.",
                users: scrobbleService.listenBrainzSimilarUsers.map(\.userName),
                actionTitle: "Compare",
                action: { user in
                    Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: user) }
                }
            )
        }
    }

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            socialListenActivityCard
            HStack(alignment: .top, spacing: 14) {
                currentPinCard
                pinColumn(
                    title: "Following Pins",
                    subtitle: "Active pins from people you follow.",
                    pins: scrobbleService.listenBrainzFollowingPins
                )
            }
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                currentPinCard
                playlistBuilderCard
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Recommended For You")
                    .font(.custom("Avenir Next Demi Bold", size: 18))

                if scrobbleService.listenBrainzRecommendations.isEmpty {
                    Text("No recommendations loaded yet.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(scrobbleService.listenBrainzRecommendations) { recommendation in
                            recommendationRow(recommendation)
                        }
                    }
                }
            }
            .appPanelStyle()
        }
    }

    private var playlistsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                playlistBuilderCard
                pinColumn(
                    title: "Pin History",
                    subtitle: "Your recent pinned recordings.",
                    pins: scrobbleService.listenBrainzPinnedHistory
                )
            }

            HStack(alignment: .top, spacing: 14) {
                playlistColumn(
                    title: "Your Playlists",
                    subtitle: "Metadata pulled from ListenBrainz.",
                    playlists: scrobbleService.listenBrainzPlaylists
                )

                playlistColumn(
                    title: "Recommendation Playlists",
                    subtitle: "Algorithmic or highlighted recommendation lists.",
                    playlists: scrobbleService.listenBrainzRecommendationPlaylists
                )
            }
        }
    }

    private var followCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Follow Someone")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            HStack(spacing: 10) {
                TextField("ListenBrainz username", text: $usernameToFollow)
                    .textFieldStyle(.roundedBorder)
                Button("Follow") {
                    let target = usernameToFollow
                    Task { await scrobbleService.followListenBrainz(user: target) }
                    usernameToFollow = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameToFollow.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(scrobbleService.listenBrainzSocialStatus)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private var compareCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Compare Archives")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            HStack(spacing: 10) {
                TextField("ListenBrainz username", text: $usernameToCompare)
                    .textFieldStyle(.roundedBorder)
                Button("Compare") {
                    let target = usernameToCompare
                    Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: target) }
                    usernameToCompare = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(usernameToCompare.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            compatibilitySummaryCard
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func compactMetric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text(value.formatted())
                .font(.custom("Avenir Next Demi Bold", size: 18))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compatibilitySummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let compatibility = scrobbleService.listenBrainzCompatibility {
                let percentage = Int((compatibility.similarityScore * 100).rounded())
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(compatibility.targetUserName)
                            .font(.custom("Avenir Next Demi Bold", size: 16))
                        Text("\(percentage)% compatibility")
                            .font(.custom("Avenir Next Medium", size: 12))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Refresh Match") {
                        Task { await scrobbleService.refreshListenBrainzCompatibility(targetUser: compatibility.targetUserName) }
                    }
                    .buttonStyle(.bordered)
                }

                if compatibility.sharedArtists.isEmpty {
                    Text("No shared top artists yet.")
                        .font(.custom("Avenir Next Regular", size: 12))
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(compatibility.sharedArtists.prefix(8)) { artist in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Demi Bold", size: 13))
                                    Text("You \(artist.yourListenCount) · Them \(artist.otherListenCount)")
                                        .font(.custom("Avenir Next Medium", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            } else {
                Text("Pick someone you follow, someone who follows you, or a similar user to compare your open listening history.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var currentPinCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Current Pin")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Spacer()
                if scrobbleService.listenBrainzCurrentPin != nil {
                    Button("Unpin") {
                        Task { _ = await scrobbleService.unpinListenBrainzCurrent() }
                    }
                    .buttonStyle(.bordered)
                }
            }

            if let pin = scrobbleService.listenBrainzCurrentPin {
                pinCard(pin)
            } else {
                Text("Nothing pinned right now.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private var socialListenActivityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Neighbor Listening")
                    .font(.custom("Avenir Next Demi Bold", size: 16))
                Spacer()
                Text("Followers + Following")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if scrobbleService.listenBrainzSocialListens.isEmpty {
                Text("No public neighbor listens loaded yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(scrobbleService.listenBrainzSocialListens.prefix(18)) { activity in
                        socialListenRow(activity)
                    }
                }
            }
        }
        .appPanelStyle()
    }

    private func socialListenRow(_ activity: ListenBrainzSocialListen) -> some View {
        HStack(alignment: .top, spacing: 10) {
            socialListenArtwork(activity.listen.imageURL)
            VStack(alignment: .leading, spacing: 3) {
                Text(activity.listen.trackName)
                    .font(.custom("Avenir Next Demi Bold", size: 13))
                Text("\(activity.listen.artistName) · \(activity.userName)")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                if let release = activity.listen.releaseName {
                    Text(release)
                        .font(.custom("Avenir Next Regular", size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let listenedAt = activity.listen.listenedAt {
                Text(listenedAt.formatted(date: .omitted, time: .shortened))
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture {
            onOpenRecommendation(
                ListenBrainzRecommendedRecording(
                    id: activity.listen.recordingMBID ?? activity.listen.id,
                    recordingMbid: activity.listen.recordingMBID ?? "",
                    title: activity.listen.trackName,
                    artistName: activity.listen.artistName,
                    releaseName: activity.listen.releaseName,
                    score: 0
                )
            )
        }
    }

    @ViewBuilder
    private func socialListenArtwork(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                socialListenArtworkPlaceholder
            }
            .frame(width: 34, height: 34)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            socialListenArtworkPlaceholder
        }
    }

    private var socialListenArtworkPlaceholder: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.06))
            Image(systemName: "waveform.path.ecg")
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(width: 34, height: 34)
    }

    private var playlistBuilderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build Playlist")
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text("Create a ListenBrainz playlist from the first eight recommendations currently loaded.")
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            TextField("Playlist title", text: $playlistTitle)
                .textFieldStyle(.roundedBorder)
            Button("Create from Recommendations") {
                let picks = Array(scrobbleService.listenBrainzRecommendations.prefix(8))
                let title = playlistTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                Task {
                    _ = await scrobbleService.createListenBrainzPlaylist(
                        title: title.isEmpty ? "OpenScrobbler Picks" : title,
                        from: picks
                    )
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(scrobbleService.listenBrainzRecommendations.isEmpty)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func statusCard(title: String, status: String, counts: [(String, Int)]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(status)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                ForEach(counts, id: \.0) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0)
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(.secondary)
                        Text("\(item.1)")
                            .font(.custom("Avenir Next Demi Bold", size: 18))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .appPanelStyle()
    }

    private func socialColumn(
        title: String,
        subtitle: String,
        users: [String],
        actionTitle: String?,
        action: ((String) -> Void)?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if users.isEmpty {
                Text("Nobody here yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(users, id: \.self) { user in
                    HStack {
                        Text(user)
                            .font(.custom("Avenir Next Medium", size: 13))
                        Spacer()
                        if let actionTitle, let action {
                            Button(actionTitle) { action(user) }
                                .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func recommendationRow(_ recommendation: ListenBrainzRecommendedRecording) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.custom("Avenir Next Demi Bold", size: 14))
                    Text(recommendation.artistName ?? "Unknown artist")
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                    if let releaseName = recommendation.releaseName {
                        Text(releaseName)
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(String(format: "%.2f", recommendation.score))
                    .font(.custom("Avenir Next Demi Bold", size: 12))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            HStack(spacing: 10) {
                Button("Inspect") {
                    onOpenRecommendation(recommendation)
                }
                .buttonStyle(.bordered)

                Button("Share to Vault") {
                    onShareRecommendation(recommendation)
                }
                .buttonStyle(.bordered)

                Button("Pin") {
                    Task { _ = await scrobbleService.pinListenBrainzRecommendation(recommendation) }
                }
                .buttonStyle(.bordered)

                Button("Recommend") {
                    onRecommendToFollowers(recommendation)
                }
                .buttonStyle(.borderedProminent)
                .disabled(scrobbleService.listenBrainzFollowers.isEmpty)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func pinColumn(title: String, subtitle: String, pins: [ListenBrainzPinnedRecording]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if pins.isEmpty {
                Text("No pin activity yet.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pins.prefix(6)) { pin in
                    pinCard(pin)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private func pinCard(_ pin: ListenBrainzPinnedRecording) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pin.trackName)
                .font(.custom("Avenir Next Demi Bold", size: 13))
            Text(pin.artistName)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
            if let userName = pin.userName {
                Text(userName)
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
            if let blurb = pin.blurb {
                Text(blurb)
                    .font(.custom("Avenir Next Regular", size: 11))
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func playlistColumn(title: String, subtitle: String, playlists: [ListenBrainzPlaylistSummary]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 16))
            Text(subtitle)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)

            if playlists.isEmpty {
                Text("No playlists loaded.")
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(playlists.prefix(6)) { playlist in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(playlist.title)
                                .font(.custom("Avenir Next Demi Bold", size: 13))
                            Spacer()
                            if let count = playlist.trackCount {
                                Text("\(count) tracks")
                                    .font(.custom("Avenir Next Medium", size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let creator = playlist.creator {
                            Text(creator)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                        if let description = playlist.description {
                            Text(description)
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }
}
