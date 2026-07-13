import Foundation
import FreeSongCore

// MARK: - JSON Metadata Cache

/// File-based metadata cache using JSON.
/// Replaces the Android SQLite cache with a simpler, faster JSON file.
public actor JSONMetadataCache: MetadataCache {

    private let cacheFile: URL
    private var cache: [String: CachedMetadataEntry] = [:]
    /// Debounces disk writes: a burst of `cacheMetadata` calls (e.g. parsing
    /// a whole library on first launch) previously rewrote the whole JSON file
    /// on every single call, making cold start O(N^2) in file I/O. Now only
    /// the last call in a burst actually saves.
    private var pendingSave: Task<Void, Never>?

    public init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let freeSongDir = appSupport.appendingPathComponent("FreeSong", isDirectory: true)
        self.init(cacheFile: freeSongDir.appendingPathComponent("metadata.json"))
    }

    /// Testable initializer pointing at an arbitrary cache file location.
    init(cacheFile: URL) {
        try? FileManager.default.createDirectory(at: cacheFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        self.cacheFile = cacheFile

        // Load cache synchronously during init (safe because init runs before any concurrent access)
        if FileManager.default.fileExists(atPath: cacheFile.path) {
            if let data = try? Data(contentsOf: cacheFile),
               let decoded = try? JSONDecoder().decode([String: CachedMetadataEntry].self, from: data) {
                cache = decoded
            } else {
                // Corrupt cache — delete so next launch starts fresh
                try? FileManager.default.removeItem(at: cacheFile)
            }
        }
    }

    public func getCachedMetadata(for file: URL) async -> CachedMetadata? {
        let path = file.path
        if let entry = cache[path] {
            let fileModified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            if entry.lastModified == fileModified {
                return CachedMetadata(title: entry.title, artist: entry.artist, lastModified: entry.lastModified)
            }
        }
        return nil
    }

    public func cacheMetadata(for file: URL, title: String, artist: String?) async {
        let path = file.path
        let fileModified = (try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date()

        let entry = CachedMetadataEntry(
            title: title,
            artist: artist,
            lastModified: fileModified
        )

        cache[path] = entry
        scheduleSave()
    }

    public func removeStaleEntries(validPaths: Set<String>) async {
        cache = cache.filter { validPaths.contains($0.key) }
        scheduleSave()
    }

    public var cacheSize: Int {
        cache.count
    }

    // MARK: - Private

    private struct CachedMetadataEntry: Codable {
        let title: String
        let artist: String?
        let lastModified: Date
    }

    /// Write-behind: coalesce a burst of mutations into a single disk write
    /// ~50ms after the last one, instead of writing on every call.
    /// ponytail: fixed short delay, not a full write-behind queue with a
    /// flush-on-terminate hook — if the process is killed inside that window
    /// the last few entries just get re-parsed next launch (cache miss, not
    /// data loss, since the source of truth is the song files on disk).
    private func scheduleSave() {
        pendingSave?.cancel()
        pendingSave = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 50_000_000)
            guard !Task.isCancelled else { return }
            await self?.saveCache()
        }
    }

    private func saveCache() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        try? data.write(to: cacheFile, options: .atomic)
    }
}