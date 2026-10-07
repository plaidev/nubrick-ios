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

final class NubrickBridgeRenderTests: XCTestCase {
    @MainActor
    func testMalformedJSONFinishesSessionBeforeNotifyingDismissal() throws {
        let runtime = NubrickCore(projectId: PROJECT_ID_FOR_TEST, onEvent: nil,
            httpRequestInterceptor: nil, onDispatch: nil, onTooltip: nil)
        let overlay = try XCTUnwrap(runtime.overlayViewController() as? OverlayViewController)
        let modal = overlay.modalForTriggerViewController
        XCTAssertNotNil(modal.startTriggerExperiment("tooltip"))
        var dismissals = 0

        _ = runtime.renderUIView(json: "{", sessionId: "tooltip", onDismiss: {
            XCTAssertFalse(modal.hasActiveTriggerExperiment)
            dismissals += 1
        })

        XCTAssertEqual(dismissals, 1)
        XCTAssertNotNil(modal.startTriggerExperiment("next"))
    }

    @MainActor
    func testMalformedJSONCannotFinishAnotherSession() throws {
        let runtime = NubrickCore(projectId: PROJECT_ID_FOR_TEST, onEvent: nil,
            httpRequestInterceptor: nil, onDispatch: nil, onTooltip: nil)
        let overlay = try XCTUnwrap(runtime.overlayViewController() as? OverlayViewController)
        let modal = overlay.modalForTriggerViewController
        XCTAssertNotNil(modal.startTriggerExperiment("old"))
        modal.finishTriggerExperiment("old")
        XCTAssertNotNil(modal.startTriggerExperiment("new"))
        var dismissals = 0

        for sessionId in ["old", nil] as [String?] {
            _ = runtime.renderUIView(json: "{", sessionId: sessionId, onDismiss: {
                XCTAssertTrue(modal.ownsTriggerExperiment("new"))
                dismissals += 1
            })
        }

        XCTAssertEqual(dismissals, 2)
        XCTAssertTrue(modal.ownsTriggerExperiment("new"))
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
