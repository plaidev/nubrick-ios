//
//  sdk.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
import SwiftUI
@testable import NubrickLocal


final class NubrickClientTests: XCTestCase {
    @MainActor
    func testInitializeNubrickClientWithoutError() throws {
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)

        XCTContext.runActivity(named: "initialize and create overlay") { _ in
            XCTAssertNoThrow(NubrickSDK.overlayViewController())
        }

        XCTContext.runActivity(named: "dispatch event") { _ in
            XCTAssertNoThrow(NubrickSDK.dispatch(NubrickEvent("Hello")))
        }
    }

    @MainActor
    func testUserPropertiesRoundTripThroughSDK() throws {
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)

        let originalUserId = NubrickSDK.getUserId() ?? ""
        let testUserId = "sdk-user-id-test"
        let testPropertyKey = "sdk_user_api_test_property"
        let testPropertyValue = "sdk-user-api-value"

        defer {
            NubrickSDK.setUserId(originalUserId)
            NubrickSDK.setUserProperties([testPropertyKey: ""])
        }

        NubrickSDK.setUserProperties([testPropertyKey: testPropertyValue])
        NubrickSDK.setUserId(testUserId)

        XCTAssertEqual(testUserId, NubrickSDK.getUserId())

        let properties = NubrickSDK.getUserProperties()
        XCTAssertEqual(testUserId, properties["userId"])
        XCTAssertEqual(testPropertyValue, properties[testPropertyKey])
    }
}

final class NubrickProviderTests: XCTestCase {
    struct NubrickConsumerView: View {
        var body: some View {
            NubrickSDK.embedding(UNKNOWN_EXPERIMENT_ID, onEvent: nil) { phase in
                switch phase {
                default:
                    Text("EXPERIMENT")
                }
            }
        }
    }

    struct TestView: View {
        var body: some View {
            NubrickProvider {
                Text("Hello")
                NubrickConsumerView()
            }
        }
    }

    @MainActor
    func testNubrickProvider() throws {
        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        XCTAssertNoThrow(TestView().body)
    }
}
