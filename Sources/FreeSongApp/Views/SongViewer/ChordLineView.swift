import SwiftUI
import FreeSongCore

/// Renders a single line of lyrics with chords positioned above the text.
/// Chords are aligned geometrically (one segment per chord) so alignment holds
/// at any font size and survives line wrapping.
struct ChordLineView: View {
    let line: SongLine
    var fontSize: Double = 18

    var body: some View {
        if line.isKeyChange, let keyChange = line.keyChange {
            HStack {
                Image(systemName: "arrow.triangle.swap")
                    .foregroundStyle(.accent)
                Text("Key Change: \(keyChange.newKey)")
                    .font(.headline.weight(.medium))
                    .foregroundStyle(.accent)
            }
            .padding(.vertical, 4)
        } else if !line.chords.isEmpty {
            chordFlow
                .padding(.vertical, 2)
        } else {
            Text(line.lyrics)
                .font(.system(size: fontSize))
                .lineLimit(nil)
                .padding(.vertical, 2)
        }
    }

    private var segments: [ChordSegment] {
        ChordSegmenter.segments(lyrics: line.lyrics, chords: line.chords)
    }

    /// One column per segment: chord (smaller, bold, accent) stacked over its
    /// lyric run. Horizontal spacing is 0 because segment texts already carry the
    /// inter-word spaces; the flow only decides where rows wrap.
    private var chordFlow: some View {
        FlowLayout(spacing: 0, lineSpacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, seg in
                VStack(alignment: .leading, spacing: 1) {
                    Text(seg.chord ?? " ")
                        .font(.system(size: fontSize * 0.8, weight: .semibold))
                        .foregroundStyle(.accent)
                        .fixedSize()
                    Text(seg.text.isEmpty ? "\u{00A0}" : seg.text)
                        .font(.system(size: fontSize))
                        .fixedSize()
                }
            }
        }
    }
}

#Preview("ChordLineView") {
    VStack(alignment: .leading, spacing: 12) {
        ChordLineView(line: SongLine(
            lyrics: "Amazing grace how sweet the sound",
            chords: [ChordPosition(chord: "G", position: 0),
                     ChordPosition(chord: "C", position: 8),
                     ChordPosition(chord: "D", position: 24)]))
        ChordLineView(line: SongLine(lyrics: "That saved a wretch like me"))
    }
    .padding()
}