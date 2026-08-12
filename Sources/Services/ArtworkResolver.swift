import Foundation

/// A provider reference is accepted only when MusicBrainz has already linked
/// the resolved entity to the external service. The resolver never searches an
/// artist, track, or release by name.
struct ArtworkProviderReference: Equatable {
    let provider: ArtworkProvider
    let level: ArtworkLevel
    let sourceURL: URL

    static func correlated(url: URL, level: ArtworkLevel) -> ArtworkProviderReference? {
        let host = url.host?.lowercased() ?? ""
        if host == "deezer.com" || host.hasSuffix(".deezer.com") {
            return ArtworkProviderReference(provider: .deezer, level: level, sourceURL: url)
        }
        if host == "discogs.com" || host.hasSuffix(".discogs.com") {
            return ArtworkProviderReference(provider: .discogs, level: level, sourceURL: url)
        }
        return nil
    }
}

enum ArtworkTraceOutcome: String, Equatable {
    case candidate
    case cacheHit
    case notFound
    case rateLimited
    case failed
    case unsupported
}

struct ArtworkTraceEvent: Equatable {
    let provider: ArtworkProvider
    let level: ArtworkLevel
    let sourceURL: URL?
    let outcome: ArtworkTraceOutcome
}

struct ArtworkResolutionResult: Equatable {
    let selected: ArtworkResolution?
    let candidates: [ArtworkResolutionCandidate]
    let trace: [ArtworkTraceEvent]
}

