//
//  user.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
@testable import NubrickLocal

@MainActor
final class UserTests: XCTestCase {
    func testComeBackInitializesRetentionTimestamp() throws {
        let suiteName = "NubrickTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let user = NubrickUser()
        user.userDB = userDefaults
        user.comeBack()

        XCTAssertNotNil(userDefaults.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue))
        XCTAssertEqual(
            userDefaults.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue) as? Int,
            0
        )
    }

    func testRetentionUsesLocalCalendarDaysRatherThanUTCDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))

        let sameLocalDayBeforeUTCMidnight = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 13, hour: 8, minute: 55
        )))
        let sameLocalDayAfterUTCMidnight = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 13, hour: 9, minute: 5
        )))
        let nextLocalDay = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 8, day: 14, hour: 0, minute: 30
        )))

        XCTAssertEqual(
            retentionCalendarDayDifference(
                from: sameLocalDayBeforeUTCMidnight,
                to: sameLocalDayAfterUTCMidnight,
                calendar: calendar
            ),
            0
        )
        XCTAssertEqual(
            retentionCalendarDayDifference(
                from: sameLocalDayAfterUTCMidnight,
                to: nextLocalDay,
                calendar: calendar
            ),
            1
        )
    }

    func testRetentionCalendarDayDifferenceHandlesDSTTransition() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))

        let beforeDST = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 8, hour: 0, minute: 30
        )))
        let afterDST = try XCTUnwrap(calendar.date(from: DateComponents(
            year: 2026, month: 3, day: 9, hour: 0, minute: 30
        )))

        XCTAssertEqual(retentionCalendarDayDifference(from: beforeDST, to: afterDST, calendar: calendar), 1)
    }

    func testHasUserIdByDefaultAndAlwaysTheSame() {
        let user = NubrickUser()
        let userId = user.id
        XCTAssertTrue(userId.count > -1)
        
        let later = NubrickUser()
        let laterId = later.id
        XCTAssertEqual(userId, laterId)
    }

    func testGetUserSeededNormalizedRndAndAlwaysTheSame() {
        let user = NubrickUser()
        let seeded0 = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded0Again = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded10 = user.getSeededNormalizedUserRnd(seed: 10)
        XCTAssertEqual(seeded0, seeded0Again)
        XCTAssertNotEqual(seeded10, seeded0)
    }
    
    func testGetUserSeededNormalizedShouldBeIn0to1() {
        let user = NubrickUser()
        for i in 1...1000 {
            let seeded = user.getSeededNormalizedUserRnd(seed: i)
            XCTAssertTrue(seeded < 1.0)
            XCTAssertTrue(seeded >= 0.0)
        }
    }
    
    func testSetUserProperties() {
        let customUserId = "hello"
        let user = NubrickUser()
        user.set(["userId": customUserId])
        let userId = user.id
        XCTAssertEqual(userId, customUserId)
    }
    
    func testUserPropertiesIncludeCustomProp() {
        let user = NubrickUser()
        
        let customUserId = "hello"
        user.set(["userId": customUserId, "custom": "world"])
        let props = user.toEventProperties(seed: 0)
        let userIdProp = props.first { prop in
            if prop.name == "userId" {
                return true
            } else {
                return false
            }
        }
        let customProp = props.first { prop in
            if prop.name == "custom" {
                return true
            } else {
                return false
            }
        }
        
        XCTAssertEqual(customUserId, userIdProp?.value)
        XCTAssertEqual("world", customProp?.value)
    }

    func testSetPropertyStoresDateAsISOInstant() {
        let user = NubrickUser()
        let key = "dateForIsoSerializationTest"

        user.setProperty(key, value: Date(timeIntervalSince1970: 1_317_826_080))

        XCTAssertEqual("2011-10-05T14:48:00Z", user.getProperty(key))
        XCTAssertEqual(.STRING, user.toEventProperties(seed: 0).first { $0.name == key }?.type)
    }

    func testLocalMinuteIsMinuteOfDay() {
        let user = NubrickUser()

        for _ in 0..<3 {
            let before = getLocalDateComponent(getCurrentDate())
            let props = user.toEventProperties(seed: 0)
            let after = getLocalDateComponent(getCurrentDate())

            guard before.hour == after.hour, before.minute == after.minute else {
                continue
            }

            let localMinute = props.first { $0.name == BuiltinUserProperty.localMinute.rawValue }?.value
            XCTAssertEqual(String(before.hour * 60 + before.minute), localMinute)
            return
        }

        XCTFail("Could not read localMinute without crossing a minute boundary")
    }
}
