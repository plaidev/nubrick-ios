//
//  decode.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/11/01.
//

import Foundation

import XCTest
@testable import NubrickLocal

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
    
    func testShouldDecodeUIBlockAction() throws {
        let decoder = JSONDecoder()
        let json = """
{"__typename":"UIBlockEventDispatcher","eventName":"cta_click","destinationPageId":"0.2c4944c774deb","httpRequest":{"__typename":"ApiHttpRequest","method":"GET","url":"http://localhost:8070/health"}}
"""
        let result = try decoder.decode(UIBlockAction.self, from: Data(json.utf8))
        XCTAssertEqual("cta_click", result.eventName)
        XCTAssertEqual("0.2c4944c774deb", result.destinationPageId)
        XCTAssertEqual("http://localhost:8070/health", result.httpRequest?.url)
    }

    func testShouldDecodeLegacyUIBlockActionName() throws {
        let decoder = JSONDecoder()
        let json = """
{"__typename":"UIBlockEventDispatcher","name":"legacy_click","destinationPageId":"0.2c4944c774deb"}
"""
        let result = try decoder.decode(UIBlockAction.self, from: Data(json.utf8))
        XCTAssertEqual("legacy_click", result.name)
    }
}
