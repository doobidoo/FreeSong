import XCTest
@testable import FreeSongImport
@testable import FreeSongStorage

final class BackupImporterTests: XCTestCase {

    var tmpDir: URL!
    var libraryRoot: URL!
    var fileRepo: FileSongRepository!
    var backupImporter: BackupImporter!

    override func setUp() async throws {
        try await super.setUp()
        tmpDir = try createTempDirectory()
        libraryRoot = tmpDir.appendingPathComponent("FreeSong", isDirectory: true)

        // NullSetlistRepository avoids requiring a Core Data model in tests.
        let setlistRepo = NullSetlistRepository()
        fileRepo = FileSongRepository(libraryRoot: libraryRoot)
        backupImporter = BackupImporter(
            fileRepository: fileRepo,
            setlistRepository: setlistRepo
        )
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tmpDir)
        try await super.tearDown()
    }

    // MARK: - importSingleFile

    func testImportSingleFileOnSong() async throws {
        let songData = makeOnSongContent(title: "Amazing Grace", artist: "John Newton", body: "Verse 1:\n[G]Amazing [D]grace")
        let sourceURL = tmpDir.appendingPathComponent("Amazing Grace.onsong")
        try songData.write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.message, "Imported successfully")

        // Verify file exists in library
        let destURL = libraryRoot.appendingPathComponent("Amazing Grace.onsong")
        XCTAssertTrue(FileManager.default.fileExists(atPath: destURL.path))
    }

    func testImportSingleFileChordPro() async throws {
        let songData = makeChordProContent(title: "Test Song", artist: "Artist", body: "Verse 1:\n[Am]Test [F]lyrics")
        let sourceURL = tmpDir.appendingPathComponent("test.chordpro")
        try songData.write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        XCTAssertTrue(result.success)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("test.chordpro").path))
    }

    func testImportSingleFileUnsupportedExtension() async throws {
        let sourceURL = tmpDir.appendingPathComponent("readme.pdf")
        try Data("fake pdf".utf8).write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, "Not a supported song file")
    }

    func testImportSingleFileBinaryContent() async throws {
        let sourceURL = tmpDir.appendingPathComponent("song.onsong")
        try makePDFData().write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.message.contains("Cannot import"))
    }

    func testImportSingleFileDuplicate() async throws {
        // Create a file in the library first
        let songData = makeOnSongContent(title: "Test", body: "Verse 1:\n[C]Test")
        let existingURL = libraryRoot.appendingPathComponent("song.onsong")
        try songData.write(to: existingURL)

        // Now try to import the same filename
        let sourceURL = tmpDir.appendingPathComponent("song.onsong")
        try songData.write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        XCTAssertFalse(result.success)
        XCTAssertEqual(result.message, "File already exists")
    }

    func testImportSingleFileHiddenFile() async throws {
        let songData = makeOnSongContent(title: "Hidden", body: "")
        let sourceURL = tmpDir.appendingPathComponent(".hidden.onsong")
        try songData.write(to: sourceURL)

        let result = await backupImporter.importSingleFile(from: sourceURL)

        // Hidden files are valid song files — they should import
        XCTAssertTrue(result.success)
    }

    // MARK: - importBackup

    func testImportBackupWithSongFiles() async throws {
        let zipURL = tmpDir.appendingPathComponent("songs.zip")
        try createTestZip(at: zipURL, files: [
            ("amazing.onsong", makeOnSongContent(title: "Amazing Grace", body: "Verse 1:\n[G]Amazing [D]grace")),
            ("how-great.chordpro", makeChordProContent(title: "How Great Thou Art", body: "Verse 1:\n[C]O Lord my [F]God")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.importedFiles, 2)
        XCTAssertEqual(result.skippedFiles, 0)
        XCTAssertEqual(result.errors.count, 0)

        // Verify files on disk
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("amazing.onsong").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("how-great.chordpro").path))
    }

    func testImportBackupWithSubdirectories() async throws {
        let zipURL = tmpDir.appendingPathComponent("nested.zip")
        try createTestZip(at: zipURL, files: [
            ("Songs/amazing.onsong", makeOnSongContent(title: "Amazing Grace", body: "")),
            ("Songs/old/how-great.onsong", makeOnSongContent(title: "How Great Thou Art", body: "")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        // Both files in subdirectories should be extracted to flat library
        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.importedFiles, 2)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("amazing.onsong").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("how-great.onsong").path))
    }

    func testImportBackupSkipsBinary() async throws {
        let zipURL = tmpDir.appendingPathComponent("mixed.zip")
        try createTestZip(at: zipURL, files: [
            ("song.onsong", makeOnSongContent(title: "Song", body: "Lyrics")),
            ("sheet.pdf", makePDFData()),
            ("cover.png", makePNGData()),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 1, "Only the .onsong file should count as total")
        // PDF and PNG have unsupported extensions — they are skipped earlier by isSongFile check
        XCTAssertEqual(result.importedFiles, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: libraryRoot.appendingPathComponent("song.onsong").path))
    }

    func testImportBackupSkipsHiddenFiles() async throws {
        let zipURL = tmpDir.appendingPathComponent("hidden.zip")
        try createTestZip(at: zipURL, files: [
            ("visible.onsong", makeOnSongContent(title: "Visible", body: "")),
            (".hidden.onsong", makeOnSongContent(title: "Hidden", body: "")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.importedFiles, 1, "Hidden file should be skipped")
        XCTAssertEqual(result.skippedFiles, 1)
    }

    func testImportBackupSkipsDuplicates() async throws {
        // Pre-populate library with one file
        let existing = libraryRoot.appendingPathComponent("existing.onsong")
        try makeOnSongContent(title: "Existing", body: "").write(to: existing)

        let zipURL = tmpDir.appendingPathComponent("dupes.zip")
        try createTestZip(at: zipURL, files: [
            ("existing.onsong", makeOnSongContent(title: "Existing", body: "")),
            ("new.onsong", makeOnSongContent(title: "New", body: "")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 2)
        XCTAssertEqual(result.importedFiles, 1, "Only new file should be imported")
        XCTAssertEqual(result.skippedFiles, 1, "Existing file should be skipped")
        XCTAssertEqual(result.importedNames.first, "new")
    }

    func testImportBackupSkipsDirectories() async throws {
        let zipURL = tmpDir.appendingPathComponent("dirs.zip")
        try createTestZip(at: zipURL, files: [
            ("songs/", Data()),
            ("song.onsong", makeOnSongContent(title: "Song", body: "")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 1, "Directory entry should not count as a file")
        XCTAssertEqual(result.importedFiles, 1)
    }

    func testImportBackupWithOnSongDatabase() async throws {
        // Create a test OnSong database
        let dbURL = tmpDir.appendingPathComponent("OnSong.sqlite3")
        try createOnSongTestDatabase(at: dbURL)

        // Create ZIP containing the database + a loose song file
        let zipURL = tmpDir.appendingPathComponent("backup.zip")
        try createTestZip(at: zipURL, files: [
            ("OnSong.sqlite3", try Data(contentsOf: dbURL)),
            ("loose.onsong", makeOnSongContent(title: "Loose Song", body: "Verse 1:\n[C]Test")),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        // 1 loose file + 2 songs from DB (3 total)
        XCTAssertEqual(result.totalFiles, 3, "Should count 1 loose + 2 DB songs")
        // importedFiles may be less than totalFiles if setlist import fails
        // (Core Data model not bundled in test environment)
        XCTAssertGreaterThanOrEqual(result.importedFiles, 3)

        // Database songs should be written to library
        let amazingURL = libraryRoot.appendingPathComponent("Amazing Grace-G.onsong")
        let howGreatURL = libraryRoot.appendingPathComponent("How Great Thou Art-C.onsong")
        let looseURL = libraryRoot.appendingPathComponent("loose.onsong")

        XCTAssertTrue(FileManager.default.fileExists(atPath: amazingURL.path), "Amazing Grace should be imported")
        XCTAssertTrue(FileManager.default.fileExists(atPath: howGreatURL.path), "How Great Thou Art should be imported")
        XCTAssertTrue(FileManager.default.fileExists(atPath: looseURL.path), "Loose song should be imported")

        // Verify imported names
        XCTAssertTrue(result.importedNames.contains("Amazing Grace"))
        XCTAssertTrue(result.importedNames.contains("How Great Thou Art"))
        XCTAssertTrue(result.importedNames.contains("loose"))
    }

    func testImportBackupWithOnSongDatabaseSkipExisting() async throws {
        // Pre-create one song file
        let amazingURL = libraryRoot.appendingPathComponent("Amazing Grace-G.onsong")
        try makeOnSongContent(title: "Amazing Grace", body: "Existing copy").write(to: amazingURL)

        let dbURL = tmpDir.appendingPathComponent("OnSong.sqlite3")
        try createOnSongTestDatabase(at: dbURL)

        let zipURL = tmpDir.appendingPathComponent("backup.zip")
        try createTestZip(at: zipURL, files: [
            ("OnSong.sqlite3", try Data(contentsOf: dbURL)),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        // Amazing Grace should be skipped (already exists), How Great Thou Art imported
        XCTAssertTrue(result.skippedFiles >= 1, "Existing file should be skipped")
        XCTAssertTrue(result.importedFiles >= 1)
    }

    func testImportBackupInvalidFile() async throws {
        let badURL = tmpDir.appendingPathComponent("not_a_zip.txt")
        try Data("this is not a zip file".utf8).write(to: badURL)

        let result = await backupImporter.importBackup(from: badURL)

        XCTAssertEqual(result.importedFiles, 0)
        XCTAssertTrue(result.errors.first?.contains("Cannot open ZIP archive") == true)
    }

    func testImportBackupEmptyArchive() async throws {
        // Create a minimal valid empty ZIP (just the EOCD record)
        let zipURL = tmpDir.appendingPathComponent("empty.zip")
        var eocd = Data([0x50, 0x4B, 0x05, 0x06]) // "PK\005\006" signature
        eocd.append(Data(repeating: 0x00, count: 18)) // zeros: disk, entries, offset, comment_len
        try eocd.write(to: zipURL)

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 0)
        XCTAssertEqual(result.importedFiles, 0)
        XCTAssertEqual(result.errors.count, 0)
    }

    // MARK: - isBackupFile

    func testIsBackupFileZip() {
        XCTAssertTrue(BackupImporter.isBackupFile("backup.zip"))
    }

    func testIsBackupFileBackup() {
        XCTAssertTrue(BackupImporter.isBackupFile("export.backup"))
    }

    func testIsBackupFileOnSongBackup() {
        XCTAssertTrue(BackupImporter.isBackupFile("songs.onsong-backup"))
    }

    func testIsBackupFileCaseInsensitive() {
        XCTAssertTrue(BackupImporter.isBackupFile("BACKUP.ZIP"))
    }

    func testIsBackupFileRejectsTxt() {
        XCTAssertFalse(BackupImporter.isBackupFile("songs.txt"))
    }

    func testIsBackupFileRejectsOnSong() {
        XCTAssertFalse(BackupImporter.isBackupFile("song.onsong"))
    }

    // MARK: - Edge Cases

    func testImportBackupWithAllUnsupportedExtensions() async throws {
        let zipURL = tmpDir.appendingPathComponent("unsupported.zip")
        try createTestZip(at: zipURL, files: [
            ("readme.md", Data("# Songs".utf8)),
            ("sheet.pdf", makePDFData()),
            ("image.png", makePNGData()),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        XCTAssertEqual(result.totalFiles, 0, "No supported song files in archive")
        XCTAssertEqual(result.importedFiles, 0)
    }

    func testImportBackupMacRomanEncodedFile() async throws {
        // Simulate a Mac Roman-encoded .onsong file (high bytes for accented chars)
        // "Résumé" in Mac Roman: 0x52 0xE9 0x73 0x75 0x6D 0xE9
        var macRomanBytes = Data([0x52, 0xE9, 0x73, 0x75, 0x6D, 0xE9])
        macRomanBytes.append("\n\nLyrics here".data(using: .utf8)!)
        // This is valid UTF-8 as well, so UTF-8 path handles it

        let zipURL = tmpDir.appendingPathComponent("macroman.zip")
        try createTestZip(at: zipURL, files: [
            ("resume.onsong", macRomanBytes),
        ])

        let result = await backupImporter.importBackup(from: zipURL)

        // UTF-8 decode should succeed since those bytes are valid UTF-8 sequences as well
        XCTAssertEqual(result.importedFiles, 1)
    }
}
