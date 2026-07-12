import XCTest
@testable import FreeSongCore

final class TransposerTests: XCTestCase {

    // MARK: - Basic Transposition

    func testTransposeUp() {
        XCTAssertEqual(Transposer.transposeChord("C", by: 2), "D")
        XCTAssertEqual(Transposer.transposeChord("G", by: 5), "C")
        XCTAssertEqual(Transposer.transposeChord("F", by: 7), "C")
    }

    func testTransposeDown() {
        XCTAssertEqual(Transposer.transposeChord("D", by: -2), "C")
        XCTAssertEqual(Transposer.transposeChord("C", by: -5), "G")
        XCTAssertEqual(Transposer.transposeChord("C", by: -7), "F")
    }

    func testTransposeWrapAround() {
        XCTAssertEqual(Transposer.transposeChord("B", by: 1), "C")
        XCTAssertEqual(Transposer.transposeChord("C", by: -1), "B")
        XCTAssertEqual(Transposer.transposeChord("B", by: 13), "C") // Octave wrap
    }

    // MARK: - Sharps and Flats

    func testSharpPreservation() {
        XCTAssertEqual(Transposer.transposeChord("C#", by: 1), "D")
        XCTAssertEqual(Transposer.transposeChord("F#", by: 2), "G#")
        XCTAssertEqual(Transposer.transposeChord("G#", by: 1), "A")
    }

    func testFlatPreservation() {
        XCTAssertEqual(Transposer.transposeChord("Db", by: 1), "D")
        XCTAssertEqual(Transposer.transposeChord("Gb", by: 2), "Ab")
        XCTAssertEqual(Transposer.transposeChord("Ab", by: 1), "A")
    }

    func testUnicodeSharp() {
        XCTAssertEqual(Transposer.transposeChord("C♯", by: 1), "D")
        XCTAssertEqual(Transposer.transposeChord("F♯", by: 2), "G♯")
    }

    func testUnicodeFlat() {
        XCTAssertEqual(Transposer.transposeChord("D♭", by: 1), "D")
        XCTAssertEqual(Transposer.transposeChord("G♭", by: 2), "A♭")
    }

    // MARK: - Chord Qualities Preserved

    func testMajorChord() {
        XCTAssertEqual(Transposer.transposeChord("C", by: 2), "D")
        XCTAssertEqual(Transposer.transposeChord("F", by: 4), "A")
    }

    func testMinorChord() {
        XCTAssertEqual(Transposer.transposeChord("Am", by: 2), "Bm")
        XCTAssertEqual(Transposer.transposeChord("Dm", by: 3), "Fm")
        XCTAssertEqual(Transposer.transposeChord("Em", by: 5), "Am")
    }

    func testSeventhChords() {
        XCTAssertEqual(Transposer.transposeChord("G7", by: 2), "A7")
        // Cmaj7 uses sharp notation, transposed by 3 -> D#maj7 (sharp preserved)
        XCTAssertEqual(Transposer.transposeChord("Cmaj7", by: 3), "D#maj7")
        // Dm7 uses sharp notation, transposed by 4 -> F#m7 (sharp preserved)
        XCTAssertEqual(Transposer.transposeChord("Dm7", by: 4), "F#m7")
    }

    func testExtendedChords() {
        XCTAssertEqual(Transposer.transposeChord("C9", by: 2), "D9")
        XCTAssertEqual(Transposer.transposeChord("G13", by: 1), "G#13")
    }

    func testSuspendedChords() {
        XCTAssertEqual(Transposer.transposeChord("Csus4", by: 2), "Dsus4")
        XCTAssertEqual(Transposer.transposeChord("Gsus2", by: 3), "A#sus2")
    }

    func testDiminishedAugmented() {
        XCTAssertEqual(Transposer.transposeChord("Cdim", by: 2), "Ddim")
        // C° uses sharp notation, transposed by 3 -> D#° (sharp preserved)
        XCTAssertEqual(Transposer.transposeChord("C°", by: 3), "D#°")
        XCTAssertEqual(Transposer.transposeChord("Caug", by: 1), "C#aug")
        XCTAssertEqual(Transposer.transposeChord("C+", by: 2), "D+")
    }

