import Foundation
import FreeSongCore

// MARK: - OnSong to FreeSong Converter

/// Converts OnSong database records into FreeSong domain models.
///
/// Handles:
/// - Parsing OnSong content into structured Song objects (sections, lines, chords)
/// - Merging database-sourced metadata (title, artist, key) with content-parsed values
/// - Validating required fields (title, content)
public enum OnSongConverter {

    /// Errors that can occur during conversion.
    public enum ConversionError: Error, LocalizedError {
        /// Song has no title (required field).
        case emptyTitle
        /// Song content is empty or blank.
        case emptyContent
        /// Content could not be parsed into a valid Song structure.
        case parseFailed(String)

        public var errorDescription: String? {
            switch self {
            case .emptyTitle:
                return "Song has no title"
            case .emptyContent:
                return "Song content is empty"
            case .parseFailed(let msg):
                return "Failed to parse song content: \(msg)"
            }
        }
    }

    /// Convert an OnSong database song record to a FreeSong domain `Song`.
    ///
    /// - Parameter onSong: Song record from the OnSong SQLite database.
    /// - Returns: A fully parsed `Song` with metadata merged from the database record.
    /// - Throws: `ConversionError` if the song cannot be converted.
    public static func convertToSong(_ onSong: OnSongDatabaseReader.OnSongSong) throws -> Song {
        // Validate: title is required
        let trimmedTitle = onSong.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else {
            throw ConversionError.emptyTitle
        }

        // Validate: content must be non-empty
        let trimmedContent = onSong.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else {
            throw ConversionError.emptyContent
        }

        // Parse content through the existing SongParser
        var song = SongParser.parse(onSong.content)

        // DB metadata takes precedence over content-parsed metadata.
        // The OnSong database stores authoritative metadata in columns;
        // content may have outdated or missing tags.
        song.title = trimmedTitle

        if let artist = onSong.artist, !artist.trimmingCharacters(in: .whitespaces).isEmpty {
            song.artist = artist
        }

        if let key = onSong.key, !key.trimmingCharacters(in: .whitespaces).isEmpty {
            song.key = key
        }

        // Clear rawContent so FileSongRepository.saveSong() generates
        // structured FreeSong content (ChordPro-style) instead of
        // re-writing the raw OnSong format.
        song.rawContent = ""

        // Basic validation: parsed song should have at least some content
        if song.sections.isEmpty && song.title.isEmpty && song.rawContent.isEmpty {
            throw ConversionError.parseFailed("No sections could be extracted from content")
        }

        return song
    }
}
