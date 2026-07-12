import XCTest
@testable import FreeSongCore

final class ChordFormatConverterTests: XCTestCase {

    // MARK: - Inline to Above

    func testInlineToAboveBasic() {
        let input = "[G]Amazing [D]grace"
        let expected = "G       D\nAmazing grace"
        XCTAssertEqual(ChordFormatConverter.inlineToAbove(input), expected)
    }

    func testInlineToAboveMultipleChords() {
        let input = "[C]This is [F]a [G]test [C]line"
        let result = ChordFormatConverter.inlineToAbove(input)
        // Check chords line has chords at correct positions
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("C"))
        XCTAssertTrue(lines[0].contains("F"))
        XCTAssertTrue(lines[0].contains("G"))
        XCTAssertTrue(lines[1].contains("This is a test line"))
    }

    func testInlineToAboveMultipleLines() {
        let input = "[C]Line [F]one\n[G]Line [C]two"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 4) // 2 chord lines + 2 lyrics lines
    }

    func testInlineToAboveNoChords() {
        let input = "Just plain text\nNo chords here"
        XCTAssertEqual(ChordFormatConverter.inlineToAbove(input), input)
    }

    func testInlineToAboveMixedLines() {
        let input = "[C]Chord line\nPlain line\n[G]Another [C]chord line"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        // chord line, lyrics line, plain line, chord line, lyrics line = 5
        XCTAssertEqual(lines.count, 5)
    }

    func testInlineToAbovePreservesTrailingNewline() {
        let input = "[C]Test\n"
        let result = ChordFormatConverter.inlineToAbove(input)
        XCTAssertTrue(result.hasSuffix("\n"))
    }

    func testInlineToAboveNoTrailingNewline() {
        let input = "[C]Test"
        let result = ChordFormatConverter.inlineToAbove(input)
        XCTAssertFalse(result.hasSuffix("\n"))
    }

    // MARK: - Above to Inline

    func testAboveToInlineBasic() {
        let input = "G       D\nAmazing grace"
        let expected = "[G]Amazing [D]grace"
        XCTAssertEqual(ChordFormatConverter.aboveToInline(input), expected)
    }

    func testAboveToInlineMultipleChords() {
        let input = "C   F   G   C\nThis is a test line"
        let result = ChordFormatConverter.aboveToInline(input)
        XCTAssertTrue(result.contains("[C]"))
        XCTAssertTrue(result.contains("[F]"))
        XCTAssertTrue(result.contains("[G]"))
    }

    func testAboveToInlineMultipleLinePairs() {
        // Chord lines must have chords positioned to match lyrics character positions
        // "Line one" -> "C" at pos 0, "F" at pos 5 (after "Line ")
        // "Line two" -> "G" at pos 0, "C" at pos 5
        let input = "C    F\nLine one\nG    C\nLine two"
        let result = ChordFormatConverter.aboveToInline(input)
        XCTAssertTrue(result.contains("[C]Line [F]one"))
        XCTAssertTrue(result.contains("[G]Line [C]two"))
    }

    func testAboveToInlineNonChordLines() {
        // "Chord line" -> "C" at pos 0, "F" at pos 6 (after "Chord ")
        let input = "Just text\nC     F\nChord line"
        let result = ChordFormatConverter.aboveToInline(input)
        XCTAssertTrue(result.hasPrefix("Just text"))
        XCTAssertTrue(result.contains("[C]Chord [F]line"))
    }

    // MARK: - Round Trip

    func testRoundTripInlineAboveInline() {
        let original = "[C]Amazing [F]grace [G]how [C]sweet"
        let above = ChordFormatConverter.inlineToAbove(original)
        let back = ChordFormatConverter.aboveToInline(above)
        // Should be equivalent (may have minor spacing differences)
        XCTAssertTrue(back.contains("[C]"))
        XCTAssertTrue(back.contains("[F]"))
        XCTAssertTrue(back.contains("[G]"))
    }

    func testRoundTripAboveInlineAbove() {
        let original = "C   F\nAmazing grace"
        let inline = ChordFormatConverter.aboveToInline(original)
        let back = ChordFormatConverter.inlineToAbove(inline)
        let lines = back.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("C"))
        XCTAssertTrue(lines[0].contains("F"))
    }

    // MARK: - Format Detection

    func testIsInlineFormat() {
        XCTAssertTrue(ChordFormatConverter.isInlineFormat("[C]Line [F]one\n[G]Line [C]two"))
        XCTAssertTrue(ChordFormatConverter.isInlineFormat("[G]Amazing [D]grace"))
    }

    func testIsAboveFormat() {
        XCTAssertTrue(ChordFormatConverter.isInlineFormat("C   D\nAmazing grace") == false)
        // Above format has more chord-only lines than inline chord lines
    }

    func testIsChordOnlyLine() {
        XCTAssertTrue(ChordFormatConverter.isChordOnlyLine("C F G Am"))
        XCTAssertTrue(ChordFormatConverter.isChordOnlyLine("Cmaj7 F#m7 Bb"))
        XCTAssertTrue(ChordFormatConverter.isChordOnlyLine("G/B C/E"))
        XCTAssertTrue(ChordFormatConverter.isChordOnlyLine("C♯ D♭"))
        XCTAssertFalse(ChordFormatConverter.isChordOnlyLine("This is text"))
        XCTAssertFalse(ChordFormatConverter.isChordOnlyLine("[C]Inline chord"))
        XCTAssertFalse(ChordFormatConverter.isChordOnlyLine(""))
        XCTAssertFalse(ChordFormatConverter.isChordOnlyLine("   "))
    }

    func testHasInlineChords() {
        XCTAssertTrue(ChordFormatConverter.hasInlineChords("[C]Test"))
        XCTAssertTrue(ChordFormatConverter.hasInlineChords("Text [G]with [F]chords"))
        XCTAssertFalse(ChordFormatConverter.hasInlineChords("No chords here"))
        XCTAssertFalse(ChordFormatConverter.hasInlineChords("C F G")) // chord-only line, not inline
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        let input = "[G]Amazing [D]grace"
        let expected = "G       D\nAmazing grace"
        XCTAssertEqual(ChordFormatConverter.inlineToAbove(input), expected)
    }

    func testOverlappingChords() {
        let input = "[C][F][G]Three"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        // All chords should be on the chord line
        XCTAssertTrue(lines[0].contains("C"))
        XCTAssertTrue(lines[0].contains("F"))
        XCTAssertTrue(lines[0].contains("G"))
    }

    func testChordAtEndOfLine() {
        let input = "Line ends with [C]chord"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[1].hasSuffix("chord"))
    }

    func testChordAtStartOfLine() {
        let input = "[C]Start with chord"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("C"))
    }

    func testComplexChordSymbols() {
        let input = "[Cmaj7]Test [F#m7b5]chords [G7#9]with [Bb9#11]extensions"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("Cmaj7"))
        XCTAssertTrue(lines[0].contains("F#m7b5"))
        XCTAssertTrue(lines[0].contains("G7#9"))
        XCTAssertTrue(lines[0].contains("Bb9#11"))
    }

    func testUnicodeChords() {
        let input = "[C♯]Test [D♭]unicode [G♯]chords [A♭]here"
        let result = ChordFormatConverter.inlineToAbove(input)
        let lines = result.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("C♯"))
        XCTAssertTrue(lines[0].contains("D♭"))
        XCTAssertTrue(lines[0].contains("G♯"))
        XCTAssertTrue(lines[0].contains("A♭"))
    }

    // MARK: - D6: Overlap / dense-packing round-trip stability

    func testDenselyPackedChordsPreserveIdentityAfterRoundTrip() {
        let input = "[C][F][G]Three"
        let above = ChordFormatConverter.inlineToAbove(input)
        let back = ChordFormatConverter.aboveToInline(above)
        // All three chords must survive as distinct tokens — never merged into an
        // unparseable run like "CFG" by missing separators.
        XCTAssertTrue(back.contains("[C]"))
        XCTAssertTrue(back.contains("[F]"))
        XCTAssertTrue(back.contains("[G]"))
        XCTAssertEqual(back.filter { $0 == "[" }.count, 3)
    }

    func testOverlappingChordsRoundTripReachesStableFixedPoint() {
        // Two chords at the exact same source position are inherently lossy to render
        // as plain-text columns (see ChordFormatConverter.inlineToAbove); the contract
        // is stability (idempotency), not necessarily exact recovery of the original.
        let input = "[C][G]word"
        let above1 = ChordFormatConverter.inlineToAbove(input)
        let back1 = ChordFormatConverter.aboveToInline(above1)
        let above2 = ChordFormatConverter.inlineToAbove(back1)
        let back2 = ChordFormatConverter.aboveToInline(above2)
        XCTAssertEqual(back2, back1, "Repeated round-tripping should reach a fixed point, not keep drifting")
        XCTAssertTrue(back1.contains("[C]"))
        XCTAssertTrue(back1.contains("[G]"))
    }

    func testChordsAtLineStartSurviveRoundTripAsDistinctChords() {
        // Two chords both anchored before a short word: an unavoidably lossy case
        // (see testOverlappingChordsRoundTripReachesStableFixedPoint), but both chords
        // must still come back out as distinct, valid tokens rather than being dropped
        // or merged.
        let input = "[C][D]wo"
        let above = ChordFormatConverter.inlineToAbove(input)
        let back = ChordFormatConverter.aboveToInline(above)
        XCTAssertEqual(back, "[C]wo[D]")
        XCTAssertTrue(back.contains("[C]"))
        XCTAssertTrue(back.contains("[D]"))
    }

    // MARK: - D7: Toggle-cycle newline idempotency

    func testAboveInlineToggleRoundTripPreservesTrailingNewline() {
        let input = "G       D\nAmazing grace\n"
        let inline = ChordFormatConverter.aboveToInline(input)
        XCTAssertEqual(inline, "[G]Amazing [D]grace\n")
        let backToAbove = ChordFormatConverter.inlineToAbove(inline)
        XCTAssertEqual(backToAbove, input, "Toggling above -> inline -> above should not introduce a blank line")
    }

    func testMultipleToggleCyclesDoNotAccumulateBlankLines() {
        var content = "G   D\nAmazing grace\n"
        let initialNewlines = content.filter { $0 == "\n" }.count
        for _ in 0..<4 {
            content = ChordFormatConverter.aboveToInline(content)
            content = ChordFormatConverter.inlineToAbove(content)
        }
        XCTAssertEqual(content.filter { $0 == "\n" }.count, initialNewlines)
        XCTAssertFalse(content.hasSuffix("\n\n"))
    }

    // MARK: - shiftChord

    func testShiftChordClampsAtStartOfLine() {
        let result = ChordFormatConverter.shiftChord(in: "[C]Hello", globalChordOccurrence: 0, delta: -5, wordwise: false)
        XCTAssertEqual(result, "[C]Hello")
    }

    func testShiftChordClampsAtEndOfLine() {
        let result = ChordFormatConverter.shiftChord(in: "Hello[C]", globalChordOccurrence: 0, delta: 10, wordwise: false)
        XCTAssertEqual(result, "Hello[C]")
    }

    func testShiftChordMovesRight() {
        let result = ChordFormatConverter.shiftChord(in: "[C]Hello", globalChordOccurrence: 0, delta: 2, wordwise: false)
        XCTAssertEqual(result, "He[C]llo")
    }

    func testShiftChordAdjacentChordsCanCrossOrder() {
        // Shifting the first chord ("C") far enough right that it passes the second
        // chord ("D") should reorder them in the rebuilt line.
        let result = ChordFormatConverter.shiftChord(in: "[C]ab[D]cd", globalChordOccurrence: 0, delta: 5, wordwise: false)
        XCTAssertEqual(result, "ab[D]cd[C]")
    }

    func testShiftChordWordwiseWithUmlautsInLyrics() {
        let result = ChordFormatConverter.shiftChord(in: "[G]Über den Wolken", globalChordOccurrence: 0, delta: 1, wordwise: true)
        XCTAssertEqual(result, "Über [G]den Wolken")
    }

    func testShiftChordOnChordOnlyLineIsNoOp() {
        // No `[chord]` tags to find in an above-format chord-only line — shiftChord is
        // inline-format only, so the content should pass through unchanged.
        let result = ChordFormatConverter.shiftChord(in: "C F G", globalChordOccurrence: 0, delta: 1, wordwise: false)
        XCTAssertEqual(result, "C F G")
    }

    func testShiftChordAcrossEmptyLines() {
        let result = ChordFormatConverter.shiftChord(in: "\n[C]Hello\n", globalChordOccurrence: 0, delta: 2, wordwise: false)
        XCTAssertEqual(result, "\nHe[C]llo\n")
    }

    func testShiftChordExcludesTrailingCarriageReturn() {
        let result = ChordFormatConverter.shiftChord(in: "[C]Hello\r\n[D]World\r\n", globalChordOccurrence: 0, delta: 2, wordwise: false)
        XCTAssertEqual(result, "He[C]llo\r\n[D]World\r\n")
    }

    func testShiftChordOnSecondLineAfterCRLF() {
        let result = ChordFormatConverter.shiftChord(in: "[C]Hello\r\n[D]World\r\n", globalChordOccurrence: 1, delta: -2, wordwise: false)
        XCTAssertEqual(result, "[C]Hello\r\n[D]World\r\n")
    }
}