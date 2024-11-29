//
//  ios-compat.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/10/05.
//

import Foundation

private var DATETIME_OFFSET: Int64 = 0

func __for_test_sync_datetime_offset(offset: Int64) {
    DATETIME_OFFSET = offset
}

func __for_test_get_datetime_offset() -> Int64 {
    return DATETIME_OFFSET
}

func syncDateFromHTTPURLResponse(t0: Date, res: HTTPURLResponse) {
    let t1 = getCurrentDate()

    guard let dateStr = res.allHeaderFields["Date"] as? String else {
        return
    }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
    
    guard let serverTime = dateFormatter.date(from: dateStr) else {
        return
    }
    
    let t0Unix = Int64(t0.timeIntervalSince1970 * 1000)
    let t1Unix = Int64(t1.timeIntervalSince1970 * 1000)
    let serverTimeUnix = Int64(serverTime.timeIntervalSince1970 * 1000)
    let networkDelay = (t1Unix - t0Unix) / 2
    let estimatedServerTimeUnix = serverTimeUnix + networkDelay
    let offset = estimatedServerTimeUnix - t1Unix

    DATETIME_OFFSET = offset
}

func getCurrentDate() -> Date {
    let currentMillis: Int64
    if #available(iOS 15, *) {
        currentMillis = Int64(Date.now.timeIntervalSince1970 * 1000)
    } else {
        currentMillis = Int64(Date().timeIntervalSince1970 * 1000)
    }
    // device time + (server time - device time) = server.time
    return Date(timeIntervalSince1970: Double(currentMillis + DATETIME_OFFSET) / 1000.0)
}

func parseDateTime(_ date: DateTime) -> Date? {
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: date)
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

