import Foundation
@testable import FreeSongSync
@testable import FreeSongCore

// MARK: - Mock HTTP Client

/// A mock ``HTTPClient`` that returns canned responses based on URL pattern matching.
final class MockHTTPClient: HTTPClient, @unchecked Sendable {
    /// Keyed by (method, url-pattern) — e.g. ("GET", "/contents/songs").
    private var responses: [(method: String?, pattern: String, data: Data, statusCode: Int)] = []
    /// All requests made through this client.
    private(set) var requests: [URLRequest] = []
    /// If set, all unmatched requests throw this error.
    var defaultError: Error?

    /// Register a canned response for URLs containing the given pattern (any HTTP method).
    func when(_ urlPattern: String, data: Data, statusCode: Int = 200) {
        responses.append((nil, urlPattern, data, statusCode))
    }

    /// Register a canned response scoped to a specific HTTP method (e.g. "GET", "PUT").
    func when(method: String, _ urlPattern: String, data: Data, statusCode: Int = 200) {
        responses.append((method, urlPattern, data, statusCode))
    }

    /// Register a canned JSON response for URLs containing the given pattern.
    func whenJSON<T: Encodable>(_ urlPattern: String, _ value: T, statusCode: Int = 200) {
        let data = (try? JSONEncoder().withSnakeCase().encode(value)) ?? Data()
        responses.append((nil, urlPattern, data, statusCode))
    }

    // MARK: HTTPClient

    func send(_ request: URLRequest) async throws -> (data: Data, statusCode: Int) {
        requests.append(request)
        guard let url = request.url?.absoluteString,
              let httpMethod = request.httpMethod else {
            throw SyncError.networkError("No URL or method in request")
        }
        // Prefer a method-specific match; fall back to a method-agnostic one.
        // When multiple candidates exist, pick the longest pattern (most specific).
        func best(forMethod specific: Bool) -> (data: Data, statusCode: Int)? {
            var best: (length: Int, data: Data, statusCode: Int)?
            for entry in responses {
                let methodOk = specific ? entry.method == httpMethod
                                       : entry.method == nil || entry.method == httpMethod
                guard methodOk, url.contains(entry.pattern) else { continue }
                if best == nil || entry.pattern.count > best!.length {
                    best = (entry.pattern.count, entry.data, entry.statusCode)
                }
            }
            return best.map { ($0.data, $0.statusCode) }
        }
        if let match = best(forMethod: true) ?? best(forMethod: false) {
            return match
        }
        if let error = defaultError {
            throw error
        }
        throw SyncError.networkError("No mock registered for: \(url)")
    }
}

// MARK: - Helper Extensions

extension JSONEncoder {
    func withSnakeCase() -> JSONEncoder {
        keyEncodingStrategy = .convertToSnakeCase
        return self
    }
}

extension JSONDecoder {
    func withSnakeCase() -> JSONDecoder {
        keyDecodingStrategy = .convertFromSnakeCase
        return self
    }
}

// MARK: - Test Fixtures

enum SyncFixtures {

    /// Sample song for syncing.
    static func makeSong(title: String = "Amazing Grace", artist: String? = "John Newton", key: String? = "G") -> Song {
        Song(
            title: title,
            artist: artist,
            key: key,
            sections: [
                SongSection(label: "Verse", lines: [
                    SongLine(lyrics: "Amazing grace how sweet the sound", chords: [
                        ChordPosition(chord: "G", position: 0),
                        ChordPosition(chord: "D", position: 17),
                    ]),
                ]),
            ]
        )
    }

    /// Generate ChordPro content for a test song.
    static func contentForSong(_ song: Song) -> String {
        var lines: [String] = []
        lines.append("{title: \(song.title)}")
        if let artist = song.artist { lines.append("{artist: \(artist)}") }
        if let key = song.key { lines.append("{key: \(key)}") }
        lines.append("")
        for section in song.sections {
            if !section.label.isEmpty { lines.append("\(section.label):") }
            for line in section.lines {
                if !line.chords.isEmpty {
                    var lyrics = line.lyrics
                    let sorted = line.chords.sorted { $0.position > $1.position }
                    for cp in sorted {
                        let idx = lyrics.index(lyrics.startIndex, offsetBy: min(cp.position, lyrics.count))
                        lyrics.insert(contentsOf: "[\(cp.chord)]", at: idx)
                    }
                    lines.append(lyrics)
                } else {
                    lines.append(line.lyrics)
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Codeberg API JSON for a directory listing with one file.
    static func directoryListing(files: [(name: String, sha: String)]) -> Data {
        let items = files.map { name, sha -> [String: Any] in
            [
                "name": name,
                "path": "songs/\(name)",
                "sha": sha,
                "type": "file",
                "content": NSNull(),
                "encoding": NSNull(),
                "size": 100,
                "download_url": "https://codeberg.org/api/v1/repos/owner/repo/contents/songs/\(name)",
            ]
        }
        return (try? JSONSerialization.data(withJSONObject: items)) ?? Data()
    }

    /// Codeberg API JSON for a single file content response.
    static func fileContent(sha: String, content: String) -> Data {
        let base64 = Data(content.utf8).base64EncodedString()
        let dict: [String: Any] = [
            "name": "file.onsong",
            "path": "songs/file.onsong",
            "sha": sha,
            "type": "file",
            "content": base64,
            "encoding": "base64",
            "size": content.utf8.count,
            "download_url": "https://codeberg.org/api/v1/repos/owner/repo/contents/songs/file.onsong",
        ]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    /// Codeberg API JSON for a create/update response.
    static func createUpdateResponse(sha: String) -> Data {
        let dict: [String: Any] = [
            "content": [
                "name": "file.onsong",
                "path": "songs/file.onsong",
                "sha": sha,
                "type": "file",
                "size": 100,
            ],
            "commit": [
                "sha": "commit123",
                "commit": ["message": "Update file.onsong"],
            ],
        ]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    /// Codeberg API JSON for /user endpoint.
    static let userResponse: Data = """
    {"id": 1, "login": "testuser"}
    """.data(using: .utf8) ?? Data()

    /// Codeberg API JSON for branch ref.
    static func refResponse(sha: String = "abc123def") -> Data {
        let dict: [String: Any] = [
            "ref": "refs/heads/main",
            "object": ["sha": sha, "type": "commit", "url": "https://..."]
        ]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }

    /// Error response.
    static func errorResponse(message: String) -> Data {
        let dict: [String: Any] = ["message": message]
        return (try? JSONSerialization.data(withJSONObject: dict)) ?? Data()
    }
}
