
//
//  compareTests.swift
//  NativebrikTests
//
//  Created by Takuma Jimbo on 2025/08/01.
//

import XCTest
@testable import Nativebrik

final class CompareTests: XCTestCase {
    func testComparePropWithConditionValue() throws {
        let userId = "hello world"
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userId", value: userId, type: .STRING), asType: nil, value: userId, op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "userRnd", value: "40", type: .INTEGER), asType: nil, value: "100", op: .LessThanOrEqual))
        XCTAssertTrue(comparePropWithConditionValue(prop: UserProperty(name: "version", value: "4", type: .SEMVER), asType: nil, value: "4.1", op: .LessThanOrEqual))
    }
    
    func testComparePropWithConditionValueWithPropTypeOverride() throws {
        XCTAssertFalse(comparePropWithConditionValue(
            prop: UserProperty(name: "xxx", value: "12.3", type: .STRING), asType: .STRING, value: "12", op: .Equal))
        XCTAssertTrue(comparePropWithConditionValue(
            prop: UserProperty(name: "xxx", value: "12.3", type: .STRING), asType: .SEMVER, value: "12", op: .Equal))
    }
    
    
    func testCompareSemverAsComparisonResultWhenOnlyMajorVersions() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "2") < 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1", "0") > 0, true)
    }
    
    func testCompareSemverAsComparisonResultWhenItsDifferentFormat() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1", "1.0") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1.0") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.0.0", "1") == 0, true)
    }
    
    func testCompareSemverAsComparisonResult() throws {
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2") == 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.2") > 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "1.2.4") < 0, true)
        XCTAssertEqual(compareSemverAsComparisonResult("1.2.3", "2") != 0, true)
    }
    
    func testCompareSemver() throws {
        // equal
        XCTAssertTrue(compareSemver(a: "1.1", b: ["1"], op: .Equal))
        XCTAssertTrue(compareSemver(a: "1", b: ["1.0"], op: .Equal))
        XCTAssertFalse(compareSemver(a: "1", b: ["1.0.1"], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .NotEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.0"], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9"], op: .GreaterThan))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1"], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1"], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9"], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1"], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .LessThan))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["0.0.9"], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1"], op: .LessThanOrEqual))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1.0.1"], op: .LessThanOrEqual))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["0.0.9"], op: .LessThanOrEqual))
        
        // in
        XCTAssertTrue(compareSemver(a: "1.0", b: ["1", "2"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["2", "3"], op: .In))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareSemver(a: "1.0", b: [], op: .NotIn))
        XCTAssertTrue(compareSemver(a: "1.0", b: ["2", "3"], op: .NotIn))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1", "2"], op: .NotIn))
        
        // between
        XCTAssertTrue(compareSemver(a: "1.0", b: ["0.0.9", "1.0.1"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: ["1.0.1", "2"], op: .Between))
        XCTAssertFalse(compareSemver(a: "1.0", b: [], op: .Between))
    }
    
    func testCompareString() throws {
        // equal
        XCTAssertTrue(compareString(a: "a", b: ["a"], op: .Equal))
        XCTAssertFalse(compareString(a: "a", b: ["b"], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareString(a: "a", b: ["b"], op: .NotEqual))
        XCTAssertFalse(compareString(a: "a", b: ["a"], op: .NotEqual))

        // in
        XCTAssertTrue(compareString(a: "a", b: ["a", "b"], op: .In))
        XCTAssertFalse(compareString(a: "a", b: ["b", "c"], op: .In))
        XCTAssertFalse(compareString(a: "a", b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareString(a: "a", b: [], op: .NotIn))
        XCTAssertTrue(compareString(a: "a", b: ["b", "c"], op: .NotIn))
        XCTAssertFalse(compareString(a: "a", b: ["a", "b"], op: .NotIn))
    }
    
    func testCompareStringWithRegex() throws {
        XCTAssertTrue(compareString(a: "hello-world_11", b: ["[a-zA-Z0-9-_]+"], op: .Regex))
        XCTAssertFalse(compareString(a: "hello", b: ["[^a-zA-Z-_]"], op: .Regex))
    }
    
    func testCompareStringWithRegexShouldBeFalseWhenThePatternIsWrong() throws {
        XCTAssertFalse(compareString(a: "+", b: ["+"], op: .Regex))
    }
    
    func testCompareDouble() throws {
        // equal
        XCTAssertTrue(compareDouble(a: 0, b: [0], op: .Equal))
        XCTAssertFalse(compareDouble(a: 0, b: [1], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareDouble(a: 0, b: [1], op: .NotEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [1], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareDouble(a: 1, b: [0], op: .GreaterThan))
        XCTAssertFalse(compareDouble(a: 1, b: [1], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareDouble(a: 1, b: [1], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareDouble(a: 1, b: [0], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [2], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareDouble(a: 1, b: [2], op: .LessThan))
        XCTAssertFalse(compareDouble(a: 1, b: [0], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareDouble(a: 1, b: [1], op: .LessThanOrEqual))
        XCTAssertTrue(compareDouble(a: 1, b: [2], op: .LessThanOrEqual))
        XCTAssertFalse(compareDouble(a: 1, b: [0], op: .LessThanOrEqual))

        // in
        XCTAssertTrue(compareDouble(a: 1, b: [0, 1], op: .In))
        XCTAssertFalse(compareDouble(a: 1, b: [2, 3], op: .In))
        XCTAssertFalse(compareDouble(a: 1, b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareDouble(a: 1, b: [], op: .NotIn))
        XCTAssertTrue(compareDouble(a: 1, b: [2, 3], op: .NotIn))
        XCTAssertFalse(compareDouble(a: 1, b: [1, 2], op: .NotIn))
        
        // between
        XCTAssertTrue(compareDouble(a: 5, b: [0, 10], op: .Between))
        XCTAssertFalse(compareDouble(a: 5, b: [10, 20], op: .Between))
        XCTAssertFalse(compareDouble(a: 5, b: [], op: .Between))
    }
    
    func testCompareInteger() throws {
        // equal
        XCTAssertTrue(compareInteger(a: 0, b: [0], op: .Equal))
        XCTAssertFalse(compareInteger(a: 0, b: [1], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareInteger(a: 0, b: [1], op: .NotEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [1], op: .NotEqual))
        
        // gt
        XCTAssertTrue(compareInteger(a: 1, b: [0], op: .GreaterThan))
        XCTAssertFalse(compareInteger(a: 1, b: [1], op: .GreaterThan))
        
        // gte
        XCTAssertTrue(compareInteger(a: 1, b: [1], op: .GreaterThanOrEqual))
        XCTAssertTrue(compareInteger(a: 1, b: [0], op: .GreaterThanOrEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [2], op: .GreaterThanOrEqual))
        
        // lt
        XCTAssertTrue(compareInteger(a: 1, b: [2], op: .LessThan))
        XCTAssertFalse(compareInteger(a: 1, b: [0], op: .LessThan))
        
        // lte
        XCTAssertTrue(compareInteger(a: 1, b: [1], op: .LessThanOrEqual))
        XCTAssertTrue(compareInteger(a: 1, b: [2], op: .LessThanOrEqual))
        XCTAssertFalse(compareInteger(a: 1, b: [0], op: .LessThanOrEqual))

        // in
        XCTAssertTrue(compareInteger(a: 1, b: [0, 1], op: .In))
        XCTAssertFalse(compareInteger(a: 1, b: [2, 3], op: .In))
        XCTAssertFalse(compareInteger(a: 1, b: [], op: .In))
        
        // not in
        XCTAssertTrue(compareInteger(a: 1, b: [], op: .NotIn))
        XCTAssertTrue(compareInteger(a: 1, b: [2, 3], op: .NotIn))
        XCTAssertFalse(compareInteger(a: 1, b: [1, 2], op: .NotIn))
        
        // between
        XCTAssertTrue(compareInteger(a: 5, b: [0, 10], op: .Between))
        XCTAssertFalse(compareInteger(a: 5, b: [10, 20], op: .Between))
        XCTAssertFalse(compareInteger(a: 5, b: [], op: .Between))
    }
    
    func testCompareBoolean() throws {
        // equal
        XCTAssertTrue(compareBoolean(a: true, b: [true], op: .Equal))
        XCTAssertFalse(compareBoolean(a: true, b: [false], op: .Equal))
        
        // not equal
        XCTAssertTrue(compareBoolean(a: false, b: [true], op: .NotEqual))
        XCTAssertFalse(compareBoolean(a: false, b: [false], op: .NotEqual))
    }
    
    func testParseStrToBoolean() {
        XCTAssertEqual(parseStringToBoolean("true"), true)
        XCTAssertEqual(parseStringToBoolean("True"), true)
        XCTAssertEqual(parseStringToBoolean("TRUE"), true)
        XCTAssertEqual(parseStringToBoolean("1"), true)
        
        XCTAssertEqual(parseStringToBoolean("false"), false)
        XCTAssertEqual(parseStringToBoolean("False"), false)
        XCTAssertEqual(parseStringToBoolean("FALSE"), false)
        XCTAssertEqual(parseStringToBoolean("Nil"), false)
        XCTAssertEqual(parseStringToBoolean("null"), false)
        XCTAssertEqual(parseStringToBoolean("0"), false)
    }
    
}
