import Foundation

struct OpenMusicEntityDetails: Equatable {
    struct Link: Identifiable, Equatable {
        let id: String
        let title: String
        let url: URL
    }

    let trackName: String?
    let artistName: String
    let releaseName: String?
    let recordingMBID: String?
    let artistMBID: String?
    let releaseMBID: String?
    let imageURL: String?
    let artistImageURL: String?
    let artistSummary: String?
    let disambiguation: String?
    let country: String?
    let type: String?
    let tags: [String]
    let links: [Link]

    var hasResolvedMusicBrainzEntity: Bool {
        recordingMBID != nil || artistMBID != nil || releaseMBID != nil
    }
}

final class MusicBrainzService {
    // OpenScrobbler treats MusicBrainz as the identity layer and supplements it
    // with Cover Art Archive, Wikidata, and Wikipedia. If a future contributor
    // adds Discogs/AcousticBrainz/etc., prefer enriching this open entity value
    // rather than leaking more provider-specific models into SwiftUI.
    private let baseURL: URL
    private let coverArtBaseURL: URL
    private let urlSession: URLSession

    init(
        baseURL: URL = URL(string: "https://musicbrainz.org/ws/2")!,
        coverArtBaseURL: URL = URL(string: "https://coverartarchive.org/release")!,
        urlSession: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.coverArtBaseURL = coverArtBaseURL
        self.urlSession = urlSession
    }

    func lookup(track: String?, artist: String, release: String?) async throws -> OpenMusicEntityDetails {
        // Run broad searches in parallel, but keep partial data when one open
        // endpoint is slow or unavailable. A single Cover Art/MusicBrainz miss
        // should not blank the whole dashboard.
        async let recordingResult = searchRecordingResult(track: track, artist: artist, release: release)
        async let artistResult = optionalResult { try await searchArtist(name: artist) }
        async let releaseResult = searchReleaseResult(release: release, artist: artist)

        let broadRecording = try? await recordingResult.get()
        let resolvedArtist = try? await artistResult.get()
        let resolvedRelease = try? await releaseResult.get()
        let resolvedRecording = coherentRecording(broadRecording, requestedArtist: artist, resolvedArtist: resolvedArtist)
        let selectedRelease = bestRelease(
            from: resolvedRecording?.releases,
            fallback: resolvedRelease,
            requestedRelease: release
        )

        let recordingMBID = resolvedRecording?.id
        let recordingArtist = resolvedRecording?.artistCredit?.first?.artist
        let artistIdentity = await artistIdentity(recordingArtist: recordingArtist, searchedArtist: resolvedArtist)
        let artistMBID = artistIdentity?.id ?? recordingArtist?.id ?? resolvedArtist?.id
        let releaseMBID = selectedRelease?.id
        let releaseGroupMBID = selectedRelease?.releaseGroup?.id
        let resolvedReleaseName = release?.nilIfBlank ?? selectedRelease?.title
        let imageURL = await fetchBestCoverArt(releaseMBID: releaseMBID, releaseGroupMBID: releaseGroupMBID)
        let artistSupplement = await fetchArtistSupplement(from: artistIdentity)
        var resolvedTags: [MusicBrainzTag] = []
        if let recordingTags = resolvedRecording?.tags {
            resolvedTags.append(contentsOf: recordingTags)
        }
        if let artistTags = artistIdentity?.tags {
            resolvedTags.append(contentsOf: artistTags)
        }
        if let releaseTags = resolvedRelease?.tags {
            resolvedTags.append(contentsOf: releaseTags)
        }
        let tags = resolvedTags
            .sorted { $0.count > $1.count }
            .map(\.name)
            .uniqued()

        return OpenMusicEntityDetails(
            trackName: track?.nilIfBlank ?? resolvedRecording?.title,
            artistName: artistIdentity?.name ?? recordingArtist?.name ?? artist,
            releaseName: resolvedReleaseName,
            recordingMBID: recordingMBID,
            artistMBID: artistMBID,
            releaseMBID: releaseMBID,
            imageURL: imageURL,
            artistImageURL: artistSupplement.imageURL,
            artistSummary: artistSupplement.summary,
            disambiguation: resolvedRecording?.disambiguation?.nilIfBlank ?? artistIdentity?.disambiguation?.nilIfBlank,
            country: artistIdentity?.country?.nilIfBlank,
            type: artistIdentity?.type?.nilIfBlank ?? resolvedRelease?.status?.nilIfBlank,
            tags: Array(tags.prefix(12)),
            links: links(recordingMBID: recordingMBID, artistMBID: artistMBID, releaseMBID: releaseMBID)
        )
    }

