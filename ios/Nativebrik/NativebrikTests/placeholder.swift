//
//  placeholder.swift
//  NativebrikTests
//
//  Created by Ryosuke Suzuki on 2024/01/15.
//

import Foundation

import XCTest
@testable import Nativebrik

final class CompileTemplateTests: XCTestCase {
    func testShouldCompileTemplate() throws {
        let template = "Hello {{ value }}"
        let result = compileTemplate(template: template) { key in
            if key == "value" {
                return "World"
            } else {
                return ""
            }
        }
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithMultiplePlaceholders() throws {
        let template = "{{ value1 }} {{ value2 }}"
        let result = compileTemplate(template: template) { key in
            if key == "value1" {
                return "Hello"
            } else if key == "value2" {
                return "World"
            } else {
                return ""
            }
        }
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithoutFmtButPipelined() throws {
        let template = "Hello {{ value | }}"
        let result = compileTemplate(template: template) { key in
            return "World"
        }
        XCTAssertEqual("Hello World", result)
    }

    func testShouldCompileTemplateWithUnknownFmt() throws {
        let template = "Hello {{ value | unknown }}"
        let result = compileTemplate(template: template) { key in
            if key == "value" {
                return "World"
            } else {
                return ""
            }
        }
        XCTAssertEqual("Hello World", result)
    }
    
    func testShouldCompileTemplateWithUpperFmt() throws {
        let template = "HELLO {{ value | upper }}"
        let result = compileTemplate(template: template) { key in
            return "world"
        }
        XCTAssertEqual("HELLO WORLD", result)
    }
    
    func testShouldCompileTemplateWithLowerFmt() throws {
        let template = "hello {{ value | lower }}"
        let result = compileTemplate(template: template) { key in
            return "WORLD"
        }
        XCTAssertEqual("hello world", result)
    }
    
    func testShouldCompileTemplateWithJsonFmt() throws {
        let template = "{{ value | json }}"
        let result = compileTemplate(template: template) { key in
            let json: [String: Any] = [
                "Key": "Value",
            ]
            return json
        }
        XCTAssertEqual("{\"Key\":\"Value\"}", result)
    }
}
