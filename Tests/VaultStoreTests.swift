import XCTest
@testable import ListenScrobbler

@MainActor
final class VaultStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ListenScrobblerVaultTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRoot {
            try? FileManager.default.removeItem(at: tempRoot)
        }
    }

    func testSharedBundleExportImportMarksRecordsAsImported() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let sender = SharedMusicVaultStore(username: "sender", files: files)
        let receiver = SharedMusicVaultStore(username: "receiver", files: files)

        let entry = sender.makeEntry(
            kind: .track,
            direction: .sent,
            artist: "Cocteau Twins",
            track: "Cherry-coloured Funk",
            album: nil,
            recipients: ["receiver"],
            sender: nil,
            message: "A pendrive memory.",
            isPublic: false
        )
        sender.add(entry)

        let exportURL = tempRoot.appendingPathComponent("shared.json")
        try sender.export(to: exportURL)
        try receiver.importBundle(from: exportURL)

        XCTAssertEqual(receiver.entries.count, 1)
        XCTAssertEqual(receiver.entries[0].direction, .imported)
        XCTAssertEqual(receiver.entries[0].source, .fileImport)
        XCTAssertEqual(receiver.entries[0].sender, "sender")
        XCTAssertEqual(receiver.entries[0].track, "Cherry-coloured Funk")
    }

    func testObsessionBundleExportImportMarksRecordsAsManualImport() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let source = ObsessionVaultStore(username: "source", files: files)
        let target = ObsessionVaultStore(username: "target", files: files)

        let entry = source.makeEntry(
            artist: "Portishead",
            track: "The Rip",
            album: "Third",
            note: "The note survives the export.",
            recordingMBID: "recording-mbid-1"
        )
        source.add(entry)

        let exportURL = tempRoot.appendingPathComponent("obsessions.json")
        try source.export(to: exportURL)
        try target.importBundle(from: exportURL)

        XCTAssertEqual(target.entries.count, 1)
        XCTAssertEqual(target.entries[0].source, .manualImport)
        XCTAssertEqual(target.entries[0].artist, "Portishead")
        XCTAssertEqual(target.entries[0].track, "The Rip")
        XCTAssertEqual(target.entries[0].note, "The note survives the export.")
        XCTAssertEqual(target.entries[0].musicBrainzRecordingID, "recording-mbid-1")
    }

    func testSharedVaultExportsAndImportsJSPFWithMusicBrainzMetadata() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let source = SharedMusicVaultStore(username: "source", files: files)
        let target = SharedMusicVaultStore(username: "target", files: files)

        let entry = source.makeEntry(
            kind: .track,
            direction: .sent,
            artist: "Broadcast",
            track: "Tears in the Typing Pool",
            album: "Tender Buttons",
            recipients: ["target"],
            sender: nil,
            message: "For your twilight playlists.",
            isPublic: true,
            sourceURL: "https://musicbrainz.org/recording/mbid-1",
            imageURL: nil,
            artistMBID: "artist-mbid-1",
            recordingMBID: "mbid-1",
            releaseMBID: "release-mbid-1"
        )
        source.add(entry)

        let exportURL = tempRoot.appendingPathComponent("shared.jspf")
        try source.exportJSPF(to: exportURL, title: "Open Archive Mix")
        try target.importJSPF(from: exportURL)

        XCTAssertEqual(target.entries.count, 1)
        XCTAssertEqual(target.entries[0].track, "Tears in the Typing Pool")
        XCTAssertEqual(target.entries[0].musicBrainzRecordingID, "mbid-1")
        XCTAssertEqual(target.entries[0].musicBrainzArtistID, "artist-mbid-1")
        XCTAssertEqual(target.entries[0].musicBrainzReleaseID, "release-mbid-1")
        XCTAssertEqual(target.entries[0].sourceURL, "https://musicbrainz.org/recording/mbid-1")
        XCTAssertEqual(target.entries[0].apiStatus, "Imported from JSPF")
    }

    func testVaultRoundTripPreservesCentralArtworkResult() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let source = SharedMusicVaultStore(username: "source", files: files)
        let target = SharedMusicVaultStore(username: "target", files: files)
        let artwork = ArtworkResolution(
            url: "https://coverartarchive.org/release/release-1/front-500",
            level: .album,
            provider: .coverArtArchive
        )

        let entry = source.makeEntry(
            kind: .album,
            direction: .sent,
            artist: "Broadcast",
            track: nil,
            album: "Tender Buttons",
            recipients: ["target"],
            sender: nil,
            message: "Artwork provenance survives this archive.",
            isPublic: false,
            artworkResolution: artwork
        )
        source.add(entry)

        let exportURL = tempRoot.appendingPathComponent("artwork-shared.json")
        try source.export(to: exportURL)
        try target.importBundle(from: exportURL)

        XCTAssertEqual(target.entries.first?.artworkResolution, artwork)
        XCTAssertEqual(target.entries.first?.imageURL, artwork.url)
    }

    func testObsessionRoundTripPreservesTypedArtworkProvenance() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let source = ObsessionVaultStore(username: "source", files: files)
        let target = ObsessionVaultStore(username: "target", files: files)
        let artwork = ArtworkResolution(
            url: "https://commons.wikimedia.org/wiki/Special:FilePath/Artist.jpg",
            level: .artist,
            provider: .wikipediaWikidata,
            sourceURL: "https://en.wikipedia.org/wiki/Artist"
        )

        let entry = source.makeEntry(
            artist: "Artist",
            track: "Track",
            album: "Album",
            note: "Typed provenance survives.",
            artworkResolution: artwork
        )
        source.add(entry)

        let exportURL = tempRoot.appendingPathComponent("artwork-obsession.json")
        try source.export(to: exportURL)
        try target.importBundle(from: exportURL)

        XCTAssertEqual(target.entries.first?.artworkResolution, artwork)
        XCTAssertEqual(target.entries.first?.artworkResolution?.level, .artist)
        XCTAssertEqual(target.entries.first?.artworkResolution?.provider, .wikipediaWikidata)
        XCTAssertEqual(target.entries.first?.artworkResolution?.sourceURL, artwork.sourceURL)
    }

    func testVaultDoesNotPersistCredentialedArtworkAsAutomaticResult() throws {
        let files = VaultFileStore(appSupportRoot: tempRoot)
        let store = SharedMusicVaultStore(username: "source", files: files)
        let artwork = ArtworkResolution(
            url: "https://api.example.test/private-cover.jpg",
            level: .track,
            provider: .appleMusic
        )

        let entry = store.makeEntry(
            kind: .track,
            direction: .sent,
            artist: "Artist",
            track: "Track",
            album: "Album",
            recipients: ["friend"],
            sender: nil,
            message: "Do not persist credentialed provider data.",
            isPublic: false,
            artworkResolution: artwork
        )
        store.add(entry)

        XCTAssertNil(store.entries.first?.artworkResolution)
        let persistedURL = files.accountDirectory(username: "source").appendingPathComponent("shared-music.json")
        let persistedData = try Data(contentsOf: persistedURL)
        XCTAssertFalse(String(decoding: persistedData, as: UTF8.self).contains("private-cover.jpg"))
    }
}
