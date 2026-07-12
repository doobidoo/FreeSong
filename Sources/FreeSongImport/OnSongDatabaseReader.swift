import Foundation
import ZIPFoundation
import SQLite
import FreeSongCore
import FreeSongStorage

// MARK: - OnSong Database Reader

/// Read-only access to OnSong SQLite database.
/// Extracts songs and setlists from OnSong.sqlite3.
public actor OnSongDatabaseReader {

    private let db: Connection

    public init(databasePath: String) throws {
        do {
            self.db = try Connection(databasePath, readonly: true)
        } catch {
            throw BackupImportError.databaseError("Failed to open database: \(error)")
        }
    }

    /// Song record from OnSong database.
    public struct OnSongSong: Sendable {
        public let id: String
        public let title: String
        public let artist: String?
        public let key: String?
        public let content: String
    }

    /// Setlist record from OnSong database.
    public struct OnSongSetlist: Sendable {
        public let id: String
        public let title: String
        public let items: [OnSongSetlistItem]
    }

    /// Setlist item from OnSong database.
    public struct OnSongSetlistItem: Sendable {
        public let songId: String
        public let title: String
        public let key: String?
        public let artist: String?
        public let orderIndex: Int
    }

    /// Import all songs from OnSong database.
    /// - Returns: Array of OnSongSong records
    public func importSongs() throws -> [OnSongSong] {
        var songs: [OnSongSong] = []

        let songTable = Table("Song")
        let id = Expression<String>("ID")
        let title = Expression<String?>("title")
        let byline = Expression<String?>("byline")
        let key = Expression<String?>("key")
        let content = Expression<String?>("content")

        let query = songTable.select(id, title, byline, key, content)
            .filter(content != nil && content != "")

        for row in try db.prepare(query) {
            guard let songTitle = row[title], !songTitle.trimmingCharacters(in: .whitespaces).isEmpty,
                  let songContent = row[content], !songContent.trimmingCharacters(in: .whitespaces).isEmpty else {
                continue
            }

            let song = OnSongSong(
                id: row[id],
                title: songTitle,
                artist: row[byline],
                key: row[key],
                content: songContent
            )
            songs.append(song)
        }

        return songs
    }

    /// Import all setlists from OnSong database.
    /// - Returns: Array of OnSongSetlist records
    public func importSetlists() throws -> [OnSongSetlist] {
        var setlists: [OnSongSetlist] = []

        let setTable = Table("SongSet")
        let setId = Expression<String>("ID")
        let setTitle = Expression<String?>("title")

        // Get all setlists
        let setlistsQuery = setTable.select(setId, setTitle)
            .filter(setTitle != nil && setTitle != "")
            .order(setTitle)

        for setRow in try db.prepare(setlistsQuery) {
            let setlistId = setRow[setId]
            let setlistTitle = setRow[setTitle]?.trimmingCharacters(in: .whitespaces) ?? ""

            guard !setlistTitle.isEmpty else { continue }

            // Get items for this setlist
            let itemTable = Table("SongSetItem")
            let itemSetId = Expression<String>("setID")
            let songId = Expression<String>("songID")
            let orderIndex = Expression<Int>("orderIndex")

            let songTable = Table("Song")
            let songTitle = Expression<String?>("title")
            let songKey = Expression<String?>("key")
            let songArtist = Expression<String?>("byline")

            let itemsQuery = itemTable
                .join(songTable, on: songTable[Expression<String>("ID")] == itemTable[songId])
                .filter(itemSetId == setlistId)
                .select(songId, songTitle, songKey, songArtist, orderIndex)
                .order(orderIndex)

            var items: [OnSongSetlistItem] = []
            for itemRow in try db.prepare(itemsQuery) {
                guard let title = itemRow[songTitle], !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                    continue
                }

                let item = OnSongSetlistItem(
                    songId: itemRow[songId],
                    title: title,
                    key: itemRow[songKey],
                    artist: itemRow[songArtist],
                    orderIndex: itemRow[orderIndex]
                )
                items.append(item)
            }

            if !items.isEmpty {
                let setlist = OnSongSetlist(
                    id: setlistId,
                    title: setlistTitle,
                    items: items
                )
                setlists.append(setlist)
            }
        }

        return setlists
    }

    // Connection is closed on deinit — no explicit close needed.
}