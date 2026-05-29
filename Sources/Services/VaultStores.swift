import Foundation

enum VaultStoreError: LocalizedError, Equatable {
    case unsupportedSchema
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema:
            return "This vault file is not supported by this version of OpenScrobbler."
        case .encodingFailed:
            return "The vault file could not be encoded."
        }
    }
}

final class VaultFileStore {
    private let fileManager: FileManager
    private let appSupportRoot: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default, appSupportRoot: URL? = nil) {
        self.fileManager = fileManager
        self.appSupportRoot = appSupportRoot
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    func accountDirectory(username: String) -> URL {
        let appSupport = appSupportRoot ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let safeUsername = username
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "/", with: "_")
            .nilIfBlank ?? "local"
        return appSupport
            .appendingPathComponent("OpenScrobbler", isDirectory: true)
            .appendingPathComponent("Vault", isDirectory: true)
            .appendingPathComponent(safeUsername, isDirectory: true)
    }

    func load<T: Decodable>(_ type: T.Type, from url: URL, fallback: T) -> T {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? decoder.decode(type, from: data) else {
            return fallback
        }
        return decoded
    }

    func save<T: Encodable>(_ value: T, to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }

    func readBundle<T: Decodable>(_ type: T.Type, from url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try decoder.decode(type, from: data)
    }

    func writeBundle<T: Encodable>(_ bundle: T, to url: URL) throws {
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    func encodedBundleData<T: Encodable>(_ bundle: T) throws -> Data {
        try encoder.encode(bundle)
    }
}

@MainActor
final class SharedMusicVaultStore: ObservableObject {
    // Vaults are local-first by design. They preserve enough MusicBrainz/JSPF
    // metadata that archived shares can later become portable playlists or
    // imported records without depending on a single social provider.
    @Published private(set) var entries: [SharedMusicEntry] = []
    @Published private(set) var status = "Shared vault ready."

    private let files: VaultFileStore
    private var username: String

    init(username: String = "local", files: VaultFileStore = VaultFileStore()) {
        self.username = username.nilIfBlank ?? "local"
        self.files = files
        reload()
    }

    func configure(username: String?) {
        let resolved = username?.nilIfBlank ?? "local"
        guard resolved.caseInsensitiveCompare(self.username) != .orderedSame else { return }
        self.username = resolved
        reload()
    }

    func add(_ entry: SharedMusicEntry) {
        entries.insert(entry, at: 0)
        persist("Archived share.")
    }

    func delete(_ entry: SharedMusicEntry) {
        entries.removeAll { $0.id == entry.id }
        persist("Deleted share.")
    }

    func export(to url: URL) throws {
        let bundle = SharedMusicVaultBundle(ownerUsername: username, records: entries)
        try files.writeBundle(bundle, to: url)
        status = "Exported \(entries.count) shared entries."
    }

    func exportJSPF(to url: URL, title: String? = nil) throws {
        let bundle = makeJSPFBundle(title: title)
        try files.writeBundle(bundle, to: url)
        status = "Exported \(bundle.playlist.track.count) JSPF tracks."
    }

    func importBundle(from url: URL) throws {
        let bundle = try files.readBundle(SharedMusicVaultBundle.self, from: url)
        guard [SharedMusicVaultBundle.schemaName, SharedMusicVaultBundle.legacySchemaName].contains(bundle.schema),
              bundle.schemaVersion == 1 else {
            throw VaultStoreError.unsupportedSchema
        }
        let imported = bundle.records.map { record in
            var copy = record
            copy.id = UUID()
            copy.ownerUsername = username
            copy.direction = .imported
            copy.source = .fileImport
            copy.receivedAt = copy.receivedAt ?? Date()
            if copy.sender == nil {
                copy.sender = bundle.ownerUsername
            }
            return copy
        }
        merge(imported)
        persist("Imported \(imported.count) shared entries.")
    }

