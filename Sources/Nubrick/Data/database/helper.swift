//
//  database.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import CoreData

private func nubrickDatabaseWarn(_ message: String) {
    print("[Nubrick] \(message)")
}

final class ExperimentHistoryEntity: NSManagedObject {
    @NSManaged var experimentId: String
    @NSManaged var timestamp: Date
    
    override var description: String {
        return "NativebrikExperimentHistory"
    }
    
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NativebrikExperimentHistory"
        entity.managedObjectClassName = NSStringFromClass(ExperimentHistoryEntity.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "experimentId"
        idAttr.attributeType = .stringAttributeType
        idAttr.isOptional = false
        
        let timestampAttr = NSAttributeDescription()
        timestampAttr.name = "timestamp"
        timestampAttr.attributeType = .dateAttributeType
        
        entity.properties = [idAttr, timestampAttr]
        
        return entity
    }
}

final class UserEventEntity: NSManagedObject {
    @NSManaged var name: String
    @NSManaged var timestamp: Date
    
    override var description: String {
        return "NativebrikUserEvent"
    }
    
    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NativebrikUserEvent"
        entity.managedObjectClassName = NSStringFromClass(UserEventEntity.self)
        
        let nameAttr = NSAttributeDescription()
        nameAttr.name = "name"
        nameAttr.attributeType = .stringAttributeType
        nameAttr.isOptional = false
        
        let timestampAttr = NSAttributeDescription()
        timestampAttr.name = "timestamp"
        timestampAttr.attributeType = .dateAttributeType
        
        entity.properties = [nameAttr, timestampAttr]
        
        return entity
    }
}

final class PendingTrackEventEntity: NSManagedObject {
    @NSManaged var eventID: String
    @NSManaged var payload: Data
    @NSManaged var eventType: String
    @NSManaged var byteCount: Int64
    @NSManaged var createdAt: Date
    @NSManaged var userId: String?
    @NSManaged var metaPayload: Data?

    static func entityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NativebrikPendingTrackEvent"
        entity.managedObjectClassName = NSStringFromClass(PendingTrackEventEntity.self)

        let eventID = NSAttributeDescription()
        eventID.name = "eventID"
        eventID.attributeType = .stringAttributeType
        eventID.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false

        let eventType = NSAttributeDescription()
        eventType.name = "eventType"
        eventType.attributeType = .stringAttributeType
        eventType.isOptional = false

        let byteCount = NSAttributeDescription()
        byteCount.name = "byteCount"
        byteCount.attributeType = .integer64AttributeType
        byteCount.isOptional = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        let userId = NSAttributeDescription()
        userId.name = "userId"
        userId.attributeType = .stringAttributeType
        userId.isOptional = true

        let metaPayload = NSAttributeDescription()
        metaPayload.name = "metaPayload"
        metaPayload.attributeType = .binaryDataAttributeType
        metaPayload.isOptional = true

        entity.properties = [eventID, payload, eventType, byteCount, createdAt, userId, metaPayload]
        return entity
    }
}

/// Owns the SDK's immutable Core Data model.
///
/// The model is fully configured during initialization and never mutated after
/// that point, so it is safe to share while persistent stores open off-main.
private final class NativebrikManagedObjectModel: @unchecked Sendable {
    static let shared = NativebrikManagedObjectModel()

    let value: NSManagedObjectModel

    private init() {
        let model = NSManagedObjectModel()
        model.entities = [
            UserEventEntity.entityDescription(),
            ExperimentHistoryEntity.entityDescription(),
            PendingTrackEventEntity.entityDescription(),
        ]
        self.value = model
    }
}

func createNativebrikCoreDataHelper(storeURL: URL? = nil) -> NSPersistentContainer? {
    let container = NSPersistentContainer(
        name: "com.nativebrik.sdk",
        managedObjectModel: NativebrikManagedObjectModel.shared.value
    )
    if let description = container.persistentStoreDescriptions.first {
        if let storeURL {
            description.url = storeURL
        }
        // The provider runs this synchronous load in a detached task. Keeping
        // this false makes its readiness task resolve only after migration and
        // SQLite open have completed.
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
    }

    var loadError: Error?
    container.loadPersistentStores { _, error in
        loadError = error
    }

    if let loadError {
        nubrickDatabaseWarn("Couldn't create a persistent Core Data store: \(loadError)")
        return nil
    }

    return container
}

/// Provides the persistent container once its store has finished opening.
///
/// The SDK starts this work during initialization but only awaits it from code
/// paths that actually need Core Data. This keeps SQLite open/migration work
/// out of the app's launch path.
protocol PersistentContainerProvider: Sendable {
    func persistentContainer() async -> NSPersistentContainer?
}

actor LazyPersistentContainerProvider: PersistentContainerProvider {
    private static let maximumLoadAttempts = 3
    private static let retryDelayNanoseconds: UInt64 = 250_000_000
    private let loadTask: Task<NSPersistentContainer?, Never>

    init(storeURL: URL? = nil) {
        self.loadTask = Task.detached(priority: .utility) {
            for attempt in 1...Self.maximumLoadAttempts {
                if let container = createNativebrikCoreDataHelper(storeURL: storeURL) {
                    return container
                }

                guard attempt < Self.maximumLoadAttempts else {
                    nubrickDatabaseWarn(
                        "Couldn't initialize the persistent Core Data store after \(Self.maximumLoadAttempts) attempts."
                    )
                    return nil
                }

                try? await Task.sleep(nanoseconds: Self.retryDelayNanoseconds)
            }
            return nil
        }
    }

    func persistentContainer() async -> NSPersistentContainer? {
        await loadTask.value
    }
}