    func fetchCoverArt(releaseMBID: String) async throws -> String? {
        let url = coverArtBaseURL.appendingPathComponent(releaseMBID)
        return try await fetchCoverArt(url: url)
    }

    private func fetchReleaseGroupCoverArt(releaseGroupMBID: String) async throws -> String? {
        let url = URL(string: "https://coverartarchive.org/release-group")!
            .appendingPathComponent(releaseGroupMBID)
        return try await fetchCoverArt(url: url)
    }

    private func fetchCoverArt(url: URL) async throws -> String? {
        var request = URLRequest(url: url)
        request.setValue("OpenScrobbler/0.1.0 ( https://github.com/openscrobbler )", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicBrainzError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicBrainzError.api(message: "Cover Art Archive returned HTTP \(http.statusCode).")
        }

        let responsePayload = try JSONDecoder().decode(CoverArtArchiveResponse.self, from: data)
        return bestCoverArtURL(from: responsePayload)
    }

    private func fetchBestCoverArt(releaseMBID: String?, releaseGroupMBID: String?) async -> String? {
        if let releaseMBID, let image = try? await fetchCoverArt(releaseMBID: releaseMBID) {
            return image
        }
        if let releaseGroupMBID, let image = try? await fetchReleaseGroupCoverArt(releaseGroupMBID: releaseGroupMBID) {
            return image
        }
        return nil
    }

    private func bestCoverArtURL(from response: CoverArtArchiveResponse) -> String? {
        let images = response.images.sorted { lhs, rhs in
            (lhs.front ?? false) && !(rhs.front ?? false)
        }
        for image in images {
            for key in ["1200", "large", "500", "250", "small"] {
                if let candidate = image.thumbnails?[key]?.nilIfBlank {
                    return candidate
                }
            }
            if let candidate = image.image?.nilIfBlank {
                return candidate
            }
        }
        return nil
    }

    private func searchRecording(title: String, artist: String, release: String?) async throws -> MusicBrainzRecording? {
        var firstCandidate: MusicBrainzRecording?
        for candidateTitle in recordingTitleCandidates(title) {
            let queries = recordingQueries(title: candidateTitle, artist: artist, release: release)
            for query in queries {
                let response: RecordingSearchResponse = try await search(
                    entity: "recording",
                    query: query,
                    includes: "artist-credits+releases+tags"
                )
                if firstCandidate == nil {
                    firstCandidate = response.recordings.first
                }
                if let recording = bestRecording(from: response.recordings, title: candidateTitle, artist: artist) {
                    return recording
                }
            }
        }
        return firstCandidate
    }

    private func searchArtist(name: String) async throws -> MusicBrainzArtist? {
        let response: ArtistSearchResponse = try await search(
            entity: "artist",
            query: "artist:\(quoted(name))",
            includes: "tags+url-rels"
        )
        return response.artists.first
    }

    func fetchArtistArtwork(artistMBID: String?, artistName: String?) async -> String? {
        let artist: MusicBrainzArtist?
        if let artistMBID = artistMBID?.nilIfBlank {
            artist = try? await lookupArtist(id: artistMBID)
        } else if let artistName = artistName?.nilIfBlank {
            artist = try? await searchArtist(name: artistName)
        } else {
            artist = nil
        }
        return await fetchArtistSupplement(from: artist).imageURL
    }

