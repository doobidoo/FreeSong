import Foundation

// MARK: - AccidentalConverter

/// Converts chord accidentals between sharp and flat notation.
/// Works on both inline [C#m] and chords-above formats.
public enum AccidentalConverter {

    // Enharmonic mappings: sharp -> flat
    private static let sharpToFlat: [(sharp: String, flat: String)] = [
        ("C#", "Db"),
        ("D#", "Eb"),
        ("F#", "Gb"),
        ("G#", "Ab"),
        ("A#", "Bb")
    ]

    // MARK: - Public API

    /// Convert all sharps to flats in the content.
    /// Works on both inline [C#m] and chords-above C#m formats.
    /// - Parameter content: Text containing chords
    /// - Returns: Text with all sharps converted to flats
    public static func convertToFlats(_ content: String) -> String {
        var result = content
        result = convertInlineChords(result, toFlats: true)
        result = convertStandaloneChords(result, toFlats: true)
        return result
    }

    /// Convert all flats to sharps in the content.
    /// - Parameter content: Text containing chords
    /// - Returns: Text with all flats converted to sharps
    public static func convertToSharps(_ content: String) -> String {
        var result = content
        result = convertInlineChords(result, toFlats: false)
        result = convertStandaloneChords(result, toFlats: false)
        return result
    }

    /// Detect if content predominantly uses sharps or flats.
    /// - Parameter content: Text containing chords
    /// - Returns: `true` if predominantly sharps, `false` if flats (or equal/no accidentals)
    public static func isSharpsFormat(_ content: String) -> Bool {
        var sharpCount = 0
        var flatCount = 0

        let pattern = #/[A-G]([#b])/#
        for match in content.matches(of: pattern) {
            if match.output.1 == "#" {
                sharpCount += 1
            } else {
                flatCount += 1
            }
        }

        return sharpCount >= flatCount // Default to sharps if equal or no accidentals
    }

    // MARK: - Private Helpers

    /// Convert inline chords [C#m] -> [Dbm] or vice versa
    private static func convertInlineChords(_ content: String, toFlats: Bool) -> String {
        let pattern = #/\[([^\]]+)\]/#
        var result = ""
        var lastEnd = content.startIndex

        for match in content.matches(of: pattern) {
            let textBefore = String(content[lastEnd..<match.range.lowerBound])
            result += textBefore
            let chord = String(match.output.1)
            let converted = convertChord(chord, toFlats: toFlats)
            result += "[\(converted)]"
            lastEnd = match.range.upperBound
        }

        if lastEnd < content.endIndex {
            result += String(content[lastEnd...])
        }

        return result
    }

    /// Convert standalone chords (above format) on chord-only lines
    private static func convertStandaloneChords(_ content: String, toFlats: Bool) -> String {
        let lines = content.split(separator: "\n", omittingEmptySubsequences: false)
        var result: [String] = []

        for line in lines {
            if ChordFormatConverter.isChordOnlyLine(String(line)) {
                // Convert each chord on this line using a more comprehensive pattern
                let chordPattern = #/([A-G][#b♯♭]?)(m|min|mi|-|M|maj|Maj|△|Δ|dim|°|o|aug|\+|ø|hdim)*(\d+)?(\/\d+)?(sus[24]?|add\d+|[#b♯♭]\d+|no\d+|alt)*(\/[A-G][#b♯♭]?)?/#
                var convertedLine = String(line)
                let matches = line.matches(of: chordPattern)
                // Process in reverse to maintain indices
                for match in matches.reversed() {
                    let fullChord = String(line[match.range])
                    let converted = convertChord(fullChord, toFlats: toFlats)
                    // Convert range from Substring to String indices
                    let startIdx = convertedLine.index(convertedLine.startIndex, offsetBy: line.distance(from: line.startIndex, to: match.range.lowerBound))
                    let endIdx = convertedLine.index(convertedLine.startIndex, offsetBy: line.distance(from: line.startIndex, to: match.range.upperBound))
                    convertedLine.replaceSubrange(startIdx..<endIdx, with: converted)
                }
                result.append(convertedLine)
            } else {
                result.append(String(line))
            }
        }

        return result.joined(separator: "\n")
    }

    /// Convert a single chord's accidentals.
    private static func convertChord(_ chord: String, toFlats: Bool) -> String {
        guard !chord.isEmpty else { return chord }

        // Handle slash chords (G/B, C#m/G#)
        if let slashIndex = chord.firstIndex(of: "/") {
            let mainPart = String(chord[..<slashIndex])
            let bassPart = String(chord[chord.index(after: slashIndex)...])
            return convertChord(mainPart, toFlats: toFlats) + "/" + convertChord(bassPart, toFlats: toFlats)
        }

        if toFlats {
            // Sharp to flat - check both ASCII and Unicode
            for pair in sharpToFlat {
                if chord.hasPrefix(pair.sharp) {
                    return pair.flat + chord.dropFirst(pair.sharp.count)
                }
                // Unicode sharp to flat
                let unicodeSharp = pair.sharp.replacingOccurrences(of: "#", with: "♯")
                if chord.hasPrefix(unicodeSharp) {
                    return pair.flat + chord.dropFirst(unicodeSharp.count)
                }
            }
        } else {
            // Flat to sharp - check both ASCII and Unicode
            for pair in sharpToFlat {
                if chord.hasPrefix(pair.flat) {
                    return pair.sharp + chord.dropFirst(pair.flat.count)
                }
                // Unicode flat to sharp
                let unicodeFlat = pair.flat.replacingOccurrences(of: "b", with: "♭")
                if chord.hasPrefix(unicodeFlat) {
                    return pair.sharp + chord.dropFirst(unicodeFlat.count)
                }
            }
        }
        return chord
    }
}