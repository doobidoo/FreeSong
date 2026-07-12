import Foundation

// MARK: - Song

/// Represents a complete song with sections, metadata, and transposition support.
public struct Song: Codable, Equatable, Hashable, Sendable {
    public var title: String
    public var artist: String?
    public var key: String?
    public var tempo: String?
    public var timeSignature: String?
    public var ccli: String?
    public var copyright: String?
    public var notes: String?
    public var sections: [SongSection]
    public var originalKey: String?
    public var transpose: Int = 0
    public var useFlats: Bool = false
    public var useNashville: Bool = false
    public var rawContent: String = ""
    /// Absolute path of the file this song was loaded from, if any.
    public var sourcePath: String? = nil

    public init(
        title: String = "",
        artist: String? = nil,
        key: String? = nil,
        tempo: String? = nil,
        timeSignature: String? = nil,
        ccli: String? = nil,
        copyright: String? = nil,
        notes: String? = nil,
        sections: [SongSection] = [],
        originalKey: String? = nil,
        transpose: Int = 0,
        useFlats: Bool = false,
        useNashville: Bool = false
    ) {
        self.title = title
        self.artist = artist
        self.key = key
        self.tempo = tempo
        self.timeSignature = timeSignature
        self.ccli = ccli
        self.copyright = copyright
        self.notes = notes
        self.sections = sections
        self.originalKey = originalKey
        self.transpose = transpose
        self.useFlats = useFlats
        self.useNashville = useNashville
    }

    /// Returns all chords in the song (flattened from all sections/lines).
    public var allChords: [String] {
        sections.flatMap { $0.lines.flatMap { $0.chords.map { $0.chord } } }
    }

    /// Returns true if song has any chords.
    public var hasChords: Bool {
        !allChords.isEmpty
    }
}