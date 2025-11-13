//
//  encode.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2025/04/10.
//

import Foundation

import XCTest
@testable import NubrickLocal

final class EncodeJsonTests: XCTestCase {
    func testShouldEncodeStruct() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = ApiHttpRequest(url: "http://localhost:8070/health", method: .GET)
        let encoded = try encoder.encode(data)
        let decoded = try decoder.decode(ApiHttpRequest.self, from: encoded)
        XCTAssertTrue(((String(data: encoded, encoding: .utf8)?.contains("\"__typename\":\"ApiHttpRequest\"")) != nil))
        XCTAssertEqual(ApiHttpRequestMethod.GET, decoded.method)
        XCTAssertEqual("http://localhost:8070/health", decoded.url)
    }
    
    func testShouldEncodeUnion() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = UIBlock.EUITextBlock(UITextBlock(id: "hello"))
        let encoded = try encoder.encode(data)
        let decoded = try decoder.decode(UIBlock.self, from: encoded)
        switch decoded {
        case .EUITextBlock(let block):
            XCTAssertEqual(block.id, "hello")
        default:
            XCTFail("Expected EUITextBlock but got \(decoded)")
        }
    }
    
    func testShouldEncodeEnum() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let data = ApiHttpRequestMethod.POST
        let encoded = try encoder.encode(data)
        let decoded = try decoder.decode(ApiHttpRequestMethod.self, from: encoded)
        XCTAssertEqual(decoded, .POST)
    }
}
