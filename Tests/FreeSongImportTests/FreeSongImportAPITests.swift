import XCTest
@testable import FreeSongImport
@testable import FreeSongStorage

final class FreeSongImportAPITests: XCTestCase {

    var tmpDir: URL!
    var libraryRoot: URL!
    var fileRepo: FileSongRepository!
    var importer: FreeSongImport!

    override func setUp() async throws {
        try await super.setUp()
        tmpDir = try createTempDirectory()
        libraryRoot = tmpDir.appendingPathComponent("FreeSong", isDirectory: true)
        fileRepo = FileSongRepository(libraryRoot: libraryRoot)
        importer = FreeSongImport(
            fileRepository: fileRepo,
            setlistRepository: NullSetlistRepository()
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
        try await super.tearDown()
    }

    // MARK: - Validation

    func testValidateBackupValidFile() throws {
        let dbURL = tmpDir.appendingPathComponent("OnSong.sqlite3")
        try createOnSongTestDatabase(at: dbURL)

        let zipURL = tmpDir.appendingPathComponent("backup.zip")
        try createTestZip(at: zipURL, files: [
            ("OnSong.sqlite3", try Data(contentsOf: dbURL)),
            ("song.onsong", makeOnSongContent(title: "Test", body: "[C]Lyrics")),
        ])

        let validation = importer.validateBackup(at: zipURL)

        XCTAssertTrue(validation.isValid)
        XCTAssertTrue(validation.hasDatabase)
        XCTAssertGreaterThan(validation.songFileCount, 0)
        XCTAssertGreaterThan(validation.totalEntries, 0)
        XCTAssertTrue(validation.warnings.isEmpty)
    }

    func testValidateBackupInvalidFile() {
        let txtURL = tmpDir.appendingPathComponent("notes.txt")
        try? Data("not a zip".utf8).write(to: txtURL)

        let validation = importer.validateBackup(at: txtURL)

        XCTAssertFalse(validation.isValid)
        XCTAssertFalse(validation.hasDatabase)
        XCTAssertEqual(validation.songFileCount, 0)
        XCTAssertFalse(validation.warnings.isEmpty)
    }

    func testValidateBackupMissingFile() {
        let missingURL = tmpDir.appendingPathComponent("does_not_exist.zip")

        let validation = importer.validateBackup(at: missingURL)

        XCTAssertFalse(validation.isValid)
        XCTAssertEqual(validation.totalEntries, 0)
        XCTAssertFalse(validation.warnings.isEmpty)
    }

    func testValidateBackupNoDatabase() throws {
        let zipURL = tmpDir.appendingPathComponent("songs-only.zip")
        try createTestZip(at: zipURL, files: [
            ("song1.onsong", makeOnSongContent(title: "Song 1", body: "[C]One")),
            ("song2.onsong", makeOnSongContent(title: "Song 2", body: "[G]Two")),
        ])

        let validation = importer.validateBackup(at: zipURL)

        XCTAssertTrue(validation.isValid, "Song files without DB should still be valid")
        XCTAssertFalse(validation.hasDatabase)
        XCTAssertEqual(validation.songFileCount, 2)
    }

    func testValidateBackupEmptyArchive() throws {
        let zipURL = tmpDir.appendingPathComponent("empty.zip")
        var eocd = Data([0x50, 0x4B, 0x05, 0x06])
        eocd.append(Data(repeating: 0x00, count: 18))
        try eocd.write(to: zipURL)

        let validation = importer.validateBackup(at: zipURL)

        XCTAssertFalse(validation.isValid, "Empty archive should not be valid")
        XCTAssertEqual(validation.totalEntries, 0)
        XCTAssertFalse(validation.warnings.isEmpty)
    }

    // MARK: - Import with Progress

    func testImportBackupFiresProgressCallbacks() async throws {
        let dbURL = tmpDir.appendingPathComponent("OnSong.sqlite3")
        try createOnSongTestDatabase(at: dbURL)

        let zipURL = tmpDir.appendingPathComponent("backup.zip")
        try createTestZip(at: zipURL, files: [
            ("OnSong.sqlite3", try Data(contentsOf: dbURL)),
            ("loose.onsong", makeOnSongContent(title: "Loose Song", body: "[C]Test")),
        ])

        actor ProgressCollector {
            var events: [ImportProgress] = []
            func append(_ event: ImportProgress) { events.append(event) }
        }
        let collector = ProgressCollector()

        let progressHandler: BackupImporter.ProgressHandler = { event in
            Task { await collector.append(event) }
        }

        let result = await importer.importBackup(from: zipURL, progress: progressHandler)

        try await Task.sleep(nanoseconds: 100_000_000)
        let progressEvents = await collector.events

        // Basic validation
        XCTAssertFalse(progressEvents.isEmpty, "Should have at least one progress event")

        // First event should be openingArchive
        if case .openingArchive = progressEvents.first {
            // good
        } else {
            XCTFail("First progress event should be .openingArchive, got \(String(describing: progressEvents.first))")
        }

        // Last event should be completed
        if case .completed = progressEvents.last {
            // good
        } else {
            XCTFail("Last progress event should be .completed, got \(String(describing: progressEvents.last))")
        }

        // Should have extracting events
        let extractEvents = progressEvents.filter {
            if case .extractingEntries = $0 { return true }
            return false
        }
        XCTAssertFalse(extractEvents.isEmpty, "Should have extraction progress events")

        // Should have readingDatabase event
        let readingEvents = progressEvents.filter {
            if case .readingDatabase = $0 { return true }
            return false
        }
        XCTAssertFalse(readingEvents.isEmpty, "Should have readingDatabase progress event")

        // Should have completed with valid result
        if case .completed(let finalResult) = progressEvents.last {
            XCTAssertEqual(finalResult.importedFiles, result.importedFiles)
        }

        // Result should be valid
        XCTAssertEqual(result.importedFiles, 3, "1 loose + 2 DB songs")
    }

    func testImportSingleFileThroughAPI() async throws {
        let songData = makeOnSongContent(title: "Test Song", artist: "Artist", body: "Verse 1:\n[C]Test")
        let sourceURL = tmpDir.appendingPathComponent("test.onsong")
        try songData.write(to: sourceURL)

        let result = await importer.importSingleFile(from: sourceURL)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Imported successfully")

        let destURL = libraryRoot.appendingPathComponent("test.onsong")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
    }

    // MARK: - End-to-End Backup Import

    func testEndToEndBackupImportThroughAPI() async throws {
        // Create a realistic backup with database
        let dbURL = tmpDir.appendingPathComponent("OnSong.sqlite3")
        try createOnSongTestDatabase(at: dbURL)

        let zipURL = tmpDir.appendingPathComponent("backup.zip")
        try createTestZip(at: zipURL, files: [
            ("OnSong.sqlite3", try Data(contentsOf: dbURL)),
            ("loose.onsong", makeOnSongContent(title: "Loose Song", body: "Verse 1:\n[C]Test")),
        ])

        let result = await importer.importBackup(from: zipURL)

        // 1 loose file + 2 DB songs + 2 setlists
        XCTAssertGreaterThanOrEqual(result.totalFiles, 3)
        XCTAssertGreaterThanOrEqual(result.importedFiles, 3)
        XCTAssertEqual(result.errors.count, 0)

        // Verify files on disk
        let amazingURL = libraryRoot.appendingPathComponent("Amazing Grace-G.onsong")
        let howGreatURL = libraryRoot.appendingPathComponent("How Great Thou Art-C.onsong")
        let looseURL = libraryRoot.appendingPathComponent("loose.onsong")

        XCTAssertTrue(FileManager.default.fileExists(atPath: amazingURL.path), "Amazing Grace should be imported")
        XCTAssertTrue(FileManager.default.fileExists(atPath: howGreatURL.path), "How Great Thou Art should be imported")
        XCTAssertTrue(FileManager.default.fileExists(atPath: looseURL.path), "Loose song should be imported")

        // Verify content is structured FreeSong format (not raw OnSong)
        let amazingContent = try String(contentsOf: amazingURL, encoding: .utf8)
        XCTAssertTrue(amazingContent.contains("{title:"), "Should be structured FreeSong format")
        XCTAssertTrue(amazingContent.contains("Amazing Grace"), "Title should be present")

        let looseContent = try String(contentsOf: looseURL, encoding: .utf8)
        XCTAssertTrue(looseContent.contains("Loose Song") || looseContent.contains("{title:"),
                      "Content should be readable")
    }
}
