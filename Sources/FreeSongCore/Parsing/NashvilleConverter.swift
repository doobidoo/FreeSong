import Foundation

// MARK: - NashvilleConverter

/// Converts between standard chord symbols and Nashville Number System notation.
/// Preserves chord qualities (m, 7, maj7, dim, aug, sus, add, etc.) after the numbers.
public enum NashvilleConverter {

    // MARK: - Constants

    private static let notesSharp = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let notesFlat = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    // Major scale degrees: 0=1, 2=2, 4=3, 5=4, 7=5, 9=6, 11=7
    private static let majorScaleDegrees = [0, 2, 4, 5, 7, 9, 11]

    // Pattern to match chord root (including Unicode accidentals)
    private static let chordRootPattern = #/^([A-G][#b♯♭]?)(.*)$/#

    // Pattern to match Nashville notation (e.g., "1", "2m", "57", "4maj7", "6dim", "#4", "b5", etc.)
    // Accidental can appear before the degree (e.g. "#4") or after (e.g. "4#" — legacy).
    private static let nashvillePattern = #/^([#b♯♭]?[1-7])(.*)$/#

    // MARK: - Public API

    /// Convert a chord to Nashville Number System notation relative to a key.
    /// - Parameters:
    ///   - chord: The chord to convert (e.g., "Am7", "F#m", "G/B")
    ///   - key: The key of the song (e.g., "C", "G", "F#")
    /// - Returns: Nashville notation (e.g., "6m7", "7m", "5")
    public static func chordToNashville(_ chord: String, key: String) -> String {
        guard !chord.isEmpty, !key.isEmpty else { return chord }

        // Handle slash chords (e.g., G/B)
        if let slashIndex = chord.firstIndex(of: "/") {
            let mainChord = String(chord[..<slashIndex])
            let bassNote = String(chord[chord.index(after: slashIndex)...])
            return chordToNashville(mainChord, key: key) + "/" + chordToNashville(bassNote, key: key)
        }

        // Extract root and quality
        guard let match = chord.firstMatch(of: chordRootPattern) else {
            return chord // Unrecognized chord
        }

        let root = String(match.output.1)
        let quality = String(match.output.2)

        // Get key root index
        guard let keyRootIndex = noteIndex(for: key) else { return chord }
        guard let chordRootIndex = noteIndex(for: root) else { return chord }

        // Calculate semitone distance from key root (0-11)
        var semitones = chordRootIndex - keyRootIndex
        if semitones < 0 { semitones += 12 }

        // Convert to Nashville number with accidental
        let nashvilleNumber = semitoneToNashville(semitones)

        // Preserve quality suffix
        return nashvilleNumber + quality
    }

    /// Convert Nashville notation back to a chord symbol given a key.
    /// - Parameters:
    ///   - nashville: The Nashville notation (e.g., "6m7", "5", "4maj7")
    ///   - key: The key of the song (e.g., "C", "G", "F#")
    ///   - preferFlats: Whether to use flat notation for accidentals
    /// - Returns: Standard chord symbol
    public static func nashvilleToChord(_ nashville: String, key: String, preferFlats: Bool = false) -> String {
        guard !nashville.isEmpty, !key.isEmpty else { return nashville }

        // Handle slash chords
        if let slashIndex = nashville.firstIndex(of: "/") {
            let mainPart = String(nashville[..<slashIndex])
            let bassPart = String(nashville[nashville.index(after: slashIndex)...])
            return nashvilleToChord(mainPart, key: key, preferFlats: preferFlats) + "/" +
                   nashvilleToChord(bassPart, key: key, preferFlats: preferFlats)
        }

        // Extract Nashville degree and quality
        guard let match = nashville.firstMatch(of: nashvillePattern) else {
            return nashville // Not Nashville notation
        }

        let degreeStr = String(match.output.1)
        let quality = String(match.output.2)

        // Parse degree (1-7) and accidental
        var degree = 0
        var accidental = 0 // 0=natural, 1=sharp, -1=flat

        if degreeStr.count >= 2 {
            let firstChar = degreeStr[degreeStr.startIndex]
            if "#b♯♭".contains(firstChar) {
                // Accidental comes first: "#4", "b5"
                accidental = (firstChar == "#" || firstChar == "♯") ? 1 : -1
                degree = Int(String(degreeStr[degreeStr.index(after: degreeStr.startIndex)])) ?? 0
            } else {
                // No accidental prefix, just the degree
                degree = Int(String(firstChar)) ?? 0
            }
        } else {
            degree = Int(degreeStr) ?? 0
        }

        guard degree >= 1 && degree <= 7 else { return nashville }

        // Get key root index
        guard let keyRootIndex = noteIndex(for: key) else { return nashville }

        // Convert degree to semitones
        let baseSemitones = nashvilleDegreeToSemitones(degree)
        let chordSemitones = (keyRootIndex + baseSemitones + accidental + 12) % 12

        // Get note name
        let notes = preferFlats ? notesFlat : notesSharp
        let root = notes[chordSemitones]

        return root + quality
    }

