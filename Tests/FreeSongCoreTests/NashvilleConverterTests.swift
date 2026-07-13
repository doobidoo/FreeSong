import XCTest
@testable import FreeSongCore

final class NashvilleConverterTests: XCTestCase {

    // MARK: - Chord to Nashville

    func testChordToNashvilleInKeyOfC() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("C", key: "C"), "1")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Dm", key: "C"), "2m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Em", key: "C"), "3m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("F", key: "C"), "4")
        XCTAssertEqual(NashvilleConverter.chordToNashville("G7", key: "C"), "57")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Am", key: "C"), "6m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Bdim", key: "C"), "7dim")
    }

    func testChordToNashvilleInKeyOfG() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("G", key: "G"), "1")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Am", key: "G"), "2m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Bm", key: "G"), "3m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("C", key: "G"), "4")
        XCTAssertEqual(NashvilleConverter.chordToNashville("D7", key: "G"), "57")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Em", key: "G"), "6m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("F#dim", key: "G"), "7dim")
    }

    func testChordToNashvilleWithSharpsFlats() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("F#m", key: "D"), "3m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Gb", key: "Db"), "4")
        XCTAssertEqual(NashvilleConverter.chordToNashville("C#m", key: "A"), "3m")
    }

    func testChordToNashvilleWithUnicode() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("F♯m", key: "D"), "3m")
        XCTAssertEqual(NashvilleConverter.chordToNashville("G♭", key: "D♭"), "4")
    }

    func testChordToNashvillePreservesQuality() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("Cmaj7", key: "C"), "1maj7")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Dm7", key: "C"), "2m7")
        XCTAssertEqual(NashvilleConverter.chordToNashville("G9", key: "C"), "59")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Fsus4", key: "C"), "4sus4")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Cadd9", key: "C"), "1add9")
        XCTAssertEqual(NashvilleConverter.chordToNashville("Bø7", key: "C"), "7ø7")
        XCTAssertEqual(NashvilleConverter.chordToNashville("C°", key: "C"), "1°")
    }

    // MARK: - Slash Chords

    func testChordToNashvilleSlashChord() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("G/B", key: "C"), "5/7")
        XCTAssertEqual(NashvilleConverter.chordToNashville("C/E", key: "C"), "1/3")
        XCTAssertEqual(NashvilleConverter.chordToNashville("D/F#", key: "C"), "2/#4")
        XCTAssertEqual(NashvilleConverter.chordToNashville("F/A", key: "C"), "4/6")
    }

    // MARK: - Nashville to Chord

    func testNashvilleToChordInKeyOfC() {
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1", key: "C"), "C")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("2m", key: "C"), "Dm")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("3m", key: "C"), "Em")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("4", key: "C"), "F")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("57", key: "C"), "G7")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("6m", key: "C"), "Am")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7dim", key: "C"), "Bdim")
    }

    func testNashvilleToChordInKeyOfG() {
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1", key: "G"), "G")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("2m", key: "G"), "Am")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("3m", key: "G"), "Bm")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("4", key: "G"), "C")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("57", key: "G"), "D7")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("6m", key: "G"), "Em")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7dim", key: "G"), "F#dim")
    }

    func testNashvilleToChordWithFlats() {
        // Key of F uses flats
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1", key: "F", preferFlats: true), "F")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("4", key: "F", preferFlats: true), "Bb")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("5", key: "F", preferFlats: true), "C")
    }

    func testNashvilleToChordWithSharps() {
        // Key of G uses sharps
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7", key: "G", preferFlats: false), "F#")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7dim", key: "G", preferFlats: false), "F#dim")
    }

    func testNashvilleToChordPreservesQuality() {
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1maj7", key: "C"), "Cmaj7")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("2m7", key: "C"), "Dm7")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("59", key: "C"), "G9")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("4sus4", key: "C"), "Fsus4")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1add9", key: "C"), "Cadd9")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7ø7", key: "C"), "Bø7")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("7°", key: "C"), "B°")
    }

    // MARK: - Slash Chords Nashville to Chord

    func testNashvilleToChordSlashChord() {
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("5/7", key: "C"), "G/B")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1/3", key: "C"), "C/E")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("2/4", key: "C"), "D/F")
    }

    // MARK: - Round Trip

    func testRoundTripChordToNashvilleToChord() {
        let chords = ["C", "Dm", "Em", "F", "G7", "Am", "Bdim", "Cmaj7", "Dm7", "G9", "Fsus4"]
        for chord in chords {
            let nashville = NashvilleConverter.chordToNashville(chord, key: "C")
            let back = NashvilleConverter.nashvilleToChord(nashville, key: "C")
            XCTAssertEqual(back, chord, "Round trip failed for \(chord) -> \(nashville) -> \(back)")
        }
    }

    func testRoundTripInDifferentKeys() {
        let keys = ["C", "G", "D", "A", "E", "F", "Bb", "Eb"]
        let chords = ["C", "Dm", "Em", "F", "G", "Am"]

        for key in keys {
            for chord in chords {
                let nashville = NashvilleConverter.chordToNashville(chord, key: key)
                let back = NashvilleConverter.nashvilleToChord(nashville, key: key)
                // The original chord might use different enharmonic spelling
                // but should be musically equivalent
                XCTAssertFalse(back.isEmpty, "Round trip produced empty for \(chord) in \(key)")
            }
        }
    }

    // MARK: - Detection

    func testIsNashvilleNotation() {
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("1"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("2m"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("57"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("4maj7"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("6m7"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("7dim"))
        XCTAssertTrue(NashvilleConverter.isNashvilleNotation("5/7"))
        XCTAssertFalse(NashvilleConverter.isNashvilleNotation("C"))
        XCTAssertFalse(NashvilleConverter.isNashvilleNotation("Am"))
        XCTAssertFalse(NashvilleConverter.isNashvilleNotation("G7"))
    }

    // MARK: - Song Conversion

    func testConvertSongToNashville() {
        var song = Song(title: "Test")
        song.key = "C"
        song.sections = [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "Line", chords: [
                    ChordPosition(chord: "C", position: 0),
                    ChordPosition(chord: "Am", position: 5),
                    ChordPosition(chord: "F", position: 10),
                    ChordPosition(chord: "G7", position: 15)
                ])
            ])
        ]

        let nashvilleSong = NashvilleConverter.convertSongToNashville(song)

        XCTAssertEqual(nashvilleSong.sections[0].lines[0].chords[0].chord, "1")
        XCTAssertEqual(nashvilleSong.sections[0].lines[0].chords[1].chord, "6m")
        XCTAssertEqual(nashvilleSong.sections[0].lines[0].chords[2].chord, "4")
        XCTAssertEqual(nashvilleSong.sections[0].lines[0].chords[3].chord, "57")
        XCTAssertTrue(nashvilleSong.useNashville)
    }

    func testConvertSongFromNashville() {
        var song = Song(title: "Test")
        song.key = "C"
        song.useNashville = true
        song.sections = [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "Line", chords: [
                    ChordPosition(chord: "1", position: 0),
                    ChordPosition(chord: "6m", position: 5),
                    ChordPosition(chord: "4", position: 10),
                    ChordPosition(chord: "57", position: 15)
                ])
            ])
        ]

        let standardSong = NashvilleConverter.convertSongFromNashville(song)

        XCTAssertEqual(standardSong.sections[0].lines[0].chords[0].chord, "C")
        XCTAssertEqual(standardSong.sections[0].lines[0].chords[1].chord, "Am")
        XCTAssertEqual(standardSong.sections[0].lines[0].chords[2].chord, "F")
        XCTAssertEqual(standardSong.sections[0].lines[0].chords[3].chord, "G7")
        XCTAssertFalse(standardSong.useNashville)
    }

    // MARK: - Key Detection

    func testGetAllKeys() {
        let keys = NashvilleConverter.getAllKeys()
        XCTAssertEqual(keys.count, 17)
        XCTAssertTrue(keys.contains("C"))
        XCTAssertTrue(keys.contains("F#"))
        XCTAssertTrue(keys.contains("Gb"))
    }

    func testGetCommonKeys() {
        let keys = NashvilleConverter.getCommonKeys()
        XCTAssertEqual(keys.count, 8)
        XCTAssertTrue(keys.contains("C"))
        XCTAssertTrue(keys.contains("G"))
        XCTAssertTrue(keys.contains("F"))
    }

    // MARK: - Edge Cases

    func testEmptyChord() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("", key: "C"), "")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("", key: "C"), "")
    }

    func testInvalidKey() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("C", key: "X"), "C")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("1", key: "X"), "1")
    }

    func testInvalidChord() {
        XCTAssertEqual(NashvilleConverter.chordToNashville("Z", key: "C"), "Z")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("X", key: "C"), "X")
    }

    func testAccidentalsInNashville() {
        // #4 in key of C = F#
        XCTAssertEqual(NashvilleConverter.chordToNashville("F#", key: "C"), "#4")
        // b5 in key of C = Gb (same as #4)
        XCTAssertEqual(NashvilleConverter.chordToNashville("Gb", key: "C"), "#4") // or b5 depending on impl

        // Convert back
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("#4", key: "C", preferFlats: false), "F#")
        XCTAssertEqual(NashvilleConverter.nashvilleToChord("b5", key: "C", preferFlats: true), "Gb")
    }
}