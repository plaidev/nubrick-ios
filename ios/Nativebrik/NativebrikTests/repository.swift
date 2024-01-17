//
//  repository.swift
//  NativebrikTests
//
//  Created by Ryosuke Suzuki on 2023/11/02.
//

import Foundation

import XCTest
@testable import Nativebrik

let HEALTH_CHECK_URL = "https://track.nativebrik.com/health"

final class HttpRequestReposotiryTests: XCTestCase {
    func testShouldCallApiHttpRequest() throws {
        let expectation = expectation(description: "Request should be expected.")
        let repository = ApiHttpRequestRepository(interceptor: nil)
        repository.fetch(request: ApiHttpRequest(url: HEALTH_CHECK_URL), assertion: nil, placeholderReplacer: { _ in
            return ""
        }) { entry in
            XCTAssertEqual(entry.state, .EXPECTED)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
    
    func testShouldAssertHttpRequest() throws {
        let expectation = expectation(description: "Request should be unexpected.")
        let repository = ApiHttpRequestRepository(interceptor: nil)
        repository.fetch(request: ApiHttpRequest(url: HEALTH_CHECK_URL), assertion: ApiHttpResponseAssertion(statusCodes: [300]), placeholderReplacer: { _ in
            return ""
        }) { entry in
            XCTAssertEqual(entry.state, .UNEXPECTED)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5)
    }
}
