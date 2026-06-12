import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ProfileView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Profile")
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                    Spacer()
                    Button("Refresh") {
                        Task { await scrobbleService.refreshProfile() }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text(scrobbleService.profileStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)

                if let profile = scrobbleService.profile {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(spacing: 6) {
                            profileAvatar(profile.imageURL)
                            if let accountBadge = accountBadgeType(profile: profile) {
                                badgeView(accountBadge, fontSize: 10, horizontal: 8, vertical: 3)
                            }
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(profile.name)
                                .font(.custom("Avenir Next Demi Bold", size: 22))
                            if let realname = profile.realname, !realname.isEmpty {
                                Text(realname)
                                    .font(.custom("Avenir Next Medium", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            HStack(spacing: 14) {
                                profilePill("Tracks", profile.trackCount)
                                profilePill("Artists", profile.artistCount)
                                profilePill("Albums", profile.albumCount)
                                profilePill("Plays", profile.playcount)
                                profilePill("Loved", scrobbleService.lovedTracksCount)
                            }
                            if let registered = profile.registeredAt {
                                Text("Listening since \(registered.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.custom("Avenir Next Regular", size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .appPanelStyle()
                } else {
                    Text("No profile loaded.")
                        .font(.custom("Avenir Next Regular", size: 13))
                        .foregroundStyle(.secondary)
                        .appPanelStyle()
                }

                if let artistCount = profileArtistCount, let avg = scrobbleService.tracksPerDayAverage {
                    Text("You have \(artistCount.formatted()) artists in your library and on average listen to \(avg.formatted()) tracks per day.")
                        .font(.custom("Avenir Next Medium", size: 15))
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .appPanelStyle()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists This Week")
                    .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.weeklyTopArtists.isEmpty {
                        Text("No weekly top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.weeklyTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                artistImage(artist.imageURL, size: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: 13))
                                    Text("\((artist.playcount ?? 0).formatted()) plays")
                                        .font(.custom("Avenir Next Regular", size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                                bar(artist.playcount, max: weeklyMax)
                            }
                            .padding(.vertical, 3)
                        }
                    }
                }
                .appPanelStyle()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Artists Overall")
                        .font(.custom("Avenir Next Medium", size: 14))
                    if scrobbleService.overallTopArtists.isEmpty {
                        Text("No overall top artists available.")
                            .font(.custom("Avenir Next Regular", size: 13))
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(scrobbleService.overallTopArtists) { artist in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    artistImage(artist.imageURL, size: 24)
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Regular", size: 12))
                                    Spacer()
                                    Text((artist.playcount ?? 0).formatted())
                                        .font(.custom("Avenir Next Regular", size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                bar(artist.playcount, max: overallMax)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                .appPanelStyle()
            }
            .padding(24)
        }
    }

    private func profilePill(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text((value ?? 0).formatted())
                .font(.custom("Avenir Next Medium", size: 13))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func bar(_ value: Int?, max: Int) -> some View {
        let ratio = max > 0 ? Double(value ?? 0) / Double(max) : 0
        return RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.cyan.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .mask(
                        GeometryReader { geo in
                            Rectangle().frame(width: geo.size.width * ratio)
                        }
                    )
            }
            .frame(height: 12)
    }

    @ViewBuilder
    private func artistImage(_ urlString: String?, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                Image(systemName: "music.mic")
                    .font(.system(size: max(10, size * 0.35)))
                    .foregroundStyle(.secondary)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func profileAvatar(_ urlString: String?) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AnimatedAvatarImage(
                urls: animatedAvatarCandidates(for: url),
                size: 56
            )
            .frame(width: 56, height: 56)
            .clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .frame(width: 56, height: 56)
        }
    }

    private func animatedAvatarCandidates(for baseURL: URL) -> [URL] {
        var candidates: [URL] = []
        // Some profile providers expose PNG avatars that redirect to GIF when animated.
        // Trying GIF first avoids rendering static avatars for animated profiles.
        let path = baseURL.path.lowercased()
        if path.contains("/avatar"), path.hasSuffix(".png") {
            var comps = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            let gifPath = baseURL.path.replacingOccurrences(of: ".png", with: ".gif")
            comps?.path = gifPath
            if let gifURL = comps?.url {
                candidates.append(gifURL)
            }
        }
        candidates.append(baseURL)
        return candidates
    }

    private var weeklyMax: Int {
        scrobbleService.weeklyTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var overallMax: Int {
        scrobbleService.overallTopArtists.compactMap(\.playcount).max() ?? 0
    }

    private var profileArtistCount: Int? {
        scrobbleService.profile?.artistCount
    }

    private func accountBadgeType(profile: CompatibilityUserProfile) -> String? {
        if let raw = profile.accountType?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty, raw != "user" {
            return raw
        }
        return scrobbleService.isSubscriber ? "subscriber" : nil
    }

    private func badgeView(_ type: String, fontSize: CGFloat, horizontal: CGFloat, vertical: CGFloat) -> some View {
        let normalized = type.lowercased()
        let label = accountBadgeLabel(for: normalized)
        let fill: AnyShapeStyle = normalized == "alum"
            ? AnyShapeStyle(LinearGradient(colors: [Color(red: 0.55, green: 0.14, blue: 1.0), Color(red: 0.70, green: 0.26, blue: 1.0)], startPoint: .leading, endPoint: .trailing))
            : AnyShapeStyle(Color.black)

        return Text(label)
            .font(.custom("Avenir Next Demi Bold", size: fontSize))
            .tracking(0.5)
            .foregroundStyle(.white)
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(fill, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}
