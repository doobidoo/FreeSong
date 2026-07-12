import Foundation
import FreeSongCore

// MARK: - File Song Repository

/// File-based song repository scanning the FreeSong folder in Documents.
/// Uses MetadataCache for fast metadata access.
public actor FileSongRepository: SongRepository {

    /// Shared instance so the in-memory song cache below is actually reused
    /// across the app's ad-hoc `FileSongRepository()` call sites instead of
    /// dying with each short-lived instance.
    public static let shared = FileSongRepository()

    nonisolated public let libraryRoot: URL
    private let metadataCache: MetadataCache
    private let parser = SongParser.self

    /// In-memory cache of fully-parsed songs, keyed by file path and validated
    /// by modification date. Avoids re-reading and re-parsing file content for
    /// files that haven't changed since the last `getAllSongs`/`getSong` call.
    private var songCache: [String: (mtime: Date, song: Song)] = [:]

    /// Create the default repository pointing to ~/Documents/FreeSong/.
    public init(metadataCache: MetadataCache = JSONMetadataCache()) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let root = documents.appendingPathComponent("FreeSong", isDirectory: true)
        self.libraryRoot = root
        self.metadataCache = metadataCache

        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    /// Create a repository with a custom library root (useful for testing).
    public init(libraryRoot: URL, metadataCache: MetadataCache = JSONMetadataCache()) {
        self.libraryRoot = libraryRoot
        self.metadataCache = metadataCache
        try? FileManager.default.createDirectory(at: libraryRoot, withIntermediateDirectories: true)
    }

    public func getAllSongs() async throws -> [Song] {
        let files = try getSongFiles()
        return try await withThrowingTaskGroup(of: Song?.self) { group in
            for file in files {
                group.addTask { try await self.parseSongWithCache(file: file) }
            }
            var songs: [Song] = []
            for try await song in group {
                if let song { songs.append(song) }
            }
            return songs.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
    }

    public func getSong(at path: String) async throws -> Song? {
        let file = resolvedURL(for: path)
        return try await parseSongWithCache(file: file)
    }

    public func saveSong(_ song: Song, at path: String) async throws {
        let file = resolvedURL(for: path)
        let content = song.rawContent.isEmpty ? SongSerializer.serialize(song) : song.rawContent
        try content.write(to: file, atomically: true, encoding: .utf8)
        await metadataCache.cacheMetadata(for: file, title: song.title, artist: song.artist)
    }

    public func deleteSong(at path: String) async throws {
        let file = resolvedURL(for: path)
        try FileManager.default.removeItem(at: file)
        songCache.removeValue(forKey: file.path)
        let remaining = Set((try? getSongFiles())?.map(\.path) ?? [])
        await metadataCache.removeStaleEntries(validPaths: remaining)
    }

    public func searchSongs(query: String) async throws -> [Song] {
        let allSongs = try await getAllSongs()
        let lowerQuery = query.lowercased()
        return allSongs.filter { song in
            song.title.lowercased().contains(lowerQuery) ||
            song.artist?.lowercased().contains(lowerQuery) == true
        }
    }

    // MARK: - Private

    /// Resolves a path string to a file URL: absolute paths are used as-is,
    /// relative paths are resolved against `libraryRoot` (not the process CWD).
    private func resolvedURL(for path: String) -> URL {
        if path.hasPrefix("/") {
            return URL(fileURLWithPath: path)
        }
        return libraryRoot.appendingPathComponent(path)
    }

    private func getSongFiles() throws -> [URL] {
        let extensions = ["onsong", "chordpro", "cho", "crd", "pro", "txt"]
        let files = try FileManager.default.contentsOfDirectory(at: libraryRoot, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles)
        return files.filter { extensions.contains($0.pathExtension.lowercased()) }
    }

    private func parseSongWithCache(file: URL) async throws -> Song? {
        let mtime = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast

        // Fast path: file unchanged since last full parse in this process -
        // skip disk read and parsing entirely.
        if let cached = songCache[file.path], cached.mtime == mtime {
            return cached.song
        }

        let content = try String(contentsOf: file, encoding: .utf8)

        let song: Song
        if let cachedMeta = await metadataCache.getCachedMetadata(for: file) {
            var parsed = parser.parse(content)
            parsed.title = cachedMeta.title
            parsed.artist = cachedMeta.artist
            parsed.sourcePath = file.path
            song = parsed
        } else {
            var parsed = parser.parse(content)
            parsed.sourcePath = file.path
            await metadataCache.cacheMetadata(for: file, title: parsed.title, artist: parsed.artist)
            song = parsed
        }

        songCache[file.path] = (mtime, song)
        return song
    }

}