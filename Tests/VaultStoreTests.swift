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
}
