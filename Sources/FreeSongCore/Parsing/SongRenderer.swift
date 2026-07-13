import Foundation

// MARK: - SongRenderer

/// Single entry point for the display pipeline: transposition (including mid-song
/// key changes), sharp/flat spelling, and Nashville Number System notation.
///
/// The three steps are order-sensitive (transpose, then respell, then Nashville) and
/// were previously hand-assembled by callers; `SongRenderer` owns that order so no
/// caller has to know or re-derive it.
public enum SongRenderer {

    /// Render `song` for display.
    /// - Parameters:
    ///   - song: The original (as-parsed/as-stored) song. Never mutated.
    ///   - transpose: Global transpose offset in semitones, on top of the song's own key.
    ///   - useFlats: Explicit spelling preference applied after transposition:
    ///     `true` respells everything as flats, `false` respells everything as sharps.
    ///   - useNashville: Convert chords to Nashville Number System notation (applied last).
    ///   - nashvilleKey: Manual key to use for Nashville conversion when the song has no
    ///     key of its own (no effect if the song already has a key or `useNashville` is false).
    /// - Returns: A new `Song` with chords, key, and key-change markers rendered for display.
    public static func render(_ song: Song, transpose: Int = 0, useFlats: Bool = false, useNashville: Bool = false, nashvilleKey: String? = nil) -> Song {
        var result = applyTranspose(song, by: transpose)
        result.transpose = transpose
        result.useFlats = useFlats

        result = applyAccidentals(result, toFlats: useFlats)
        if useNashville {
            result = applyNashville(result, fallbackKey: nashvilleKey)
        }
        return result
    }

    // MARK: - Transposition (with key-change stacking)

    /// Transpose every chord by `transpose`. Chords after a mid-song key change also get
    /// the semitone distance from the song's base key to that key change's target key,
    /// stacked on top of `transpose`.
    ///
    /// This matches the Android reference (`SongViewActivity.displaySong`): source files
    /// write chords after a `Key: X` marker as if the song were still in its base key, so
    /// the app auto-transposes the rest of the way to X. Android recomputes that key-change
    /// distance from a *live, already-transposed* base key against the marker's raw text,
    /// which algebraically cancels the global transpose out for everything after a key
    /// change. We instead compute the key-change distance from the song's *original*
    /// (untransposed) key and add `transpose` on top, so a global transpose consistently
    /// shifts the whole song, modulations included — the more intuitive behavior, and the
    /// one this feature's spec calls for ("stacks the user's global transpose on top").
    private static func applyTranspose(_ song: Song, by transpose: Int) -> Song {
        var result = song
        let baseKey = song.key ?? song.originalKey ?? ""
        var extraSemitones = 0

        for sectionIndex in result.sections.indices {
            for lineIndex in result.sections[sectionIndex].lines.indices {
                if let keyChange = song.sections[sectionIndex].lines[lineIndex].keyChange {
                    extraSemitones = baseKey.isEmpty
                        ? 0
                        : Transposer.semitonesBetween(fromKey: baseKey, toKey: keyChange.newKey)
                    result.sections[sectionIndex].lines[lineIndex].keyChange?.newKey =
                        Transposer.transposeChord(keyChange.newKey, by: transpose)
                    continue
                }

                for chordIndex in result.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let original = song.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord =
                        Transposer.transposeChord(original, by: transpose + extraSemitones)
                }
            }
        }

        if let key = result.key, !key.isEmpty {
            result.key = Transposer.transposeChord(key, by: transpose)
        }
        return result
    }

    // MARK: - Accidentals

    /// Respell every chord, key-change target, and the song key in the requested
    /// spelling. Conversion is a no-op for chords already in the target spelling.
    private static func applyAccidentals(_ song: Song, toFlats: Bool) -> Song {
        let convert = toFlats ? AccidentalConverter.convertToFlats : AccidentalConverter.convertToSharps
        var result = song
        for sectionIndex in result.sections.indices {
            for lineIndex in result.sections[sectionIndex].lines.indices {
                for chordIndex in result.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let chord = result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord = convert(chord)
                }
                if let keyChange = result.sections[sectionIndex].lines[lineIndex].keyChange {
                    result.sections[sectionIndex].lines[lineIndex].keyChange?.newKey = convert(keyChange.newKey)
                }
            }
        }
        if let key = result.key {
            result.key = convert(key)
        }
        return result
    }

    // MARK: - Nashville

    /// Convert to Nashville, tracking the key forward across key changes so chords after
    /// a modulation are numbered relative to the new (already-transposed) key.
    private static func applyNashville(_ song: Song, fallbackKey: String? = nil) -> Song {
        var result = song
        result.useNashville = true
        var currentKey = song.key ?? song.originalKey ?? fallbackKey ?? "C"

        for sectionIndex in result.sections.indices {
            for lineIndex in result.sections[sectionIndex].lines.indices {
                if let keyChange = song.sections[sectionIndex].lines[lineIndex].keyChange {
                    currentKey = keyChange.newKey
                    continue
                }
                for chordIndex in result.sections[sectionIndex].lines[lineIndex].chords.indices {
                    let chord = result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord
                    result.sections[sectionIndex].lines[lineIndex].chords[chordIndex].chord =
                        NashvilleConverter.chordToNashville(chord, key: currentKey)
                }
            }
        }
        return result
    }
}
