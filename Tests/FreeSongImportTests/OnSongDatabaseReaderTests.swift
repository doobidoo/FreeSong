import XCTest
@testable import FreeSongImport

final class OnSongDatabaseReaderTests: XCTestCase {

    var dbURL: URL!
    var emptyDbURL: URL!
    var partialDbURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        let tmpDir = try createTempDirectory()
        dbURL = tmpDir.appendingPathComponent("test.db")
        emptyDbURL = tmpDir.appendingPathComponent("empty.db")
        partialDbURL = tmpDir.appendingPathComponent("partial.db")

        try createOnSongTestDatabase(at: dbURL)
        try createEmptyOnSongDatabase(at: emptyDbURL)
        try createPartialOnSongDatabase(at: partialDbURL)
    }

    override func tearDown() async throws {
        // Clean up parent temp directories
        for url in [dbURL, emptyDbURL, partialDbURL] {
            if let url = url {
                let parent = url.deletingLastPathComponent()
                try? FileManager.default.removeItem(at: parent)
            }
        }
        try await super.tearDown()
    }

    // MARK: - Reading Songs

    func testReadSongs() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        XCTAssertEqual(songs.count, 2, "Should return songs with non-empty content")
    }

    func testReadSongsContent() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        let amazingGrace = songs.first { $0.title == "Amazing Grace" }
        XCTAssertNotNil(amazingGrace)
        XCTAssertEqual(amazingGrace?.artist, "John Newton")
        XCTAssertEqual(amazingGrace?.key, "G")
        XCTAssertTrue(amazingGrace?.content.contains("[G]Amazing [D]grace") == true)
    }

    func testReadSongsFiltersEmptyContent() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        let emptySong = songs.first { $0.title == "Empty Song" }
        XCTAssertNil(emptySong, "Songs with empty content should be filtered out")
    }

    func testReadSongsFiltersNullContent() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        // Song 3 has empty content in the test DB
        let allTitles = songs.map(\.title)
        XCTAssertFalse(allTitles.contains("Empty Song"))
    }

    func testReadSongsReturnsCorrectCount() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let songs = try await reader.importSongs()

        XCTAssertEqual(songs.count, 2)
        let titles = Set(songs.map(\.title))
        XCTAssertTrue(titles.contains("Amazing Grace"))
        XCTAssertTrue(titles.contains("How Great Thou Art"))
    }

    // MARK: - Reading Setlists

    func testReadSetlists() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        XCTAssertEqual(setlists.count, 2)
    }

    func testReadSetlistNames() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        let names = Set(setlists.map(\.title))
        XCTAssertTrue(names.contains("Sunday Morning"))
        XCTAssertTrue(names.contains("Evening Service"))
    }

    func testReadSetlistItems() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        let sundayMorning = setlists.first { $0.title == "Sunday Morning" }
        XCTAssertNotNil(sundayMorning)
        XCTAssertEqual(sundayMorning?.items.count, 2, "Sunday Morning should have 2 songs")
    }

    func testReadSetlistItemOrder() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        let sundayMorning = setlists.first { $0.title == "Sunday Morning" }
        let items = sundayMorning?.items ?? []

        XCTAssertEqual(items.count, 2)
        // Items should be in orderIndex order
        XCTAssertEqual(items[0].orderIndex, 0)
        XCTAssertEqual(items[1].orderIndex, 1)
    }

    func testReadSetlistItemContent() async throws {
        let reader = try OnSongDatabaseReader(databasePath: dbURL.path)
        let setlists = try await reader.importSetlists()

        let sundayMorning = setlists.first { $0.title == "Sunday Morning" }
        let firstItem = sundayMorning?.items.first

        XCTAssertNotNil(firstItem)
        XCTAssertEqual(firstItem?.title, "Amazing Grace")
        XCTAssertEqual(firstItem?.key, "G")
        XCTAssertEqual(firstItem?.artist, "John Newton")
    }

    // MARK: - Edge Cases

    func testEmptyDatabaseReadSongs() async throws {
        let reader = try OnSongDatabaseReader(databasePath: emptyDbURL.path)
        let songs = try await reader.importSongs()
        XCTAssertTrue(songs.isEmpty, "Empty database should return no songs")
    }

    func testEmptyDatabaseReadSetlists() async throws {
        let reader = try OnSongDatabaseReader(databasePath: emptyDbURL.path)
        let setlists = try await reader.importSetlists()
        XCTAssertTrue(setlists.isEmpty, "Empty database should return no setlists")
    }

    func testPartialDatabaseReadSongs() async throws {
        let reader = try OnSongDatabaseReader(databasePath: partialDbURL.path)
        let songs = try await reader.importSongs()
        XCTAssertEqual(songs.count, 1)
        XCTAssertEqual(songs.first?.title, "Only Song")
    }

    func testPartialDatabaseReadSetlists() async throws {
        // Database has Song table but no SongSet/SongSetItem tables
        let reader = try OnSongDatabaseReader(databasePath: partialDbURL.path)
        await XCTAssertThrowsError(try await reader.importSetlists())
    }

    func testMissingDatabaseFile() {
        let missingURL = URL(fileURLWithPath: "/nonexistent/path/database.db")
        XCTAssertThrowsError(try OnSongDatabaseReader(databasePath: missingURL.path)) { error in
            guard let backupError = error as? BackupImportError else {
                XCTFail("Expected BackupImportError, got \(type(of: error))")
                return
            }
            if case .databaseError(let msg) = backupError {
                XCTAssertTrue(msg.contains("Failed to open database"))
            } else {
                XCTFail("Expected databaseError, got \(backupError)")
            }
        }
    }
}

// MARK: - XCTest Helpers

/// Assert that an async throwing expression throws an error.
private func XCTAssertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #filePath,
    line: UInt = #line,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expression did not throw", file: file, line: line)
    } catch {
        errorHandler(error)
    }
}
