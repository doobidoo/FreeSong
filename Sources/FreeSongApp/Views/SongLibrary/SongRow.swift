import SwiftUI
import FreeSongCore

struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if let artist = song.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let key = song.key, !key.isEmpty {
                Text(key)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(.accent.opacity(0.12)))
            }
        }
        .padding(.vertical, 2)
    }
}
