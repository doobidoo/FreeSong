import XCTest
@testable import FreeSongCore

final class SongSerializerTests: XCTestCase {

    func testRoundTripPreservesSectionsChordsAndMetadata() {
        let song = Song(
            title: "Amazing Grace",
            artist: "John Newton",
            key: "G",
            tempo: "80",
            ccli: "12345",
            copyright: "Public Domain",
            sections: [
                SongSection(label: "Verse 1", lines: [
                    SongLine(lyrics: "Amazing grace how sweet the sound", chords: [
                        ChordPosition(chord: "G", position: 0),
                        ChordPosition(chord: "D", position: 20)
                    ]),
                    SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "A")),
                    SongLine(lyrics: "That saved a wretch like me", chords: [
                        ChordPosition(chord: "Em", position: 5)
                    ])
                ]),
                SongSection(label: "Chorus", lines: [
                    SongLine(lyrics: "I once was lost", chords: [ChordPosition(chord: "C", position: 0)])
                ])
            ]
        )

        let text = SongSerializer.serialize(song)
        let parsed = SongParser.parse(text)

        XCTAssertEqual(parsed.title, song.title)
        XCTAssertEqual(parsed.artist, song.artist)
        XCTAssertEqual(parsed.key, song.key)
        XCTAssertEqual(parsed.tempo, song.tempo)
        XCTAssertEqual(parsed.ccli, song.ccli)
        XCTAssertEqual(parsed.copyright, song.copyright)
        XCTAssertEqual(parsed.sections, song.sections)
    }

    func testRoundTripWithNoOptionalMetadata() {
        let song = Song(
            title: "Bare Song",
            sections: [
                SongSection(label: "Verse", lines: [
                    SongLine(lyrics: "just words", chords: [])
                ])
            ]
        )

        let text = SongSerializer.serialize(song)
        let parsed = SongParser.parse(text)

        XCTAssertEqual(parsed.title, song.title)
        XCTAssertEqual(parsed.sections, song.sections)
    }
}