    func importJSPF(from url: URL) throws {
        let bundle = try files.readBundle(OpenPlaylistBundle.self, from: url)
        let imported = bundle.playlist.track.compactMap { track -> SharedMusicEntry? in
            // JSPF extension payloads carry MusicBrainz IDs without making the
            // playlist unreadable to other tools. Keep this path permissive so
            // community-exported playlists can round-trip through the vault.
            let mbids = track.extension?["https://musicbrainz.org/doc/jspf#track"]
            let artistName = track.creator?.nilIfBlank ?? "Unknown artist"
            let trackTitle = track.title?.nilIfBlank ?? "Unknown track"
            return SharedMusicEntry(
                id: UUID(),
                ownerUsername: username,
                direction: .imported,
                source: .fileImport,
                entityKind: .track,
                artist: artistName,
                track: trackTitle,
                album: track.album?.nilIfBlank,
                recipients: [],
                sender: bundle.playlist.creator.nilIfBlank,
                message: track.annotation?.nilIfBlank ?? bundle.playlist.annotation?.nilIfBlank,
                isPublic: bundle.playlist.extension?["https://musicbrainz.org/doc/jspf#playlist"]?.publicFlag ?? false,
                compatibilityURL: track.identifier?.nilIfBlank,
                musicBrainzArtistID: mbids?.artistMbid?.nilIfBlank,
                musicBrainzRecordingID: mbids?.recordingMbid?.nilIfBlank ?? musicBrainzRecordingID(from: track.identifier),
                musicBrainzReleaseID: mbids?.releaseMbid?.nilIfBlank,
                imageURL: track.image?.nilIfBlank,
                createdAt: bundle.playlist.date,
                sentAt: nil,
                receivedAt: Date(),
                apiStatus: "Imported from JSPF"
            )
        }
        merge(imported)
        persist("Imported \(imported.count) JSPF entries.")
    }

    func makeEntry(
        kind: SharedMusicEntry.EntityKind,
        direction: SharedMusicEntry.Direction,
        artist: String,
        track: String?,
        album: String?,
        recipients: [String],
        sender: String?,
        message: String?,
        isPublic: Bool,
        sourceURL: String? = nil,
        imageURL: String? = nil,
        artistMBID: String? = nil,
        recordingMBID: String? = nil,
        releaseMBID: String? = nil
    ) -> SharedMusicEntry {
        let now = Date()
        return SharedMusicEntry(
            id: UUID(),
            ownerUsername: username,
            direction: direction,
            source: .appLocal,
            entityKind: kind,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            track: track?.nilIfBlank,
            album: album?.nilIfBlank,
            recipients: recipients.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            sender: sender?.nilIfBlank,
            message: message?.nilIfBlank,
            isPublic: isPublic,
            compatibilityURL: sourceURL?.nilIfBlank,
            musicBrainzArtistID: artistMBID?.nilIfBlank,
            musicBrainzRecordingID: recordingMBID?.nilIfBlank,
            musicBrainzReleaseID: releaseMBID?.nilIfBlank,
            imageURL: imageURL?.nilIfBlank,
            createdAt: now,
            sentAt: direction == .sent ? now : nil,
            receivedAt: direction == .received ? now : nil,
            apiStatus: "Archived locally"
        )
    }

    private var fileURL: URL {
        files.accountDirectory(username: username).appendingPathComponent("shared-music.json")
    }

    private func reload() {
        entries = files.load([SharedMusicEntry].self, from: fileURL, fallback: [])
            .sorted { $0.createdAt > $1.createdAt }
        status = entries.isEmpty ? "No shared entries archived yet." : "Loaded \(entries.count) shared entries."
    }

    private func merge(_ imported: [SharedMusicEntry]) {
        let existingKeys = Set(entries.map(dedupeKey))
        let fresh = imported.filter { !existingKeys.contains(dedupeKey($0)) }
        entries = (fresh + entries).sorted { $0.createdAt > $1.createdAt }
    }