    private func lookupArtist(id: String) async throws -> MusicBrainzArtist {
        var components = URLComponents(
            url: baseURL.appendingPathComponent("artist").appendingPathComponent(id),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "inc", value: "tags+url-rels")
        ]
        guard let url = components?.url else { throw MusicBrainzError.invalidResponse }
        return try await fetchJSON(url: url)
    }

    private func artistIdentity(
        recordingArtist: MusicBrainzArtist?,
        searchedArtist: MusicBrainzArtist?
    ) async -> MusicBrainzArtist? {
        guard let recordingArtist else { return searchedArtist }
        guard recordingArtist.id != searchedArtist?.id else {
            return searchedArtist ?? recordingArtist
        }
        return (try? await lookupArtist(id: recordingArtist.id)) ?? recordingArtist
    }

    private func searchRelease(title: String, artist: String) async throws -> MusicBrainzRelease? {
        let response: ReleaseSearchResponse = try await search(
            entity: "release",
            query: "release:\(quoted(title)) AND artist:\(quoted(artist))",
            includes: "artist-credits+tags"
        )
        if let release = response.releases.first {
            return release
        }
        let fallbackResponse: ReleaseSearchResponse = try await search(
            entity: "release",
            query: "release:\(quoted(title))",
            includes: "artist-credits+tags"
        )
        return fallbackResponse.releases.first { normalized($0.title) == normalized(title) }
            ?? fallbackResponse.releases.first
    }

    private func search<T: Decodable>(entity: String, query: String, includes: String) async throws -> T {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(entity),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "5"),
            URLQueryItem(name: "inc", value: includes)
        ]
        guard let url = components?.url else { throw MusicBrainzError.invalidResponse }

        var request = URLRequest(url: url)
        request.setValue("OpenScrobbler/0.1.0 ( https://github.com/openscrobbler )", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicBrainzError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicBrainzError.api(message: "MusicBrainz returned HTTP \(http.statusCode).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchJSON<T: Decodable>(url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue("OpenScrobbler/0.1.0 ( https://github.com/openscrobbler )", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MusicBrainzError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MusicBrainzError.api(message: "Open metadata endpoint returned HTTP \(http.statusCode).")
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchArtistSupplement(from artist: MusicBrainzArtist?) async -> MusicBrainzArtistSupplement {
        // MusicBrainz does not host artist photos or prose. Wikidata relations
        // let us discover a Commons image and Wikipedia summary while staying in
        // the open-data ecosystem.
        guard let wikidataID = artist?.wikidataID else {
            return .empty
        }
        guard let entity = try? await fetchWikidataEntity(id: wikidataID) else {
            return .empty
        }

        async let summary = fetchWikipediaSummary(title: entity.englishWikipediaTitle)
        let imageURL = entity.imageFileName.flatMap(commonsImageURL(fileName:))
        return MusicBrainzArtistSupplement(
            imageURL: imageURL,
            summary: await summary?.nilIfBlank
        )
    }

    private func fetchWikidataEntity(id: String) async throws -> WikidataEntitySummary {
        let url = URL(string: "https://www.wikidata.org/wiki/Special:EntityData/\(id).json")!
        let response: WikidataEntityDataResponse = try await fetchJSON(url: url)
        guard let entity = response.entities[id] else {
            throw MusicBrainzError.invalidResponse
        }
        return WikidataEntitySummary(
            englishWikipediaTitle: entity.sitelinks?["enwiki"]?.title,
            imageFileName: entity.claims?["P18"]?.first?.mainsnak.datavalue?.value
        )
    }

    private func fetchWikipediaSummary(title: String?) async -> String? {
        guard let title = title?.nilIfBlank else { return nil }
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?")
        guard let encoded = title.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            return nil
        }
        let response: WikipediaSummaryResponse? = try? await fetchJSON(url: url)
        return response?.extract
    }

    private func commonsImageURL(fileName: String) -> String? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "#?")
        guard let encoded = fileName.addingPercentEncoding(withAllowedCharacters: allowed) else {
            return nil
        }
        return "https://commons.wikimedia.org/wiki/Special:FilePath/\(encoded)?width=640"
    }

    private func quoted(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: ""))\""
    }

    private func optionalResult<T>(_ operation: () async throws -> T?) async -> Result<T?, Error> {
        do {
            return .success(try await operation())
        } catch {
            return .failure(error)
        }
    }

    private func searchRecordingResult(
        track: String?,
        artist: String,
        release: String?
    ) async -> Result<MusicBrainzRecording?, Error> {
        guard let track else { return .success(nil) }
        return await optionalResult {
            try await searchRecording(title: track, artist: artist, release: release)
        }
    }

    private func searchReleaseResult(
        release: String?,
        artist: String
    ) async -> Result<MusicBrainzRelease?, Error> {
        guard let release else { return .success(nil) }
        return await optionalResult {
            try await searchRelease(title: release, artist: artist)
        }
    }

    private func coherentRecording(
        _ recording: MusicBrainzRecording?,
        requestedArtist: String,
        resolvedArtist: MusicBrainzArtist?
    ) -> MusicBrainzRecording? {
        guard let recording else { return nil }
        guard let resolvedArtist else { return recording }
        let recordingArtist = recording.artistCredit?.first?.artist
        if recordingArtist?.id == resolvedArtist.id {
            return recording
        }

        // MusicBrainz has many same-name artists. If the recording belongs to a
        // different MBID than the artist search selected, using its release/cover
        // produces misleading detail like the wrong album in the inspector.
        if normalized(recordingArtist?.name) == normalized(requestedArtist),
           normalized(resolvedArtist.name) == normalized(requestedArtist) {
            return nil
        }
        return recording
    }

    private func bestRelease(
        from releases: [MusicBrainzRelease]?,
        fallback: MusicBrainzRelease?,
        requestedRelease: String?
    ) -> MusicBrainzRelease? {
        let candidates = (releases ?? []) + [fallback].compactMap { $0 }
        guard !candidates.isEmpty else { return nil }
        if let requested = requestedRelease?.nilIfBlank,
           let exact = candidates.first(where: { normalized($0.title) == normalized(requested) }) {
            return exact
        }
        return candidates.first(where: { $0.coverArtArchive?.front == true }) ?? candidates.first
    }

    private func bestRecording(
        from recordings: [MusicBrainzRecording],
        title: String,
        artist: String
    ) -> MusicBrainzRecording? {
        let requestedTitle = normalized(title)
        let requestedArtist = normalized(artist)
        return recordings.first { recording in
            normalized(recording.title) == requestedTitle &&
                recording.artistCredit?.contains { normalized($0.artist.name) == requestedArtist } == true
        } ?? recordings.first { recording in
            recording.artistCredit?.contains { normalized($0.artist.name) == requestedArtist } == true
        }
    }

    private func recordingQueries(title: String, artist: String, release: String?) -> [String] {
        var queries: [String] = []
        if let release = release?.nilIfBlank {
            queries.append([
                "recording:\(quoted(title))",
                "artist:\(quoted(artist))",
                "release:\(quoted(release))"
            ].joined(separator: " AND "))
        }
        queries.append([
            "recording:\(quoted(title))",
            "artist:\(quoted(artist))"
        ].joined(separator: " AND "))
        return queries.uniqued()
    }

    private func recordingTitleCandidates(_ title: String) -> [String] {
        var candidates: [String] = []
        func append(_ candidate: String) {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            candidates.append(trimmed)
        }

        append(title)
        append(title.replacingOccurrences(
            of: #"\s*[\(\[\{][^\)\]\}]*[\)\]\}]"#,
            with: "",
            options: .regularExpression
        ))
        append(title.replacingOccurrences(
            of: #"\s[-–—]\s.*$"#,
            with: "",
            options: .regularExpression
        ))
        return candidates.uniqued()
    }

    private func normalized(_ value: String?) -> String {
        value?
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
    }

    private func links(recordingMBID: String?, artistMBID: String?, releaseMBID: String?) -> [OpenMusicEntityDetails.Link] {
        var output: [OpenMusicEntityDetails.Link] = []
        if let recordingMBID {
            output.append(.init(
                id: "recording-\(recordingMBID)",
                title: "MusicBrainz Recording",
                url: URL(string: "https://musicbrainz.org/recording/\(recordingMBID)")!
            ))
            output.append(.init(
                id: "listenbrainz-\(recordingMBID)",
                title: "ListenBrainz Recording",
                url: URL(string: "https://listenbrainz.org/player/?recording_mbids=\(recordingMBID)")!
            ))
        }
        if let artistMBID {
            output.append(.init(
                id: "artist-\(artistMBID)",
                title: "MusicBrainz Artist",
                url: URL(string: "https://musicbrainz.org/artist/\(artistMBID)")!
            ))
        }
        if let releaseMBID {
            output.append(.init(
                id: "release-\(releaseMBID)",
                title: "MusicBrainz Release",
                url: URL(string: "https://musicbrainz.org/release/\(releaseMBID)")!
            ))
        }
        return output
    }
}

