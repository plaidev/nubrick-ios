//
//  frequency.swift
//  Nubrick
//
//  Created by ryosuke.suzuki on 2025/07/24.
//

import XCTest
@testable import NubrickLocal

final class FrequencyUnitUtilTests: XCTestCase {
    func testSubtractWeek() {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        let weekBefore = FrequencyUnit.WEEK.subtract(1, from: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.weekOfYear], from: weekBefore, to: now).weekOfYear, 1)
    }

    func testBucketStartHour() {
        let cal = Calendar(identifier: .gregorian)
        let ts = ISO8601DateFormatter().date(from: "2025-07-24T10:23:45Z")!
        let bucket = FrequencyUnit.HOUR.bucketStart(for: ts, calendar: cal)
        XCTAssertEqual(bucket, ISO8601DateFormatter().date(from: "2025-07-24T10:00:00Z"))
    }
}
