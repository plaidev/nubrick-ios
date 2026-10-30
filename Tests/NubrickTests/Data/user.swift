//
//  user.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import Combine
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

    func testComeBackSaturatesCorruptedRetentionCount() throws {
        let suiteName = "NubrickTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let user = NubrickUser()
        user.userDB = userDefaults
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: getCurrentDate())!
        userDefaults.set(Int(yesterday.timeIntervalSince1970), forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_T.rawValue)
        userDefaults.set(Int.max, forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue)

        user.comeBack()

        XCTAssertEqual(
            userDefaults.object(forKey: NativebrikUserDefaultsKeys.RETENTION_PERIOD_COUNT.rawValue) as? Int,
            Int.max
        )
    }

    func testIdentityMigrationClassifiesOnlyExactGeneratedUUIDs() throws {
        let generated = "ABCDEF01-2345-4678-9ABC-DEF012345678"
        let cases: [(String?, String)] = [
            (nil, ""), ("", ""), (" \n", ""), (generated, ""),
            ("customer-123", "customer-123"),
            (generated.lowercased(), generated.lowercased()),
            ("ABCDEF01-2345-1678-9ABC-DEF012345678", "ABCDEF01-2345-1678-9ABC-DEF012345678"),
            ("ABCDEF01-2345-4678-7ABC-DEF012345678", "ABCDEF01-2345-4678-7ABC-DEF012345678"),
            ("not-a-uuid", "not-a-uuid"),
            (" " + generated, " " + generated), (generated + "\n", generated + "\n"),
        ]
        for (stored, expectedCustom) in cases {
            let suite = "NubrickTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            defer { defaults.removePersistentDomain(forName: suite) }
            if let stored { defaults.set(stored, forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue) }
            let user = NubrickUser(userDefaults: defaults)
            XCTAssertEqual(user.customUserId, expectedCustom, "Stored: \(stored ?? "nil")")
            XCTAssertFalse(user.trackingId.isEmpty)
            if stored == generated {
                XCTAssertEqual(user.trackingId, stored)
            } else {
                XCTAssertNotEqual(user.trackingId, stored)
            }
            XCTAssertNotNil(user.trackingId.range(
                of: "\\A[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}\\z",
                options: .regularExpression
            ))
            XCTAssertEqual(defaults.string(forKey: NativebrikUserDefaultsKeys.USER_ID.rawValue), user.trackingId)
            XCTAssertEqual(defaults.string(forKey: NativebrikUserDefaultsKeys.CUSTOM_USER_ID.rawValue), expectedCustom)
            let reloaded = NubrickUser(userDefaults: defaults)
            XCTAssertEqual(reloaded.trackingId, user.trackingId)
            XCTAssertEqual(reloaded.customUserId, expectedCustom)

            user.setProperty("userId", value: "")
            let cleared = NubrickUser(userDefaults: defaults)
            XCTAssertEqual(cleared.customUserId, "")
            XCTAssertEqual(cleared.trackingId, user.trackingId)
        }
    }

    func testCustomerIdentityDrivesPropertiesTemplatesAndDeliveryOnly() async throws {
        let suite = "NubrickTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let user = NubrickUser(userDefaults: defaults)
        let trackingId = user.trackingId
        let random = user.getSeededNormalizedUserRnd(seed: 42)
        let retention = user.retention
        var published: [String: Any] = [:]
        let subscription = user.userDataPublisher.sink { published = $0 }
        defer { subscription.cancel() }

        for (index, input) in ["", "customer-a", " customer-b ", " \n"].enumerated() {
            switch index {
            case 0, 1: user.setProperty("userId", value: input)
            case 2: user.setProperties(["userId": input, "plan": "pro"])
            default: user.set(["userId": input])
            }
            let expected = input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "" : input
            XCTAssertEqual(user.customUserId, expected)
            XCTAssertEqual(user.getProperty("userId"), expected)
            XCTAssertEqual(user.getProperties()["userId"], expected)
            XCTAssertNil(user.getProperties()["customUserId"])
            XCTAssertEqual(published["id"] as? String, expected)
            XCTAssertEqual(published["userId"] as? String, expected)
            let template = _createVariableForTemplate(user: user).value["user"] as? [String: Any]
            XCTAssertEqual(template?["id"] as? String, expected)
            XCTAssertEqual(template?["userId"] as? String, expected)
            let properties = user.toEventProperties(seed: 42)
            XCTAssertEqual(properties.filter { $0.name == "userId" }.count, 1)
            let matchesEmpty = await isInDistribution(
                distribution: [ExperimentCondition(property: "userId", operator: "Equal", value: "")],
                properties: properties
            )
            XCTAssertEqual(matchesEmpty, expected.isEmpty)
            XCTAssertEqual(user.trackingId, trackingId)
            XCTAssertEqual(user.getSeededNormalizedUserRnd(seed: 42), random)
            XCTAssertEqual(user.retention, retention)
            let reloaded = NubrickUser(userDefaults: defaults)
            XCTAssertEqual(reloaded.customUserId, expected)
            XCTAssertEqual(reloaded.trackingId, trackingId)
        }
        XCTAssertEqual(user.getProperty("plan"), "pro")
    }

    func testGetUserSeededNormalizedRndAndAlwaysTheSame() {
        let user = NubrickUser()
        let seeded0 = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded0Again = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded10 = user.getSeededNormalizedUserRnd(seed: 10)
        XCTAssertEqual(seeded0, seeded0Again)
        XCTAssertNotEqual(seeded10, seeded0)
    }

    func testGetUserSeededNormalizedRndHandlesOverflowingRemoteSeed() throws {
        let suiteName = "NubrickTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(Int.max, forKey: "NATIVEBRIK_USER_SEED")

        let user = NubrickUser(userDefaults: userDefaults)
        let seeded = user.getSeededNormalizedUserRnd(seed: Int.max)

        XCTAssertGreaterThanOrEqual(seeded, 0)
        XCTAssertLessThan(seeded, 1)
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
        let userId = user.customUserId
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
