import Foundation

// MARK: - SetListItem

/// Represents a song entry in a setlist.
public struct SetListItem: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var setListId: UUID?
    public var songPath: String
    public var songTitle: String
    public var songArtist: String?
    public var position: Int
    public var notes: String?

    public init(
        id: UUID = UUID(),
        setListId: UUID? = nil,
        songPath: String,
        songTitle: String,
        songArtist: String? = nil,
        position: Int = 0,
        notes: String? = nil
    ) {
        self.id = id
        self.setListId = setListId
        self.songPath = songPath
        self.songTitle = songTitle
        self.songArtist = songArtist
        self.position = position
        self.notes = notes
    }
}

// MARK: - SetList

/// Represents a setlist containing ordered song references.
public struct SetList: Codable, Equatable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var createdAt: Date
    public var modifiedAt: Date
    public var items: [SetListItem]

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        modifiedAt: Date = Date(),
        items: [SetListItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.items = items
    }

    public mutating func addItem(_ item: SetListItem) {
        var newItem = item
        newItem.setListId = id
        newItem.position = items.count
        items.append(newItem)
        modifiedAt = Date()
    }

    public mutating func removeItem(at index: Int) {
        guard index >= 0 && index < items.count else { return }
        items.remove(at: index)
        // Re-index positions
        for i in index..<items.count {
            items[i].position = i
        }
        modifiedAt = Date()
    }

    public mutating func moveItem(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < items.count,
              toIndex >= 0 && toIndex < items.count,
              fromIndex != toIndex else { return }

        let item = items.remove(at: fromIndex)
        items.insert(item, at: toIndex)
        // Re-index positions
        for i in 0..<items.count {
            items[i].position = i
        }
        modifiedAt = Date()
    }

    public mutating func updateName(_ newName: String) {
        name = newName
        modifiedAt = Date()
    }
}