/// Resolves artwork from services that can be queried anonymously. Provider
/// access is restricted to stable IDs carried by explicit MusicBrainz URL
/// relationships. There are deliberately no API-key, OAuth, or token hooks in
/// this type.
actor AnonymousArtworkResolver {
    private struct CacheEntry {
        let candidate: ArtworkResolutionCandidate?
        let expiresAt: Date
    }

    private enum FetchOutcome {
        case candidate(ArtworkResolutionCandidate)
        case notFound
        case rateLimited
        case failed
        case unsupported
    }

    private struct FetchResult {
        let outcome: FetchOutcome
        let fromCache: Bool
    }

    private let urlSession: URLSession
    private let deezerBaseURL: URL
    private let discogsBaseURL: URL
    private let now: () -> Date
    private var cache: [String: CacheEntry] = [:]
    private var inFlight: [String: Task<FetchOutcome, Never>] = [:]

    init(
        urlSession: URLSession = .shared,
        deezerBaseURL: URL = URL(string: "https://api.deezer.com")!,
        discogsBaseURL: URL = URL(string: "https://api.discogs.com")!,
        now: @escaping () -> Date = Date.init
    ) {
        self.urlSession = urlSession
        self.deezerBaseURL = deezerBaseURL
        self.discogsBaseURL = discogsBaseURL
        self.now = now
    }

    func resolve(
        primaryCandidates: [ArtworkResolutionCandidate],
        references: [ArtworkProviderReference],
        target: ArtworkLevel
    ) async -> ArtworkResolutionResult {
        var candidates = primaryCandidates.filter { $0.url.nilIfBlank != nil }
        var trace = candidates.map {
            ArtworkTraceEvent(
                provider: $0.provider,
                level: $0.level,
                sourceURL: $0.sourceURL.flatMap(URL.init(string:)),
                outcome: .candidate
            )
        }

        let levels: [ArtworkLevel] = target == .artist
            ? [.artist]
            : [.track, .album, .ep, .artist]
        let uniqueReferences = references.uniquedByResolutionIdentity()

        for level in levels {
            if let selected = candidates.first(where: { $0.level == level })?.resolution {
                return ArtworkResolutionResult(selected: selected, candidates: candidates, trace: trace)
            }

            let matchingReferences = uniqueReferences
                .filter { $0.level == level }
                .sorted { providerPriority($0.provider) < providerPriority($1.provider) }

            for reference in matchingReferences {
                let fetched = await candidate(for: reference)
                let outcome: ArtworkTraceOutcome
                switch fetched.outcome {
                case let .candidate(candidate):
                    outcome = fetched.fromCache ? .cacheHit : .candidate
                    if !candidates.contains(where: { normalizedURL($0.url) == normalizedURL(candidate.url) }) {
                        candidates.append(candidate)
                    }
                case .notFound:
                    outcome = fetched.fromCache ? .cacheHit : .notFound
                case .rateLimited:
                    outcome = .rateLimited
                case .failed:
                    outcome = .failed
                case .unsupported:
                    outcome = .unsupported
                }
                trace.append(ArtworkTraceEvent(
                    provider: reference.provider,
                    level: reference.level,
                    sourceURL: reference.sourceURL,
                    outcome: outcome
                ))

                if let selected = candidates.first(where: { $0.level == level })?.resolution {
                    return ArtworkResolutionResult(selected: selected, candidates: candidates, trace: trace)
                }
            }
        }

        return ArtworkResolutionResult(selected: nil, candidates: candidates, trace: trace)
    }

    private func candidate(for reference: ArtworkProviderReference) async -> FetchResult {
        guard let endpoint = endpoint(for: reference) else {
            return FetchResult(outcome: .unsupported, fromCache: false)
        }
        let key = "\(reference.provider.rawValue)|\(reference.level.rawValue)|\(endpoint.absoluteString)"
        let currentTime = now()
        if let cached = cache[key], cached.expiresAt > currentTime {
            if let candidate = cached.candidate {
                return FetchResult(outcome: .candidate(candidate), fromCache: true)
            }
            return FetchResult(outcome: .notFound, fromCache: true)
        }

        if let task = inFlight[key] {
            return FetchResult(outcome: await task.value, fromCache: true)
        }

        let task = Task<FetchOutcome, Never> { [urlSession] in
            await Self.fetch(
                reference: reference,
                endpoint: endpoint,
                urlSession: urlSession
            )
        }
        inFlight[key] = task
        let outcome = await task.value
        inFlight[key] = nil

        switch outcome {
        case let .candidate(candidate):
            cache[key] = CacheEntry(candidate: candidate, expiresAt: currentTime.addingTimeInterval(86_400))
        case .notFound:
            cache[key] = CacheEntry(candidate: nil, expiresAt: currentTime.addingTimeInterval(3_600))
        case .rateLimited, .failed, .unsupported:
            break
        }
        return FetchResult(outcome: outcome, fromCache: false)
    }

    private func endpoint(for reference: ArtworkProviderReference) -> URL? {
        let components = reference.sourceURL.pathComponents.filter { $0 != "/" }
        switch reference.provider {
        case .deezer:
            guard let entity = components.first(where: { ["artist", "album", "track"].contains($0.lowercased()) }),
                  let entityIndex = components.firstIndex(of: entity),
                  components.indices.contains(entityIndex + 1),
                  let identifier = components[entityIndex + 1].split(separator: "-").first,
                  identifier.allSatisfy(\.isNumber) else { return nil }
            return deezerBaseURL
                .appendingPathComponent(entity.lowercased())
                .appendingPathComponent(String(identifier))
        case .discogs:
            guard let entity = components.first(where: { ["artist", "release", "master"].contains($0.lowercased()) }),
                  let entityIndex = components.firstIndex(of: entity),
                  components.indices.contains(entityIndex + 1),
                  let identifier = components[entityIndex + 1].split(separator: "-").first,
                  identifier.allSatisfy(\.isNumber) else { return nil }
            let apiEntity: String
            switch entity.lowercased() {
            case "artist": apiEntity = "artists"
            case "release": apiEntity = "releases"
            default: apiEntity = "masters"
            }
            return discogsBaseURL
                .appendingPathComponent(apiEntity)
                .appendingPathComponent(String(identifier))
        default:
            return nil
        }
    }

    private static func fetch(
        reference: ArtworkProviderReference,
        endpoint: URL,
        urlSession: URLSession
    ) async -> FetchOutcome {
        var request = URLRequest(url: endpoint)
        request.setValue(
            "ListenScrobbler/1.1 (+https://github.com/kubrick06010/ListenScrobbler)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await urlSession.data(for: request)
            guard let http = response as? HTTPURLResponse else { return .failed }
            switch http.statusCode {
            case 200..<300:
                break
            case 404:
                return .notFound
            case 429:
                return .rateLimited
            default:
                return .failed
            }

            let imageURL: String?
            switch reference.provider {
            case .deezer:
                imageURL = deezerImageURL(data: data, endpoint: endpoint)
            case .discogs:
                imageURL = discogsImageURL(data: data)
            default:
                return .unsupported
            }
            guard let imageURL = imageURL?.nilIfBlank else { return .notFound }
            return .candidate(ArtworkResolutionCandidate(
                url: secureArtworkURL(imageURL),
                level: reference.level,
                provider: reference.provider,
                sourceURL: reference.sourceURL.absoluteString
            ))
        } catch {
            return .failed
        }
    }

    private static func deezerImageURL(data: Data, endpoint: URL) -> String? {
        if endpoint.pathComponents.contains("artist"),
           let response = try? JSONDecoder().decode(DeezerArtistArtworkResponse.self, from: data) {
            return response.pictureXL ?? response.pictureBig ?? response.pictureMedium ?? response.picture
        }
        if endpoint.pathComponents.contains("album"),
           let response = try? JSONDecoder().decode(DeezerAlbumArtworkResponse.self, from: data) {
            return response.coverXL ?? response.coverBig ?? response.coverMedium ?? response.cover
        }
        if endpoint.pathComponents.contains("track"),
           let response = try? JSONDecoder().decode(DeezerTrackArtworkResponse.self, from: data) {
            return response.album?.coverXL
                ?? response.album?.coverBig
                ?? response.album?.coverMedium
                ?? response.album?.cover
        }
        return nil
    }

    private static func discogsImageURL(data: Data) -> String? {
        guard let response = try? JSONDecoder().decode(DiscogsArtworkResponse.self, from: data) else {
            return nil
        }
        let image = response.images?.first(where: { $0.type?.lowercased() == "primary" })
            ?? response.images?.first
        return image?.uri ?? image?.resourceURL ?? image?.uri150
    }

    private static func secureArtworkURL(_ value: String) -> String {
        guard var components = URLComponents(string: value),
              components.scheme?.lowercased() == "http" else { return value }
        components.scheme = "https"
        return components.url?.absoluteString ?? value
    }

    private func providerPriority(_ provider: ArtworkProvider) -> Int {
        switch provider {
        case .deezer: return 0
        case .discogs: return 1
        default: return 2
        }
    }

    private func normalizedURL(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private struct DeezerArtistArtworkResponse: Decodable {
    let picture: String?
    let pictureMedium: String?
    let pictureBig: String?
    let pictureXL: String?

    enum CodingKeys: String, CodingKey {
        case picture
        case pictureMedium = "picture_medium"
        case pictureBig = "picture_big"
        case pictureXL = "picture_xl"
    }
}

private struct DeezerAlbumArtworkResponse: Decodable {
    let cover: String?
    let coverMedium: String?
    let coverBig: String?
    let coverXL: String?

    enum CodingKeys: String, CodingKey {
        case cover
        case coverMedium = "cover_medium"
        case coverBig = "cover_big"
        case coverXL = "cover_xl"
    }
}

private struct DeezerTrackArtworkResponse: Decodable {
    let album: DeezerAlbumArtworkResponse?
}

private struct DiscogsArtworkResponse: Decodable {
    let images: [DiscogsArtworkImage]?
}

private struct DiscogsArtworkImage: Decodable {
    let type: String?
    let uri: String?
    let resourceURL: String?
    let uri150: String?

    enum CodingKeys: String, CodingKey {
        case type, uri, uri150
        case resourceURL = "resource_url"
    }
}

private extension Array where Element == ArtworkProviderReference {
    func uniquedByResolutionIdentity() -> [ArtworkProviderReference] {
        var seen = Set<String>()
        return filter {
            seen.insert("\($0.provider.rawValue)|\($0.level.rawValue)|\($0.sourceURL.absoluteString)").inserted
        }
    }
}
