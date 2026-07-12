import Foundation

// MARK: - SongSerializer

/// Serializes a ``Song`` back to ChordPro-flavored text — the inverse of ``SongParser``.
/// Canonical implementation shared by callers that persist songs (file storage, sync)
/// so there is exactly one place that knows the on-disk text format.
public enum SongSerializer {

    /// Render `song` as ChordPro-style text (metadata tags, section labels, inline
    /// chords, and `Key:` markers for key changes).
    public static func serialize(_ song: Song) -> String {
        var lines: [String] = []

        // Metadata as ChordPro tags
        lines.append("{title: \(song.title)}")
        if let artist = song.artist { lines.append("{artist: \(artist)}") }
        if let key = song.key { lines.append("{key: \(key)}") }
        if let tempo = song.tempo { lines.append("{tempo: \(tempo)}") }
        if let ccli = song.ccli { lines.append("{ccli: \(ccli)}") }
        if let copyright = song.copyright { lines.append("{copyright: \(copyright)}") }
        lines.append("")

        // Sections
        for section in song.sections {
            if !section.label.isEmpty {
                lines.append("\(section.label):")
            }
            for line in section.lines {
                if line.isKeyChange, let keyChange = line.keyChange {
                    lines.append("Key: \(keyChange.newKey)")
                } else if !line.chords.isEmpty {
                    // Inline chord format
                    var lyrics = line.lyrics
                    // Sort chords by position descending to insert correctly
                    let sortedChords = line.chords.sorted { $0.position > $1.position }
                    for chord in sortedChords {
                        let index = lyrics.index(lyrics.startIndex, offsetBy: min(chord.position, lyrics.count))
                        lyrics.insert(contentsOf: "[\(chord.chord)]", at: index)
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
}
