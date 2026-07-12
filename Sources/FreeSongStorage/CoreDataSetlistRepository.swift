import Foundation
import CoreData
import FreeSongCore

// MARK: - Core Data Stack

/// Core Data stack for FreeSong storage.
public final class CoreDataStack: Sendable {
    public static let shared = CoreDataStack()

    public let container: NSPersistentContainer

    private init() {
        let model = CoreDataStack.makeModel()
        container = NSPersistentContainer(name: "FreeSong", managedObjectModel: model)

        // Enable CloudKit sync (optional - requires entitlements)
        #if os(iOS) || os(macOS)
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }
        #endif

        container.loadPersistentStores { _, error in
            if let error = error {
                print("Core Data store loading: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        // SetListItem entity
        let itemEntity = NSEntityDescription()
        itemEntity.name = "SetListItem"
        itemEntity.managedObjectClassName = "FreeSongStorage.SetListItemEntity"

        let itemId = NSAttributeDescription(); itemId.name = "id"; itemId.attributeType = .UUIDAttributeType; itemId.isOptional = false
        let itemSongPath = NSAttributeDescription(); itemSongPath.name = "songPath"; itemSongPath.attributeType = .stringAttributeType; itemSongPath.isOptional = false
        let itemSongTitle = NSAttributeDescription(); itemSongTitle.name = "songTitle"; itemSongTitle.attributeType = .stringAttributeType; itemSongTitle.isOptional = false
        let itemSongArtist = NSAttributeDescription(); itemSongArtist.name = "songArtist"; itemSongArtist.attributeType = .stringAttributeType; itemSongArtist.isOptional = true
        let itemPosition = NSAttributeDescription(); itemPosition.name = "position"; itemPosition.attributeType = .integer16AttributeType; itemPosition.isOptional = false
        let itemNotes = NSAttributeDescription(); itemNotes.name = "notes"; itemNotes.attributeType = .stringAttributeType; itemNotes.isOptional = true
        itemEntity.properties = [itemId, itemSongPath, itemSongTitle, itemSongArtist, itemPosition, itemNotes]

        // SetList entity
        let listEntity = NSEntityDescription()
        listEntity.name = "SetList"
        listEntity.managedObjectClassName = "FreeSongStorage.SetListEntity"

        let listId = NSAttributeDescription(); listId.name = "id"; listId.attributeType = .UUIDAttributeType; listId.isOptional = false
        let listName = NSAttributeDescription(); listName.name = "name"; listName.attributeType = .stringAttributeType; listName.isOptional = false
        let listCreatedAt = NSAttributeDescription(); listCreatedAt.name = "createdAt"; listCreatedAt.attributeType = .dateAttributeType; listCreatedAt.isOptional = false
        let listModifiedAt = NSAttributeDescription(); listModifiedAt.name = "modifiedAt"; listModifiedAt.attributeType = .dateAttributeType; listModifiedAt.isOptional = false
        listEntity.properties = [listId, listName, listCreatedAt, listModifiedAt]

        // Relationships
        let itemsRel = NSRelationshipDescription()
        itemsRel.name = "items"
        itemsRel.destinationEntity = itemEntity
        itemsRel.minCount = 0; itemsRel.maxCount = 0
        itemsRel.isOrdered = true
        itemsRel.deleteRule = .cascadeDeleteRule

        let setListRel = NSRelationshipDescription()
        setListRel.name = "setList"
        setListRel.destinationEntity = listEntity
        setListRel.minCount = 1; setListRel.maxCount = 1
        setListRel.deleteRule = .nullifyDeleteRule

        itemsRel.inverseRelationship = setListRel
        setListRel.inverseRelationship = itemsRel

        listEntity.properties.append(itemsRel)
        itemEntity.properties.append(setListRel)

        model.entities = [listEntity, itemEntity]
        return model
    }

    public var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    public func saveContext(_ context: NSManagedObjectContext? = nil) throws {
        let context = context ?? viewContext
        if context.hasChanges {
            try context.save()
        }
    }
}

// MARK: - Core Data Setlist Repository

/// Core Data implementation of SetlistRepository.
/// Uses NSFetchedResultsController for reactive UI updates.
public actor CoreDataSetlistRepository: SetlistRepository {

    private let stack: CoreDataStack

    public init() {
        self.stack = CoreDataStack.shared
    }

    /// Create with a custom Core Data stack (useful for testing with in-memory stores).
    public init(stack: CoreDataStack) {
        self.stack = stack
    }

    public func getAllSetlists() async throws -> [SetList] {
        try await stack.viewContext.perform {
            let request = NSFetchRequest<SetListEntity>(entityName: "SetList")
            request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["items"]

            let entities = try self.stack.viewContext.fetch(request)
            return entities.map { self.setListFromEntity($0) }
        }
    }

    public func getSetlist(id: UUID) async throws -> SetList? {
        try await stack.viewContext.perform {
            let request = NSFetchRequest<SetListEntity>(entityName: "SetList")
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            if let entity = try self.stack.viewContext.fetch(request).first {
                return self.setListFromEntity(entity)
            }
            return nil
        }
    }

    public func saveSetlist(_ setlist: SetList) async throws {
        try await stack.viewContext.perform {
            let entity: SetListEntity
            if let existing = try self.fetchEntity(id: setlist.id) {
                entity = existing
            } else {
                entity = SetListEntity(context: self.stack.viewContext)
                entity.id = setlist.id
                entity.createdAt = setlist.createdAt
            }

            entity.name = setlist.name
            entity.modifiedAt = setlist.modifiedAt

            // Update items
            self.syncItems(entity, with: setlist.items)

            try self.stack.saveContext()
        }
    }

    public func deleteSetlist(id: UUID) async throws {
        try await stack.viewContext.perform {
            if let entity = try self.fetchEntity(id: id) {
                self.stack.viewContext.delete(entity)
                try self.stack.saveContext()
            }
        }
    }

    public func getSetlistsContaining(songPath: String) async throws -> [SetList] {
        try await stack.viewContext.perform {
            let request = NSFetchRequest<SetListEntity>(entityName: "SetList")
            request.predicate = NSPredicate(format: "ANY items.songPath == %@", songPath)
            request.sortDescriptors = [NSSortDescriptor(key: "modifiedAt", ascending: false)]

            let entities = try self.stack.viewContext.fetch(request)
            return entities.map { self.setListFromEntity($0) }
        }
    }

    // MARK: - Private

    nonisolated private func fetchEntity(id: UUID) throws -> SetListEntity? {
        let request = NSFetchRequest<SetListEntity>(entityName: "SetList")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try stack.viewContext.fetch(request).first
    }

    nonisolated private func syncItems(_ entity: SetListEntity, with items: [SetListItem]) {
        // Remove deleted items
        let existingItems = entity.items?.allObjects as? [SetListItemEntity] ?? []
        let newItemIDs = Set(items.map { $0.id })
        for item in existingItems {
            if !newItemIDs.contains(item.id) {
                entity.removeFromItems(item)
                stack.viewContext.delete(item)
            }
        }

        // Update or create items
        for (index, item) in items.enumerated() {
            let itemEntity: SetListItemEntity
            if let existing = existingItems.first(where: { $0.id == item.id }) {
                itemEntity = existing
            } else {
                itemEntity = SetListItemEntity(context: stack.viewContext)
                itemEntity.id = item.id
            }

            itemEntity.songPath = item.songPath
            itemEntity.songTitle = item.songTitle
            itemEntity.songArtist = item.songArtist
            itemEntity.position = Int16(index)
            itemEntity.notes = item.notes
            entity.addToItems(itemEntity)
        }
    }

    nonisolated private func setListFromEntity(_ entity: SetListEntity) -> SetList {
        var setlist = SetList(
            id: entity.id,
            name: entity.name,
            createdAt: entity.createdAt,
            modifiedAt: entity.modifiedAt,
            items: []
        )

        let items = (entity.items?.allObjects as? [SetListItemEntity] ?? [])
            .sorted { $0.position < $1.position }
            .map { itemEntity in
                SetListItem(
                    id: itemEntity.id,
                    setListId: entity.id,
                    songPath: itemEntity.songPath,
                    songTitle: itemEntity.songTitle,
                    songArtist: itemEntity.songArtist,
                    position: Int(itemEntity.position),
                    notes: itemEntity.notes
                )
            }

        setlist.items = items
        return setlist
    }
}

// MARK: - Core Data Entities (Generated by Xcode from .xcdatamodeld)
// These are referenced above - actual classes generated at build time
@objc(SetListEntity)
public class SetListEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var createdAt: Date
    @NSManaged public var modifiedAt: Date
    @NSManaged public var items: NSSet?
}

@objc(SetListItemEntity)
public class SetListItemEntity: NSManagedObject {
    @NSManaged public var id: UUID
    @NSManaged public var songPath: String
    @NSManaged public var songTitle: String
    @NSManaged public var songArtist: String?
    @NSManaged public var position: Int16
    @NSManaged public var notes: String?
    @NSManaged public var setList: SetListEntity?
}

// Extension to help with item management
extension SetListEntity {
    func removeFromItems(_ item: SetListItemEntity) {
        let mutableItems = items?.mutableCopy() as? NSMutableSet
        mutableItems?.remove(item)
        items = mutableItems
    }

    func addToItems(_ item: SetListItemEntity) {
        let mutableItems = items?.mutableCopy() as? NSMutableSet
        mutableItems?.add(item)
        items = mutableItems
    }
}