import SwiftUI
import WebKit
import AppKit
import UniformTypeIdentifiers

struct ChartsView: View {
    @EnvironmentObject private var scrobbleService: ScrobbleService
    @State private var listenBrainzRange: ListenBrainzStatsRange = .week
    let onOpenTrack: (_ track: String, _ artist: String) -> Void
    let onOpenArtist: (_ artist: String) -> Void
    let onOpenAlbum: (_ album: String, _ artist: String, _ imageURL: String?) -> Void
    let onShareListen: (ShareDraft) -> Void

    var body: some View {
        GeometryReader { proxy in
            let metrics = ChartsMetrics(width: proxy.size.width - 48)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Charts")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.screenTitleFont))

                    listenBrainzCharts(metrics: metrics)
                    listenBrainzArtistOrigins(metrics: metrics)
                    listenBrainzArtistAffinity(metrics: metrics)

                    if !scrobbleService.weeklyTopArtists.isEmpty {
                        Text("\(scrobbleService.weeklyTopArtists.count) Artists")
                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))

                        LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                            ForEach(scrobbleService.weeklyTopArtists.prefix(8)) { artist in
                                VStack(alignment: .leading, spacing: 6) {
                                    resolvedCover(
                                        artist: artist.name,
                                        track: nil,
                                        album: nil,
                                        target: .artist,
                                        sourceResolution: artist.artworkResolution,
                                        size: metrics.coverSize,
                                        placeholder: artist.name
                                    )
                                    Text(artist.name)
                                        .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(AppLocalization.integer(artist.playcount ?? 0)) listens")
                                        .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                        .foregroundStyle(.secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onOpenArtist(artist.name)
                                }
                            }
                        }
                        .appPanelStyle()
                    }

