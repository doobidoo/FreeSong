import Foundation

// MARK: - SongParser

/// Parser for OnSong, ChordPro, and plain text song file formats.
/// Handles metadata extraction, section parsing, chord positioning, and key changes.
public enum SongParser {

    // MARK: - Patterns

    private static let chordPattern = #/\[([^\]]+)\]/#
    private static let chordProTagPattern = #/\{([^:}]+)(?::([^}]*))?\}/#
    private static let sectionLabelPattern = #/^(Verse|Chorus|Bridge|Pre-?Chorus|Intro|Outro|Tag|Interlude|Instrumental|Ending|Coda|Refrain|Strophe|Vamp)\s*(\d*):?\s*$/#
    private static let keyChangePattern = #/(?i)^Key:\s*([A-G][#b♯♭]?m?)\s*$/#

    // MARK: - Public API

    /// Parse a song file from disk.
    /// - Parameter url: File URL to parse
    /// - Returns: Parsed Song object
    /// - Throws: Error if file cannot be read
    public static func parseFile(at url: URL) throws -> Song {
        let content = try String(contentsOf: url, encoding: .utf8)
        return parse(content)
    }

    /// Parse only metadata (title, artist) from a file.
    /// Reads only the first 30 lines for performance.
    /// - Parameter url: File URL to parse
    /// - Returns: Tuple of (title, artist)
    /// - Throws: Error if file cannot be read
    public static func parseMetadataOnly(at url: URL) throws -> (title: String, artist: String?) {
        var title: String? = nil
        var artist: String? = nil
        var firstLine = true
        var secondLine = true
        var lineCount = 0
        let maxLines = 30
        var titleFromPlainLine = false
        var foundChordOrSection = false

        let data = try Data(contentsOf: url)
        guard let content = String(data: data, encoding: .utf8) else {
            throw SongParserError.invalidEncoding
        }

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)

        for line in lines {
            if lineCount >= maxLines { break }
            lineCount += 1

            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty { continue }

            // Check for ChordPro tags {tag: value}
            if let match = trimmedLine.firstMatch(of: chordProTagPattern) {
                let tag = String(match.output.1).lowercased()
                let value = (match.output.2?.isEmpty ?? true ? "" : String(match.output.2!)).trimmingCharacters(in: .whitespaces)

                if (tag == "title" || tag == "t") && title == nil {
                    title = value
                } else if (tag == "subtitle" || tag == "st" || tag == "su" || tag == "artist") && artist == nil {
                    artist = value
                }

                if title != nil && artist != nil {
                    return (title!, artist)
                }
            }

            // Track song-structure indicators so we can distinguish real OnSong
            // files from plain text that happens to have 2+ lines.
            if trimmedLine.firstMatch(of: keyChangePattern) != nil
                || trimmedLine.firstMatch(of: chordPattern) != nil
                || trimmedLine.firstMatch(of: sectionLabelPattern) != nil
                || isChordOnlyLine(trimmedLine) {
                foundChordOrSection = true
            }

            // OnSong format: first non-tag line is title, second is artist
            if firstLine && !trimmedLine.hasPrefix("{") && !trimmedLine.hasPrefix("[") {
                if title == nil {
                    title = trimmedLine
                    titleFromPlainLine = true
                }
                firstLine = false
                continue
            }

            if secondLine && !trimmedLine.hasPrefix("{") && !trimmedLine.hasPrefix("[") &&
               trimmedLine.firstMatch(of: chordPattern) == nil &&
               !isChordOnlyLine(trimmedLine) {
                if artist == nil {
                    artist = trimmedLine
                }
                secondLine = false

                if title != nil && (titleFromPlainLine == false || foundChordOrSection) {
                    return (title!, artist ?? "")
                }
            }

            firstLine = false
            secondLine = false
        }

        // Fallback: use filename as title
        // Only use OnSong first-line heuristic if we found song indicators.
        if title == nil || title!.isEmpty || (titleFromPlainLine && !foundChordOrSection) {
            let name = url.lastPathComponent
            if let dotIndex = name.lastIndex(of: ".") {
                title = String(name[..<dotIndex])
            } else {
                title = name
            }
            if titleFromPlainLine && !foundChordOrSection {
                artist = nil
            }
        }

