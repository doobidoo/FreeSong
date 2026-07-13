import XCTest
import FreeSongCore
@testable import FreeSongStorage

final class JSONMetadataCacheTests: XCTestCase {

    private var cacheFile: URL!
    private var cache: JSONMetadataCache!

    override func setUp() {
        cacheFile = FileManager.default.temporaryDirectory
            .appendingPathComponent("freesong-metadata-test-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("metadata.json")
        cache = JSONMetadataCache(cacheFile: cacheFile)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: cacheFile.deletingLastPathComponent())
        cache = nil
    }

    /// A burst of writes (e.g. parsing a whole library on first launch) should
    /// coalesce into a single debounced disk write, not one write per call.
    func testBurstOfWritesCoalescesIntoOneDiskWrite() async throws {
        for index in 0..<20 {
            await cache.cacheMetadata(for: URL(fileURLWithPath: "/tmp/song\(index).onsong"), title: "Song \(index)", artist: nil)
        }

        // Nothing written yet - still debouncing.
        XCTAssertFalse(FileManager.default.fileExists(atPath: cacheFile.path))

        try await Task.sleep(nanoseconds: 150_000_000)

        XCTAssertTrue(FileManager.default.fileExists(atPath: cacheFile.path))
        let data = try Data(contentsOf: cacheFile)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: data)
        XCTAssertEqual(decoded.count, 20)
    }

    func testCachedMetadataSurvivesReloadFromDisk() async throws {
        let file = URL(fileURLWithPath: "/tmp/reload.onsong")
        await cache.cacheMetadata(for: file, title: "Reload Title", artist: "Reload Artist")
        try await Task.sleep(nanoseconds: 150_000_000)

        let reloaded = JSONMetadataCache(cacheFile: cacheFile)
        let size = await reloaded.cacheSize
        XCTAssertEqual(size, 1)
    }
}

/// Minimal helper to decode the JSON cache file's values without depending on
/// JSONMetadataCache's private entry type.
private struct JSONValue: Decodable {}