    private func dedupeKey(_ entry: SharedMusicEntry) -> String {
        [
            entry.entityKind.rawValue,
            entry.musicBrainzRecordingID?.lowercased() ?? "",
            entry.musicBrainzReleaseID?.lowercased() ?? "",
            entry.musicBrainzArtistID?.lowercased() ?? "",
            entry.artist.lowercased(),
            entry.track?.lowercased() ?? "",
            entry.album?.lowercased() ?? "",
            entry.message?.lowercased() ?? "",
            entry.sender?.lowercased() ?? "",
            entry.recipients.joined(separator: ",").lowercased()
        ].joined(separator: "|")
    }

    private func makeJSPFBundle(title: String?) -> OpenPlaylistBundle {
        let exportedTracks = entries
            .filter { $0.entityKind == .track }
            .map { entry in
                OpenPlaylistTrack(
                    identifier: trackIdentifier(for: entry),
                    title: entry.track?.nilIfBlank ?? entry.title,
                    creator: entry.artist.nilIfBlank,
                    album: entry.album?.nilIfBlank,
                    annotation: entry.message?.nilIfBlank,
                    image: entry.imageURL?.nilIfBlank,
                    duration: nil,
                    extension: [
                        "https://musicbrainz.org/doc/jspf#track": OpenPlaylistExtensionPayload(
                            artistMbid: entry.musicBrainzArtistID?.nilIfBlank,
                            recordingMbid: entry.musicBrainzRecordingID?.nilIfBlank,
                            releaseMbid: entry.musicBrainzReleaseID?.nilIfBlank,
                            publicFlag: nil
                        )
                    ]
                )
            }

        let resolvedTitle = title?.nilIfBlank ?? "OpenScrobbler Shared"
        return OpenPlaylistBundle(
            playlist: OpenPlaylistJSPF(
                title: resolvedTitle,
                creator: username,
                annotation: "Exported by OpenScrobbler",
                identifier: "openscrobbler:shared:\(username.lowercased())",
                date: Date(),
                track: exportedTracks,
                extension: [
                    "https://musicbrainz.org/doc/jspf#playlist": OpenPlaylistExtensionPayload(
                        artistMbid: nil,
                        recordingMbid: nil,
                        releaseMbid: nil,
                        publicFlag: false
                    )
                ]
            )
        )
    }

    private func trackIdentifier(for entry: SharedMusicEntry) -> String? {
        if let recordingMBID = entry.musicBrainzRecordingID?.nilIfBlank {
            return "https://musicbrainz.org/recording/\(recordingMBID)"
        }
        return entry.sourceURL?.nilIfBlank
    }

    private func musicBrainzRecordingID(from identifier: String?) -> String? {
        guard let identifier = identifier?.nilIfBlank else { return nil }
        guard let url = URL(string: identifier) else { return nil }
        guard url.host?.contains("musicbrainz.org") == true, url.path.contains("/recording/") else {
            return nil
        }
        return url.lastPathComponent.nilIfBlank
    }

    private func persist(_ successStatus: String) {
        do {
            try files.save(entries, to: fileURL)
            status = successStatus
        } catch {
            status = error.localizedDescription
        }
    }
}

@MainActor
final class ObsessionVaultStore: ObservableObject {
    @Published private(set) var entries: [ObsessionEntry] = []
    @Published private(set) var status = "Obsession vault ready."

    private let files: VaultFileStore
    private var username: String

    init(username: String = "local", files: VaultFileStore = VaultFileStore()) {
        self.username = username.nilIfBlank ?? "local"
        self.files = files
        reload()
    }

    func configure(username: String?) {
        let resolved = username?.nilIfBlank ?? "local"
        guard resolved.caseInsensitiveCompare(self.username) != .orderedSame else { return }
        self.username = resolved
        reload()
    }

    func add(_ entry: ObsessionEntry) {
        entries.insert(entry, at: 0)
        persist("Captured obsession.")
    }

