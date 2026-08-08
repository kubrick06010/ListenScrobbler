import SwiftUI

struct ArtistExperienceData: Identifiable {
    let artist: CompatibilityArtistDetails?
    let openDetails: OpenMusicEntityDetails?
    let enrichment: OpenListeningEnrichment?

    var id: String { openDetails?.artistMBID ?? name }
    var name: String { openDetails?.artistName.nilIfBlank ?? artist?.name.nilIfBlank ?? String(localized: "Unknown artist") }
    var imageURL: String? { openDetails?.artistImageURL?.nilIfBlank ?? artist?.imageURL?.nilIfBlank }
    var summary: String? {
        if let localizedOpenSummary = openDetails?.artistSummaryForPreferredAppLanguage {
            return localizedOpenSummary
        }
        if preferredAppLanguageCode() == "en" {
            return artist?.summary?.nilIfBlank
        }
        return localizedMetadataSummary
    }
    var summaryURL: URL? { openDetails?.artistSummaryURL }
    var userListenCount: Int? { enrichment?.userArtistListenCount ?? artist?.userPlaycount }
    var globalListenCount: Int? { enrichment?.globalArtistListenCount ?? artist?.playcount }
    var globalListenerCount: Int? { enrichment?.globalArtistListenerCount ?? artist?.listeners }
    var tags: [String] {
        let weighted = enrichment?.artistProfile?.tags.map(\.name) ?? []
        return (weighted + (openDetails?.tags ?? []) + (artist?.tags ?? [])).uniquedCaseInsensitive()
    }
    var popularRecordings: [ListenBrainzPopularRecording] { enrichment?.topArtistRecordings ?? [] }
    var similarArtists: [ListenBrainzSimilarArtist] { enrichment?.similarArtists ?? [] }
    var compatibilitySimilarArtists: [CompatibilitySimilarArtist] { artist?.similarArtists ?? [] }
    var connections: [OpenMusicEntityDetails.ArtistConnection] { openDetails?.artistConnections ?? [] }

    var constellationNodes: [SimilarArtistGraphNode] {
        var output: [SimilarArtistGraphNode] = []
        var seenNames = Set<String>()

        func append(_ node: SimilarArtistGraphNode) {
            let key = normalizedName(node.name)
            guard !key.isEmpty, key != normalizedName(name), seenNames.insert(key).inserted else { return }
            output.append(node)
        }

        let musicalConnections = connections.filter { $0.relationship != "Alias" }
        for connection in musicalConnections.prefix(5) {
            append(.init(
                id: "connection-\(connection.id)",
                name: connection.name,
                value: 1,
                imageURL: nil,
                relationship: localizedRelationship(connection.relationship),
                kind: .connection
            ))
        }

        if !similarArtists.isEmpty {
            for related in similarArtists.prefix(8) {
                append(.init(
                    id: "listenbrainz-\(related.id)",
                    name: related.name,
                    value: Double(max(1, related.totalListenCount)),
                    imageURL: related.imageURL,
                    relationship: String(localized: "Similar on ListenBrainz"),
                    kind: .similarity
                ))
            }
        } else {
            for (index, related) in compatibilitySimilarArtists.prefix(8).enumerated() {
                append(.init(
                    id: "compatibility-\(related.id)",
                    name: related.name,
                    value: Double(max(1, compatibilitySimilarArtists.count - index)),
                    imageURL: related.imageURL,
                    relationship: String(localized: "Similar artist"),
                    kind: .similarity
                ))
            }
        }

        for connection in connections.filter({ $0.relationship == "Alias" }).prefix(4) {
            append(.init(
                id: "alias-\(connection.id)",
                name: connection.name,
                value: 1,
                imageURL: nil,
                relationship: String(localized: "Alias"),
                kind: .alias
            ))
        }

        return Array(output.prefix(12))
    }

    var lifeSpan: String? {
        let begin = year(openDetails?.artistBeginDate) ?? enrichment?.artistProfile?.beginYear.map(String.init)
        let end = year(openDetails?.artistEndDate)
        if let begin, let end { return "\(begin)–\(end)" }
        if let begin, openDetails?.artistEnded == false {
            return String.localizedStringWithFormat(String(localized: "Active since %@"), begin)
        }
        return begin
    }