        return (title!, artist)
    }

    /// Parse song content from string.
    /// - Parameter content: Raw song text
    /// - Returns: Parsed Song object
    public static func parse(_ content: String) -> Song {
        var song = Song()
        song.rawContent = content

        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var firstLine = true
        var secondLine = true
        var hasBaseKey = false // Track if we've set the initial key
        var hasContent = false // Track if we have any song content (sections/lines)
        var currentSection = SongSection(label: "")
        var pendingChordLine: String? = nil // For OnSong format: chord line above lyrics

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines
            if trimmedLine.isEmpty {
                // If we have a pending chord line with no lyrics, add it
                if let pending = pendingChordLine {
                    let songLine = parseChordOnlyLine(pending)
                    currentSection.lines.append(songLine)
                    pendingChordLine = nil
                }
                continue
            }

            // Check for OnSong-style key change: "Key: D"
            if let match = trimmedLine.firstMatch(of: keyChangePattern) {
                let newKey = String(match.output.1)
                // Flush pending chord line
                if let pending = pendingChordLine {
                    let songLine = parseChordOnlyLine(pending)
                    currentSection.lines.append(songLine)
                    pendingChordLine = nil
                }
                // If we already have content, this is a key change, not the base key
                if !hasBaseKey && !hasContent {
                    // First key directive before any content - set as base key
                    song.key = newKey
                    hasBaseKey = true
                } else {
                    // Key after content exists - create key change line
                    if !hasBaseKey {
                        // No base key was set, but we have content - can't infer base key
                    }
                    let keyChangeLine = SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: newKey))
                    currentSection.lines.append(keyChangeLine)
                }
                firstLine = false
                secondLine = false
                continue
            }

            // Check for ChordPro tags {tag: value}
            if let match = trimmedLine.firstMatch(of: chordProTagPattern) {
                let tag = String(match.output.1).lowercased()
                let value = (match.output.2?.isEmpty ?? true ? "" : String(match.output.2!)).trimmingCharacters(in: .whitespaces)

                // Handle key tag specially for key changes
                if tag == "key" {
                    if !hasBaseKey && !hasContent {
                        // First key before any content - set as base key
                        song.key = value
                        hasBaseKey = true
                    } else {
                        // Key after content exists - create key change line
                        // Flush pending chord line
                        if let pending = pendingChordLine {
                            let songLine = parseChordOnlyLine(pending)
                            currentSection.lines.append(songLine)
                            pendingChordLine = nil
                        }
                        let keyChangeLine = SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: value))
                        currentSection.lines.append(keyChangeLine)
                    }
                    // If the whole line is just this tag, skip to next line
                    if match.range.lowerBound == trimmedLine.startIndex &&
                       match.range.upperBound == trimmedLine.endIndex {
                        firstLine = false
                        secondLine = false
                        continue
                    }
                } else {
                    processTag(song: &song, tag: tag, value: value)

                    // If the whole line is just a tag, skip to next line
                    if match.range.lowerBound == trimmedLine.startIndex &&
                       match.range.upperBound == trimmedLine.endIndex {
                        firstLine = false
                        secondLine = false
                        continue
                    }
                }
            }

            // Check for section labels (Verse 1:, Chorus:, etc.)
            if let match = trimmedLine.firstMatch(of: sectionLabelPattern) {
                // Flush pending chord line
                if let pending = pendingChordLine {
                    let songLine = parseChordOnlyLine(pending)
                    currentSection.lines.append(songLine)
                    pendingChordLine = nil
                    hasContent = true
                }
                // Save previous section if it has content
                if !currentSection.lines.isEmpty {
                    song.sections.append(currentSection)
                }
                // Start new section
                let label = String(match.output.1)
                let num = String(match.output.2)
                currentSection = SongSection(label: label + (num.isEmpty ? "" : " \(num)"))
                hasContent = true // Section label counts as content
                firstLine = false
                secondLine = false
                continue
            }

            // OnSong format: first line is title, second line is artist
            if firstLine && !trimmedLine.hasPrefix("{") && !trimmedLine.hasPrefix("[") {
                if song.title.isEmpty {
                    song.title = trimmedLine
                }
                firstLine = false
                continue
            }
            if secondLine && !trimmedLine.hasPrefix("{") && !trimmedLine.hasPrefix("[") &&
               trimmedLine.firstMatch(of: chordPattern) == nil &&
               !isChordOnlyLine(trimmedLine) {
                if song.artist == nil || song.artist!.isEmpty {
                    song.artist = trimmedLine
                }
                secondLine = false
                continue
            }

            firstLine = false
            secondLine = false

            // Check if this is a chord-only line (OnSong format)
            if isChordOnlyLine(trimmedLine) {
                // Flush any existing pending chord line
                if let pending = pendingChordLine {
                    let songLine = parseChordOnlyLine(pending)
                    currentSection.lines.append(songLine)
                    hasContent = true
                }
                // Store this chord line to combine with next lyrics line
                // Keep original spacing for position calculation
                pendingChordLine = String(line)
                continue
            }

            // This is a lyrics line (possibly with inline [chords])
            if let pending = pendingChordLine {
                // Combine pending chord line with this lyrics line
                let songLine = parseLineWithChordAbove(chordLine: pending, lyricsLine: trimmedLine)
                currentSection.lines.append(songLine)
                pendingChordLine = nil
            } else {
                // Parse line with inline chords [chord]
                let songLine = parseLine(trimmedLine)
                currentSection.lines.append(songLine)
            }
            hasContent = true
        }

        // Flush any remaining pending chord line
        if let pending = pendingChordLine {
            let songLine = parseChordOnlyLine(pending)
            currentSection.lines.append(songLine)
        }

        // Add last section
        if !currentSection.lines.isEmpty {
            song.sections.append(currentSection)
        }

        return song
    }

    // MARK: - Private Helpers

    /// Check if a line contains only chord symbols (OnSong format).
    private static func isChordOnlyLine(_ line: String) -> Bool {
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: " ")
        if parts.isEmpty { return false }

        var chordCount = 0
        for part in parts {
            if part.isEmpty { continue }
            if isValidChord(String(part)) {
                chordCount += 1
            } else {
                return false // Contains non-chord text
            }
        }
        return chordCount > 0
    }

    /// Check if a string is a valid chord symbol.
    /// Supports comprehensive chord notation matching the Java implementation.
    private static func isValidChord(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }

        // Remove parentheses for matching (e.g., m(maj7) -> mmaj7)
        let normalized = s.replacingOccurrences(of: #"[()]"#, with: "", options: .regularExpression)

        // Support standalone bass notation like /G, /Bb, /F# (bass movement without explicit chord)
        // This is common notation meaning "keep previous chord, move bass to this note"
        if normalized.firstMatch(of: #/^\/[A-G][#b♯♭]?$/#) != nil {
            return true
        }

        let pattern = #/^[A-G][#b♯♭]?(m|min|mi|-|M|maj|Maj|△|Δ|dim|°|o|aug|\+|ø|hdim)*(\d+)?(\/\d+)?(sus[24]?|add\d+|[#b♯♭]\d+|no\d+|alt)*(\/[A-G][#b♯♭]?)?$/#

        return normalized.firstMatch(of: pattern) != nil
    }

    /// Parse a chord-only line into a SongLine (chords with no lyrics).
    private static func parseChordOnlyLine(_ chordLine: String) -> SongLine {
        var songLine = SongLine(lyrics: "", chords: [])

        var pos = 0
        var currentChord = ""

        for (index, char) in chordLine.enumerated() {
            if char == " " || char == "\t" {
                if !currentChord.isEmpty {
                    songLine.chords.append(ChordPosition(chord: currentChord, position: pos))
                    currentChord = ""
                }
                pos = index + 1
            } else {
                if currentChord.isEmpty {
                    pos = index
                }
                currentChord.append(char)
            }
        }
        if !currentChord.isEmpty {
            songLine.chords.append(ChordPosition(chord: currentChord, position: pos))
        }

        return songLine
    }

    /// Parse a lyrics line with a chord line positioned above it.
    private static func parseLineWithChordAbove(chordLine: String, lyricsLine: String) -> SongLine {
        var songLine = SongLine(lyrics: lyricsLine, chords: [])

        var pos = 0
        var currentChord = ""

        for (index, char) in chordLine.enumerated() {
            if char == " " || char == "\t" {
                if !currentChord.isEmpty {
                    songLine.chords.append(ChordPosition(chord: currentChord, position: pos))
                    currentChord = ""
                }
            } else {
                if currentChord.isEmpty {
                    pos = index // Position where chord starts
                }
                currentChord.append(char)
            }
        }
        if !currentChord.isEmpty {
            songLine.chords.append(ChordPosition(chord: currentChord, position: pos))
        }

        return songLine
    }

    /// Process a ChordPro tag and update song metadata.
    private static func processTag(song: inout Song, tag: String, value: String) {
        switch tag {
        case "title", "t":
            song.title = value
        case "subtitle", "st", "su", "artist":
            song.artist = value
        case "key":
            song.key = value
        case "tempo":
            song.tempo = value
        case "ccli":
            song.ccli = value
        case "copyright", "footer", "f":
            song.copyright = value
        default:
            break
        }
    }

    /// Parse a single line, extracting chords and lyrics.
    private static func parseLine(_ line: String) -> SongLine {
        var songLine = SongLine(lyrics: "", chords: [])
        var lyrics = ""
        var lastEnd = line.startIndex

        for match in line.matches(of: chordPattern) {
            // Add text before this chord
            let textBefore = String(line[lastEnd..<match.range.lowerBound])
            lyrics += textBefore

            // Chord position is AFTER the preceding text (where the chord appears)
            let position = lyrics.count

            // Add chord at current position
            let chord = String(match.output.1)
            songLine.chords.append(ChordPosition(chord: chord, position: position))

            lastEnd = match.range.upperBound
        }

        // Add remaining text
        if lastEnd < line.endIndex {
            lyrics += String(line[lastEnd...])
        }

        songLine.lyrics = lyrics
        return songLine
    }
}

// MARK: - Errors

public enum SongParserError: Error, LocalizedError {
    case invalidEncoding
    case fileNotFound
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidEncoding: return "File encoding is not valid UTF-8"
        case .fileNotFound: return "File not found"
        case .parseError(let msg): return "Parse error: \(msg)"
        }
    }
}