import XCTest
@testable import FreeSongCore

final class ModelTests: XCTestCase {

    // MARK: - ChordPosition

    func testChordPositionInit() {
        let chord = ChordPosition(chord: "G", position: 5)
        XCTAssertEqual(chord.chord, "G")
        XCTAssertEqual(chord.position, 5)
    }

    func testChordPositionEquality() {
        let chord1 = ChordPosition(chord: "G", position: 5)
        let chord2 = ChordPosition(chord: "G", position: 5)
        let chord3 = ChordPosition(chord: "C", position: 5)
        XCTAssertEqual(chord1, chord2)
        XCTAssertNotEqual(chord1, chord3)
    }

    func testChordPositionCodable() throws {
        let chord = ChordPosition(chord: "G#m7", position: 10)
        let encoded = try JSONEncoder().encode(chord)
        let decoded = try JSONDecoder().decode(ChordPosition.self, from: encoded)
        XCTAssertEqual(chord, decoded)
    }

    // MARK: - KeyChange

    func testKeyChangeInit() {
        let keyChange = KeyChange(newKey: "D")
        XCTAssertEqual(keyChange.newKey, "D")
    }

    func testKeyChangeEquality() {
        let kc1 = KeyChange(newKey: "D")
        let kc2 = KeyChange(newKey: "D")
        let kc3 = KeyChange(newKey: "E")
        XCTAssertEqual(kc1, kc2)
        XCTAssertNotEqual(kc1, kc3)
    }

    func testKeyChangeCodable() throws {
        let keyChange = KeyChange(newKey: "F#m")
        let encoded = try JSONEncoder().encode(keyChange)
        let decoded = try JSONDecoder().decode(KeyChange.self, from: encoded)
        XCTAssertEqual(keyChange, decoded)
    }

    // MARK: - SongLine

    func testSongLineInit() {
        let line = SongLine(lyrics: "Amazing grace", chords: [ChordPosition(chord: "G", position: 0)])
        XCTAssertEqual(line.lyrics, "Amazing grace")
        XCTAssertEqual(line.chords.count, 1)
        XCTAssertNil(line.keyChange)
    }

    func testSongLineWithKeyChange() {
        let line = SongLine(lyrics: "", chords: [], keyChange: KeyChange(newKey: "D"))
        XCTAssertTrue(line.isKeyChange)
        XCTAssertEqual(line.keyChange?.newKey, "D")
    }

    func testSongLineAddChord() {
        var line = SongLine(lyrics: "Test")
        line.addChord(ChordPosition(chord: "C", position: 0))
        line.addChord(ChordPosition(chord: "F", position: 5))
        XCTAssertEqual(line.chords.count, 2)
    }

    func testSongLineEquality() {
        let line1 = SongLine(lyrics: "Test", chords: [ChordPosition(chord: "C", position: 0)])
        let line2 = SongLine(lyrics: "Test", chords: [ChordPosition(chord: "C", position: 0)])
        let line3 = SongLine(lyrics: "Different", chords: [ChordPosition(chord: "C", position: 0)])
        XCTAssertEqual(line1, line2)
        XCTAssertNotEqual(line1, line3)
    }

    func testSongLineCodable() throws {
        let line = SongLine(
            lyrics: "Amazing grace",
            chords: [ChordPosition(chord: "G", position: 0), ChordPosition(chord: "D", position: 7)],
            keyChange: KeyChange(newKey: "D")
        )
        let encoded = try JSONEncoder().encode(line)
        let decoded = try JSONDecoder().decode(SongLine.self, from: encoded)
        XCTAssertEqual(line, decoded)
    }

    // MARK: - SongSection

    func testSongSectionInit() {
        let section = SongSection(label: "Verse 1", lines: [])
        XCTAssertEqual(section.label, "Verse 1")
        XCTAssertTrue(section.lines.isEmpty)
    }

    func testSongSectionAddLine() {
        var section = SongSection(label: "Verse")
        let line = SongLine(lyrics: "Test line")
        section.addLine(line)
        XCTAssertEqual(section.lines.count, 1)
    }

    func testSongSectionEquality() {
        let section1 = SongSection(label: "Verse", lines: [SongLine(lyrics: "Test")])
        let section2 = SongSection(label: "Verse", lines: [SongLine(lyrics: "Test")])
        let section3 = SongSection(label: "Chorus", lines: [SongLine(lyrics: "Test")])
        XCTAssertEqual(section1, section2)
        XCTAssertNotEqual(section1, section3)
    }

    func testSongSectionCodable() throws {
        let section = SongSection(
            label: "Verse 1",
            lines: [
                SongLine(lyrics: "Line 1", chords: [ChordPosition(chord: "C", position: 0)]),
                SongLine(lyrics: "Line 2", chords: [ChordPosition(chord: "F", position: 0)])
            ]
        )
        let encoded = try JSONEncoder().encode(section)
        let decoded = try JSONDecoder().decode(SongSection.self, from: encoded)
        XCTAssertEqual(section, decoded)
    }

    // MARK: - Song