    var location: String? {
        openDetails?.artistArea?.nilIfBlank
            ?? enrichment?.artistProfile?.area?.nilIfBlank
            ?? countryName(openDetails?.country)
    }

    var semanticType: String? {
        switch (enrichment?.artistProfile?.type ?? openDetails?.type)?.lowercased() {
        case "person": return String(localized: "Artist")
        case "group": return String(localized: "Group")
        case "orchestra": return String(localized: "Orchestra")
        case "choir": return String(localized: "Choir")
        case let value?: return value.capitalized
        case nil: return nil
        }
    }

    var links: [OpenMusicEntityDetails.Link] {
        var links = openDetails?.links ?? []
        for link in enrichment?.artistProfile?.links ?? [] where !links.contains(where: { $0.url == link.url }) {
            links.append(.init(id: "profile-\(link.id)", title: link.title, url: link.url))
        }
        if let summaryURL, !links.contains(where: { $0.url == summaryURL }) {
            links.append(.init(id: "artist-wikipedia", title: "Wikipedia", url: summaryURL))
        }
        return links
    }

    var hasDetailContent: Bool {
        summary != nil || userListenCount != nil || !popularRecordings.isEmpty || !constellationNodes.isEmpty || !links.isEmpty
    }

    private var localizedMetadataSummary: String? {
        var fragments: [String] = []
        if let semanticType {
            fragments.append(String.localizedStringWithFormat(String(localized: "%@ is listed as %@ in MusicBrainz"), name, semanticType.lowercased()))
        } else {
            fragments.append(String.localizedStringWithFormat(String(localized: "%@ is indexed in MusicBrainz"), name))
        }
        if let lifeSpan {
            fragments.append(lifeSpan)
        }
        if let location {
            fragments.append(String.localizedStringWithFormat(String(localized: "Area: %@"), location))
        }
        if !tags.isEmpty {
            fragments.append(String.localizedStringWithFormat(String(localized: "Tags: %@"), tags.prefix(5).joined(separator: ", ")))
        }
        return fragments.isEmpty ? nil : fragments.joined(separator: ". ") + "."
    }

    private func year(_ date: String?) -> String? {
        date?.prefix(4).allSatisfy(\.isNumber) == true ? String(date!.prefix(4)) : nil
    }

    private func countryName(_ code: String?) -> String? {
        guard let code = code?.nilIfBlank else { return nil }
        return preferredAppLocale().localizedString(forRegionCode: code) ?? code
    }

    private func normalizedName(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    func localizedRelationship(_ relationship: String) -> String {
        switch relationship.lowercased() {
        case "alias": return String(localized: "Alias")
        case "member": return String(localized: "Member")
        case "member of": return String(localized: "Member of")
        case "collaboration": return String(localized: "Collaboration")
        case "supporting musician": return String(localized: "Supporting musician")
        case "instrumental support": return String(localized: "Instrumental support")
        case "vocal support": return String(localized: "Vocal support")
        case "tribute": return String(localized: "Tribute")
        default: return relationship
        }
    }
}

struct ArtistSummaryCard: View {
    let data: ArtistExperienceData
    let compact: Bool
    let onShowArtist: () -> Void

    var body: some View {
        Group {
            if compact {
                compactLayout
            } else {
                wideLayout
            }
        }
        .padding(compact ? 16 : 20)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial)
                LinearGradient(
                    colors: [Color.accentColor.opacity(0.10), .clear, Color.blue.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.primary.opacity(0.10))
        }
    }

    private var wideLayout: some View {
        HStack(alignment: .top, spacing: 20) {
            profileColumn
                .frame(width: 236, alignment: .leading)
            if !data.constellationNodes.isEmpty {
                Divider().opacity(0.65)
                constellation
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var compactLayout: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                ArtistArtwork(url: data.imageURL, name: data.name, size: 98)
                identity
            }
            if let summary = data.summary {
                Text(summary)
                    .font(.custom("Avenir Next Regular", size: 14))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            relationshipAndTags
            if !data.constellationNodes.isEmpty {
                constellation
            }
            profileButton
        }
    }

    private var profileColumn: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("ARTIST PROFILE")
                .font(.custom("Avenir Next Demi Bold", size: 10))
                .tracking(1.4)
                .foregroundStyle(.secondary)
            ArtistArtwork(url: data.imageURL, name: data.name, size: 154)
            identity
            if let summary = data.summary {
                Text(summary)
                    .font(.custom("Avenir Next Regular", size: 13))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }
            relationshipAndTags
            profileButton
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var identity: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(data.name)
                .font(.custom("Avenir Next Demi Bold", size: compact ? 22 : 25))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)

