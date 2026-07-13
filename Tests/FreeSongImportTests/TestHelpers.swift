import XCTest
@testable import FreeSongImport
@testable import FreeSongCore
@testable import FreeSongStorage

// MARK: - Fixture Creation

/// Creates a temporary directory for test isolation. Returns the URL.
/// Caller is responsible for cleanup (use `removeItem(at:)` in tearDown).
func createTempDirectory() throws -> URL {
    let tmp = FileManager.default.temporaryDirectory
        .appendingPathComponent("freesong-test-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
    return tmp
}

/// Creates an OnSong SQLite test database with songs and setlists.
func createOnSongTestDatabase(at url: URL) throws {
    let sql = """
    CREATE TABLE Song (ID TEXT PRIMARY KEY, title TEXT, byline TEXT, key TEXT, content TEXT);
    INSERT INTO Song VALUES ('1', 'Amazing Grace', 'John Newton', 'G', 'Amazing Grace
    John Newton

    Verse 1:
    [G]Amazing [D]grace how [Em]sweet the [C]sound');
    INSERT INTO Song VALUES ('2', 'How Great Thou Art', 'Stuart K. Hine', 'C', 'How Great Thou Art
    Stuart K. Hine

    Verse 1:
    [C]O Lord my [F]God, when [C]I in [G]awesome [C]wonder');
    INSERT INTO Song VALUES ('3', 'Empty Song', NULL, NULL, '');
    CREATE TABLE SongSet (ID TEXT PRIMARY KEY, title TEXT);
    INSERT INTO SongSet VALUES ('1', 'Sunday Morning');
    INSERT INTO SongSet VALUES ('2', 'Evening Service');
    CREATE TABLE SongSetItem (setID TEXT, songID TEXT, orderIndex INTEGER);
    INSERT INTO SongSetItem VALUES ('1', '1', 0);
    INSERT INTO SongSetItem VALUES ('1', '2', 1);
    INSERT INTO SongSetItem VALUES ('2', '1', 0);
    """
    try executeSQLite(url: url, sql: sql)
}

/// Creates an OnSong database with tables but no rows.
func createEmptyOnSongDatabase(at url: URL) throws {
    let sql = """
    CREATE TABLE Song (ID TEXT PRIMARY KEY, title TEXT, byline TEXT, key TEXT, content TEXT);
    CREATE TABLE SongSet (ID TEXT PRIMARY KEY, title TEXT);
    CREATE TABLE SongSetItem (setID TEXT, songID TEXT, orderIndex INTEGER);
    """
    try executeSQLite(url: url, sql: sql)
}

/// Creates an OnSong database missing the SongSetItem table (migration edge case).
func createPartialOnSongDatabase(at url: URL) throws {
    let sql = """
    CREATE TABLE Song (ID TEXT PRIMARY KEY, title TEXT, byline TEXT, key TEXT, content TEXT);
    INSERT INTO Song VALUES ('1', 'Only Song', NULL, 'G', 'Some content here');
    """
    try executeSQLite(url: url, sql: sql)
}

/// Creates a ZIP archive at `url` containing the given file entries.
func createTestZip(at url: URL, files: [(name: String, content: Data)]) throws {
    let tmpDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("zip-staging-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: tmpDir) }

    try FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

    for file in files {
        let fileURL = tmpDir.appendingPathComponent(file.name)
        // Create parent directories if needed (e.g. subdir/song.onsong)
        let parent = fileURL.deletingLastPathComponent()
        if parent != tmpDir {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try file.content.write(to: fileURL)
    }

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
    process.arguments = ["-r", "--quiet", url.path] + files.map(\.name)
    process.currentDirectoryURL = tmpDir
    try process.run()
    process.waitUntilExit()
}

// MARK: - Song Content Builders

/// Build an .onsong file with chords-above-lyrics format.
func makeOnSongContent(title: String, artist: String? = nil, key: String? = nil, body: String) -> Data {
    var lines: [String] = [title]
    if let artist = artist {
        lines.append(artist)
    }
    lines.append("")
    if let key = key {
        lines.append("{key: \(key)}")
    }
    lines.append(body)
    return lines.joined(separator: "\n").data(using: .utf8)!
}

/// Build a ChordPro file.
func makeChordProContent(title: String, artist: String? = nil, key: String? = nil, body: String) -> Data {
    var lines: [String] = []
    lines.append("{title: \(title)}")
    if let artist = artist {
        lines.append("{artist: \(artist)}")
    }
    if let key = key {
        lines.append("{key: \(key)}")
    }
    lines.append("")
    lines.append(body)
    return lines.joined(separator: "\n").data(using: .utf8)!
}

/// Build a PDF signature (for binary detection testing).
func makePDFData() -> Data {
    var bytes = Data([0x25, 0x50, 0x44, 0x46]) // %PDF
    bytes.append(Data(repeating: 0x00, count: 20))
    return bytes
}

/// Build a PNG signature.
func makePNGData() -> Data {
    var bytes = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    bytes.append(Data(repeating: 0x00, count: 20))
    return bytes
}

/// Build a JPEG signature.
func makeJPEGData() -> Data {
    var bytes = Data([0xFF, 0xD8, 0xFF, 0xE0])
    bytes.append(Data(repeating: 0x00, count: 20))
    return bytes
}

/// Build high-entropy binary noise (>10% non-printable bytes).
func makeBinaryNoise() -> Data {
    var bytes = Data()
    for i in 0..<200 {
        bytes.append(i < 30 ? 0x00 : UInt8(0x41 + (i % 26))) // 15% null bytes
    }
    return bytes
}

// MARK: - Private Helpers

// MARK: - Test Mock

/// A setlist repository that performs no operations (no Core Data needed).
/// Used in test environments where the Core Data model is not bundled.
public actor NullSetlistRepository: SetlistRepository {
    public init() {}

    public func getAllSetlists() async throws -> [SetList] { [] }
    public func getSetlist(id: UUID) async throws -> SetList? { nil }
    public func saveSetlist(_ setlist: SetList) async throws {}
    public func deleteSetlist(id: UUID) async throws {}
    public func getSetlistsContaining(songPath: String) async throws -> [SetList] { [] }
}

/// Execute SQL against a SQLite database using the system `sqlite3` CLI.
private func executeSQLite(url: URL, sql: String) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
    process.arguments = [url.path]

    let stdin = Pipe()
    process.standardInput = stdin
    try process.run()
    stdin.fileHandleForWriting.write(sql.data(using: .utf8)!)
    stdin.fileHandleForWriting.closeFile()
    process.waitUntilExit()

    if process.terminationStatus != 0 {
        throw NSError(domain: "TestHelpers", code: -1, userInfo: [
            NSLocalizedDescriptionKey: "sqlite3 exited with status \(process.terminationStatus)"
        ])
    }
}
