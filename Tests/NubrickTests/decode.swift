//
//  decode.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/11/01.
//

import Foundation

import XCTest
@testable import Nativebrik

final class DecodeJsonTests: XCTestCase {
    func testShouldDecodeApiHttpRequest() throws {
        let decoder = JSONDecoder()
        let json = """
{
    "__typename": "ApiHttpRequest",
    "method": "GET",
    "url": "http://localhost:8070/health"
}
"""
        let result = try decoder.decode(ApiHttpRequest.self, from: Data(json.utf8))
        XCTAssertEqual(ApiHttpRequestMethod.GET, result.method)
        XCTAssertEqual("http://localhost:8070/health", result.url)
    }
    
    func testShouldDecodeUIBlockEventDispatcher() throws {
        let decoder = JSONDecoder()
        let json = """
{"__typename":"UIBlockEventDispatcher","destinationPageId":"0.2c4944c774deb","httpRequest":{"__typename":"ApiHttpRequest","method":"GET","url":"http://localhost:8070/health"}}
"""
        let result = try decoder.decode(UIBlockEventDispatcher.self, from: Data(json.utf8))
        XCTAssertEqual("0.2c4944c774deb", result.destinationPageId)
        XCTAssertEqual("http://localhost:8070/health", result.httpRequest?.url)
    }
}