            if !metadata.isEmpty {
                Text(metadata.joined(separator: " · "))
                    .font(.custom("Avenir Next Medium", size: 13))
                    .foregroundStyle(.secondary)
            }

            if let listens = data.userListenCount {
                Group {
                    if listens == 1 {
                        Label("1 listen in your library", systemImage: "waveform.badge.person.crop")
                    } else {
                        Label("\(AppLocalization.integer(listens)) listens in your library", systemImage: "waveform.badge.person.crop")
                    }
                }
                .font(.custom("Avenir Next Demi Bold", size: 12))
                .padding(.horizontal, 9)
                .padding(.vertical, 6)
                .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
        }
    }

    @ViewBuilder private var relationshipAndTags: some View {
        if !data.tags.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(Array(data.tags.prefix(compact ? 5 : 4)), id: \.self) { tag in
                    Text(tag)
                        .font(.custom("Avenir Next Medium", size: 10))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
            }
        }
    }

    private var profileButton: some View {
        Button(action: onShowArtist) {
            HStack(spacing: 7) {
                Text("Open artist profile")
                Image(systemName: "arrow.up.right")
            }
            .frame(maxWidth: compact ? nil : .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(!data.hasDetailContent)
        .keyboardShortcut(.return, modifiers: [.command, .shift])
        .help("Open biography, listening history, recordings and sources")
    }

    private var constellation: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Artist constellation")
                        .font(.custom("Avenir Next Demi Bold", size: compact ? 17 : 19))
                    Text("Similarity, groups, collaborations and aliases from open music data")
                        .font(.custom("Avenir Next Medium", size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if data.constellationNodes.count == 1 {
                    Text("1 connection")
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(data.constellationNodes.count) connections")
                        .font(.custom("Avenir Next Demi Bold", size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            SimilarArtistGraphView(
                centerName: data.name,
                centerImageURL: data.imageURL,
                nodes: data.constellationNodes,
                compact: compact
            )
            .frame(height: compact ? 330 : 390)
        }
    }

    private var metadata: [String] {
        [data.lifeSpan, data.location, data.semanticType].compactMap { $0 }
    }
}

struct ArtistDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    let data: ArtistExperienceData

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                hero
                listeningSection
                constellationSection
                if let summary = data.summary { biography(summary) }
                connectionsSection
                popularSection
                similarSection
                linksSection
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .frame(minWidth: 620, idealWidth: 780, minHeight: 560, idealHeight: 720)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .navigationTitle(data.name)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 22) {
            ArtistArtwork(url: data.imageURL, name: data.name, size: 180)
            VStack(alignment: .leading, spacing: 8) {
                Text(data.name)
                    .font(.custom("Avenir Next Demi Bold", size: 34))
                    .textSelection(.enabled)
                Text([data.lifeSpan, data.location, data.semanticType].compactMap { $0 }.joined(separator: " · "))
                    .font(.custom("Avenir Next Medium", size: 15))
                    .foregroundStyle(.secondary)
                if !data.tags.isEmpty {
                    Text(data.tags.prefix(8).joined(separator: " · "))
                        .font(.custom("Avenir Next Medium", size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }

    private func biography(_ summary: String) -> some View {
        section("About", systemImage: "text.quote") {
            Text(summary)
                .font(.custom("Avenir Next Regular", size: 15))
                .textSelection(.enabled)
            if let url = data.summaryURL {
                Button("Read on Wikipedia") { openURL(url) }
                    .buttonStyle(.link)
            }
        }
    }

    @ViewBuilder private var listeningSection: some View {
        let facts: [(String, Int?)] = [
            ("Your listens", data.userListenCount),
            ("Public listens", data.globalListenCount),
            ("Public listeners", data.globalListenerCount)
        ].filter { $0.1 != nil }
        if !facts.isEmpty {
            section("Your relationship", systemImage: "person.wave.2") {
                HStack(spacing: 28) {
                    ForEach(facts, id: \.0) { fact in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AppLocalization.integer(fact.1!)).font(.title2.bold())
                            Text(fact.0).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var popularSection: some View {
        if !data.popularRecordings.isEmpty {
            section("Popular recordings", systemImage: "music.note.list") {
                ForEach(data.popularRecordings.prefix(8)) { recording in
                    HStack(spacing: 12) {
                        ArtistArtwork(url: recording.imageURL, name: recording.title, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(recording.title).fontWeight(.semibold)
                            if let release = recording.releaseName {
                                Text(release).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let count = recording.totalListenCount {
                            Text("\(AppLocalization.integer(count)) listens").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder private var constellationSection: some View {
        if !data.constellationNodes.isEmpty {
            section("Artist constellation", systemImage: "point.3.connected.trianglepath.dotted") {
                Text("A combined view of ListenBrainz similarity and MusicBrainz relationships. Select a node to see why it is connected.")
                    .font(.custom("Avenir Next Medium", size: 12))
                    .foregroundStyle(.secondary)
                SimilarArtistGraphView(
                    centerName: data.name,
                    centerImageURL: data.imageURL,
                    nodes: data.constellationNodes,
                    compact: false
                )
                .frame(height: 440)
            }
        }
    }

    @ViewBuilder private var connectionsSection: some View {
        if !data.connections.isEmpty {
            section("Musical connections", systemImage: "person.3.sequence") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    ForEach(data.connections.filter { $0.relationship != "Alias" }) { connection in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(connection.name).fontWeight(.semibold)
                            Text(data.localizedRelationship(connection.relationship)).font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                let aliases = data.connections.filter { $0.relationship == "Alias" }
                if !aliases.isEmpty {
                    DisclosureGroup("Aliases (\(aliases.count))") {
                        FlowLayout(spacing: 8) {
                            ForEach(aliases) { connection in
                                Text(connection.name)
                                    .font(.custom("Avenir Next Medium", size: 12))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(.thinMaterial, in: Capsule())
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }

    @ViewBuilder private var similarSection: some View {
        if !data.similarArtists.isEmpty || !data.compatibilitySimilarArtists.isEmpty {
            section("Related artists", systemImage: "point.3.connected.trianglepath.dotted") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    if !data.similarArtists.isEmpty {
                        ForEach(data.similarArtists.prefix(8)) { artist in
                            relatedArtistRow(name: artist.name, imageURL: artist.imageURL)
                        }
                    } else {
                        ForEach(data.compatibilitySimilarArtists.prefix(8)) { artist in
                            relatedArtistRow(name: artist.name, imageURL: artist.imageURL)
                        }
                    }
                }
            }
        }
    }

    private func relatedArtistRow(name: String, imageURL: String?) -> some View {
        HStack(spacing: 10) {
            ArtistArtwork(url: imageURL, name: name, size: 42)
            Text(name).fontWeight(.medium).lineLimit(2)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var linksSection: some View {
        let links = preferredLinks
        if !links.isEmpty {
            section("Explore elsewhere", systemImage: "arrow.up.right.square") {
                FlowLayout(spacing: 8) {
                    ForEach(links) { link in
                        Button(link.title) { openURL(link.url) }
                            .buttonStyle(.bordered)
                    }
                }
            }
        }
    }

    private var preferredLinks: [OpenMusicEntityDetails.Link] {
        let order = ["Official website", "Wikipedia", "MusicBrainz Artist", "Discogs", "AllMusic", "Listen", "Last.fm"]
        return data.links.sorted {
            (order.firstIndex(of: $0.title) ?? order.count) < (order.firstIndex(of: $1.title) ?? order.count)
        }.prefix(8).map { $0 }
    }

    private func section<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage).font(.title3.bold())
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ArtistArtwork: View {
    let url: String?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityLabel("Artwork for \(name)")
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "person.crop.square")
                .font(.system(size: size * 0.32, weight: .light))
                .foregroundStyle(.secondary)
        }
    }
}
