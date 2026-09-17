//
//  database.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation
import CoreData

protocol DatabaseRepository : Sendable {
    @discardableResult func appendUserEvent(name: String) async -> Bool
    @discardableResult func appendExperimentHistory(experimentId: String) async -> Bool
    func isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?) async -> Boolean
    func isMatchedToUserEventFrequencyCondition(condition: UserEventFrequencyCondition?) async -> Boolean
}

final class DatabaseRepositoryImpl: DatabaseRepository {
    private let persistentContainerProvider: any PersistentContainerProvider

    init(persistentContainerProvider: any PersistentContainerProvider) {
        self.persistentContainerProvider = persistentContainerProvider
    }

    @discardableResult
    func appendUserEvent(name: String) async -> Bool {
        guard let persistentContainer = await persistentContainerProvider.persistentContainer() else {
            return false
        }
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            return false
        }
        let context = persistentContainer.newBackgroundContext()
        return await context.perform {
            let event = UserEventEntity(context: context)
            event.name = name
            event.timestamp = getCurrentDate()
            do {
                try context.save()
                return true
            } catch {
                print("Couldn't save UserEventEntity \(error)")
                return false
            }
        }
    }

    @discardableResult
    func appendExperimentHistory(experimentId: String) async -> Bool {
        guard let persistentContainer = await persistentContainerProvider.persistentContainer() else {
            return false
        }
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            return false
        }
        let context = persistentContainer.newBackgroundContext()
        return await context.perform {
            let history = ExperimentHistoryEntity(context: context)
            history.experimentId = experimentId
            history.timestamp = getCurrentDate()
            do {
                try context.save()
                return true
            } catch {
                print("Couldn't save ExperimentHistoryEntity \(error)")
                return false
            }
        }
    }

    func isNotInFrequency(experimentId: String, frequency: ExperimentFrequency?) async -> Boolean {
        guard let persistentContainer = await persistentContainerProvider.persistentContainer() else {
            return false
        }
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            return false
        }
        guard let frequency = frequency else {
            return true
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2 // Monday, matching Android's calendar-week boundary.
        calendar.minimumDaysInFirstWeek = 4
        let unit = frequency.unit ?? .DAY

        // A missing period means "only once", so include the experiment's
        // complete display history instead of approximating it with a cutoff.
        let now = getCurrentDate()
        let after: Date?
        if let period = frequency.period {
            guard period > 0 else {
                return true
            }

            // Minute/hour frequencies are rolling windows. Longer units are calendar periods.
            let baseDate: Date
            switch unit {
            case .MINUTE, .HOUR:
                baseDate = now
            case .DAY, .unknown:
                baseDate = calendar.startOfDay(for: now)
            case .WEEK:
                baseDate = calendar.dateInterval(of: .weekOfYear, for: now)?.start
                    ?? calendar.startOfDay(for: now)
            case .MONTH:
                baseDate = calendar.dateInterval(of: .month, for: now)?.start
                    ?? calendar.startOfDay(for: now)
            }

            // The current calendar unit is included in the frequency interval.
            let unitsToSubtract: Int
            switch unit {
            case .DAY, .WEEK, .MONTH, .unknown:
                unitsToSubtract = max(period - 1, 0)
            case .MINUTE, .HOUR:
                unitsToSubtract = period
            }
            after = unit.subtract(unitsToSubtract, from: baseDate, calendar: calendar)
        } else {
            after = nil
        }

        guard let count = await self.experimentHistoryCount(
            persistentContainer: persistentContainer,
            experimentId: experimentId,
            after: after,
            now: now
        ) else {
            return false
        }
        return count == 0
    }

    private func experimentHistoryCount(
        persistentContainer: NSPersistentContainer,
        experimentId: String,
        after: Date?,
        now: Date
    ) async -> Int? {
        let bgContext = persistentContainer.newBackgroundContext()
        return await bgContext.perform {
            do {
                let request = ExperimentHistoryEntity.fetchRequest()
                var predicates = [
                    NSPredicate(format: "experimentId = %@", experimentId),
                    NSPredicate(format: "timestamp <= %@", now as NSDate),
                ]
                if let after {
                    predicates.append(NSPredicate(format: "timestamp >= %@", after as NSDate))
                }
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

                let count = try bgContext.count(for: request)
                guard count != NSNotFound else {
                    print("Couldn’t count ExperimentHistoryEntity")
                    return nil
                }
                return count
            } catch {
                print("Couldn’t fetch ExperimentHistoryEntity: \(error)")
                return nil
            }
        }
    }

    func isMatchedToUserEventFrequencyCondition(condition: UserEventFrequencyCondition?) async -> Boolean {
        guard let persistentContainer = await persistentContainerProvider.persistentContainer() else {
            return false
        }
        guard !persistentContainer.persistentStoreCoordinator.persistentStores.isEmpty else {
            return false
        }
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

        guard let counts = await self.userEventCounts(
            persistentContainer: persistentContainer,
            name: eventName,
            unit: timeUnit,
            lookbackPeriod: condition.lookbackPeriod,
            since: condition.since
        ) else {
            return false
        }

        let total = counts.values.reduce(0, +)
        return compareInteger(a: total, b: [threshold], op: condition.comparison ?? .Equal)
    }

    // Calculate the number of events aggregated by the given unit, looking back
    // `lookbackPeriod` * `unit` and since `since` (ISO8601). Missing bounds are
    // unbounded.
    private func userEventCounts(
        persistentContainer: NSPersistentContainer,
        name: String,
        unit: FrequencyUnit,
        lookbackPeriod: Int?,
        since: String?
    ) async -> [Date: Int]? {
        let calendar = Calendar(identifier: .gregorian)
        let now = getCurrentDate()

        // Determine the reference ("since") date.
        let sinceDate: Date?
        if let since {
            guard let parsed = parseDateTime(since) else { return nil }
            sinceDate = parsed
        } else {
            sinceDate = nil
        }

        // Negative periods are invalid remote configuration. Clamp them to an
        // empty lookback rather than passing a potentially hostile value into
        // date arithmetic.
        let startDate = lookbackPeriod.map {
            unit.subtract(max($0, 0), from: now, calendar: calendar)
        }

        let bgContext = persistentContainer.newBackgroundContext()
        return await bgContext.perform {
            do {
                let request = NSFetchRequest<UserEventEntity>(entityName: "NativebrikUserEvent")
                var predicates = [
                    NSPredicate(format: "name = %@", name),
                    NSPredicate(format: "timestamp <= %@", now as NSDate),
                ]
                if let startDate {
                    predicates.append(NSPredicate(format: "timestamp >= %@", startDate as NSDate))
                }
                if let sinceDate {
                    predicates.append(NSPredicate(format: "timestamp >= %@", sinceDate as NSDate))
                }
                request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

                let events = try bgContext.fetch(request)
                var counts: [Date: Int] = [:]
                for event in events {
                    let bucket = unit.bucketStart(for: event.timestamp, calendar: calendar)
                    counts[bucket, default: 0] += 1
                }
                return counts
            } catch {
                print("Couldn’t fetch UserEventEntity: \(error)")
                return nil
            }
        }
    }
}
