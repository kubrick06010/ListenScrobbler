import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ScrobbleDetailPanel: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @Environment(\.openURL) private var openURL
    let item: CompatibilityRecentScrobble
    let kind: DeepLinkTarget.Kind
    let availableWidth: CGFloat
    let onShare: (ShareDraft) -> Void
    let onCaptureObsession: (ObsessionDraft) -> Void
    @State private var biography: ArtistBiographySheetItem?

    var body: some View {
        let metrics = DetailPanelMetrics(width: availableWidth)

        ScrollView {
            VStack(alignment: .leading, spacing: metrics.sectionSpacing) {
                HStack {
                    Text(panelTitle)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.headerFont))
                    Spacer()
                    detailActions
                    Text(scrobbleService.inspectStatus)
                        .font(.custom("Avenir Next Medium", size: 12))
                        .foregroundStyle(.secondary)
                }

                if kind == .track || kind == .album {
                    trackHeader(metrics: metrics)
                }

                if let openDetails = scrobbleService.inspectedOpenEntityDetails {
                    openMetadataSection(openDetails)
                }

                if let enrichment = scrobbleService.inspectedOpenEnrichment {
                    openEnrichmentSection(enrichment, metrics: metrics)
                }

                // Mirror the legacy iOS navigation model here: related content must follow the
                // entity the user opened, not the artist context we happen to have loaded.
                if kind == .track, let track = scrobbleService.inspectedTrackDetails {
                    statGrid(
                        listeners: track.listeners,
                        plays: track.playcount,
                        library: track.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !track.tags.isEmpty {
                        tagLinks(title: "Popular tags", tags: Array(track.tags.prefix(7)))
                    }
                    if !scrobbleService.inspectedSimilarTracks.isEmpty {
                        Text("Similar Tracks")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarTracksGrid(scrobbleService.inspectedSimilarTracks, compact: metrics.isCompact)
                    }
                }

                if kind == .album, !scrobbleService.inspectedSimilarAlbums.isEmpty {
                    Text("Similar Albums")
                        .font(.custom("Avenir Next Medium", size: 17))
                    similarAlbumsGrid(scrobbleService.inspectedSimilarAlbums, compact: metrics.isCompact)
                }

                if let artist = scrobbleService.inspectedArtistDetails {
                    if kind == .track || kind == .album {
                        Divider()
                    }
                    Text(artist.name)
                        .font(.custom("Avenir Next Demi Bold", size: metrics.artistTitleFont))
                        .lineLimit(metrics.isCompact ? 3 : 2)
                        .fixedSize(horizontal: false, vertical: true)

                    artistSection(artist, metrics: metrics)

                    statGrid(
                        listeners: artist.listeners,
                        plays: artist.playcount,
                        library: artist.userPlaycount,
                        compact: metrics.isCompact
                    )
                    if !artist.tags.isEmpty {
                        tagLinks(title: "Tags", tags: Array(artist.tags.prefix(10)))
                    }
                    // Match the classic iOS app's semantics: only artist detail
                    // renders similar artists. Track/album detail get their own
                    // "similar" blocks instead of inheriting artist similarity.
                    if kind == .artist, !artist.similarArtists.isEmpty {
                        Text("Similar Artists")
                            .font(.custom("Avenir Next Medium", size: 17))
                        similarArtistsGrid(artist.similarArtists, compact: metrics.isCompact)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 4)
        }
        .sheet(item: $biography) { item in
            ArtistBiographySheetView(item: item)
        }
    }

    private var panelTitle: String {
        switch kind {
        case .track:
            return "Track Detail"
        case .artist:
            return "Artist Detail"
        case .album:
            return "Album Detail"
        }
    }

    private var detailActions: some View {
        HStack(spacing: 8) {
            if kind == .track {
                Button {
                    onCaptureObsession(obsessionDraft)
                } label: {
                    Image(systemName: "heart.text.square")
                }
                .help("Capture obsession")
            }

            if let artistBiographyItem {
                Button {
                    biography = artistBiographyItem
                } label: {
                    Image(systemName: "book")
                }
                .help("Artist biography")
            }

            Button {
                onShare(shareDraft)
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .help("Archive share")
        }
        .buttonStyle(.bordered)
    }

    private var shareDraft: ShareDraft {
        ShareDraft(
            kind: shareKind,
            artist: item.artist,
            track: kind == .track ? item.track : nil,
            album: kind == .album ? (item.album ?? item.track) : item.album,
            sourceURL: item.url,
            imageURL: detailArtworkURL,
            artistMBID: scrobbleService.inspectedOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.inspectedOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.inspectedOpenEntityDetails?.releaseMBID
        )
    }

    private var obsessionDraft: ObsessionDraft {
        ObsessionDraft(
            artist: item.artist,
            track: item.track,
            album: scrobbleService.inspectedTrackDetails?.album ?? item.album,
            sourceURL: scrobbleService.inspectedTrackDetails?.url ?? item.url,
            imageURL: detailArtworkURL,
            artistMBID: scrobbleService.inspectedOpenEntityDetails?.artistMBID,
            recordingMBID: scrobbleService.inspectedOpenEntityDetails?.recordingMBID,
            releaseMBID: scrobbleService.inspectedOpenEntityDetails?.releaseMBID
        )
    }

    private var detailArtworkURL: String? {
        scrobbleService.inspectedTrackDetails?.imageURL
            ?? item.imageURL
            ?? scrobbleService.inspectedOpenEntityDetails?.imageURL
    }

    private var artistBiographyItem: ArtistBiographySheetItem? {
        guard let details = scrobbleService.inspectedOpenEntityDetails,
              let summary = details.artistSummary?.nilIfBlank else {
            return nil
        }
        return ArtistBiographySheetItem(
            artistName: details.artistName,
            summary: summary,
            imageURL: details.artistImageURL ?? scrobbleService.inspectedArtistDetails?.imageURL,
            sourceURL: details.artistSummaryURL,
            languageCode: details.artistSummaryLanguageCode
        )
    }

    private var shareKind: SharedMusicEntry.EntityKind {
        switch kind {
        case .track:
            return .track
        case .artist:
            return .artist
        case .album:
            return .album
        }
    }

    // Apple’s current adaptive-layout guidance favors reflow over brute-force
    // shrinking: keep hierarchy intact, switch arrangement when width becomes
    // constrained, and only scale typography within safe bounds. This panel
    // follows that approach by collapsing from a side-by-side inspector into a
    // stacked detail layout before text becomes unreadably narrow.
    // References:
    // Apple. (n.d.). ViewThatFits. https://developer.apple.com/documentation/swiftui/viewthatfits
    // Apple. (n.d.). Human Interface Guidelines. https://developer.apple.com/design/human-interface-guidelines/
    private struct DetailPanelMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 620 }
        var isNarrowCompact: Bool { width < 500 }
        var artworkSize: CGFloat {
            if isNarrowCompact { return min(180, max(128, width - 56)) }
            if isCompact { return min(220, max(150, width - 48)) }
            return 180
        }
        var headerFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 20 : 24) }
        var titleFont: CGFloat { isNarrowCompact ? 18 : (isCompact ? 22 : 26) }
        var subtitleFont: CGFloat { isNarrowCompact ? 14 : (isCompact ? 16 : 20) }
        var albumFont: CGFloat { isNarrowCompact ? 13 : (isCompact ? 14 : 16) }
        var artistTitleFont: CGFloat { isNarrowCompact ? 22 : (isCompact ? 26 : 32) }
        var sectionSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
        var stackSpacing: CGFloat { isNarrowCompact ? 8 : (isCompact ? 10 : 12) }
    }

    @ViewBuilder
    private func trackHeader(metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artwork(size: metrics.artworkSize)
                trackTextBlock(metrics: metrics)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
        }
    }

    private func trackTextBlock(metrics: DetailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerPrimaryText)
                .font(.custom("Avenir Next Demi Bold", size: metrics.titleFont))
                .lineLimit(metrics.isNarrowCompact ? 5 : 4)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Text(headerSecondaryText)
                .font(.custom("Avenir Next Medium", size: metrics.subtitleFont))
                .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                .fixedSize(horizontal: false, vertical: true)
            if let tertiary = headerTertiaryText {
                Text(tertiary)
                    .font(.custom("Avenir Next Medium", size: metrics.albumFont))
                    .foregroundStyle(.secondary)
                    .lineLimit(metrics.isNarrowCompact ? 4 : 3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var headerPrimaryText: String {
        switch kind {
        case .track:
            return item.track
        case .artist:
            return item.artist
        case .album:
            return item.album ?? item.track
        }
    }

    private var headerSecondaryText: String {
        switch kind {
        case .track:
            return "by \(item.artist)"
        case .artist:
            return "Artist overview"
        case .album:
            return "by \(item.artist)"
        }
    }

    private var headerTertiaryText: String? {
        switch kind {
        case .track:
            if let album = scrobbleService.inspectedTrackDetails?.album ?? item.album {
                return "from \(album)"
            }
            return nil
        case .artist:
            return nil
        case .album:
            return nil
        }
    }

    @ViewBuilder
    private func artistSection(_ artist: CompatibilityArtistDetails, metrics: DetailPanelMetrics) -> some View {
        if metrics.isCompact {
            VStack(alignment: .leading, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL, size: metrics.artworkSize)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            HStack(alignment: .top, spacing: metrics.stackSpacing) {
                artistArt(artist.imageURL)
                HTMLSummaryText(rawHTML: artist.summary ?? "No artist biography available.", fontSize: 14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func openMetadataSection(_ details: OpenMusicEntityDetails) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Open Metadata")
                    .font(.custom("Avenir Next Medium", size: 17))
                Spacer()
                Text(details.hasResolvedMusicBrainzEntity ? "MusicBrainz resolved" : "Best effort")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 8) {
                metadataCell("Recording MBID", details.recordingMBID)
                metadataCell("Artist MBID", details.artistMBID)
                metadataCell("Release MBID", details.releaseMBID)
                metadataCell("Country", details.country)
                metadataCell("Type", details.type)
                metadataCell("Disambiguation", details.disambiguation)
            }

            if !details.tags.isEmpty {
                tagLinks(title: "MusicBrainz tags", tags: details.tags)
            }

            if !details.links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(details.links) { link in
                        Button(link.title) {
                            openURL(link.url)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func openEnrichmentSection(_ enrichment: OpenListeningEnrichment, metrics: DetailPanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ListenBrainz Context")
                    .font(.custom("Avenir Next Medium", size: 17))
                Spacer()
                Text("Open data")
                    .font(.custom("Avenir Next Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
            }

            LazyVGrid(
                columns: metrics.isCompact
                    ? [GridItem(.adaptive(minimum: 142), alignment: .leading)]
                    : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                stat("Your track plays", enrichment.userRecordingListenCount)
                stat("Your artist plays", enrichment.userArtistListenCount)
                stat("Your album plays", enrichment.userReleaseListenCount)
                stat("Global track plays", enrichment.globalRecordingListenCount)
                stat("Global track listeners", enrichment.globalRecordingListenerCount)
                stat("Global artist plays", enrichment.globalArtistListenCount)
            }

            if let profile = enrichment.artistProfile {
                listenBrainzArtistProfileSection(profile)
            }

            if !enrichment.similarArtists.isEmpty {
                Text("Similar Artists")
                    .font(.custom("Avenir Next Medium", size: 15))
                openSimilarArtistsGrid(enrichment.similarArtists, compact: metrics.isCompact)
            }

            if !enrichment.topArtistRecordings.isEmpty {
                Text("Top Tracks By This Artist")
                    .font(.custom("Avenir Next Medium", size: 15))
                openPopularRecordingsGrid(enrichment.topArtistRecordings, compact: metrics.isCompact)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func listenBrainzArtistProfileSection(_ profile: ListenBrainzArtistProfile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Artist Profile")
                .font(.custom("Avenir Next Medium", size: 15))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), alignment: .leading)], alignment: .leading, spacing: 8) {
                metadataCell("Formed", profile.beginYear.map(String.init))
                metadataCell("Area", profile.area)
                metadataCell("Type", profile.type)
            }

            if !profile.tags.isEmpty {
                weightedTagLinks(title: "ListenBrainz tags", tags: Array(profile.tags.prefix(10)))
            }

            let links = preferredArtistLinks(profile.links)
            if !links.isEmpty {
                HStack(spacing: 8) {
                    ForEach(links.prefix(5)) { link in
                        Button(link.title) {
                            openURL(link.url)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func metadataCell(_ title: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
            Text(value?.nilIfBlank ?? "—")
                .font(.custom("Avenir Next Medium", size: 12))
                .lineLimit(2)
                .textSelection(.enabled)
        }
    }

    private func statGrid(listeners: Int?, plays: Int?, library: Int?, compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 132), alignment: .leading)]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            stat("Listeners", listeners)
            stat("Plays", plays)
            stat("In your library", library)
        }
    }

    private func similarArtistsGrid(_ artists: [CompatibilitySimilarArtist], compact: Bool) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: item.artist,
                    nodes: Array(artists.prefix(compact ? 8 : 12)).enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.id)",
                            name: artist.name,
                            value: Double(max(1, artists.count - index)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: compact
                )
                .frame(height: compact ? 300 : 360)
            } else {
                let columns = compact
                    ? [GridItem(.adaptive(minimum: 88), spacing: 14, alignment: .topLeading)]
                    : [GridItem(.adaptive(minimum: 90), spacing: 16, alignment: .topLeading)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(artists.prefix(compact ? 6 : 8)) { similar in
                        similarArtistLink(similar)
                    }
                }
            }
        }
    }

    private func openSimilarArtistsGrid(_ artists: [ListenBrainzSimilarArtist], compact: Bool) -> some View {
        Group {
            if artists.count >= 3 {
                SimilarArtistGraphView(
                    centerName: item.artist,
                    nodes: Array(artists.prefix(compact ? 8 : 12)).enumerated().map { index, artist in
                        SimilarArtistGraphNode(
                            id: "\(index)-\(artist.id)",
                            name: artist.name,
                            value: Double(max(1, artist.totalListenCount)),
                            imageURL: artist.imageURL
                        )
                    },
                    compact: compact
                )
                .frame(height: compact ? 300 : 360)
            } else {
                let columns = compact
                    ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
                    : [GridItem(.adaptive(minimum: 132), spacing: 16, alignment: .topLeading)]

                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(artists.prefix(compact ? 6 : 8)) { artist in
                        VStack(alignment: .leading, spacing: 4) {
                            artworkThumbnail(artist.imageURL, size: 74)
                            Text(artist.name)
                                .font(.custom("Avenir Next Medium", size: 12))
                                .lineLimit(2)
                            Text("\(artist.totalListenCount.formatted()) plays")
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func openPopularRecordingsGrid(_ recordings: [ListenBrainzPopularRecording], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 180), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 220), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(recordings.prefix(compact ? 4 : 8)) { recording in
                HStack(alignment: .top, spacing: 10) {
                    artworkThumbnail(recording.imageURL, size: 54)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(recording.title)
                            .font(.custom("Avenir Next Medium", size: 12))
                            .lineLimit(2)
                        if let release = recording.releaseName {
                            Text(release)
                                .font(.custom("Avenir Next Regular", size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Text("\(count(recording.totalListenCount)) plays")
                            .font(.custom("Avenir Next Regular", size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(8)
                .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    private func similarTracksGrid(_ tracks: [CompatibilitySimilarTrack], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(tracks.prefix(compact ? 6 : 8)) { track in
                similarTrackLink(track)
            }
        }
    }

    private func similarAlbumsGrid(_ albums: [CompatibilitySimilarAlbum], compact: Bool) -> some View {
        let columns = compact
            ? [GridItem(.adaptive(minimum: 118), spacing: 14, alignment: .topLeading)]
            : [GridItem(.adaptive(minimum: 124), spacing: 16, alignment: .topLeading)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
            ForEach(albums.prefix(compact ? 6 : 8)) { album in
                similarAlbumLink(album)
            }
        }
    }

    @ViewBuilder
    private func artwork(size: CGFloat = 180) -> some View {
        if let urlString = detailArtworkURL,
           let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func artistArt(_ urlString: String?, size: CGFloat = 180) -> some View {
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

    private func stat(_ title: String, _ value: Int?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value.map { $0.formatted() } ?? "—")
                .font(.custom("Avenir Next Demi Bold", size: 22))
            Text(title)
                .font(.custom("Avenir Next Medium", size: 12))
            .foregroundStyle(.secondary)
        }
    }

    private func count(_ value: Int?) -> String {
        value.map { $0.formatted() } ?? "—"
    }

    private func tagLinks(title: String, tags: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.custom("Avenir Next Medium", size: 13))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func weightedTagLinks(title: String, tags: [ListenBrainzArtistTag]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.custom("Avenir Next Medium", size: 13))
                .foregroundStyle(.secondary)
            FlowLayout(spacing: 6) {
                ForEach(tags) { tag in
                    HStack(spacing: 7) {
                        Text(tag.name)
                            .font(.custom("Avenir Next Medium", size: 13))
                        if tag.count > 0 {
                            Text("\(tag.count)")
                                .font(.custom("Avenir Next Medium", size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06), in: Capsule())
                }
            }
        }
    }

    private func preferredArtistLinks(_ links: [ListenBrainzArtistLink]) -> [ListenBrainzArtistLink] {
        let priority = ["Official Homepage", "Youtube", "Streaming", "Social Network", "Wikidata"]
        return links.sorted { lhs, rhs in
            let left = priority.firstIndex(of: lhs.title) ?? priority.count
            let right = priority.firstIndex(of: rhs.title) ?? priority.count
            if left == right {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return left < right
        }
    }

    private func similarArtistLink(_ similar: CompatibilitySimilarArtist) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artistArt(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 74, alignment: .leading)
        }
    }

    private func similarTrackLink(_ similar: CompatibilitySimilarTrack) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artworkThumbnail(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 92, alignment: .leading)
            Text(similar.artist)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
        }
    }

    private func similarAlbumLink(_ similar: CompatibilitySimilarAlbum) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            artworkThumbnail(similar.imageURL, size: 74)
            Text(similar.name)
                .font(.custom("Avenir Next Regular", size: 12))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(width: 92, alignment: .leading)
            Text(similar.artist)
                .font(.custom("Avenir Next Medium", size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(width: 92, alignment: .leading)
        }
    }

    @ViewBuilder
    private func artworkThumbnail(_ urlString: String?, size: CGFloat) -> some View {
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

private struct ArtistBiographySheetItem: Identifiable {
    let artistName: String
    let summary: String
    let imageURL: String?
    let sourceURL: URL?
    let languageCode: String?

    var id: String {
        [artistName, languageCode ?? "unknown"].joined(separator: "|")
    }
}

private struct ArtistBiographySheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let item: ArtistBiographySheetItem

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Artist Biography")
                    .font(.custom("Avenir Next Demi Bold", size: 22))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    biographyImage

                    Text(item.artistName)
                        .font(.custom("Avenir Next Demi Bold", size: 28))
                        .fixedSize(horizontal: false, vertical: true)

                    Text(item.summary)
                        .font(.custom("Avenir Next Regular", size: 14))
                        .lineSpacing(3)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)

                    if let sourceURL = item.sourceURL {
                        Button {
                            openURL(sourceURL)
                        } label: {
                            Label("Wikipedia", systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 460)
    }

    @ViewBuilder
    private var biographyImage: some View {
        if let imageURL = item.imageURL, let url = URL(string: imageURL) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.white.opacity(0.06)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 220)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
