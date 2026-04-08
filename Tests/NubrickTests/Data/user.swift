//
//  user.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
@testable import NubrickLocal

@MainActor
final class UserTests: XCTestCase {
    func testHasUserIdByDefaultAndAlwaysTheSame() {
        let user = NubrickUser()
        let userId = user.id
        XCTAssertTrue(userId.count > -1)
        
        let later = NubrickUser()
        let laterId = later.id
        XCTAssertEqual(userId, laterId)
    }

    func testGetUserSeededNormalizedRndAndAlwaysTheSame() {
        let user = NubrickUser()
        let seeded0 = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded0Again = user.getSeededNormalizedUserRnd(seed: 0)
        let seeded10 = user.getSeededNormalizedUserRnd(seed: 10)
        XCTAssertEqual(seeded0, seeded0Again)
        XCTAssertNotEqual(seeded10, seeded0)
    }
    
    func testGetUserSeededNormalizedShouldBeIn0to1() {
        let user = NubrickUser()
        for i in 1...1000 {
            let seeded = user.getSeededNormalizedUserRnd(seed: i)
            XCTAssertTrue(seeded < 1.0)
            XCTAssertTrue(seeded >= 0.0)
        }
    }
    
    func testSetUserProperties() {
        let customUserId = "hello"
        let user = NubrickUser()
        user.set(["userId": customUserId])
        let userId = user.id
        XCTAssertEqual(userId, customUserId)
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