    func delete(_ entry: ObsessionEntry) {
        entries.removeAll { $0.id == entry.id }
        persist("Deleted obsession.")
    }

    func export(to url: URL) throws {
        let bundle = ObsessionVaultBundle(ownerUsername: username, records: entries)
        try files.writeBundle(bundle, to: url)
        status = "Exported \(entries.count) obsession entries."
    }

    func importBundle(from url: URL) throws {
        let bundle = try files.readBundle(ObsessionVaultBundle.self, from: url)
        guard [ObsessionVaultBundle.schemaName, ObsessionVaultBundle.legacySchemaName].contains(bundle.schema),
              bundle.schemaVersion == 1 else {
            throw VaultStoreError.unsupportedSchema
        }
        let imported = bundle.records.map { record in
            var copy = record
            copy.id = UUID()
            copy.ownerUsername = username
            copy.source = .manualImport
            copy.firstSeenAt = copy.firstSeenAt
            return copy
        }
        merge(imported)
        persist("Imported \(imported.count) obsession entries.")
    }

    func makeEntry(
        artist: String,
        track: String,
        album: String?,
        note: String?,
        sourceURL: String? = nil,
        imageURL: String? = nil,
        artistMBID: String? = nil,
        recordingMBID: String? = nil,
        releaseMBID: String? = nil
    ) -> ObsessionEntry {
        let now = Date()
        return ObsessionEntry(
            id: UUID(),
            ownerUsername: username,
            artist: artist.trimmingCharacters(in: .whitespacesAndNewlines),
            track: track.trimmingCharacters(in: .whitespacesAndNewlines),
            album: album?.nilIfBlank,
            note: note?.nilIfBlank,
            imageURL: imageURL?.nilIfBlank,
            compatibilityURL: sourceURL?.nilIfBlank ?? fallbackTrackURL(artist: artist, track: track),
            musicBrainzArtistID: artistMBID?.nilIfBlank,
            musicBrainzRecordingID: recordingMBID?.nilIfBlank,
            musicBrainzReleaseID: releaseMBID?.nilIfBlank,
            firstSeenAt: now,
            setAt: now,
            endedAt: nil,
            rankMarker: nil,
            source: .userCaptured
        )
    }

    private var fileURL: URL {
        files.accountDirectory(username: username).appendingPathComponent("obsessions.json")
    }

    private func reload() {
        entries = files.load([ObsessionEntry].self, from: fileURL, fallback: [])
            .sorted { $0.firstSeenAt > $1.firstSeenAt }
        status = entries.isEmpty ? "No obsessions captured yet." : "Loaded \(entries.count) obsessions."
    }

    private func merge(_ imported: [ObsessionEntry]) {
        let existingKeys = Set(entries.map(dedupeKey))
        let fresh = imported.filter { !existingKeys.contains(dedupeKey($0)) }
        entries = (fresh + entries).sorted { $0.firstSeenAt > $1.firstSeenAt }
    }

    private func dedupeKey(_ entry: ObsessionEntry) -> String {
        [
            entry.musicBrainzRecordingID?.lowercased() ?? "",
            entry.artist.lowercased(),
            entry.track.lowercased(),
            entry.setAt.map { Calendar.current.startOfDay(for: $0).timeIntervalSince1970.description } ?? ""
        ].joined(separator: "|")
    }

    private func persist(_ successStatus: String) {
        do {
            try files.save(entries, to: fileURL)
            status = successStatus
        } catch {
            status = error.localizedDescription
        }
    }

    private func fallbackTrackURL(artist: String, track: String) -> String? {
        guard let encodedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let encodedTrack = track.trimmingCharacters(in: .whitespacesAndNewlines).addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              !encodedArtist.isEmpty,
              !encodedTrack.isEmpty else {
            return nil
        }
        return "https://listenbrainz.org/search/\(encodedArtist)%20\(encodedTrack)"
    }
}
