//
//  ios-compat.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/10/05.
//

import Foundation

func getCurrentDate() -> Date {
    if #available(iOS 15, *) {
        return Date.now
    } else {
        return Date()
    }
}

func getToday() -> Date {
    let now = getCurrentDate()
    let calendar = Calendar(identifier: .gregorian)
    var dateComponents = calendar.dateComponents(Set([.year, .month, .day, .hour, .minute, .second]), from: now)
    dateComponents.hour = 0
    dateComponents.minute = 0
    dateComponents.second = 0
    dateComponents.nanosecond = 0
    return calendar.date(from: dateComponents) ?? now
}

struct LocalDateComponent {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int
    var second: Int
    var weekday: Weekdays
}
func getLocalDateComponent(_ date: Date) -> LocalDateComponent {
    let calendar = Calendar(identifier: .gregorian)
    let dateComponents = calendar.dateComponents(Set([.year, .month, .day, .hour, .minute, .second, .weekday]), from: date)
    
    // swift version compat
    let weekdayIdentifier: Weekdays = {
        switch (dateComponents.weekday ?? 1) {
        case 1:
            return Weekdays.SUNDAY
        case 2:
            return Weekdays.MONDAY
        case 3:
            return Weekdays.TUESDAY
        case 4:
            return Weekdays.WEDNESDAY
        case 5:
            return Weekdays.THURSDAY
        case 6:
            return Weekdays.FRIDAY
        case 7:
            return Weekdays.SATURDAY
        default:
            return Weekdays.SUNDAY
        }
    }()
    
    return LocalDateComponent(
        year: dateComponents.year ?? 2000,
        month: dateComponents.month ?? 1,
        day: dateComponents.day ?? 1,
        hour: dateComponents.hour ?? 0,
        minute: dateComponents.minute ?? 0,
        second: dateComponents.second ?? 0,
        weekday: weekdayIdentifier
    )
}

func formatToISO8601(_ date: Date) -> String {
    if #available(iOS 15, *) {
        return date.ISO8601Format()
    } else {
        let formatter = ISO8601DateFormatter()
        return formatter.string(from: date)
    }
}

func getLanguageCode() -> String {
    if #available(iOS 16, *) {
        return Locale.current.language.languageCode?.identifier ?? "en"
    } else {
        return Locale.current.languageCode ?? "en"
    }
}

func getRegionCode() -> String {
    if #available(iOS 16, *) {
        return Locale.current.region?.identifier ?? "US"
    } else {
        return Locale.current.regionCode ?? "US"
    }
}

