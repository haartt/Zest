internal import CoreData

/// Programmatic CoreData stack — no `.xcdatamodeld` file required.
/// Entity: WorkoutSession { id, date, durationSeconds, trackName, genre }
final class PersistenceController {

    static let shared = PersistenceController()

    /// In-memory store for SwiftUI previews.
    static let preview: PersistenceController = {
        let ctrl = PersistenceController(inMemory: true)
        let ctx = ctrl.container.viewContext
        // Seed preview data
        let sample = WorkoutSession(context: ctx)
        sample.id              = UUID()
        sample.date            = Date().addingTimeInterval(-3600)
        sample.durationSeconds = 1823
        sample.trackName       = "Night Runner"
        sample.genre           = "Techno"
        try? ctx.save()
        return ctrl
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let c = NSPersistentContainer(
            name: "Zest",
            managedObjectModel: Self.managedObjectModel
        )
        container = c
        if inMemory {
            c.persistentStoreDescriptions.first?.type = NSInMemoryStoreType
            c.persistentStoreDescriptions.first?.url = nil
        }
        c.loadPersistentStores { [weak c] _, error in
            guard let c else { return }
            if let error {
                // Don't crash the whole app on store migration / corruption.
                // Fall back to an in-memory store so the rest of the app can run.
                print("[CoreData] Load error: \(error)")

                if !inMemory {
                    let desc = NSPersistentStoreDescription()
                    desc.type = NSInMemoryStoreType
                    desc.url = nil
                    c.persistentStoreDescriptions = [desc]
                    c.loadPersistentStores { _, secondError in
                        if let secondError {
                            print("[CoreData] In-memory fallback failed: \(secondError)")
                        }
                    }
                }
            }
        }
        c.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Programmatic NSManagedObjectModel

    static let managedObjectModel: NSManagedObjectModel = {
        let model = NSManagedObjectModel()

        let entity = NSEntityDescription()
        entity.name = "WorkoutSession"
        entity.managedObjectClassName = NSStringFromClass(WorkoutSession.self)

        func makeAttr(_ name: String, type: NSAttributeType, optional: Bool = true) -> NSAttributeDescription {
            let attr = NSAttributeDescription()
            attr.name = name
            attr.attributeType = type
            attr.isOptional = optional
            return attr
        }

        entity.properties = [
            makeAttr("id",              type: .UUIDAttributeType),
            makeAttr("date",            type: .dateAttributeType),
            makeAttr("durationSeconds", type: .integer32AttributeType, optional: false),
            makeAttr("trackName",       type: .stringAttributeType),
            makeAttr("genre",           type: .stringAttributeType),
        ]

        model.entities = [entity]
        return model
    }()

    // MARK: - Write helpers

    func saveSession(
        date: Date,
        duration: Int,
        trackName: String,
        genre: String,
        context: NSManagedObjectContext
    ) {
        let session = WorkoutSession(context: context)
        session.id              = UUID()
        session.date            = date
        session.durationSeconds = Int32(duration)
        session.trackName       = trackName
        session.genre           = genre
        do {
            try context.save()
        } catch {
            print("[CoreData] Save error: \(error)")
        }
    }
}