                    Text("\(topAlbums.count) Albums")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                        ForEach(topAlbums.prefix(8), id: \.id) { album in
                            VStack(alignment: .leading, spacing: 6) {
                                resolvedCover(
                                    artist: album.artist,
                                    track: nil,
                                    album: album.title,
                                    target: .album,
                                    sourceResolution: album.artworkResolution,
                                    size: metrics.coverSize
                                )
                                Text(album.title)
                                    .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text(album.artist)
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                Text("\(AppLocalization.integer(album.count)) listens")
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont - 1))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenAlbum(album.title, album.artist, album.artworkResolution?.automaticArtworkResolution?.url)
                            }
                        }
                    }
                    .appPanelStyle()

                    Text("\(topTracks.count) Tracks")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                    VStack(spacing: 10) {
                        ForEach(topTracks.prefix(10), id: \.id) { track in
                            HStack(alignment: .top, spacing: 10) {
                                resolvedCover(
                                    artist: track.artist,
                                    track: track.title,
                                    album: nil,
                                    target: .track,
                                    sourceResolution: track.artworkResolution,
                                    size: metrics.trackCoverSize
                                )
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(track.title)
                                        .font(.custom("Avenir Next Medium", size: metrics.trackTitleFont))
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                    Text(track.artist)
                                        .font(.custom("Avenir Next Regular", size: metrics.trackMetaFont))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(metrics.isCompact ? 2 : 1)
                                }
                                Spacer(minLength: 8)
                                Text(AppLocalization.integer(track.count))
                                    .font(.custom("Avenir Next Medium", size: metrics.trackCountFont))
                                    .foregroundStyle(.secondary)
                                    .fixedSize()
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenTrack(track.title, track.artist)
                            }
                        }
                    }
                    .appPanelStyle()
                }
                .frame(maxWidth: metrics.contentMaxWidth, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        // Validation can finish after this view appears. Tie the task to the
        // connection identity so a first attempt made while the username is
        // still unknown cannot permanently leave the charts empty.
        .task(id: listenBrainzLoadIdentity) {
            guard scrobbleService.listenBrainzEnabled else { return }
            await refreshListenBrainzArchive()
        }
    }

    private var listenBrainzLoadIdentity: String {
        "\(scrobbleService.listenBrainzEnabled)-\(scrobbleService.listenBrainzUsername ?? "")"
    }

    @ViewBuilder
    private func listenBrainzCharts(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 20) {
                    archiveTitle
                    Spacer(minLength: 24)
                    archiveControls(maxWidth: 430)
                }

                VStack(alignment: .leading, spacing: 3) {
                    archiveTitle
                    archiveControls(maxWidth: .infinity)
                        .padding(.top, 10)
                }
            }

            if let snapshot = scrobbleService.listenBrainzStats {
                LazyVGrid(columns: metrics.metricColumns, alignment: .leading, spacing: 10) {
                    metricPill("User", snapshot.username)
                    metricPill("Range", snapshot.range.title)
                    metricPill("Listens", snapshot.totalListenCount.map { AppLocalization.integer($0) } ?? AppLocalization.string("Pending"))
                    metricPill("Fetched", AppLocalization.date(snapshot.fetchedAt, date: .omitted, time: .shortened))
                }

                if !snapshot.listeningActivity.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Listening Activity")
                            .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                        Text(activitySubtitle(snapshot.listeningActivity))
                            .font(.custom("Avenir Next Medium", size: 11))
                            .foregroundStyle(.secondary)
                    }
                    ListeningActivityChartView(activity: snapshot.listeningActivity, range: snapshot.range)
                }

                if !snapshot.topRecordings.isEmpty || !snapshot.topArtists.isEmpty {
                    LazyVGrid(columns: metrics.rankingColumns, alignment: .leading, spacing: 14) {
                        if !snapshot.topRecordings.isEmpty {
                            rankingPanel(title: listenBrainzCountTitle(snapshot.topRecordings.count, kind: .tracks)) {
                                ForEach(snapshot.topRecordings.prefix(metrics.rankingItemLimit)) { recording in
                                    chartRow(
                                        title: recording.trackName,
                                        subtitle: recordingSubtitle(recording),
                                        count: recording.listenCount
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpenTrack(recording.trackName, recording.artistName) }
                                }
                            }
                        }

                        if !snapshot.topArtists.isEmpty {
                            rankingPanel(title: listenBrainzCountTitle(snapshot.topArtists.count, kind: .artists)) {
                                ForEach(snapshot.topArtists.prefix(metrics.rankingItemLimit)) { artist in
                                    chartRow(
                                        title: artist.name,
                                        subtitle: "Artist",
                                        count: artist.listenCount
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture { onOpenArtist(artist.name) }
                                }
                            }
                        }
                    }
                }

                if !snapshot.topReleases.isEmpty {
                    Text(listenBrainzCountTitle(snapshot.topReleases.count, kind: .releases))
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    LazyVGrid(columns: metrics.cardColumns, alignment: .leading, spacing: 16) {
                        ForEach(snapshot.topReleases.prefix(8)) { release in
                            VStack(alignment: .leading, spacing: 6) {
                                resolvedCover(
                                    artist: release.artistName,
                                    track: nil,
                                    album: release.name,
                                    target: .album,
                                    sourceResolution: nil,
                                    size: metrics.coverSize,
                                    placeholder: release.name
                                )
                                Text(release.name)
                                    .font(.custom("Avenir Next Medium", size: metrics.cardTitleFont))
                                    .lineLimit(2)
                                Text(release.artistName)
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont))
                                    .foregroundStyle(.secondary)
                                Text("\(AppLocalization.integer(release.listenCount)) listens")
                                    .font(.custom("Avenir Next Regular", size: metrics.cardMetaFont - 1))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                onOpenAlbum(release.name, release.artistName, nil)
                            }
                        }
                    }
                }

                if !snapshot.recentListens.isEmpty {
                    Text("Recent ListenBrainz Activity")
                        .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont - 4))
                    VStack(spacing: 8) {
                        ForEach(snapshot.recentListens.prefix(8)) { listen in
                            ListenActionRow(
                                title: listen.trackName,
                                artist: listen.artistName,
                                album: listen.releaseName,
                                artworkResolution: listen.artworkResolution,
                                url: nil,
                                loved: false,
                                playedAt: listen.listenedAt,
                                nowPlaying: false,
                                recordingMBID: listen.recordingMBID,
                                recordingMSID: listen.recordingMSID,
                                artistMBID: listen.artistMBID,
                                releaseMBID: listen.releaseMBID,
                                onDelete: {
                                    Task {
                                        _ = await scrobbleService.deleteListenBrainzListen(
                                            CompatibilityRecentScrobble(
                                                id: "listenbrainz-\(listen.id)",
                                                track: listen.trackName,
                                                artist: listen.artistName,
                                                album: listen.releaseName,
                                                artworkResolution: listen.artworkResolution,
                                                url: listen.recordingMBID.map { "https://listenbrainz.org/player/?recording_mbids=\($0)" },
                                                loved: false,
                                                playedAt: listen.listenedAt,
                                                nowPlaying: false,
                                                recordingMbid: listen.recordingMBID,
                                                recordingMsid: listen.recordingMSID
                                            )
                                        )
                                    }
                                },
                                onOpen: { onOpenTrack(listen.trackName, listen.artistName) },
                                onShare: onShareListen
                            )
                        }
                    }
                }
            } else if scrobbleService.listenBrainzEnabled {
                Text("No ListenBrainz charts loaded yet.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            } else {
                Text("Connect ListenBrainz in Preferences to unlock open archive charts, recent listens, and cross-platform history.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    private var archiveTitle: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("ListenBrainz Archive")
                .font(.custom("Avenir Next Demi Bold", size: 28))
            Text(scrobbleService.listenBrainzStatsStatus)
                .font(.custom("Avenir Next Medium", size: 12))
                .foregroundStyle(.secondary)
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private func archiveControls(maxWidth: CGFloat) -> some View {
        HStack(spacing: 10) {
            Picker("Range", selection: $listenBrainzRange) {
                ForEach(ListenBrainzStatsRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: maxWidth)
            .onChange(of: listenBrainzRange) { range in
                Task { await refreshListenBrainzArchive(range: range) }
            }

            Button {
                Task { await refreshListenBrainzArchive() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.bordered)
            .help("Refresh ListenBrainz charts")
        }
    }

    private func rankingPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.custom("Avenir Next Demi Bold", size: 20))
            VStack(spacing: 8) {
                content()
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func activitySubtitle(_ activity: [ListenBrainzListeningActivity]) -> String {
        guard let peak = activity.max(by: { $0.listenCount < $1.listenCount }) else { return "" }
        let peakLabel = peak.from.map {
            $0.formatted(
                .dateTime
                    .weekday(.wide)
                    .day()
                    .month(.wide)
                    .year()
                    .locale(preferredAppLocale())
            )
        } ?? peak.label
        return AppLocalization.localizedStringWithFormat(
            AppLocalization.string("Peak: %@ listens on %@"),
            AppLocalization.integer(peak.listenCount),
            peakLabel
        )
    }

    private enum ListenBrainzCountKind {
        case tracks
        case artists
        case releases
    }

    private func listenBrainzCountTitle(_ count: Int, kind: ListenBrainzCountKind) -> String {
        let format: String
        switch kind {
        case .tracks:
            format = AppLocalization.string("%d ListenBrainz Tracks")
        case .artists:
            format = AppLocalization.string("%d ListenBrainz Artists")
        case .releases:
            format = AppLocalization.string("%d ListenBrainz Releases")
        }
        return AppLocalization.localizedStringWithFormat(format, count)
    }

    @ViewBuilder
    private func listenBrainzArtistOrigins(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Artist Origins")
                    .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                Text(scrobbleService.listenBrainzArtistMapStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            if !scrobbleService.listenBrainzArtistMap.isEmpty {
                HStack(spacing: 12) {
                    metricPill("Countries", "\(scrobbleService.listenBrainzArtistMap.count)")
                    metricPill("Top Origin", countryLabel(for: scrobbleService.listenBrainzArtistMap.first?.countryCode))
                    metricPill("Range", listenBrainzRange.title)
                }

                VStack(spacing: 8) {
                    ForEach(scrobbleService.listenBrainzArtistMap.prefix(10)) { entry in
                        artistOriginRow(entry, max: scrobbleService.listenBrainzArtistMap.first?.artistCount ?? 1)
                    }
                }
            } else if scrobbleService.listenBrainzEnabled {
                Text("No origin map available yet for this range.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    @ViewBuilder
    private func listenBrainzArtistAffinity(metrics: ChartsMetrics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Affinity Network")
                    .font(.custom("Avenir Next Demi Bold", size: metrics.sectionCountFont))
                Text(scrobbleService.listenBrainzArtistAffinityStatus)
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            if let graph = scrobbleService.listenBrainzArtistAffinityGraph, !graph.nodes.isEmpty {
                HStack(spacing: 12) {
                    metricPill("Seed Artists", "\(graph.nodes.filter(\.isSeed).count)")
                    metricPill("Nodes", "\(graph.nodes.count)")
                    metricPill("Edges", "\(graph.edges.count)")
                }

                ArtistAffinityGraphView(graph: graph) { artist in
                    onOpenArtist(artist)
                }
                .frame(height: 360)
            } else if scrobbleService.listenBrainzEnabled {
                Text("No affinity network available yet for this range.")
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .appPanelStyle()
    }

    private func metricPill(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.custom("Avenir Next Medium", size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.custom("Avenir Next Demi Bold", size: 13))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func recordingSubtitle(_ recording: ListenBrainzRecordingStat) -> String {
        if let release = recording.releaseName?.nilIfBlank {
            return "\(recording.artistName) - \(release)"
        }
        return recording.artistName
    }

    private func chartRow(title: String, subtitle: String, count: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "waveform")
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Avenir Next Medium", size: 15))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.custom("Avenir Next Regular", size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(AppLocalization.integer(count))
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func artistOriginRow(_ entry: ListenBrainzArtistMapEntry, max: Int) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(countryLabel(for: entry.countryCode))
                    .font(.custom("Avenir Next Medium", size: 15))
                Text(entry.countryCode)
                    .font(.custom("Avenir Next Regular", size: 11))
                    .foregroundStyle(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.92), Color.accentColor.opacity(0.82)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .mask(
                            GeometryReader { geo in
                                let ratio = max > 0 ? Double(entry.artistCount) / Double(max) : 0
                                Rectangle().frame(width: geo.size.width * ratio)
                            }
                        )
                }
                .frame(height: 12)

            Text(AppLocalization.integer(entry.artistCount))
                .font(.custom("Avenir Next Demi Bold", size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 54, alignment: .trailing)
        }
        .padding(8)
        .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func countryLabel(for code: String?) -> String {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines), !code.isEmpty else {
            return AppLocalization.string("Unknown")
        }
        return code
    }

    private func refreshListenBrainzArchive(range: ListenBrainzStatsRange? = nil) async {
        let selectedRange = range ?? listenBrainzRange
        await scrobbleService.refreshListenBrainzStats(range: selectedRange)
        await scrobbleService.refreshListenBrainzArtistMap(range: selectedRange)
        await scrobbleService.refreshListenBrainzArtistAffinity(range: selectedRange)
    }

    // Charts use adaptive card columns instead of hard-coded horizontal strips.
    // The current desktop pattern is to let cards wrap as width changes and keep
    // content readable, rather than preserving a fixed card width that forces
    // clipping or excessive horizontal scrolling.
    private struct ChartsMetrics {
        let width: CGFloat

        var isCompact: Bool { width < 980 }
        var isNarrow: Bool { width < 760 }
        var contentMaxWidth: CGFloat { isCompact ? .infinity : 1240 }
        var screenTitleFont: CGFloat { isNarrow ? 22 : 24 }
        var sectionCountFont: CGFloat { isNarrow ? 24 : 30 }
        var coverSize: CGFloat { isNarrow ? 136 : 156 }
        var trackCoverSize: CGFloat { isNarrow ? 46 : 54 }
        var cardTitleFont: CGFloat { isNarrow ? 15 : 16 }
        var cardMetaFont: CGFloat { isNarrow ? 13 : 14 }
        var trackTitleFont: CGFloat { isNarrow ? 16 : 18 }
        var trackMetaFont: CGFloat { isNarrow ? 14 : 16 }
        var trackCountFont: CGFloat { isNarrow ? 14 : 16 }
        var cardColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 144 : 160), spacing: 16, alignment: .topLeading)]
        }
        var metricColumns: [GridItem] {
            [GridItem(.adaptive(minimum: isNarrow ? 112 : 132), spacing: 10, alignment: .leading)]
        }
        var rankingColumns: [GridItem] {
            if width >= 900 {
                return Array(repeating: GridItem(.flexible(minimum: 280), spacing: 14, alignment: .topLeading), count: 2)
            }
            return [GridItem(.flexible(minimum: 260), alignment: .topLeading)]
        }
        var rankingItemLimit: Int { width >= 900 ? 8 : 10 }
    }

    @ViewBuilder
    private func cover(_ urlString: String?, size: CGFloat, placeholder: String? = nil) -> some View {
        if let urlString, let url = URL(string: urlString) {
            CachedAsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                coverPlaceholder(size: size, text: placeholder)
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            coverPlaceholder(size: size, text: placeholder)
        }
    }

    private func resolvedCover(
        artist: String,
        track: String?,
        album: String?,
        target: ArtworkLevel,
        sourceResolution: ArtworkResolution?,
        size: CGFloat,
        placeholder: String? = nil
    ) -> some View {
        ResolvedArtworkImage(
            artist: artist,
            track: track,
            album: album,
            target: target,
            sourceResolution: sourceResolution
        ) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            coverPlaceholder(size: size, text: placeholder)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func coverPlaceholder(size: CGFloat, text: String?) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            if let text, !text.isEmpty {
                Text(monogram(for: text))
                    .font(.custom("Avenir Next Demi Bold", size: max(18, size * 0.26)))
                    .foregroundStyle(Color.white.opacity(0.78))
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: max(14, size * 0.2), weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }

    private func monogram(for text: String) -> String {
        let parts = text.split(separator: " ").prefix(2)
        let chars = parts.compactMap { $0.first }.map { String($0).uppercased() }
        if !chars.isEmpty {
            return chars.joined()
        }
        return String(text.prefix(2)).uppercased()
    }

    private var topTracks: [ChartEntry] {
        groupedEntries { item in
            (title: item.track, artist: item.artist, artworkResolution: item.artworkResolution)
        }
    }

    private var topAlbums: [ChartEntry] {
        groupedEntries { item in
            let title = item.album ?? AppLocalization.string("Unknown Album")
            return (title: title, artist: item.artist, artworkResolution: item.artworkResolution)
        }
    }

    private func groupedEntries(
        _ key: (CompatibilityRecentScrobble) -> (title: String, artist: String, artworkResolution: ArtworkResolution?)
    ) -> [ChartEntry] {
        var map: [String: ChartEntry] = [:]
        for item in scrobbleService.latestScrobbles {
            let parts = key(item)
            let id = "\(parts.artist)|\(parts.title)"
            if var existing = map[id] {
                existing.count += 1
                if existing.artworkResolution?.automaticArtworkResolution == nil {
                    existing.artworkResolution = parts.artworkResolution?.automaticArtworkResolution
                }
                map[id] = existing
            } else {
                map[id] = ChartEntry(
                    id: id,
                    title: parts.title,
                    artist: parts.artist,
                    artworkResolution: parts.artworkResolution?.automaticArtworkResolution,
                    count: 1
                )
            }
        }
        return map.values.sorted { $0.count > $1.count }
    }
}
