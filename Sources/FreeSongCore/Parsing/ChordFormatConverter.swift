import Foundation

// MARK: - ChordFormatConverter

/// Utility for converting between chord formats:
/// - Inline chords: `[G]Amazing [D]grace` (ChordPro style)
/// - Chords above lyrics: Chords on separate line above lyrics (OnSong style)
public enum ChordFormatConverter {

    private static let chordPattern = #/\[([^\]]+)\]/#

    // MARK: - Public API

    /// Convert inline chords `[G]lyrics` to chords-above format.
    /// Example: `"[G]Amazing [D]grace"` becomes:
    /// `"G       D\nAmazing grace"`
    /// - Parameter content: Text with inline chords
    /// - Returns: Text with chords on separate lines above lyrics
    public static func inlineToAbove(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var outLines: [String] = []

        for lineStr in lines {
            if hasInlineChords(lineStr) {
                var chordLine = ""
                var lyricsLine = ""

                var lastEnd = lineStr.startIndex

                for match in lineStr.matches(of: chordPattern) {
                    // Add text before this chord to lyrics
                    let textBefore = String(lineStr[lastEnd..<match.range.lowerBound])
                    lyricsLine += textBefore
                    let chordPosition = lyricsLine.count

                    // Position chord above the next character
                    if chordLine.count < chordPosition {
                        chordLine += String(repeating: " ", count: chordPosition - chordLine.count)
                    } else if !chordLine.isEmpty {
                        // Touching or overlapping the previous chord (chordLine always ends
                        // with the previous chord's own text at this point, never a space) —
                        // force exactly one separating space so both chords stay distinguishable
                        // tokens on the way back to inline (accept the resulting visual overlap).
                        chordLine += " "
                    }
                    chordLine += match.output.1

                    lastEnd = match.range.upperBound
                }

                // Add remaining text
                if lastEnd < lineStr.endIndex {
                    lyricsLine += String(lineStr[lastEnd...])
                }

                // Only add chord line if there were chords
                if !chordLine.isEmpty {
                    outLines.append(chordLine)
                }
                outLines.append(lyricsLine)
            } else {
                outLines.append(lineStr)
            }
        }

        return outLines.joined(separator: "\n")
    }

    /// Convert chords-above format to inline `[G]lyrics`.
    /// Example:
    /// `"G       D\nAmazing grace"` becomes `"[G]Amazing [D]grace"`
    /// - Parameter content: Text with chords above lyrics
    /// - Returns: Text with inline chords
    public static func aboveToInline(_ content: String) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var outLines: [String] = []

        var i = 0
        while i < lines.count {
            let line = lines[i]

            // Check if this is a chord-only line followed by a lyrics line
            if isChordOnlyLine(line) && i + 1 < lines.count && !isChordOnlyLine(lines[i + 1]) {
                outLines.append(mergeChordAndLyrics(chordLine: line, lyricsLine: lines[i + 1]))
                i += 2 // Skip the lyrics line since we merged it
            } else {
                outLines.append(line)
                i += 1
            }
        }

