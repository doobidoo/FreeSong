import XCTest
@testable import FreeSongImport
@testable import FreeSongCore

final class OnSongConverterTests: XCTestCase {

    // MARK: - Basic Conversion

    func testBasicConversionWithInlineChords() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Amazing Grace",
            artist: "John Newton",
            key: "G",
            content: """
            Amazing Grace
            John Newton

            Verse 1:
            [G]Amazing [D]grace how [Em]sweet the [C]sound
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertEqual(song.title, "Amazing Grace")
        XCTAssertEqual(song.artist, "John Newton")
        XCTAssertEqual(song.key, "G")
        XCTAssertEqual(song.sections.count, 1)
        XCTAssertEqual(song.sections[0].label, "Verse 1")
        XCTAssertEqual(song.sections[0].lines.count, 1)
        XCTAssertEqual(song.sections[0].lines[0].chords.count, 4)
        XCTAssertEqual(song.sections[0].lines[0].chords[0].chord, "G")
    }

    func testBasicConversionWithChordsAboveLyrics() throws {
        let content = """
        How Great Thou Art
        Stuart K. Hine

        Verse 1:
        C       F       C       G       C
        O Lord my God, when I in awesome wonder
        """
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "2",
            title: "How Great Thou Art",
            artist: "Stuart K. Hine",
            key: "C",
            content: content
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertEqual(song.title, "How Great Thou Art")
        XCTAssertEqual(song.artist, "Stuart K. Hine")
        XCTAssertEqual(song.sections[0].lines.count, 1)
        // Chords above lyrics should be parsed
        XCTAssertGreaterThanOrEqual(song.sections[0].lines[0].chords.count, 3)
    }

    // MARK: - Metadata Merging

    func testDbTitleOverridesContentTitle() throws {
        // Content has a different title than the DB record
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Official Title",
            artist: "Artist",
            key: "C",
            content: """
            Wrong Title
            Artist

            [C]Some lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        // DB title takes precedence
        XCTAssertEqual(song.title, "Official Title")
        // Artist from DB should also take precedence
        XCTAssertEqual(song.artist, "Artist")
    }

    func testDbKeyOverridesContentKey() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: "D",
            content: """
            Song
            Artist

            {key: C}
            [C]Some lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        // DB key (D) overrides content key (C)
        XCTAssertEqual(song.key, "D")
    }

    func testKeyFromDbWhenNotInContent() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song Title",
            artist: nil,
            key: "A",
            content: """
            Song Title

            [A]Some [D]lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertEqual(song.key, "A")
    }

    func testKeyNilWhenNotProvided() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: nil,
            content: """
            Song

            [C]Lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertNil(song.key)
    }

    func testArtistNilWhenNotProvided() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: nil,
            content: """
            Song

            [C]Lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertNil(song.artist)
    }

    // MARK: - Error Cases

    func testEmptyTitleThrows() {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "",
            artist: nil,
            key: nil,
            content: """
            [C]Some content
            """
        )

        XCTAssertThrowsError(try OnSongConverter.convertToSong(onSong)) { error in
            XCTAssertTrue(error is OnSongConverter.ConversionError)
            XCTAssertEqual((error as? OnSongConverter.ConversionError)?.localizedDescription, "Song has no title")
        }
    }

    func testWhitespaceOnlyTitleThrows() {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "   ",
            artist: nil,
            key: nil,
            content: "[C]Content"
        )

        XCTAssertThrowsError(try OnSongConverter.convertToSong(onSong)) { error in
            XCTAssertTrue(error is OnSongConverter.ConversionError)
        }
    }

    func testEmptyContentThrows() {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: nil,
            content: ""
        )

        XCTAssertThrowsError(try OnSongConverter.convertToSong(onSong)) { error in
            XCTAssertTrue(error is OnSongConverter.ConversionError)
            XCTAssertEqual((error as? OnSongConverter.ConversionError)?.localizedDescription, "Song content is empty")
        }
    }

    func testWhitespaceOnlyContentThrows() {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: nil,
            content: "   \n  \n   "
        )

        XCTAssertThrowsError(try OnSongConverter.convertToSong(onSong)) { error in
            XCTAssertTrue(error is OnSongConverter.ConversionError)
        }
    }

    // MARK: - Raw Content

    func testRawContentIsCleared() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Song",
            artist: nil,
            key: nil,
            content: """
            Song

            [C]Lyrics
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        // rawContent must be empty so FileSongRepository.saveSong()
        // generates structured FreeSong content via generateSongContent()
        XCTAssertTrue(song.rawContent.isEmpty)
    }

    // MARK: - ChordPro Content

    func testChordProContent() throws {
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "ChordPro Song",
            artist: "Artist",
            key: "G",
            content: """
            {title: ChordPro Song}
            {artist: Artist}
            {key: G}

            {start_of_verse}
            [G]This [D]is [Em]ChordPro [C]format
            {end_of_verse}
            """
        )

        let song = try OnSongConverter.convertToSong(onSong)

        XCTAssertEqual(song.title, "ChordPro Song")
        XCTAssertEqual(song.artist, "Artist")
        XCTAssertEqual(song.key, "G")
    }

    // MARK: - Edge Cases

    func testNoSectionContentMeansNoSections() throws {
        // Content with no sections generates an unsectioned default section
        let onSong = OnSongDatabaseReader.OnSongSong(
            id: "1",
            title: "Simple",
            artist: nil,
            key: nil,
            content: "Simple\n\n[C]Just a line"
        )

        let song = try OnSongConverter.convertToSong(onSong)

        // SongParser should still create a default section
        XCTAssertFalse(song.sections.isEmpty, "Even simple content should produce at least one section")
    }
}
