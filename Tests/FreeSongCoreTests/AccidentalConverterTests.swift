import XCTest
@testable import FreeSongCore

final class AccidentalConverterTests: XCTestCase {

    // MARK: - Convert to Flats

    func testConvertToFlatsBasic() {
        let result = AccidentalConverter.convertToFlats("C# D# F# G# A#")
        XCTAssertEqual(result, "Db Eb Gb Ab Bb")
    }

    func testConvertToFlatsInlineChords() {
        let result = AccidentalConverter.convertToFlats("[C#m]Amazing [F#]grace")
        XCTAssertEqual(result, "[Dbm]Amazing [Gb]grace")
    }

    func testConvertToFlatsChordsAbove() {
        let input = "C#       F#\nAmazing grace"
        let result = AccidentalConverter.convertToFlats(input)
        XCTAssertEqual(result, "Db       Gb\nAmazing grace")
    }

    func testConvertToFlatsSlashChords() {
        let result = AccidentalConverter.convertToFlats("G/B C#/G#")
        XCTAssertEqual(result, "G/B Db/Ab")
    }

    // MARK: - Convert to Sharps

    func testConvertToSharpsBasic() {
        let result = AccidentalConverter.convertToSharps("Db Eb Gb Ab Bb")
        XCTAssertEqual(result, "C# D# F# G# A#")
    }

    func testConvertToSharpsInlineChords() {
        let result = AccidentalConverter.convertToSharps("[Dbm]Amazing [Gb]grace")
        XCTAssertEqual(result, "[C#m]Amazing [F#]grace")
    }

    func testConvertToSharpsChordsAbove() {
        let input = "Db       Gb\nAmazing grace"
        let result = AccidentalConverter.convertToSharps(input)
        XCTAssertEqual(result, "C#       F#\nAmazing grace")
    }

    func testConvertToSharpsSlashChords() {
        let result = AccidentalConverter.convertToSharps("G/B Db/Ab")
        XCTAssertEqual(result, "G/B C#/G#")
    }

    // MARK: - Detection

    func testIsSharpsFormat() {
        XCTAssertTrue(AccidentalConverter.isSharpsFormat("C# D# F#"))
        XCTAssertTrue(AccidentalConverter.isSharpsFormat("[C#m] [F#]"))
        XCTAssertTrue(AccidentalConverter.isSharpsFormat("C D E")) // no accidentals -> sharps
    }

    func testIsFlatsFormat() {
        XCTAssertFalse(AccidentalConverter.isSharpsFormat("Db Eb Gb"))
        XCTAssertFalse(AccidentalConverter.isSharpsFormat("[Dbm] [Gb]"))
    }

    func testEqualSharpsFlats() {
        // When equal, defaults to sharps
        XCTAssertTrue(AccidentalConverter.isSharpsFormat("C# Db"))
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        XCTAssertEqual(AccidentalConverter.convertToFlats(""), "")
        XCTAssertEqual(AccidentalConverter.convertToSharps(""), "")
    }

    func testNoAccidentals() {
        XCTAssertEqual(AccidentalConverter.convertToFlats("C D E"), "C D E")
        XCTAssertEqual(AccidentalConverter.convertToSharps("C D E"), "C D E")
    }

    func testMixedContent() {
        let input = "Verse 1:\n[C#m]Amazing [F#]grace\nDb       Gb\nHow sweet the sound"
        let toFlats = AccidentalConverter.convertToFlats(input)
        XCTAssertTrue(toFlats.contains("[Dbm]"))
        XCTAssertTrue(toFlats.contains("[Gb]"))
        XCTAssertTrue(toFlats.contains("Db       Gb"))
    }

    func testUnicodeAccidentals() {
        // Unicode sharp/flat should be handled
        let result = AccidentalConverter.convertToFlats("C♯ D♯")
        XCTAssertEqual(result, "Db Eb")

        let result2 = AccidentalConverter.convertToSharps("D♭ E♭")
        XCTAssertEqual(result2, "C# D#")
    }
}