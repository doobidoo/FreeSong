import SwiftUI
import FreeSongCore

/// Renders a single line of lyrics with chords positioned above the text.
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
            VStack(alignment: .leading, spacing: 0) {
                chordLine
                lyricsLine
            }
        } else {
            Text(line.lyrics)
                .font(.system(size: fontSize, design: .monospaced))
                .lineLimit(nil)
                .padding(.vertical, 2)
        }
    }

    /// Chords sorted by position, padded with spaces to align over lyrics.
    private var chordLine: some View {
        var result = ""
        var cursor = 0
        for cp in line.chords.sorted(by: { $0.position < $1.position }) {
            let pos = max(cp.position, cursor)
            result += String(repeating: " ", count: pos - cursor)
            result += cp.chord + " "
            cursor = pos + cp.chord.count + 1
        }
        return Text(result)
            .font(.system(size: fontSize * 0.75, design: .monospaced).weight(.semibold))
            .foregroundStyle(.accent)
            .padding(.bottom, -2)
    }

    private var lyricsLine: some View {
        Text(line.lyrics)
            .font(.system(size: fontSize, design: .monospaced))
            .lineLimit(nil)
    }
}
