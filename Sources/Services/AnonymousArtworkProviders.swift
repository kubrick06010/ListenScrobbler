import Foundation

/// Read-only providers that can be used by a distributed build without
/// shipping a secret. IDs must come from an explicit MusicBrainz URL relation;
/// these clients deliberately do not perform name searches.
struct AnonymousArtworkCandidate: Equatable {
    let url: String
    let level: ArtworkLevel
    let provider: ArtworkProvider
}

enum AnonymousArtworkProviders {
    static func candidates(
        artistRelations: [MusicBrainzRelation],
        recordingRelations: [MusicBrainzRelation],
        releaseRelations: [MusicBrainzRelation],
        urlSession: URLSession
    ) async -> [AnonymousArtworkCandidate] {
        var candidates: [AnonymousArtworkCandidate] = []

        if let deezerArtistID = relationID(kind: "deezer", relations: artistRelations),
           let image = await DeezerArtworkClient.artistImage(id: deezerArtistID, session: urlSession) {
            candidates.append(.init(url: image, level: .artist, provider: .deezer))
        }
        if let discogsArtistID = relationID(kind: "discogs", relations: artistRelations),
           let image = await DiscogsArtworkClient.artistImage(id: discogsArtistID, session: urlSession) {
            candidates.append(.init(url: image, level: .artist, provider: .discogs))
        }

        if let deezerTrackID = relationID(kind: "deezer", relations: recordingRelations),
           let image = await DeezerArtworkClient.trackImage(id: deezerTrackID, session: urlSession) {
            candidates.append(.init(url: image, level: .track, provider: .deezer))
        }
        if let discogsTrackID = relationID(kind: "discogs", relations: recordingRelations),
           let image = await DiscogsArtworkClient.releaseImage(id: discogsTrackID, session: urlSession) {
            candidates.append(.init(url: image, level: .track, provider: .discogs))
        }

        if let deezerAlbumID = relationID(kind: "deezer", relations: releaseRelations),
           let image = await DeezerArtworkClient.albumImage(id: deezerAlbumID, session: urlSession) {
            candidates.append(.init(url: image, level: .album, provider: .deezer))
        }
        if let discogsReleaseID = relationID(kind: "discogs", relations: releaseRelations),
           let image = await DiscogsArtworkClient.releaseImage(id: discogsReleaseID, session: urlSession) {
            candidates.append(.init(url: image, level: .album, provider: .discogs))
        }
        return candidates
    }

    private static func relationID(kind: String, relations: [MusicBrainzRelation]) -> String? {
        relations.lazy
            .filter { relation in
                let resource = relation.url?.resource.lowercased() ?? ""
                if kind == "deezer" {
                    return resource.contains("deezer.com/")
                }
                return relation.type?.lowercased() == kind || resource.contains("discogs.com/")
            }
            .compactMap { $0.url?.resource }
            .compactMap { URL(string: $0) }
            .compactMap { url in
                return url.pathComponents.reversed()
                    .compactMap { $0.split(separator: "-").first.map(String.init) }
                    .first(where: { $0.allSatisfy(\.isNumber) })
            }
            .first(where: { !$0.isEmpty })
    }
}

private enum AnonymousArtworkHTTP {
    static func json(url: URL, session: URLSession) async -> [String: Any]? {
        var request = URLRequest(url: url)
        request.setValue("ListenScrobbler/0.1.0 (https://github.com/kubrick06010/ListenScrobbler)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func string(_ value: Any?) -> String? {
        (value as? String)?.nilIfBlank
    }
}

private enum DeezerArtworkClient {
    static func artistImage(id: String, session: URLSession) async -> String? {
        await image(path: "artist/\(id)", key: "picture_xl", session: session)
    }

    static func albumImage(id: String, session: URLSession) async -> String? {
        await image(path: "album/\(id)", key: "cover_xl", session: session)
    }

    static func trackImage(id: String, session: URLSession) async -> String? {
        guard let payload = await AnonymousArtworkHTTP.json(
            url: URL(string: "https://api.deezer.com/track/\(id)")!, session: session),
              let album = payload["album"] as? [String: Any] else { return nil }
        return AnonymousArtworkHTTP.string(album["cover_xl"])
    }

    private static func image(path: String, key: String, session: URLSession) async -> String? {
        guard let payload = await AnonymousArtworkHTTP.json(
            url: URL(string: "https://api.deezer.com/\(path)")!, session: session) else { return nil }
        return AnonymousArtworkHTTP.string(payload[key])
    }
}

private enum DiscogsArtworkClient {
    static func artistImage(id: String, session: URLSession) async -> String? {
        guard let payload = await AnonymousArtworkHTTP.json(
            url: URL(string: "https://api.discogs.com/artists/\(id)")!, session: session),
              let images = payload["images"] as? [[String: Any]] else { return nil }
        return images.first(where: { AnonymousArtworkHTTP.string($0["type"]) == "primary" })
            .flatMap { AnonymousArtworkHTTP.string($0["uri"]) }
            ?? images.first.flatMap { AnonymousArtworkHTTP.string($0["uri"]) }
    }

    static func releaseImage(id: String, session: URLSession) async -> String? {
        guard let payload = await AnonymousArtworkHTTP.json(
            url: URL(string: "https://api.discogs.com/releases/\(id)")!, session: session),
              let images = payload["images"] as? [[String: Any]] else { return nil }
        return images.first(where: { AnonymousArtworkHTTP.string($0["type"]) == "primary" })
            .flatMap { AnonymousArtworkHTTP.string($0["uri"]) }
            ?? images.first.flatMap { AnonymousArtworkHTTP.string($0["uri"]) }
    }
}
