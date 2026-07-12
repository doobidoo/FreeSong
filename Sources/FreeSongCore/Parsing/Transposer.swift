import Foundation

// MARK: - Transposer

/// Handles chord transposition by semitones.
/// Supports slash chords, Unicode accidentals (♯/♭), and preserves chord qualities.
public enum Transposer {

    // MARK: - Note Arrays

    private static let notesSharp = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let notesFlat = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    // Pattern to match chord root note (with optional sharp/flat, including Unicode)
    private static let chordRootPattern = #/^([A-G][#b♯♭]?)(.*)$/#

    // MARK: - Public API

    /// Transpose a single chord by semitones.
    /// - Parameters:
    ///   - chord: The chord to transpose (e.g., "Am7", "G/B", "F#m")
    ///   - semitones: Number of semitones to transpose (positive = up, negative = down)
    /// - Returns: The transposed chord, or original if unrecognized
    public static func transposeChord(_ chord: String, by semitones: Int) -> String {
        guard !chord.isEmpty else { return chord }

        // Handle slash chords (e.g., G/B)
        if let slashIndex = chord.firstIndex(of: "/") {
            let mainChord = String(chord[..<slashIndex])
            let bassNote = String(chord[chord.index(after: slashIndex)...])
            return transposeChord(mainChord, by: semitones) + "/" + transposeChord(bassNote, by: semitones)
        }

        guard let match = chord.firstMatch(of: chordRootPattern) else {
            return chord // Return unchanged if not a recognized chord
        }

        let root = String(match.output.1)
        let suffix = String(match.output.2)

        guard let noteIndex = noteIndex(for: root) else {
            return chord // Unknown note
        }

        // Transpose
        var newIndex = (noteIndex + semitones) % 12
        if newIndex < 0 { newIndex += 12 }

        // Use sharps or flats based on original chord (support both ASCII and Unicode)
        let usesFlat = root.contains("b") || root.contains("♭")
        let usesUnicode = root.contains("♯") || root.contains("♭")
        let notes = usesFlat ? notesFlat : notesSharp
        var result = notes[newIndex] + suffix
        // Preserve Unicode accidental characters in the output
        if usesUnicode {
            result = result
                .replacingOccurrences(of: "#", with: "♯")
                .replacingOccurrences(of: "b", with: "♭")
        }
        return result
    }

    /// Transpose a song in place.
    /// - Parameters:
    ///   - song: The song to transpose (modified in place)
    ///   - semitones: Number of semitones to transpose
    public static func transposeSong(_ song: inout Song, by semitones: Int) {
        for sectionIndex in song.sections.indices {
            for lineIndex in song.sections[sectionIndex].lines.indices {
                // Transpose chords in this line
                for chordIndex in song.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let chord = song.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    song.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord =
                        transposeChord(chord, by: semitones)
                }
                // Transpose key change if present
                if var keyChange = song.sections[sectionIndex].lines[lineIndex].keyChange {
                    keyChange.newKey = transposeChord(keyChange.newKey, by: semitones)
                    song.sections[sectionIndex].lines[lineIndex].keyChange = keyChange
                }
            }
        }

        // Update the key if set
        if let key = song.key, !key.isEmpty {
            song.key = transposeChord(key, by: semitones)
        }
    }

    /// Create a transposed copy of a song.
    /// - Parameters:
    ///   - song: The song to transpose
    ///   - semitones: Number of semitones to transpose
    /// - Returns: New transposed song
    public static func transposedSong(_ song: Song, by semitones: Int) -> Song {
        var result = song
        transposeSong(&result, by: semitones)
        result.transpose = semitones
        return result
    }

    /// Get the display name for a transposition.
    /// - Parameter semitones: The transposition amount
    /// - Returns: Display string (e.g., "Original", "+2", "-3")
    public static func transpositionName(for semitones: Int) -> String {
        if semitones == 0 { return "Original" }
        if semitones > 0 { return "+\(semitones)" }
        return "\(semitones)"
    }

    /// Calculate the number of semitones between two keys.
    /// Used for key change transposition.
    /// - Parameters:
    ///   - fromKey: The original key (e.g., "C", "Am", "F#")
    ///   - toKey: The target key (e.g., "D", "Bm", "G#")
    /// - Returns: Number of semitones to transpose (0-11), or 0 if keys are invalid
    public static func semitonesBetween(fromKey: String, toKey: String) -> Int {
        guard !fromKey.isEmpty, !toKey.isEmpty else { return 0 }

        guard let fromIndex = keyNoteIndex(fromKey),
              let toIndex = keyNoteIndex(toKey) else { return 0 }

        var diff = toIndex - fromIndex
        if diff < 0 { diff += 12 }
        return diff
    }

    // MARK: - Private Helpers

    /// Get the semitone index (0-11) for a note root.
    /// Handles both ASCII (#, b) and Unicode (♯, ♭) accidentals.
    private static func noteIndex(for note: String) -> Int? {
        let normalized = note.replacingOccurrences(of: "♯", with: "#").replacingOccurrences(of: "♭", with: "b")

        for i in 0..<notesSharp.count {
            if notesSharp[i].caseInsensitiveCompare(normalized) == .orderedSame ||
               notesFlat[i].caseInsensitiveCompare(normalized) == .orderedSame {
                return i
            }
        }
        return nil
    }

    /// Get the semitone index of a key's root note.
    /// Extracts the root note from keys like "C", "Am", "F#m", "Bbmaj7".
    private static func keyNoteIndex(_ key: String) -> Int? {
        guard !key.isEmpty else { return nil }

        // Extract just the root note (first letter + optional accidental)
        let root: String
        if key.count >= 2,
           let second = key.dropFirst().first,
           "#b♯♭".contains(second) {
            root = String(key.prefix(2))
        } else {
            root = String(key.prefix(1))
        }

        return noteIndex(for: root)
    }
}