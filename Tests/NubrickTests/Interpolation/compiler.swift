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
        let variable = Variable(value: [
            "value": "World",
        ])
        let result = compile(template, variable)
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithMultiplePlaceholders() throws {
        let template = "{{ value1 }} {{ value2 }}"
        let variable = Variable(value: [
            "value1": "Hello",
            "value2": "World",
        ])
        let result = compile(template, variable)
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithoutFmtButPipelined() throws {
        let template = "Hello {{ value | }}"
        let variable = Variable(value: [
            "value": "World"
        ])
        let result = compile(template, variable)
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithUnknownFmt() throws {
        let template = "Hello {{ value | unknown }}"
        let variable = Variable(value: [
            "value": "World"
        ])
        let result = compile(template, variable)
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithUpperFmt() throws {
        let variable = Variable(value: [
            "value": "world"
        ])
        let template = "HELLO {{ value | upper }}"
        let result = compile(template, variable)
        XCTAssertEqual("HELLO WORLD", result)
    }

    func testShouldCompileTemplateWithLowerFmt() throws {
        let variable = Variable(value: [
            "value": "WORLD"
        ])
        let template = "hello {{ value | lower }}"
        let result = compile(template, variable)
        XCTAssertEqual("hello world", result)
    }

    func testShouldCompileTemplateWithJsonFmt() throws {
        let variable = Variable(value: [
            "value": ["Key": "Value"]
        ])
        let template = "{{ value | json }}"
        let result = compile(template, variable)
        XCTAssertEqual("{\"Key\":\"Value\"}", result)
    }

    func testShouldCompileTemplateWithJsonFmtString() throws {
        let variable = Variable(value: [
            "value": "hello"
        ])
        let template = "{{ value | json }}"
        let result = compile(template, variable)
        XCTAssertEqual("\"hello\"", result)
    }

    func testShouldCompileTemplateWithJsonFmtNumber() throws {
        let variable = Variable(value: [
            "value": 100
        ])
        let template = "{{ value | json }}"
        let result = compile(template, variable)
        XCTAssertEqual("100", result)
    }

    func testShouldCompileTemplateWithJsonFmtNull() throws {
        let variable = Variable(value: [
            "value": NSNull()
        ])
        let template = "{{ value | json }}"
        let result = compile(template, variable)
        XCTAssertEqual("null", result)
    }

    func testShouldCompileTemplateWithJsonFmtNull2() throws {
        let variable = Variable(value: [:])
        let template = "{{ value.test | json }}"
        let result = compile(template, variable)
        XCTAssertEqual("null", result)
    }
}