    func testSongInit() {
        let song = Song(title: "Test", artist: "Artist", key: "C")
        XCTAssertEqual(song.title, "Test")
        XCTAssertEqual(song.artist, "Artist")
        XCTAssertEqual(song.key, "C")
        XCTAssertTrue(song.sections.isEmpty)
    }

    func testSongDefaultValues() {
        let song = Song(title: "Test")
        XCTAssertEqual(song.transpose, 0)
        XCTAssertFalse(song.useFlats)
        XCTAssertFalse(song.useNashville)
    }

    func testSongAllChords() {
        let song = Song(
            title: "Test",
            sections: [
                SongSection(label: "V1", lines: [
                    SongLine(lyrics: "L1", chords: [ChordPosition(chord: "C", position: 0), ChordPosition(chord: "F", position: 5)]),
                    SongLine(lyrics: "L2", chords: [ChordPosition(chord: "G", position: 0)])
                ]),
                SongSection(label: "C", lines: [
                    SongLine(lyrics: "L3", chords: [ChordPosition(chord: "Am", position: 0)])
                ])
            ]
        )
        let chords = song.allChords
        XCTAssertEqual(chords.count, 4)
        XCTAssertTrue(chords.contains("C"))
        XCTAssertTrue(chords.contains("F"))
        XCTAssertTrue(chords.contains("G"))
        XCTAssertTrue(chords.contains("Am"))
    }

    func testSongHasChords() {
        let songWithChords = Song(title: "Test", sections: [SongSection(label: "V", lines: [SongLine(lyrics: "L", chords: [ChordPosition(chord: "C", position: 0)])])])
        let songWithoutChords = Song(title: "Test", sections: [SongSection(label: "V", lines: [SongLine(lyrics: "L")])])
        XCTAssertTrue(songWithChords.hasChords)
        XCTAssertFalse(songWithoutChords.hasChords)
    }

    func testSongEquality() {
        let song1 = Song(title: "Test", artist: "A", key: "C")
        let song2 = Song(title: "Test", artist: "A", key: "C")
        let song3 = Song(title: "Different", artist: "A", key: "C")
        XCTAssertEqual(song1, song2)
        XCTAssertNotEqual(song1, song3)
    }

    func testSongCodable() throws {
        let song = Song(
            title: "Test Song",
            artist: "Test Artist",
            key: "G",
            tempo: "120",
            timeSignature: "4/4",
            ccli: "123456",
            copyright: "© 2024",
            notes: "Some notes",
            sections: [
                SongSection(label: "Verse 1", lines: [
                    SongLine(lyrics: "Amazing grace", chords: [ChordPosition(chord: "G", position: 0), ChordPosition(chord: "D", position: 7)])
                ])
            ],
            originalKey: "G",
            transpose: 2,
            useFlats: true,
            useNashville: false
        )
        let encoded = try JSONEncoder().encode(song)
        let decoded = try JSONDecoder().decode(Song.self, from: encoded)
        XCTAssertEqual(song, decoded)
    }

    // MARK: - SetListItem

