import Foundation
import FreeSongCore

// MARK: - SongRepository Protocol

/// Protocol for song storage operations.
/// Implementations can use file system, database, or cloud storage.
public protocol SongRepository: Sendable {
    /// Get all songs in the library.
    func getAllSongs() async throws -> [Song]

    /// Get a song by its file path.
    func getSong(at path: String) async throws -> Song?

    /// Save a song to storage.
    func saveSong(_ song: Song, at path: String) async throws

    /// Delete a song from storage.
    func deleteSong(at path: String) async throws

    /// Search songs by title or artist.
    func searchSongs(query: String) async throws -> [Song]

    /// Get the library root directory.
    var libraryRoot: URL { get }
}

// MARK: - SetlistRepository Protocol

/// Protocol for setlist storage operations.
public protocol SetlistRepository: Sendable {
    /// Get all setlists.
    func getAllSetlists() async throws -> [SetList]

    /// Get a setlist by ID.
    func getSetlist(id: UUID) async throws -> SetList?

    /// Save a setlist (create or update).
    func saveSetlist(_ setlist: SetList) async throws

    /// Delete a setlist.
    func deleteSetlist(id: UUID) async throws

    /// Get setlists containing a specific song path.
    func getSetlistsContaining(songPath: String) async throws -> [SetList]
}

// MARK: - MetadataCache Protocol

/// Protocol for song metadata caching.
public protocol MetadataCache: Sendable {
    /// Get cached metadata for a file.
    func getCachedMetadata(for file: URL) async -> CachedMetadata?

    /// Cache metadata for a file.
    func cacheMetadata(for file: URL, title: String, artist: String?) async

    /// Remove stale cache entries.
    func removeStaleEntries(validPaths: Set<String>) async

    /// Get cache size.
    var cacheSize: Int { get async }
}

/// Cached metadata result.
public struct CachedMetadata: Sendable {
    public let title: String
    public let artist: String?
    public let lastModified: Date

    public init(title: String, artist: String?, lastModified: Date) {
        self.title = title
        self.artist = artist
        self.lastModified = lastModified
    }
}