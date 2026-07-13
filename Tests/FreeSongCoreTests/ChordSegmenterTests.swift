import XCTest
@testable import FreeSongCore

final class ChordSegmenterTests: XCTestCase {

    func testChordAtStart() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing", chords: [ChordPosition(chord: "G", position: 0)])
        XCTAssertEqual(segs, [ChordSegment(chord: "G", text: "Amazing")])
    }

    func testLeadingLyricRunBeforeFirstChord() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing grace", chords: [ChordPosition(chord: "C", position: 8)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Amazing "),
            ChordSegment(chord: "C", text: "grace"),
        ])
    }

    func testMultipleChordsUnsortedInput() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing grace how",
            chords: [ChordPosition(chord: "D", position: 14),
                     ChordPosition(chord: "G", position: 0)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Amazing grace "),
            ChordSegment(chord: "D", text: "how"),
        ])
    }

    func testChordMidWord() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 4)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Amaz"),
            ChordSegment(chord: "C", text: "ing"),
        ])
    }

    func testChordAtExactEndGetsEmptyText() {
        let segs = ChordSegmenter.segments(
            lyrics: "Amazing", chords: [ChordPosition(chord: "G", position: 7)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Amazing"),
            ChordSegment(chord: "G", text: ""),
        ])
    }

    func testChordBeyondEndClampsToEmptyText() {
        let segs = ChordSegmenter.segments(
            lyrics: "Am", chords: [ChordPosition(chord: "G", position: 10)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: nil, text: "Am"),
            ChordSegment(chord: "G", text: ""),
        ])
    }

    func testEmptyLyricsWithMultipleChords() {
        let segs = ChordSegmenter.segments(
            lyrics: "",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 4)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: ""),
            ChordSegment(chord: "C", text: ""),
        ])
    }

    func testRoundTripConcatenationPreservesLyrics() {
        let lyrics = "When we've been there ten thousand years"
        let chords = [ChordPosition(chord: "G", position: 0),
                      ChordPosition(chord: "C", position: 20),
                      ChordPosition(chord: "D", position: 30)]
        let joined = ChordSegmenter.segments(lyrics: lyrics, chords: chords)
            .map(\.text).joined()
        XCTAssertEqual(joined, lyrics)
    }

    func testUnicodeUsesCharacterIndexing() {
        // "Café " is 5 Characters (é is one grapheme); position 5 is 's'.
        let segs = ChordSegmenter.segments(
            lyrics: "Café song",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 5)])
        XCTAssertEqual(segs, [
            ChordSegment(chord: "G", text: "Café "),
            ChordSegment(chord: "C", text: "song"),
        ])
    }
}