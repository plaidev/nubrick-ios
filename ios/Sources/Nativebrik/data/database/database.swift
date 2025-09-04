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
    func isMatchedToUserEventFrequencyCondition(condition: UserEventFrequencyCondition?) -> Boolean
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
        let calendar = Calendar(identifier: .gregorian)
        let value = frequency.period ?? (365 * 50)
        let unit = frequency.unit ?? .DAY

        // Use helper to compute the date boundary.
        let baseDate: Date = (unit == .MINUTE || unit == .HOUR) ? getCurrentDate() : getToday()
        let after = unit.subtract(value, from: baseDate, calendar: calendar)
        let count = self.experimentHisotryCountAfter(experimentId: experimentId, after: after)
        return count == 0
    }

    private func experimentHisotryCountAfter(experimentId: String, after: Date) -> Int {
        let request = ExperimentHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "experimentId = %@ && timestamp >= %@", experimentId, after as NSDate)

        let bgContext = persistentContainer.newBackgroundContext()
        var count: Int = 0
        bgContext.performAndWait {
            do {
                count = try bgContext.count(for: request)
            } catch {
                print("Couldn’t fetch ExperimentHistoryEntity: \(error)")
            }
        }
        return count
    }

    func isMatchedToUserEventFrequencyCondition(condition: UserEventFrequencyCondition?) -> Boolean {
        guard let condition = condition else {
            return true
        }
        guard let eventName = condition.eventName else {
            return true
        }
        guard let threshold = condition.threshold else {
            return true
        }
        let timeUnit: FrequencyUnit = condition.unit ?? .DAY

        let counts = self.userEventCounts(
            name: eventName,
            unit: timeUnit,
            lookbackPeriod: condition.lookbackPeriod,
            since: condition.since
        )

        let total = counts.values.count
        return compareInteger(a: total, b: [threshold], op: condition.comparison ?? .Equal)
    }

    // calculate the number of events aggregated by the given unit, looking back `lookbackPeriod` * `unit` since `since` (ISO8601).
    // if `lookbackPeriod` is not provided, it will look back 50 years.
    // if `since` is not provided, it will be 50 years ago.
    private func userEventCounts(
        name: String,
        unit: FrequencyUnit,
        lookbackPeriod: Int?,
        since: String?
    ) -> [Date: Int] {
        let calendar = Calendar(identifier: .gregorian)
        let isoFormatter = ISO8601DateFormatter()

        // Default values – 50 years expressed in days.
        let fiftyYearsInDays = 365 * 50

        // Determine the reference ("since") date.
        let sinceDate: Date = {
            if let since = since, let parsed = isoFormatter.date(from: since) {
                return parsed
            }
            // If `since` is not provided, default to 50 years ago.
            return calendar.date(byAdding: .day, value: -fiftyYearsInDays, to: getCurrentDate()) ?? getCurrentDate()
        }()

        // Determine the period length. If not provided, default to 50 years.
        let periodCount = lookbackPeriod ?? (365 * 50)

        // Lower-bound date.
        let today = getCurrentDate()
        let startDate = unit.subtract(periodCount, from: today, calendar: calendar)

        // Fetch events after latest of (startDate, sinceDate).
        let request = UserEventEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "name = %@ AND timestamp >= %@ AND timestamp >= %@",
            name,
            startDate as NSDate,
            sinceDate as NSDate
        )

        let bgContext = persistentContainer.newBackgroundContext()
        var counts: [Date: Int] = [:]
        bgContext.performAndWait {
            do {
                let events = try bgContext.fetch(request) as! [UserEventEntity]
                for event in events {
                    let bucket = unit.bucketStart(for: event.timestamp, calendar: calendar)
                    counts[bucket, default: 0] += 1
                }
            } catch {
                print("Couldn’t fetch UserEventEntity: \(error)")
            }
        }
        return counts
    }
}
