import XCTest
import FreeSongCore
@testable import FreeSongStorage

final class FileSongRepositoryTests: XCTestCase {

    private var tempDir: URL!
    private var repo: FileSongRepository!

    override func setUp() async throws {
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("freesong-storage-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        repo = FileSongRepository(libraryRoot: tempDir)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
        repo = nil
    }

    // MARK: - Path resolution

    func testSaveWithRelativePathResolvesAgainstLibraryRoot() async throws {
        let song = Song(title: "Title", sections: [SongSection(label: "Verse 1", lines: [SongLine(lyrics: "La la la")])])
        try await repo.saveSong(song, at: "Title.onsong")

        let expected = tempDir.appendingPathComponent("Title.onsong")
        XCTAssertTrue(FileManager.default.fileExists(atPath: expected.path))

        let cwdCandidate = URL(fileURLWithPath: "Title.onsong")
        XCTAssertFalse(FileManager.default.fileExists(atPath: cwdCandidate.path))
    }

    func testSaveWithAbsolutePathUsesPathAsIs() async throws {
        let absolutePath = tempDir.appendingPathComponent("Absolute.onsong").path
        let song = Song(title: "Absolute", sections: [SongSection(label: "Verse 1", lines: [SongLine(lyrics: "hi")])])
        try await repo.saveSong(song, at: absolutePath)

        XCTAssertTrue(FileManager.default.fileExists(atPath: absolutePath))
    }

    // MARK: - Save / load round trip

    func testSaveLoadRoundTripPreservesContentAndStampsSourcePath() async throws {
        let song = Song(
            title: "Über den Wolken",
            artist: "Reinhard Mey",
            key: "G",
            sections: [
                SongSection(label: "Verse 1", lines: [
                    SongLine(lyrics: "Hoch über den Wolken", chords: [
                        ChordPosition(chord: "G", position: 0),
                        ChordPosition(chord: "D", position: 10)
                    ]),
                    SongLine(lyrics: "muß die Freiheit wohl grenzenlos sein")
                ]),
                SongSection(label: "Chorus", lines: [
                    SongLine(lyrics: "Alle Ängste, alle Sorgen", chords: [
                        ChordPosition(chord: "Em", position: 5)
                    ])
                ])
            ]
        )

        try await repo.saveSong(song, at: "wolken.onsong")
        let loaded = try await repo.getSong(at: "wolken.onsong")

        let expectedPath = tempDir.appendingPathComponent("wolken.onsong").path
        XCTAssertEqual(loaded?.sourcePath, expectedPath)
        XCTAssertEqual(loaded?.title, song.title)
        XCTAssertEqual(loaded?.artist, song.artist)
        XCTAssertEqual(loaded?.sections, song.sections)
    }

    // MARK: - generateSongContent <-> SongParser round trip (via save/load, since generateSongContent is private)

    func testGeneratedContentParsesBackToSameSections() async throws {
        let content = """
        Über den Wolken
        Reinhard Mey

        Verse 1:
        [G]Hoch über den Wolken muß die Freiheit wohl [D]grenzenlos sein
        Alle Ängste, alle Sorgen, sagt man blieben tief drunten verborgen

        Chorus:
        [Em]Nur schwerelos und [C]frei
        """
        var parsedSong = SongParser.parse(content)
        parsedSong.rawContent = "" // force saveSong through generateSongContent, not the raw passthrough

        try await repo.saveSong(parsedSong, at: "roundtrip.onsong")
        let loaded = try await repo.getSong(at: "roundtrip.onsong")

        XCTAssertEqual(loaded?.sections, parsedSong.sections)
    }

    // MARK: - Delete

    func testDeleteSongRemovesFile() async throws {
        let song = Song(title: "ToDelete", sections: [SongSection(label: "Verse 1", lines: [SongLine(lyrics: "x")])])
        try await repo.saveSong(song, at: "todelete.onsong")
        let file = tempDir.appendingPathComponent("todelete.onsong")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        try await repo.deleteSong(at: "todelete.onsong")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    // MARK: - In-memory mtime cache (perf: avoid re-reading/re-parsing unchanged files)

    func testUnchangedFileReturnsCachedParseNotDiskContent() async throws {
        let song = Song(title: "Cached Title", sections: [SongSection(label: "Verse 1", lines: [SongLine(lyrics: "x")])])
        try await repo.saveSong(song, at: "cache.onsong")
        let file = tempDir.appendingPathComponent("cache.onsong")

        let first = try await repo.getSong(at: "cache.onsong")
        XCTAssertEqual(first?.title, "Cached Title")

        // Overwrite the file's content directly but restore its original
        // modification date (read/written via the same resourceValues API the
        // repository uses, for matching precision), simulating a no-op touch.
        // Since mtime is unchanged, the repository should serve its in-memory
        // parse instead of re-reading/re-parsing the (different) on-disk content.
        let originalDate = try XCTUnwrap(
            file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
        )
        try "Different Title\n\nVerse 1:\nchanged".write(to: file, atomically: true, encoding: .utf8)
        var mutableFile = file
        var values = URLResourceValues()
        values.contentModificationDate = originalDate
        try mutableFile.setResourceValues(values)

        let second = try await repo.getSong(at: "cache.onsong")
        XCTAssertEqual(second?.title, "Cached Title")
    }

    func testTouchedFileIsReparsed() async throws {
        let song = Song(title: "Original Title", sections: [SongSection(label: "Verse 1", lines: [SongLine(lyrics: "x")])])
        try await repo.saveSong(song, at: "touch.onsong")
        let file = tempDir.appendingPathComponent("touch.onsong")

        let first = try await repo.getSong(at: "touch.onsong")
        XCTAssertEqual(first?.title, "Original Title")

        try "New Title\n\nVerse 1:\nchanged".write(to: file, atomically: true, encoding: .utf8)
        var mutableFile = file
        var values = URLResourceValues()
        values.contentModificationDate = Date().addingTimeInterval(5)
        try mutableFile.setResourceValues(values)

        let second = try await repo.getSong(at: "touch.onsong")
        XCTAssertEqual(second?.title, "New Title")
    }
}
