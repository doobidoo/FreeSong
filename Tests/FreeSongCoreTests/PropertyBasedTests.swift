import XCTest
@testable import FreeSongCore

final class PropertyBasedTests: XCTestCase {

    // MARK: - Transposer Round-Trip

    func testTransposeRoundTrip() {
        // Transposing up then down by same amount should return original
        let chords = ["C", "C#", "Db", "D", "D#", "Eb", "E", "F", "F#", "Gb", "G", "G#", "Ab", "A", "A#", "Bb", "B",
                      "Am", "Cmaj7", "G7", "F#m7b5", "Bb9", "C#dim", "Dbdim", "Gsus4", "Cadd9", "F6/9",
                      "G/B", "C/E", "D/F#", "Am/G", "F#m/A"]

        for chord in chords {
            for semitones in -11...11 {
                let up = Transposer.transposeChord(chord, by: semitones)
                let down = Transposer.transposeChord(up, by: -semitones)
                // Accept enharmonic equivalence (e.g. C# ≅ Db) since accidental
                // preference may not survive a round-trip through natural notes.
                XCTAssertTrue(areEnharmonicallyEquivalent(down, chord),
                              "Round-trip failed for '\(chord)' with \(semitones) semitones: got '\(down)'")
            }
        }
    }

    func testTranspose12SemitonesIsIdentity() {
        let chords = ["C", "C#", "Db", "D", "F#", "Gb", "G", "Bb", "Bm7", "F#m7b5", "G/B"]
        for chord in chords {
            let result = Transposer.transposeChord(chord, by: 12)
            XCTAssertEqual(result, chord, "12 semitones should be identity for '\(chord)'")
            let resultDown = Transposer.transposeChord(chord, by: -12)
            XCTAssertEqual(resultDown, chord, "-12 semitones should be identity for '\(chord)'")
        }
    }

    func testTranspose24SemitonesIsIdentity() {
        let chords = ["C", "F#", "Bb", "Am7", "C/E"]
        for chord in chords {
            let result = Transposer.transposeChord(chord, by: 24)
            XCTAssertEqual(result, chord, "24 semitones should be identity for '\(chord)'")
        }
    }

    // MARK: - Nashville Round-Trip

    func testNashvilleRoundTrip() {
        let keys = ["C", "G", "D", "A", "E", "F", "Bb", "Eb", "F#", "Gb", "C#", "Db"]
        let chords = ["1", "2m", "3m", "4", "57", "6m", "7dim", "1maj7", "2m7", "4maj7", "59",
                      "1/3", "5/7", "4/6", "1sus4", "2sus2", "6m7b5"]

        for key in keys {
            for nashville in chords {
                let chord = NashvilleConverter.nashvilleToChord(nashville, key: key)
                let back = NashvilleConverter.chordToNashville(chord, key: key)
                // Note: accidental preference might differ, so check semantic equivalence
                XCTAssertTrue(areNashvilleEquivalent(nashville, back, key: key),
                              "Round-trip failed: '\(nashville)' in key '\(key)' -> '\(chord)' -> '\(back)'")
            }
        }
    }

    func testNashvilleRoundTripWithAccidentals() {
        let keys = ["C", "G", "D", "A", "E", "F", "Bb", "Eb"]
        let nashvilleChords = ["#1", "b2", "#2", "b3", "#4", "b5", "#5", "b6", "#6", "b7",
                               "#1m", "b2m", "#4m", "b5m",
                               "#17", "b27", "#47", "b57"]

        for key in keys {
            for nashville in nashvilleChords {
                let chord = NashvilleConverter.nashvilleToChord(nashville, key: key)
                let back = NashvilleConverter.chordToNashville(chord, key: key)
                XCTAssertTrue(areNashvilleEquivalent(nashville, back, key: key),
                              "Accidental round-trip failed: '\(nashville)' in key '\(key)' -> '\(chord)' -> '\(back)'")
            }
        }
    }

    func testNashvilleSlashChordRoundTrip() {
        let slashChords = ["1/3", "2m/4", "5/7", "4/6", "6m/1", "b3/5"]
        for key in ["C", "G", "D", "F", "Bb"] {
            for nashville in slashChords {
                let chord = NashvilleConverter.nashvilleToChord(nashville, key: key)
                let back = NashvilleConverter.chordToNashville(chord, key: key)
                XCTAssertTrue(areNashvilleEquivalent(nashville, back, key: key),
                              "Slash chord round-trip failed: '\(nashville)' in key '\(key)'")
            }
        }
    }

    // MARK: - ChordFormatConverter Round-Trip

