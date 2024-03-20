//
//  database.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import CoreData

protocol DatabaseRepository {
    func appendUserEvent(name: String)
    func appendExperimentHistory(experimentId: String)
    func isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?) -> Boolean
}

class DatabaseRepositoryImpl: DatabaseRepository {
    private let persistentContainer: NSPersistentContainer

    init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    func appendUserEvent(name: String) {
        Task {
            await MainActor.run {
                let context = self.persistentContainer.viewContext
                let event = UserEventEntity(context: context)
                event.name = name
                event.timestamp = getCurrentDate()
                do {
                    try context.save()
                } catch {
                    print("Cound'nt save UserEventEntity \(error)")
                }
            }
        }
    }

    func appendExperimentHistory(experimentId: String) {
        Task {
            await MainActor.run {
                let context = self.persistentContainer.viewContext
                let history = ExperimentHistoryEntity(context: context)
                history.experimentId = experimentId
                history.timestamp = getCurrentDate()
                do {
                    try context.save()
                } catch {
                    print("Cound'nt save ExperimentHistoryEntity \(error)")
                }
            }
        }
    }

    func isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?) -> Boolean {
        guard let frequency = frequency else {
            return true
        }
        let period: TimeInterval = Double(frequency.period ?? 365 * 50) * 60 * 60 * 24 // 50 years
        var after = getToday()
        after.addTimeInterval(-period)
        let count = self.experimentHisotryCountAfter(experimentId: experimentId, after: after)
        return count == 0
    }

    private func experimentHisotryCountAfter(experimentId: String, after: Date) -> Int {
        let request = ExperimentHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "experimentId = %@ && timestamp >= %@", experimentId, after as NSDate)

        let context = self.persistentContainer.viewContext
        return (try? context.count(for: request)) ?? 0
    }
}
