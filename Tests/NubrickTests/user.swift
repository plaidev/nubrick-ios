//
//  user.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
@testable import Nubrick

final class UserTests: XCTestCase {
    func testHasUserIdByDefaultAndAlwaysTheSame() {
        let user = NubrickUser()
        XCTAssertTrue(user.id.count > -1)
        
        let later = NubrickUser()
        XCTAssertEqual(user.id, later.id)
    }

    func testGetUserSeededNormalizedRndAndAlwaysTheSame() {
        let user = NubrickUser()
        XCTAssertEqual(user.getSeededNormalizedUserRnd(seed: 0), user.getSeededNormalizedUserRnd(seed: 0))
        XCTAssertNotEqual(user.getSeededNormalizedUserRnd(seed: 10), user.getSeededNormalizedUserRnd(seed: 0))
    }
    
    func testGetUserSeededNormalizedShouldBeIn0to1() {
        let user = NubrickUser()
        for i in 1...1000 {
            XCTAssertTrue(user.getSeededNormalizedUserRnd(seed: i) < 1.0)
            XCTAssertTrue(user.getSeededNormalizedUserRnd(seed: i) >= 0.0)
        }
    }
    
    func testSetUserProperties() {
        let customUserId = "hello"
        let user = NubrickUser()
        user.set(["userId": customUserId])
        XCTAssertEqual(user.id, customUserId)
    }
    
    func testUserPropertiesIncludeCustomProp() {
        let user = NubrickUser()
        
        let customUserId = "hello"
        user.set(["userId": customUserId, "custom": "world"])
        let props = user.toEventProperties(seed: 0)
        let userIdProp = props.first { prop in
            if prop.name == "userId" {
                return true
            } else {
                return false
            }
        }
        let customProp = props.first { prop in
            if prop.name == "custom" {
                return true
            } else {
                return false
            }
        }
        
        XCTAssertEqual(customUserId, userIdProp?.value)
        XCTAssertEqual("world", customProp?.value)
    }
}