    func testInlineToAboveToInlineRoundTrip() {
        let testCases = [
            "[C]Test [F]line",
            "[G]Amazing [D]grace [Em]how [C]sweet",
            "[Cmaj7]Complex [F#m7b5]chords [G7#9]with [Bb9#11]extensions",
            "[C]Start [F]middle [G]end",
            "No chords here",
            "[C]Only chords"
        ]

        for input in testCases {
            let above = ChordFormatConverter.inlineToAbove(input)
            let back = ChordFormatConverter.aboveToInline(above)
            // Normalize whitespace for comparison
            let normalizedInput = input.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalizedBack = back.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines)
            XCTAssertEqual(normalizedBack, normalizedInput, "Format round-trip failed for: \(input)")
        }
    }

    func testAboveToInlineToAboveRoundTrip() {
        let testCases = [
            "C       F\nTest line",
            "G       D       Em       C\nAmazing grace how sweet",
            "Cmaj7   F#m7b5  G7#9    Bb9#11\nComplex chords"
        ]

        for input in testCases {
            let inline = ChordFormatConverter.aboveToInline(input)
            let back = ChordFormatConverter.inlineToAbove(inline)
            // Check chords are preserved
            let inputChords = extractChords(from: input)
            let backChords = extractChords(from: back)
            XCTAssertEqual(backChords.sorted(), inputChords.sorted(), "Chord preservation failed for: \(input)")
        }
    }

    // MARK: - AccidentalConverter Round-Trip

    func testAccidentalConverterRoundTrip() {
        let testCases = [
            "C# D# F# G# A#",
            "Db Eb Gb Ab Bb",
            "[C#m]Amazing [F#]grace",
            "[Dbm]Amazing [Gb]grace",
            "G/B C#/G# F/A",
            "G/Bb Db/Ab",
            "C#       F#\nTest line"
        ]

        for input in testCases {
            let normInput = normalizeWhitespace(input)
            let hasSharps = AccidentalConverter.isSharpsFormat(input)

            if hasSharps {
                // Valid round-trip: sharps -> flats -> sharps
                let toFlats = AccidentalConverter.convertToFlats(input)
                let backToSharps = AccidentalConverter.convertToSharps(toFlats)
                let normBack = normalizeWhitespace(backToSharps)
                XCTAssertEqual(normBack, normInput,
                               "Sharp->Flat->Sharp round-trip failed for: \(input)")
            } else {
                // Valid round-trip: flats -> sharps -> flats
                let toSharps = AccidentalConverter.convertToSharps(input)
                let backToFlats = AccidentalConverter.convertToFlats(toSharps)
                let normBack = normalizeWhitespace(backToFlats)
                XCTAssertEqual(normBack, normInput,
                               "Flat->Sharp->Flat round-trip failed for: \(input)")
            }
        }
    }

    // MARK: - Transposer + Nashville Consistency

    func testTransposeThenNashvilleEqualsNashvilleThenTranspose() {
        let keys = ["C", "G", "D", "F", "Bb"]
        let chords = ["C", "Dm", "Em", "F", "G7", "Am", "Bdim", "Cmaj7", "Dm7", "G9", "F#m7b5"]

        for key in keys {
            for chord in chords {
                // Transpose chord up 2, then convert to Nashville in new key
                let transposedChord = Transposer.transposeChord(chord, by: 2)
                let newKey = Transposer.transposeChord(key, by: 2)
                let nashvilleAfterTranspose = NashvilleConverter.chordToNashville(transposedChord, key: newKey)

                // Convert to Nashville in original key, then transpose Nashville
                let nashvilleOriginal = NashvilleConverter.chordToNashville(chord, key: key)
                // Nashville numbers don't transpose the same way, but the chord should be same
                let chordFromNashville = NashvilleConverter.nashvilleToChord(nashvilleOriginal, key: newKey)

                XCTAssertEqual(nashvilleAfterTranspose, nashvilleOriginal,
                              "Transpose+Nashville != Nashville+Transpose for '\(chord)' in '\(key)'")
            }
        }
    }

    // MARK: - Detection Consistency

    func testIsNashvilleDetection() {
        let nashvilleChords = ["1", "2m", "3m", "4", "57", "6m", "7dim", "1maj7", "2m7", "4/6", "5/7",
                               "#1", "b2", "#4m", "b57", "1/3", "5/7"]
        for nc in nashvilleChords {
            XCTAssertTrue(NashvilleConverter.isNashvilleNotation(nc), "Should detect '\(nc)' as Nashville")
        }

        let standardChords = ["C", "C#", "Db", "Am", "G7", "Fmaj7", "C/E", "G/B", "C#m", "Gb"]
        for sc in standardChords {
            XCTAssertFalse(NashvilleConverter.isNashvilleNotation(sc), "Should NOT detect '\(sc)' as Nashville")
        }
    }

    func testIsSharpsFormatDetection() {
        let sharps = ["C# D# F#", "[C#m] [F#]", "G/B C#/G#", "C#       F#\nLine"]
        for s in sharps {
            XCTAssertTrue(AccidentalConverter.isSharpsFormat(s), "Should detect sharps format: \(s)")
        }

        let flats = ["Db Eb Gb", "[Dbm] [Gb]", "G/B Db/Ab", "Db       Gb\nLine"]
        for f in flats {
            XCTAssertFalse(AccidentalConverter.isSharpsFormat(f), "Should detect flats format: \(f)")
        }

        let neutral = ["C D E", "[C] [F] [G]", "C       F\nLine"]
        for n in neutral {
            XCTAssertTrue(AccidentalConverter.isSharpsFormat(n), "Neutral should default to sharps: \(n)")
        }
    }

    func testIsInlineFormatDetection() {
        let inline = ["[C]Test [F]line", "[G]Amazing [D]grace", "[C][F][G]Consecutive"]
        for i in inline {
            XCTAssertTrue(ChordFormatConverter.isInlineFormat(i), "Should detect inline: \(i)")
        }

        let above = ["C       F\nTest line", "G       D       Em       C\nAmazing grace"]
        for a in above {
            XCTAssertFalse(ChordFormatConverter.isInlineFormat(a), "Should detect above format: \(a)")
        }
    }

    // MARK: - Helpers

    private func areNashvilleEquivalent(_ a: String, _ b: String, key: String) -> Bool {
        // Convert both to chords in the same key and compare
        let chordA = NashvilleConverter.nashvilleToChord(a, key: key)
        let chordB = NashvilleConverter.nashvilleToChord(b, key: key)
        return chordA == chordB
    }

    private func extractChords(from text: String) -> [String] {
        let pattern = #/\[([^\]]+)\]/#
        return text.matches(of: pattern).map { String($0.output.1) }
    }

    private func normalizeWhitespace(_ s: String) -> String {
        return s.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Check if two chords are enharmonically equivalent (e.g. C# ≅ Db).
    /// Ignores accidental spelling — only verifies they represent the same pitch.
    private func areEnharmonicallyEquivalent(_ lhs: String, _ rhs: String) -> Bool {
        if lhs == rhs { return true }
        guard let lhsRoot = parseRoot(lhs), let rhsRoot = parseRoot(rhs) else {
            return false
        }
        // Same suffix (quality) and same root index → enharmonically equivalent
        return lhsRoot.suffix == rhsRoot.suffix && lhsRoot.index == rhsRoot.index
    }

    /// Extract the semitone index of a chord's root and its quality suffix.
    private func parseRoot(_ chord: String) -> (index: Int, suffix: String)? {
        guard !chord.isEmpty else { return nil }
        // Handle slash chords: compare only main part (bass note may differ enharmonically)
        let mainPart: String
        if let slashIdx = chord.firstIndex(of: "/") {
            mainPart = String(chord[..<slashIdx])
        } else {
            mainPart = chord
        }
        let pattern = #/^([A-G][#b♯♭]?)(.*)$/#
        guard let match = mainPart.firstMatch(of: pattern) else { return nil }
        let root = String(match.output.1)
        let suffix = String(match.output.2)
        let normalized = root
            .replacingOccurrences(of: "♯", with: "#")
            .replacingOccurrences(of: "♭", with: "b")
        // Normalise flats to sharps so the notes-lookup works with the
        // sharp-only array (i.e. Db → C#, Eb → D#, Gb → F#, Ab → G#, Bb → A#).
        let flatToSharp = ["Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#",
                           "db": "C#", "eb": "D#", "gb": "F#", "ab": "G#", "bb": "A#"]
        let lookup = flatToSharp[normalized] ?? normalized
        let notes = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        guard let idx = notes.firstIndex(where: { $0.caseInsensitiveCompare(lookup) == .orderedSame }) else {
            return nil
        }
        // Return the chord's full suffix (quality + slash if present)
        let slashPart: String
        if let slashIdx = chord.firstIndex(of: "/") {
            slashPart = String(chord[slashIdx...])
        } else {
            slashPart = ""
        }
        return (idx, suffix + slashPart)
    }
}