        return outLines.joined(separator: "\n")
    }

    /// Check if a line contains inline chords `[chord]`.
    public static func hasInlineChords(_ line: String) -> Bool {
        line.firstMatch(of: chordPattern) != nil
    }

    /// Check if a line contains only chord symbols (OnSong format).
    /// Supports comprehensive chord notation including:
    /// - Basic: C, Am, G7, Dm7
    /// - Extended: Cmaj7, Cm7b5, C7#9, C9#11
    /// - Minor-Major: CmM7, CmMaj7, Cm(maj7), Cm△7
    /// - Alterations: C7#5, C7b9, Cm7#5, C7#5#9
    /// - Suspended: Csus4, C7sus4, Csus2
    /// - Added: Cadd9, C6/9, Cadd11
    /// - Diminished: Cdim, Cdim7, C°, C°7
    /// - Augmented: Caug, C+, C+7
    /// - Half-diminished: Cø, Cø7, Cm7b5, Chdim7
    /// - Slash chords: C/E, Am/G, Dm7/C
    /// - Unicode symbols: C♯, D♭, C△7, C°, Cø
    public static func isChordOnlyLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        let parts = trimmed.split(separator: " ")
        guard !parts.isEmpty else { return false }

        var chordCount = 0
        for part in parts {
            if isValidChord(String(part)) {
                chordCount += 1
            } else {
                return false // Contains non-chord text
            }
        }
        return chordCount > 0
    }

    /// Detect if content primarily uses inline chords format.
    /// - Parameter content: Text to analyze
    /// - Returns: `true` if inline format, `false` if above format
    public static func isInlineFormat(_ content: String) -> Bool {
        let lines = content.split(separator: "\n")
        var inlineCount = 0
        var aboveCount = 0

        for line in lines {
            let lineStr = String(line)
            if hasInlineChords(lineStr) {
                inlineCount += 1
            } else if isChordOnlyLine(lineStr) {
                aboveCount += 1
            }
        }

        // If more inline chords than chord-only lines, it's inline format
        return inlineCount > aboveCount
    }

    // MARK: - Chord Shifting (inline format only)

    /// Move a chord left or right within its line in inline format content.
    /// Identifies the target chord by its global occurrence index across all content lines.
    /// - Parameters:
    ///   - content: Raw song content in inline format
    ///   - globalChordOccurrence: 0-based index of the [chord] tag across all lines
    ///   - delta: Chars to move; positive = right, negative = left
    ///   - wordwise: If true, jump to next/previous word boundary
    /// - Returns: Updated content, or original if chord not found
    public static func shiftChord(in content: String, globalChordOccurrence: Int, delta: Int, wordwise: Bool) -> String {
        // Find all [chord] occurrences and their line
        var lines = content.components(separatedBy: "\n")
        var occurrence = 0
        for lineIndex in lines.indices {
            // CRLF content: exclude a trailing "\r" from the shiftable range so it's
            // never treated as shiftable lyric text; it gets reattached afterward.
            let hasCR = lines[lineIndex].hasSuffix("\r")
            let line = hasCR ? String(lines[lineIndex].dropLast()) : lines[lineIndex]

            var ranges: [Range<String.Index>] = []
            var search = line.startIndex
            while search < line.endIndex,
                  let open = line[search...].range(of: "["),
                  let close = line.range(of: "]", range: line.index(after: open.lowerBound)..<line.endIndex) {
                ranges.append(open.lowerBound..<line.index(after: close.lowerBound))
                search = close.upperBound
            }
            for chordIndex in ranges.indices {
                if occurrence == globalChordOccurrence {
                    let shifted = shiftChordInLine(line, chordIndex: chordIndex, delta: delta, wordwise: wordwise)
                    lines[lineIndex] = hasCR ? shifted + "\r" : shifted
                    return lines.joined(separator: "\n")
                }
                occurrence += 1
            }
        }
        return content
    }

    private static func shiftChordInLine(_ line: String, chordIndex: Int, delta: Int, wordwise: Bool) -> String {
        // Step 1: strip ALL chord tags to get pure lyrics text + a mapping of chord→lyric position
        var stripped = ""
        var chordPositions: [(tag: String, lyricsPos: Int)] = []
        var remaining = line[...]
        while !remaining.isEmpty {
            if let open = remaining.range(of: "["),
               let close = remaining.range(of: "]", range: open.upperBound..<remaining.endIndex) {
                stripped += String(remaining[..<open.lowerBound])
                // Half-open range: exactly "[chord]", not one character past it. A closed
                // range here would also crash when the chord is the last thing on the line
                // (close.upperBound == remaining.endIndex is not a valid closed-range bound).
                chordPositions.append((tag: String(remaining[open.lowerBound..<close.upperBound]), lyricsPos: stripped.count))
                remaining = remaining[close.upperBound...]
            } else {
                stripped += String(remaining)
                break
            }
        }
        guard chordIndex < chordPositions.count else { return line }

        // Step 2: compute new lyrics position for the selected chord
        var pos = chordPositions[chordIndex].lyricsPos
        if wordwise {
            pos = wordBoundary(in: stripped, from: pos, forward: delta > 0)
        } else {
            pos = max(0, min(stripped.count, pos + delta))
        }
        chordPositions[chordIndex] = (tag: chordPositions[chordIndex].tag, lyricsPos: pos)

        // Step 3: rebuild line — insert chord tags at their (possibly updated) lyrics positions.
        // Sort by position, breaking ties by original index rather than relying on
        // sort stability, so equal-position chords keep their original relative order.
        let sorted = chordPositions.enumerated().sorted { a, b in
            if a.element.lyricsPos != b.element.lyricsPos { return a.element.lyricsPos < b.element.lyricsPos }
            return a.offset < b.offset
        }
        var result = ""
        var cursor = stripped.startIndex
        for cp in sorted {
            let targetIdx = stripped.index(stripped.startIndex, offsetBy: min(cp.element.lyricsPos, stripped.count))
            result += String(stripped[cursor..<targetIdx])
            result += cp.element.tag
            cursor = targetIdx
        }
        result += String(stripped[cursor...])
        return result
    }

    /// Find the next/previous word boundary position.
    private static func wordBoundary(in text: String, from pos: Int, forward: Bool) -> Int {
        let chars = Array(text)
        if forward {
            var i = pos + 1
            while i < chars.count && chars[i] != " " { i += 1 }
            while i < chars.count && chars[i] == " " { i += 1 }
            return min(i, chars.count)
        } else {
            var i = pos - 1
            while i > 0 && chars[i - 1] == " " { i -= 1 }
            while i > 0 && chars[i - 1] != " " { i -= 1 }
            return max(0, i)
        }
    }

    // MARK: - Private Helpers

    /// Check if a string is a valid chord symbol.
    private static func isValidChord(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }

        // Remove parentheses for matching (e.g., m(maj7) -> mmaj7)
        let normalized = s.replacingOccurrences(of: #"[()]"#, with: "", options: .regularExpression)

        // Comprehensive chord regex matching Java implementation
        let pattern = #/^[A-G][#b♯♭]?(m|min|mi|-|M|maj|Maj|△|Δ|dim|°|o|aug|\+|ø|hdim)*(\d+)?(\/\d+)?(sus[24]?|add\d+|[#b♯♭]\d+|no\d+|alt)*(\/[A-G][#b♯♭]?)?$/#

        return normalized.firstMatch(of: pattern) != nil
    }

    /// Merge a chord line with a lyrics line into inline chord format.
    /// Chords are inserted at their character positions.
    private static func mergeChordAndLyrics(chordLine: String, lyricsLine: String) -> String {
        // Parse chords and their positions from chord line
        struct ChordPos {
            let chord: String
            let position: Int
        }

        var chords: [ChordPos] = []
        var pos = 0
        var currentChord = ""

        for (index, char) in chordLine.enumerated() {
            if char == " " || char == "\t" {
                if !currentChord.isEmpty {
                    chords.append(ChordPos(chord: currentChord, position: pos))
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
            chords.append(ChordPos(chord: currentChord, position: pos))
        }

        // Clamp every chord to the lyrics' own true bounds — a column past the end of
        // the lyrics (because an earlier overlap pushed it right, see `inlineToAbove`)
        // is not a real later lyric position, just visual overlap that leaked into the
        // column count. Insert in reverse scan order so each insertion's offset is
        // computed before any bracket to its own right shifts the string, and ties at
        // the same clamped position naturally keep their original left-to-right order.
        let lyricsLen = lyricsLine.count
        var result = lyricsLine
        for chordPos in chords.reversed() {
            let clamped = min(chordPos.position, lyricsLen)
            let index = result.index(result.startIndex, offsetBy: clamped)
            result.insert(contentsOf: "[\(chordPos.chord)]", at: index)
        }

        return result
    }
}