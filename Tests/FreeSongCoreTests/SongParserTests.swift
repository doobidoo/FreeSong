import XCTest
@testable import FreeSongCore

final class SongParserTests: XCTestCase {

    // MARK: - OnSong Format

    func testParseOnSongBasic() {
        let content = """
        Amazing Grace
        John Newton

        Verse 1:
        G       D
        Amazing grace, how sweet the sound
        Em      C
        That saved a wretch like me

        Chorus:
        G       C
        I once was lost, but now am found
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.title, "Amazing Grace")
        XCTAssertEqual(song.artist, "John Newton")
        XCTAssertEqual(song.sections.count, 2)
        XCTAssertEqual(song.sections[0].label, "Verse 1")
        XCTAssertEqual(song.sections[1].label, "Chorus")
    }

    func testParseOnSongWithInlineChords() {
        let content = """
        Test Song
        Artist Name

        [G]Amazing [D]grace, how [Em]sweet the [C]sound
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.title, "Test Song")
        XCTAssertEqual(song.artist, "Artist Name")
        XCTAssertEqual(song.sections[0].lines[0].chords.count, 4)
        XCTAssertEqual(song.sections[0].lines[0].chords[0].chord, "G")
        XCTAssertEqual(song.sections[0].lines[0].chords[0].position, 0)
    }

    func testParseOnSongKeyChange() {
        let content = """
        Key: C
        Test Song
        Artist

        C       F
        Line in C

        Key: D

        D       G
        Line in D
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.key, "C")
        XCTAssertEqual(song.sections.count, 1) // Single section since no section labels
        // Key change should create a KeyChange line
        let keyChangeLines = song.sections[0].lines.filter { $0.isKeyChange }
        XCTAssertEqual(keyChangeLines.count, 1)
        XCTAssertEqual(keyChangeLines[0].keyChange?.newKey, "D")
    }

    // MARK: - ChordPro Format

    func testParseChordProBasic() {
        let content = """
        {title: Amazing Grace}
        {subtitle: John Newton}
        {key: G}

        {start_of_verse}
        [G]Amazing [D]grace, how [Em]sweet the [C]sound
        {end_of_verse}
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.title, "Amazing Grace")
        XCTAssertEqual(song.artist, "John Newton")
        XCTAssertEqual(song.key, "G")
    }

    func testParseChordProWithTags() {
        let content = """
        {title: Test}
        {artist: Artist}
        {tempo: 120}
        {ccli: 123456}
        {copyright: © 2024}

        [C]Line [F]one
        [G]Line [C]two
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.title, "Test")
        XCTAssertEqual(song.artist, "Artist")
        XCTAssertEqual(song.tempo, "120")
        XCTAssertEqual(song.ccli, "123456")
        XCTAssertEqual(song.copyright, "© 2024")
    }

    func testParseChordProSectionLabels() {
        let content = """
        {title: Test}

        {comment: Verse 1}
        [C]Verse line
        {comment: Chorus}
        [F]Chorus line
        """
        let song = SongParser.parse(content)

        // ChordPro comments don't create sections in our parser
        // but OnSong-style section labels do
        XCTAssertEqual(song.sections.count, 1)
    }

    // MARK: - Section Labels

    func testParseSectionLabels() {
        let content = """
        Test
        Artist

        Verse 1:
        [C]Line one

        Chorus:
        [F]Chorus line

        Bridge:
        [G]Bridge line
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.sections.count, 3)
        XCTAssertEqual(song.sections[0].label, "Verse 1")
        XCTAssertEqual(song.sections[1].label, "Chorus")
        XCTAssertEqual(song.sections[2].label, "Bridge")
    }

    func testParseSectionLabelsWithNumbers() {
        let content = """
        Test
        Artist

        Verse 1:
        Line

        Verse 2:
        Line

        Pre-Chorus:
        Line
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.sections[0].label, "Verse 1")
        XCTAssertEqual(song.sections[1].label, "Verse 2")
        XCTAssertEqual(song.sections[2].label, "Pre-Chorus")
    }

    // MARK: - Metadata Only

    func testParseMetadataOnly() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("test.onsong")

        let content = """
        {title: Metadata Test}
        {artist: Test Artist}
        {key: G}
        {tempo: 100}

        [G]Verse line
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let (title, artist) = try SongParser.parseMetadataOnly(at: fileURL)

        XCTAssertEqual(title, "Metadata Test")
        XCTAssertEqual(artist, "Test Artist")

        try? FileManager.default.removeItem(at: fileURL)
    }

    func testParseMetadataOnlyFallbackToFilename() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("My Song.txt")

        let content = "Just some text\nNo tags here"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let (title, artist) = try SongParser.parseMetadataOnly(at: fileURL)

        XCTAssertEqual(title, "My Song")
        XCTAssertNil(artist)

        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - Edge Cases

    func testParseEmptyLines() {
        let content = """
        Title
        Artist


        [C]Line with empty lines before
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.title, "Title")
        XCTAssertEqual(song.artist, "Artist")
        XCTAssertEqual(song.sections[0].lines.count, 1)
    }

    func testParseChordOnlyLines() {
        let content = """
        Title
        Artist

        C       F       G
        Line with chords above

        [C]Inline chords
        """
        let song = SongParser.parse(content)

        // First line should be chord-only (combined with next lyrics line)
        // Second line should be inline
        XCTAssertGreaterThanOrEqual(song.sections[0].lines.count, 2)
    }

    func testParseStandaloneBass() {
        let content = """
        Title
        Artist

        C       /G      /B      Am
        Line with bass movement
        """
        let song = SongParser.parse(content)

        // Should parse standalone bass notes as chords
        XCTAssertGreaterThanOrEqual(song.sections[0].lines[0].chords.count, 3)
    }

    func testParseComplexChords() {
        let content = """
        Title
        Artist

        [Cmaj7]Test [F#m7b5]chords [G7#9]with [Bb9#11]extensions
        [Csus4]And [G7sus4]suspended [Cadd9]added [C6/9]six-nine
        [Cdim]Dim [C°]degree [Cø7]half-dim [Caug]aug [C+]plus
        """
        let song = SongParser.parse(content)

        let chords = song.sections[0].lines.flatMap { $0.chords.map { $0.chord } }
        XCTAssertTrue(chords.contains("Cmaj7"))
        XCTAssertTrue(chords.contains("F#m7b5"))
        XCTAssertTrue(chords.contains("G7#9"))
        XCTAssertTrue(chords.contains("Bb9#11"))
        XCTAssertTrue(chords.contains("Csus4"))
        XCTAssertTrue(chords.contains("G7sus4"))
        XCTAssertTrue(chords.contains("Cadd9"))
        XCTAssertTrue(chords.contains("C6/9"))
        XCTAssertTrue(chords.contains("Cdim"))
        XCTAssertTrue(chords.contains("C°"))
        XCTAssertTrue(chords.contains("Cø7"))
        XCTAssertTrue(chords.contains("Caug"))
        XCTAssertTrue(chords.contains("C+"))
    }

    func testParseUnicodeChords() {
        let content = """
        Title
        Artist

        [C♯]Sharp [D♭]flat [G♯]more [A♭]unicode [F♯]chords
        """
        let song = SongParser.parse(content)

        let chords = song.sections[0].lines[0].chords.map { $0.chord }
        XCTAssertTrue(chords.contains("C♯"))
        XCTAssertTrue(chords.contains("D♭"))
        XCTAssertTrue(chords.contains("G♯"))
        XCTAssertTrue(chords.contains("A♭"))
        XCTAssertTrue(chords.contains("F♯"))
    }

    func testParseChordProKeyChange() {
        let content = """
        {title: Test}
        {key: C}

        [C]Verse in C

        {key: D}

        [D]Verse in D
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.key, "C")
        // Key change after content should create KeyChange line
        let keyChanges = song.sections.flatMap { $0.lines.filter { $0.isKeyChange } }
        XCTAssertEqual(keyChanges.count, 1)
        XCTAssertEqual(keyChanges[0].keyChange?.newKey, "D")
    }

    func testParseOnSongKeyLine() {
        let content = """
        Title
        Artist

        Key: C

        [C]Verse in C

        Key: D

        [D]Verse in D
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.key, "C")
        let keyChanges = song.sections.flatMap { $0.lines.filter { $0.isKeyChange } }
        XCTAssertEqual(keyChanges.count, 1)
        XCTAssertEqual(keyChanges[0].keyChange?.newKey, "D")
    }

    // MARK: - Raw Content Preservation

    func testRawContentPreserved() {
        let content = """
        Title
        Artist

        [C]Test line
        """
        let song = SongParser.parse(content)

        XCTAssertEqual(song.rawContent, content)
    }

    // MARK: - Multiple Files

    func testParseFileFromDisk() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("song.onsong")

        let content = """
        File Song
        File Artist

        [G]From [C]file [D]disk
        """
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let song = try SongParser.parseFile(at: fileURL)

        XCTAssertEqual(song.title, "File Song")
        XCTAssertEqual(song.artist, "File Artist")
        XCTAssertEqual(song.sections[0].lines[0].chords.count, 3)

        try? FileManager.default.removeItem(at: fileURL)
    }
}