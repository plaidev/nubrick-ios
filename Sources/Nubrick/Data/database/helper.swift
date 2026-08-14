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

@MainActor
private let nativebrikManagedObjectModel: NSManagedObjectModel = {
    let model = NSManagedObjectModel()
    model.entities = [
        UserEventEntity.entityDescription(),
        ExperimentHistoryEntity.entityDescription(),
        PendingTrackEventEntity.entityDescription(),
    ]
    return model
}()

@MainActor
func createNativebrikCoreDataHelper(storeURL: URL? = nil) -> NSPersistentContainer? {
    let container = NSPersistentContainer(name: "com.nativebrik.sdk", managedObjectModel: nativebrikManagedObjectModel)
    if let description = container.persistentStoreDescriptions.first {
        if let storeURL {
            description.url = storeURL
        }
        description.shouldAddStoreAsynchronously = false
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
    }

    var loadError: Error?
    container.loadPersistentStores { _, error in
        loadError = error
    }

    if let loadError {
        let message = "Couldn't create a persistent Core Data store. Nubrick SDK won't initialize without local database support: \(loadError)"
        #if DEBUG
        assertionFailure(message)
        #endif
        nubrickDatabaseWarn(message)
        return nil
    }

    return container
}
