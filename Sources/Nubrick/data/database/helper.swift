//
//  database.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import CoreData

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

func createNativebrikCoreDataHelper() -> NSPersistentContainer {
    let model = NSManagedObjectModel()
    model.entities = [UserEventEntity.entityDescription(), ExperimentHistoryEntity.entityDescription()]
    let container = NSPersistentContainer(name: "com.nativebrik.sdk", managedObjectModel: model)
    
    container.loadPersistentStores { storeDescription, error in
        if (error as NSError?) != nil {
            fatalError("Nativebrik SDK couldn't create a coredata database.")
        }
    }
    return container
}
