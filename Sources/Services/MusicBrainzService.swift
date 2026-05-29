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
        // Run broad searches in parallel; MusicBrainz data can be sparse, so the
        // result is assembled from the best recording, artist, and release match.
        async let recording = track.flatMap { title in
            Task { try await searchRecording(title: title, artist: artist, release: release) }
        }?.value
        async let artistMatch = searchArtist(name: artist)
        async let releaseMatch = release.flatMap { releaseName in
            Task { try await searchRelease(title: releaseName, artist: artist) }
        }?.value

        let resolvedRecording = try await recording
        let resolvedArtist = try await artistMatch
        let resolvedRelease = try await releaseMatch

        let recordingMBID = resolvedRecording?.id
        let artistMBID = resolvedRecording?.artistCredit?.first?.artist.id ?? resolvedArtist?.id
        let releaseMBID = resolvedRecording?.releases?.first?.id ?? resolvedRelease?.id
        let resolvedReleaseName = release?.nilIfBlank ?? resolvedRecording?.releases?.first?.title ?? resolvedRelease?.title
        let imageURL: String?
        if let releaseMBID {
            imageURL = try? await fetchCoverArt(releaseMBID: releaseMBID)
        } else {
            imageURL = nil
        }
        let artistSupplement = await fetchArtistSupplement(from: resolvedArtist)
        var resolvedTags: [MusicBrainzTag] = []
        if let recordingTags = resolvedRecording?.tags {
            resolvedTags.append(contentsOf: recordingTags)
        }
        if let artistTags = resolvedArtist?.tags {
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
            artistName: resolvedArtist?.name ?? resolvedRecording?.artistCredit?.first?.artist.name ?? artist,
            releaseName: resolvedReleaseName,
            recordingMBID: recordingMBID,
            artistMBID: artistMBID,
            releaseMBID: releaseMBID,
            imageURL: imageURL,
            artistImageURL: artistSupplement.imageURL,
            artistSummary: artistSupplement.summary,
            disambiguation: resolvedRecording?.disambiguation?.nilIfBlank ?? resolvedArtist?.disambiguation?.nilIfBlank,
            country: resolvedArtist?.country?.nilIfBlank,
            type: resolvedArtist?.type?.nilIfBlank ?? resolvedRelease?.status?.nilIfBlank,
            tags: Array(tags.prefix(12)),
            links: links(recordingMBID: recordingMBID, artistMBID: artistMBID, releaseMBID: releaseMBID)
        )
    }

    func fetchCoverArt(releaseMBID: String) async throws -> String? {
        let url = coverArtBaseURL.appendingPathComponent(releaseMBID)
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
        var terms = [
            "recording:\(quoted(title))",
            "artist:\(quoted(artist))"
        ]
        if let release = release?.nilIfBlank {
            terms.append("release:\(quoted(release))")
        }
        let response: RecordingSearchResponse = try await search(
            entity: "recording",
            query: terms.joined(separator: " AND "),
            includes: "artist-credits+releases+tags"
        )
        return response.recordings.first
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

    private func searchRelease(title: String, artist: String) async throws -> MusicBrainzRelease? {
        let response: ReleaseSearchResponse = try await search(
            entity: "release",
            query: "release:\(quoted(title)) AND artist:\(quoted(artist))",
            includes: "artist-credits+tags"
        )
        return response.releases.first
    }

    private func search<T: Decodable>(entity: String, query: String, includes: String) async throws -> T {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(entity),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "query", value: query),
            URLQueryItem(name: "fmt", value: "json"),
            URLQueryItem(name: "limit", value: "1"),
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