    func testSetListItemInit() {
        let item = SetListItem(songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        XCTAssertEqual(item.songPath, "/path/song.txt")
        XCTAssertEqual(item.songTitle, "Song")
        XCTAssertEqual(item.songArtist, "Artist")
        XCTAssertEqual(item.position, 0)
        XCTAssertNil(item.notes)
        XCTAssertNotNil(item.id)
    }

    func testSetListItemWithAllFields() {
        let id = UUID()
        let setListId = UUID()
        let item = SetListItem(
            id: id,
            setListId: setListId,
            songPath: "/path/song.txt",
            songTitle: "Song",
            songArtist: "Artist",
            position: 5,
            notes: "Play slowly"
        )
        XCTAssertEqual(item.id, id)
        XCTAssertEqual(item.setListId, setListId)
        XCTAssertEqual(item.position, 5)
        XCTAssertEqual(item.notes, "Play slowly")
    }

    func testSetListItemEquality() {
        let item1 = SetListItem(songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        let item2 = SetListItem(songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        // Different UUIDs mean not equal
        XCTAssertNotEqual(item1, item2)

        // Same UUID
        let id = UUID()
        let item3 = SetListItem(id: id, songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        let item4 = SetListItem(id: id, songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        XCTAssertEqual(item3, item4)
    }

    func testSetListItemCodable() throws {
        let item = SetListItem(
            songPath: "/path/song.txt",
            songTitle: "Song Title",
            songArtist: "Artist Name",
            position: 3,
            notes: "Solo verse"
        )
        let encoded = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(SetListItem.self, from: encoded)
        XCTAssertEqual(item.songPath, decoded.songPath)
        XCTAssertEqual(item.songTitle, decoded.songTitle)
        XCTAssertEqual(item.songArtist, decoded.songArtist)
        XCTAssertEqual(item.position, decoded.position)
        XCTAssertEqual(item.notes, decoded.notes)
    }

    // MARK: - SetList

    func testSetListInit() {
        let setlist = SetList(name: "Worship Set")
        XCTAssertEqual(setlist.name, "Worship Set")
        XCTAssertTrue(setlist.items.isEmpty)
        XCTAssertNotNil(setlist.id)
        XCTAssertEqual(setlist.createdAt, setlist.modifiedAt)
    }

    func testSetListAddItem() {
        var setlist = SetList(name: "Test")
        let item = SetListItem(songPath: "/path/song.txt", songTitle: "Song", songArtist: "Artist")
        setlist.addItem(item)

        XCTAssertEqual(setlist.items.count, 1)
        XCTAssertEqual(setlist.items[0].songTitle, "Song")
        XCTAssertEqual(setlist.items[0].setListId, setlist.id)
        XCTAssertEqual(setlist.items[0].position, 0)
        XCTAssertTrue(setlist.modifiedAt > setlist.createdAt)
    }

    func testSetListAddMultipleItems() {
        var setlist = SetList(name: "Test")
        setlist.addItem(SetListItem(songPath: "/1.txt", songTitle: "Song 1"))
        setlist.addItem(SetListItem(songPath: "/2.txt", songTitle: "Song 2"))
        setlist.addItem(SetListItem(songPath: "/3.txt", songTitle: "Song 3"))

        XCTAssertEqual(setlist.items.count, 3)
        XCTAssertEqual(setlist.items[0].position, 0)
        XCTAssertEqual(setlist.items[1].position, 1)
        XCTAssertEqual(setlist.items[2].position, 2)
    }

    func testSetListRemoveItem() {
        var setlist = SetList(name: "Test")
        setlist.addItem(SetListItem(songPath: "/1.txt", songTitle: "Song 1"))
        setlist.addItem(SetListItem(songPath: "/2.txt", songTitle: "Song 2"))
        setlist.addItem(SetListItem(songPath: "/3.txt", songTitle: "Song 3"))

        setlist.removeItem(at: 1)

        XCTAssertEqual(setlist.items.count, 2)
        XCTAssertEqual(setlist.items[0].songTitle, "Song 1")
        XCTAssertEqual(setlist.items[1].songTitle, "Song 3")
        XCTAssertEqual(setlist.items[0].position, 0)
        XCTAssertEqual(setlist.items[1].position, 1)
    }

    func testSetListMoveItem() {
        var setlist = SetList(name: "Test")
        setlist.addItem(SetListItem(songPath: "/1.txt", songTitle: "Song 1"))
        setlist.addItem(SetListItem(songPath: "/2.txt", songTitle: "Song 2"))
        setlist.addItem(SetListItem(songPath: "/3.txt", songTitle: "Song 3"))

        setlist.moveItem(from: 0, to: 2)

        XCTAssertEqual(setlist.items[0].songTitle, "Song 2")
        XCTAssertEqual(setlist.items[1].songTitle, "Song 3")
        XCTAssertEqual(setlist.items[2].songTitle, "Song 1")
        XCTAssertEqual(setlist.items[0].position, 0)
        XCTAssertEqual(setlist.items[1].position, 1)
        XCTAssertEqual(setlist.items[2].position, 2)
    }

    func testSetListUpdateName() {
        var setlist = SetList(name: "Original")
        let originalModified = setlist.modifiedAt

        // Small delay to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.01)
        setlist.updateName("Updated")

        XCTAssertEqual(setlist.name, "Updated")
        XCTAssertTrue(setlist.modifiedAt > originalModified)
    }

    func testSetListEquality() {
        let id = UUID()
        let date = Date()
        let setlist1 = SetList(id: id, name: "Test", createdAt: date, modifiedAt: date, items: [])
        let setlist2 = SetList(id: id, name: "Test", createdAt: date, modifiedAt: date, items: [])
        XCTAssertEqual(setlist1, setlist2)
    }

    func testSetListCodable() throws {
        var setlist = SetList(name: "Worship Set")
        setlist.addItem(SetListItem(songPath: "/song1.txt", songTitle: "Song 1", songArtist: "Artist 1"))
        setlist.addItem(SetListItem(songPath: "/song2.txt", songTitle: "Song 2", songArtist: "Artist 2"))

        let encoded = try JSONEncoder().encode(setlist)
        let decoded = try JSONDecoder().decode(SetList.self, from: encoded)

        XCTAssertEqual(setlist.name, decoded.name)
        XCTAssertEqual(setlist.items.count, decoded.items.count)
        XCTAssertEqual(setlist.items[0].songTitle, decoded.items[0].songTitle)
        XCTAssertEqual(setlist.items[1].songTitle, decoded.items[1].songTitle)
    }

    // MARK: - Sendable Conformance

    func testModelsAreSendable() {
        // This test compiles only if all models conform to Sendable
        let _: any Sendable = ChordPosition(chord: "C", position: 0)
        let _: any Sendable = KeyChange(newKey: "D")
        let _: any Sendable = SongLine(lyrics: "Test")
        let _: any Sendable = SongSection(label: "Verse")
        let _: any Sendable = Song(title: "Test")
        let _: any Sendable = SetListItem(songPath: "/path", songTitle: "Song")
        let _: any Sendable = SetList(name: "Set")
    }
}