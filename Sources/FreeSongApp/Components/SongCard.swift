import SwiftUI
import FreeSongCore

/// A compact card displaying a song's title, artist, and key.
struct SongCard: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            // Song icon
            Image(systemName: "music.note")
                .font(.title3)
                .foregroundStyle(.accent)
                .frame(width: 32)

            // Title + Artist
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

            // Key badge
            if let key = song.key, !key.isEmpty {
                Text(key)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.accent.opacity(0.12))
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview("SongCard") {
    List {
        SongCard(song: Song(title: "Amazing Grace", artist: "John Newton", key: "G"))
        SongCard(song: Song(title: "Here I Am to Worship", key: "D"))
        SongCard(song: Song(title: "Way Maker", artist: "Sinach"))
    }
}
