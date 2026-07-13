import Foundation

/// A run of lyric text with an optional chord anchored above its first character.
public struct ChordSegment: Equatable, Sendable {
    public var chord: String?
    public var text: String

    public init(chord: String?, text: String) {
        self.chord = chord
        self.text = text
    }
}

/// Splits a lyric line into segments for geometric chord-over-syllable layout.
///
/// Each chord starts a new segment that runs until the next chord (or end of
/// line). A leading run before the first chord becomes a chord-less segment.
/// Positions are clamped into `0...lyrics.count`; a chord at or past the end
/// gets an empty-text segment. Concatenating all segment texts reproduces the
/// original lyrics.
public enum ChordSegmenter {
    public static func segments(lyrics: String, chords: [ChordPosition]) -> [ChordSegment] {
        let chars = Array(lyrics)
        let n = chars.count
        let sorted = chords.sorted { $0.position < $1.position }

        guard let first = sorted.first else {
            return lyrics.isEmpty ? [] : [ChordSegment(chord: nil, text: lyrics)]
        }

        var result: [ChordSegment] = []
        let firstPos = min(max(first.position, 0), n)
        if firstPos > 0 {
            result.append(ChordSegment(chord: nil, text: String(chars[0..<firstPos])))
        }

        for (i, cp) in sorted.enumerated() {
            let start = min(max(cp.position, 0), n)
            let end = (i + 1 < sorted.count)
                ? min(max(sorted[i + 1].position, start), n)
                : n
            let text = start < end ? String(chars[start..<end]) : ""
            result.append(ChordSegment(chord: cp.chord, text: text))
        }
        return result
    }
}