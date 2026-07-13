import XCTest
@testable import FreeSongCore

final class SongRendererTests: XCTestCase {

    // MARK: - Helpers

    private func song(key: String?, sections: [SongSection]) -> Song {
        Song(title: "Test", key: key, sections: sections)
    }

    // MARK: - Plain transpose

    func testRenderTransposeOnly() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "C", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, transpose: 2)
        XCTAssertEqual(rendered.key, "D")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "D")
        XCTAssertEqual(rendered.transpose, 2)
    }

    func testRenderNoOpIsIdentityForChords() {
        let s = song(key: "G", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "G", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s)
        XCTAssertEqual(rendered.key, "G")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "G")
    }

    // MARK: - Flats

    func testRenderTransposeThenFlats() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "C", position: 0)])
            ])
        ])
        // C + 1 semitone = C#, which should be respelled as Db when useFlats is set.
        let rendered = SongRenderer.render(s, transpose: 1, useFlats: true)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "Db")
        XCTAssertEqual(rendered.key, "Db")
        XCTAssertTrue(rendered.useFlats)
    }

    // MARK: - Sharps (useFlats == false is an explicit sharps preference)

    func testRenderSharpsRespellsFlatSong() {
        let s = song(key: "Eb", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [
                    ChordPosition(chord: "Eb", position: 0),
                    ChordPosition(chord: "Bbm7", position: 5)
                ])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: false)
        XCTAssertEqual(rendered.key, "D#")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "D#")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[1].chord, "A#m7")
    }

    func testRenderSharpsConvertsBassNotes() {
        let s = song(key: "Ab", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "Ab/Eb", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: false)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "G#/D#")
    }

    func testRenderFlatsConvertsBassNotes() {
        let s = song(key: "C#", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "C#/G#", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: true)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "Db/Ab")
    }

    func testRenderSharpsIsNoOpWhenAlreadySharps() {
        let s = song(key: "A", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [
                    ChordPosition(chord: "F#m", position: 0),
                    ChordPosition(chord: "D", position: 5)
                ])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: false)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "F#m")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[1].chord, "D")
    }

    func testRenderFlatsIsNoOpWhenAlreadyFlats() {
        let s = song(key: "Bb", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "Eb", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: true)
        XCTAssertEqual(rendered.key, "Bb")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "Eb")
    }

    func testRenderTransposeThenSharps() {
        // Bb - 1 semitone = A; Eb - 1 = D. Transposer may emit either spelling;
        // the explicit sharps preference guarantees no flats survive.
        let s = song(key: "Bb", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "Eb", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, transpose: -2, useFlats: false)
        XCTAssertEqual(rendered.key, "G#")
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "C#")
    }

    func testRenderSharpsRespellsKeyChangeTarget() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "Eb")),
                SongLine(lyrics: "L2", chords: [ChordPosition(chord: "C", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, useFlats: false)
        XCTAssertEqual(rendered.sections[0].lines[1].keyChange?.newKey, "D#")
    }

    // MARK: - Nashville

    func testRenderNashvilleUsesTransposedKey() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "F", position: 0)])
            ])
        ])
        // Transpose C->D (+2); F also moves +2 to G. In key D, G is the 4 chord.
        let rendered = SongRenderer.render(s, transpose: 2, useNashville: true)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "4")
        XCTAssertTrue(rendered.useNashville)
    }

    func testRenderTransposeFlatsNashvilleCombined() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "La", chords: [ChordPosition(chord: "G", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, transpose: 0, useFlats: true, useNashville: true)
        // G is the 5 chord in C regardless of sharp/flat spelling.
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "5")
    }

    // MARK: - Key changes

    func testKeyChangeTransposesFollowingChords() {
        // Base key C, chords written as if still in C after the "Key: D" marker;
        // SongRenderer should auto-transpose them the rest of the way to D (+2).
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D")),
                SongLine(lyrics: "L2", chords: [ChordPosition(chord: "F", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "C", "Chords before the key change are untouched")
        XCTAssertEqual(rendered.sections[0].lines[2].chords[0].chord, "G", "F transposed +2 (C->D) to G")
        XCTAssertEqual(rendered.sections[0].lines[1].keyChange?.newKey, "D")
    }

    func testKeyChangeStacksWithGlobalTranspose() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D")),
                SongLine(lyrics: "L2", chords: [ChordPosition(chord: "F", position: 0)])
            ])
        ])
        // Global +1 on top of the +2 (C->D) key-change transposition = +3 for the F chord.
        let rendered = SongRenderer.render(s, transpose: 1)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "C#", "Pre-key-change chord only gets the global +1")
        XCTAssertEqual(rendered.sections[0].lines[2].chords[0].chord, "G#", "Post-key-change chord gets +1 (global) +2 (modulation) = +3")
        XCTAssertEqual(rendered.sections[0].lines[1].keyChange?.newKey, "D#", "Displayed key-change label reflects the global transpose")
    }

    func testKeyChangeWithNashvilleTracksNewKey() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D")),
                SongLine(lyrics: "L2", chords: [ChordPosition(chord: "G", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s, useNashville: true)
        XCTAssertEqual(rendered.sections[0].lines[0].chords[0].chord, "1", "C is the 1 chord in the base key C")
        // After the key change, chords are first auto-transposed to the new key (G -> A,
        // +2 for C->D), then numbered relative to D: A is the 5 chord in D.
        XCTAssertEqual(rendered.sections[0].lines[2].chords[0].chord, "5")
    }

    func testMultipleKeyChangesEachRelativeToBaseKey() {
        let s = song(key: "C", sections: [
            SongSection(label: "Verse", lines: [
                SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D")),
                SongLine(lyrics: "L2", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "E")),
                SongLine(lyrics: "L3", chords: [ChordPosition(chord: "C", position: 0)])
            ])
        ])
        let rendered = SongRenderer.render(s)
        XCTAssertEqual(rendered.sections[0].lines[2].chords[0].chord, "D", "C + (C->D distance) = D")
        XCTAssertEqual(rendered.sections[0].lines[4].chords[0].chord, "E", "C + (C->E distance), independent of the first key change")
    }
}