enum MusicBrainzError: LocalizedError, Equatable {
    case invalidResponse
    case api(message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Unexpected response from MusicBrainz."
        case let .api(message):
            return message
        }
    }
}

private struct RecordingSearchResponse: Decodable {
    let recordings: [MusicBrainzRecording]
}

private struct ArtistSearchResponse: Decodable {
    let artists: [MusicBrainzArtist]
}

private struct ReleaseSearchResponse: Decodable {
    let releases: [MusicBrainzRelease]
}

private struct MusicBrainzRecording: Decodable {
    let id: String
    let title: String
    let disambiguation: String?
    let artistCredit: [MusicBrainzArtistCredit]?
    let releases: [MusicBrainzRelease]?
    let tags: [MusicBrainzTag]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case disambiguation
        case artistCredit = "artist-credit"
        case releases
        case tags
    }
}

private struct MusicBrainzArtistCredit: Decodable {
    let artist: MusicBrainzArtist
}

private struct MusicBrainzArtist: Decodable {
    let id: String
    let name: String
    let disambiguation: String?
    let country: String?
    let type: String?
    let tags: [MusicBrainzTag]?
    let relations: [MusicBrainzRelation]?

    var wikidataID: String? {
        relations?
            .lazy
            .filter { $0.type == "wikidata" }
            .compactMap { $0.url?.resource.wikidataEntityID }
            .first
    }
}