    /// Detect if a string is Nashville notation.
    public static func isNashvilleNotation(_ str: String) -> Bool {
        guard !str.isEmpty else { return false }

        // Remove slash chord bass if present
        var mainPart = str
        if let slashIndex = str.firstIndex(of: "/") {
            mainPart = String(str[..<slashIndex])
        }

        return mainPart.firstMatch(of: nashvillePattern) != nil
    }

    /// Convert all chords in a song to Nashville notation.
    /// - Parameters:
    ///   - song: The song to convert
    ///   - key: The key to use (defaults to song's key)
    /// - Returns: New song with Nashville chords
    public static func convertSongToNashville(_ song: Song, key: String? = nil) -> Song {
        let songKey = key ?? song.key ?? song.originalKey ?? "C"
        var result = song
        result.useNashville = true

        for sectionIndex in result.sections.indices {
            for lineIndex in result.sections[sectionIndex].lines.indices {
                for chordIndex in result.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let chord = result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord =
                        chordToNashville(chord, key: songKey)
                }
            }
        }

        return result
    }

    /// Convert all Nashville chords in a song back to standard notation.
    /// - Parameters:
    ///   - song: The song to convert
    ///   - key: The key to use
    ///   - preferFlats: Whether to use flat notation
    /// - Returns: New song with standard chord symbols
    public static func convertSongFromNashville(_ song: Song, key: String? = nil, preferFlats: Bool = false) -> Song {
        let songKey = key ?? song.key ?? song.originalKey ?? "C"
        var result = song
        result.useNashville = false

        for sectionIndex in result.sections.indices {
            for lineIndex in result.sections[sectionIndex].lines.indices {
                for chordIndex in result.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let chord = result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord =
                        nashvilleToChord(chord, key: songKey, preferFlats: preferFlats)
                }
            }
        }

        return result
    }

    /// Get all possible keys for UI selection.
    public static func getAllKeys() -> [String] {
        return [
            "C", "C#", "Db", "D", "D#", "Eb", "E", "F",
            "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B"
        ]
    }

    /// Get common keys for quick selection.
    public static func getCommonKeys() -> [String] {
        return ["C", "G", "D", "A", "E", "F", "Bb", "Eb"]
    }

    // MARK: - Private Helpers

    private static func noteIndex(for note: String) -> Int? {
        guard !note.isEmpty else { return nil }

        // Extract root note (first letter + optional accidental)
        var root: String
        if note.count >= 2 {
            let second = note[note.index(note.startIndex, offsetBy: 1)]
            if "#b♯♭".contains(second) {
                root = String(note.prefix(2))
            } else {
                root = String(note.prefix(1))
            }
        } else {
            root = String(note.prefix(1))
        }

        // Normalize Unicode accidentals
        let normalized = root.replacingOccurrences(of: "♯", with: "#")
                             .replacingOccurrences(of: "♭", with: "b")

        for i in 0..<notesSharp.count {
            if notesSharp[i].caseInsensitiveCompare(normalized) == .orderedSame ||
               notesFlat[i].caseInsensitiveCompare(normalized) == .orderedSame {
                return i
            }
        }
        return nil
    }

    private static func semitoneToNashville(_ semitones: Int) -> String {
        switch semitones {
        case 0: return "1"
        case 1: return "#1"  // or b2
        case 2: return "2"
        case 3: return "#2"  // or b3
        case 4: return "3"
        case 5: return "4"
        case 6: return "#4"  // or b5
        case 7: return "5"
        case 8: return "#5"  // or b6
        case 9: return "6"
        case 10: return "#6" // or b7
        case 11: return "7"
        default: return String(semitones)
        }
    }

    private static func nashvilleDegreeToSemitones(_ degree: Int) -> Int {
        guard degree >= 1 && degree <= 7 else { return 0 }
        return majorScaleDegrees[degree - 1]
    }
}