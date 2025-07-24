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
        let value = frequency.period ?? (365 * 50) // default 50 years measured in days when unit is DAY

        // Calculate the "after" date by subtracting the period according to unit
        let after: Date = {
            switch frequency.unit ?? .DAY {
            case .MINUTE:
                return calendar.date(byAdding: .minute, value: -value, to: getCurrentDate()) ?? getCurrentDate()
            case .HOUR:
                return calendar.date(byAdding: .hour, value: -value, to: getCurrentDate()) ?? getCurrentDate()
            case .DAY:
                return calendar.date(byAdding: .day, value: -value, to: getToday()) ?? getToday()
            case .WEEK:
                return calendar.date(byAdding: .weekOfYear, value: -value, to: getToday()) ?? getToday()
            case .MONTH:
                return calendar.date(byAdding: .month, value: -value, to: getToday()) ?? getToday()
            case .unknown:
                return calendar.date(byAdding: .day, value: -value, to: getToday()) ?? getToday()
            }
        }()
        let count = self.experimentHisotryCountAfter(experimentId: experimentId, after: after)
        return count == 0
    }

    private func experimentHisotryCountAfter(experimentId: String, after: Date) -> Int {
        let request = ExperimentHistoryEntity.fetchRequest()
        request.predicate = NSPredicate(format: "experimentId = %@ && timestamp >= %@", experimentId, after as NSDate)

        let context = self.persistentContainer.viewContext
        return (try? context.count(for: request)) ?? 0
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

        // Aggregate total number of events across all buckets for comparison.
        let total = counts.values.reduce(0, +)

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

        // Calculate lower-bound date based on the unit.
        let startDate: Date
        switch unit {
        case .MINUTE:
            startDate = calendar.date(byAdding: .minute, value: -periodCount, to: sinceDate) ?? sinceDate
        case .HOUR:
            startDate = calendar.date(byAdding: .hour, value: -periodCount, to: sinceDate) ?? sinceDate
        case .DAY:
            startDate = calendar.date(byAdding: .day, value: -periodCount, to: sinceDate) ?? sinceDate
        case .WEEK:
            startDate = calendar.date(byAdding: .weekOfYear, value: -periodCount, to: sinceDate) ?? sinceDate
        case .MONTH:
            startDate = calendar.date(byAdding: .month, value: -periodCount, to: sinceDate) ?? sinceDate
        case .unknown:
            startDate = calendar.date(byAdding: .day, value: -periodCount, to: sinceDate) ?? sinceDate
        }

        // Fetch events after latest of (startDate, sinceDate).
        let request = UserEventEntity.fetchRequest()
        request.predicate = NSPredicate(
            format: "name = %@ AND timestamp >= %@ AND timestamp >= %@",
            name,
            startDate as NSDate,
            sinceDate as NSDate
        )

        let context = self.persistentContainer.viewContext
        guard let events = try? context.fetch(request) as? [UserEventEntity] else {
            return [:]
        }

        // Aggregate events into buckets defined by `unit`.
        var counts: [Date: Int] = [:]
        for event in events {
            let timestamp = event.timestamp
            let bucket: Date
            switch unit {
            case .MINUTE:
                var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: timestamp)
                comps.second = 0
                bucket = calendar.date(from: comps) ?? timestamp
            case .HOUR:
                var comps = calendar.dateComponents([.year, .month, .day, .hour], from: timestamp)
                comps.minute = 0
                comps.second = 0
                bucket = calendar.date(from: comps) ?? timestamp
            case .DAY:
                bucket = calendar.startOfDay(for: timestamp)
            case .WEEK:
                bucket = calendar.dateInterval(of: .weekOfYear, for: timestamp)?.start ?? calendar.startOfDay(for: timestamp)
            case .MONTH:
                bucket = calendar.dateInterval(of: .month, for: timestamp)?.start ?? calendar.startOfDay(for: timestamp)
            case .unknown:
                bucket = calendar.startOfDay(for: timestamp)
            }
            counts[bucket, default: 0] += 1
        }

        return counts
    }
}