private struct MusicBrainzRelease: Decodable {
    let id: String
    let title: String
    let status: String?
    let tags: [MusicBrainzTag]?
    let releaseGroup: MusicBrainzReleaseGroup?
    let coverArtArchive: MusicBrainzCoverArtArchive?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case status
        case tags
        case releaseGroup = "release-group"
        case coverArtArchive = "cover-art-archive"
    }
}

private struct MusicBrainzReleaseGroup: Decodable {
    let id: String
}

private struct MusicBrainzCoverArtArchive: Decodable {
    let front: Bool?
}

private struct MusicBrainzTag: Decodable {
    let count: Int
    let name: String
}

private struct CoverArtArchiveResponse: Decodable {
    let images: [CoverArtArchiveImage]
}

private struct CoverArtArchiveImage: Decodable {
    let image: String?
    let front: Bool?
    let thumbnails: [String: String]?
}

private struct MusicBrainzRelation: Decodable {
    let type: String?
    let url: MusicBrainzRelationURL?
}

private struct MusicBrainzRelationURL: Decodable {
    let resource: String
}

private struct MusicBrainzArtistSupplement {
    let imageURL: String?
    let summary: String?

    static let empty = MusicBrainzArtistSupplement(imageURL: nil, summary: nil)
}

private struct WikidataEntitySummary {
    let englishWikipediaTitle: String?
    let imageFileName: String?
}

private struct WikidataEntityDataResponse: Decodable {
    let entities: [String: WikidataEntity]
}

private struct WikidataEntity: Decodable {
    let sitelinks: [String: WikidataSitelink]?
    let claims: [String: [WikidataClaim]]?
}

private struct WikidataSitelink: Decodable {
    let title: String
}

private struct WikidataClaim: Decodable {
    let mainsnak: WikidataMainSnak
}

private struct WikidataMainSnak: Decodable {
    let datavalue: WikidataDataValue?
}

private struct WikidataDataValue: Decodable {
    let value: String?

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        value = try? container.decode(String.self, forKey: .value)
    }

    private enum CodingKeys: String, CodingKey {
        case value
    }
}

private struct WikipediaSummaryResponse: Decodable {
    let extract: String?
}

private extension String {
    var wikidataEntityID: String? {
        guard let range = range(of: #"Q\d+"#, options: .regularExpression) else {
            return nil
        }
        return String(self[range])
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen = Set<String>()
        return filter { seen.insert($0.lowercased()).inserted }
    }
}
