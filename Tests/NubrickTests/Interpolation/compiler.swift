//
//  compiler.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2024/01/15.
//

import Foundation

import XCTest
@testable import NubrickLocal

final class CompileTemplateTests: XCTestCase {
    func testShouldCompileTemplate() throws {
        let template = "Hello {{ value }}"
        let json: [String: Any] = [
            "value": "World",
        ]
        let result = compile(template, json)
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithMultiplePlaceholders() throws {
        let template = "{{ value1 }} {{ value2 }}"
        let json: [String: Any] = [
            "value1": "Hello",
            "value2": "World",
        ]
        let result = compile(template, json)
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithoutFmtButPipelined() throws {
        let template = "Hello {{ value | }}"
        let json: [String: Any] = [
            "value": "World"
        ]
        let result = compile(template, json)
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithUnknownFmt() throws {
        let template = "Hello {{ value | unknown }}"
        let json: [String: Any] = [
            "value": "World"
        ]
        let result = compile(template, json)
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithUpperFmt() throws {
        let json: [String: Any] = [
            "value": "world"
        ]
        let template = "HELLO {{ value | upper }}"
        let result = compile(template, json)
        XCTAssertEqual("HELLO WORLD", result)
    }
    
    func testShouldCompileTemplateWithLowerFmt() throws {
        let json: [String: Any] = [
            "value": "WORLD"
        ]
        let template = "hello {{ value | lower }}"
        let result = compile(template, json)
        XCTAssertEqual("hello world", result)
    }
    
    func testShouldCompileTemplateWithJsonFmt() throws {
        let json: [String: Any] = [
            "value": ["Key": "Value"]
        ]
        let template = "{{ value | json }}"
        let result = compile(template, json)
        XCTAssertEqual("{\"Key\":\"Value\"}", result)
    }
    
    func testShouldCompileTemplateWithJsonFmtString() throws {
        let json: [String: Any] = [
            "value": "hello"
        ]
        let template = "{{ value | json }}"
        let result = compile(template, json)
        XCTAssertEqual("\"hello\"", result)
    }
    
    func testShouldCompileTemplateWithJsonFmtNumber() throws {
        let json: [String: Any] = [
            "value": 100
        ]
        let template = "{{ value | json }}"
        let result = compile(template, json)
        XCTAssertEqual("100", result)
    }
    
    func testShouldCompileTemplateWithJsonFmtNull() throws {
        let json: [String: Any] = [
            "value": NSNull()
        ]
        let template = "{{ value | json }}"
        let result = compile(template, json)
        XCTAssertEqual("null", result)
    }
    
    func testShouldCompileTemplateWithJsonFmtNull2() throws {
        let json: [String: Any] = [:]
        let template = "{{ value.test | json }}"
        let result = compile(template, json)
        XCTAssertEqual("null", result)
    }
}
