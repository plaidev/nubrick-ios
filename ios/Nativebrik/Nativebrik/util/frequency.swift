//
//  frequency.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2025/07/24.
//


import Foundation

// Utility helpers for working with FrequencyUnit.
extension FrequencyUnit {
    /// Calendar.Component corresponding to the frequency unit.
    fileprivate func calendarComponent() -> Calendar.Component {
        switch self {
        case .MINUTE: return .minute
        case .HOUR:   return .hour
        case .DAY:    return .day
        case .WEEK:   return .weekOfYear
        case .MONTH:  return .month
        case .unknown: return .day
        }
    }

    /// Returns a new date by subtracting `value` * `unit` from `date`.
    func subtract(_ value: Int, from date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        return calendar.date(byAdding: self.calendarComponent(), value: -value, to: date) ?? date
    }

    /// Returns bucket start that represents the aggregation window containing `date`.
    func bucketStart(for date: Date, calendar: Calendar = Calendar(identifier: .gregorian)) -> Date {
        switch self {
        case .MINUTE:
            var comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            comps.second = 0
            return calendar.date(from: comps) ?? date
        case .HOUR:
            var comps = calendar.dateComponents([.year, .month, .day, .hour], from: date)
            comps.minute = 0
            comps.second = 0
            return calendar.date(from: comps) ?? date
        case .DAY:
            return calendar.startOfDay(for: date)
        case .WEEK:
            return calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
        case .MONTH:
            return calendar.dateInterval(of: .month, for: date)?.start ?? calendar.startOfDay(for: date)
        case .unknown:
            return calendar.startOfDay(for: date)
        }
    }
}
