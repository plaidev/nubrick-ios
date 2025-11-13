//
//  ios-compat.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/11/29.
//

import XCTest
import ViewInspector
@testable import NubrickLocal

final class IOSCompatTest: XCTestCase {
    func testSyncDateFromHTTPULReponseShouldWork() throws {
        __for_test_sync_datetime_offset(offset: 0)
        let url = URL(string: "https://example.com")!
        let now = Date()
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        let formattedDate = formatter.string(from: tomorrow)
        let res = HTTPURLResponse(url: url, statusCode: 400, httpVersion: "2.0", headerFields: [
            "Date": formattedDate
        ])!
        syncDateFromHTTPURLResponse(t0: now, res: res)
        let offset = __for_test_get_datetime_offset()
        let diff = abs(offset - 24 * 60 * 60 * 1000)
        assert(diff < 1000, "time offset should be around 24 hours")
    }
    
    func testGetCurrentDate() throws {
        __for_test_sync_datetime_offset(offset: 24 * 60 * 60 * 1000)
        let deviceCurrent = Date()
        let syncedCurrent = getCurrentDate()
        let diff = syncedCurrent.timeIntervalSince1970 - deviceCurrent.timeIntervalSince1970
        assert(abs(diff - 24 * 60 * 60) < 2, "diff should be around 2 sec")
    }
    
}