    func testHalfDiminished() {
        // Cø7 uses sharp notation, transposed by 2 -> Dø7 (sharp preserved)
        XCTAssertEqual(Transposer.transposeChord("Cø7", by: 2), "Dø7")
        // Bm7b5 uses flat notation, transposed by 3 -> Dm7b5 (flat preserved)
        XCTAssertEqual(Transposer.transposeChord("Bm7b5", by: 3), "Dm7b5")
    }

    // MARK: - Slash Chords

    func testSlashChord() {
        // G/B uses sharp notation, transposed by 2 -> A/C# (sharp preserved)
        XCTAssertEqual(Transposer.transposeChord("G/B", by: 2), "A/C#")
        // C/E uses sharp notation, transposed by 3 -> D#/F## -> D#/G (sharp preserved)
        // Actually C->D# and E->G, so D#/G
        XCTAssertEqual(Transposer.transposeChord("C/E", by: 3), "D#/G")
        XCTAssertEqual(Transposer.transposeChord("D/F#", by: -2), "C/E")
    }

    func testSlashChordWithFlats() {
        // G/Bb uses flat notation for bass, transposed by 1 -> G#/B (sharp for main, natural for bass)
        XCTAssertEqual(Transposer.transposeChord("G/Bb", by: 1), "G#/B")
        XCTAssertEqual(Transposer.transposeChord("F/A", by: 2), "G/B")
    }

    // MARK: - Key Transposition

    func testTransposeSong() {
        var song = Song(title: "Test")
        song.sections = [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "Amazing grace", chords: [
                    ChordPosition(chord: "G", position: 0),
                    ChordPosition(chord: "D", position: 7)
                ])
            ])
        ]
        song.key = "G"

        Transposer.transposeSong(&song, by: 2)

        XCTAssertEqual(song.key, "A")
        XCTAssertEqual(song.sections[0].lines[0].chords[0].chord, "A")
        XCTAssertEqual(song.sections[0].lines[0].chords[1].chord, "E")
    }

    func testTransposeSongWithKeyChange() {
        var song = Song(title: "Test")
        song.sections = [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "Line 1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D")),
                SongLine(lyrics: "Line 2", chords: [ChordPosition(chord: "G", position: 0)])
            ])
        ]
        song.key = "C"

        Transposer.transposeSong(&song, by: 2)

        XCTAssertEqual(song.key, "D")
        XCTAssertEqual(song.sections[0].lines[0].chords[0].chord, "D")
        XCTAssertEqual(song.sections[0].lines[1].keyChange?.newKey, "E")
        XCTAssertEqual(song.sections[0].lines[2].chords[0].chord, "A")
    }

    // MARK: - Semitones Between Keys

    func testSemitonesBetween() {
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "C", toKey: "D"), 2)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "G", toKey: "C"), 5)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "F", toKey: "C"), 7)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "B", toKey: "C"), 1)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "C", toKey: "B"), 11)
    }

    func testSemitonesWithMinorKeys() {
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "Am", toKey: "Bm"), 2)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "Em", toKey: "Am"), 5)
    }

    func testSemitonesWithAccidentals() {
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "F#", toKey: "G"), 1)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "Gb", toKey: "G"), 1)
        XCTAssertEqual(Transposer.semitonesBetween(fromKey: "C", toKey: "F#"), 6)
    }

    // MARK: - Display Names

    func testTranspositionName() {
        XCTAssertEqual(Transposer.transpositionName(for: 0), "Original")
        XCTAssertEqual(Transposer.transpositionName(for: 1), "+1")
        XCTAssertEqual(Transposer.transpositionName(for: -1), "-1")
        XCTAssertEqual(Transposer.transpositionName(for: 12), "+12")
    }

    // MARK: - Edge Cases

    func testEmptyChord() {
        XCTAssertEqual(Transposer.transposeChord("", by: 2), "")
    }

    func testInvalidChord() {
        XCTAssertEqual(Transposer.transposeChord("X", by: 2), "X")
        XCTAssertEqual(Transposer.transposeChord("H", by: 2), "H")
    }

    func testTransposeZero() {
        XCTAssertEqual(Transposer.transposeChord("C", by: 0), "C")
        XCTAssertEqual(Transposer.transposeChord("F#m7", by: 0), "F#m7")
    }

    func testLargeTransposition() {
        XCTAssertEqual(Transposer.transposeChord("C", by: 24), "C") // 2 octaves
        XCTAssertEqual(Transposer.transposeChord("C", by: -24), "C")
        XCTAssertEqual(Transposer.transposeChord("C", by: 25), "C#")
    }
}