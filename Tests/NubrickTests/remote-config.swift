//
//  remote-config.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/10/27.
//

import XCTest
@testable import NubrickLocal

// https://nativebrik.com/experiments/result?projectId=ckto7v223akg00ag3jsg
let PROJECT_ID_FOR_TEST = "ckto7v223akg00ag3jsg"
// https://nativebrik.com/experiments/result?projectId=ckto7v223akg00ag3jsg&id=ckto9eq23akg00ag3jt0
let REMOTE_CONFIG_ID_1_FOR_TEST = "REMOTE_CONFIG_1"
let REMOTE_CONFIG_1_FOR_TEST_MESSAGE = "hello"
let UNKNOWN_EXPERIMENT_ID = "UNKNOWN_ID_XXXXXX"

final class RemoteConfigTests: XCTestCase {
    @MainActor
    func testRemoteConfigShouldFetch() {
        let completedExpectation = expectation(description: "Fetch remote config for test")
        let loadingExpectation = expectation(description: "Remote config loading phase")

        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        NubrickSDK.remoteConfig(REMOTE_CONFIG_ID_1_FOR_TEST) { phase in
            switch phase {
            case .completed(let variant):
                let message = variant.getAsString("message")
                XCTAssertEqual(message, REMOTE_CONFIG_1_FOR_TEST_MESSAGE)
                completedExpectation.fulfill()
            case .loading:
                loadingExpectation.fulfill()
            default:
                XCTFail("should found the remote config \(phase)")
                completedExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }

    @MainActor
    func testRemoteConfigShouldNotFetch() {
        let completedExpectation = expectation(description: "Fetch non-exist remote config for test")
        let loadingExpectation = expectation(description: "Remote config loading phase")

        NubrickSDK.initialize(projectId: PROJECT_ID_FOR_TEST)
        NubrickSDK.remoteConfig(UNKNOWN_EXPERIMENT_ID) { phase in
            switch phase {
            case .completed:
                XCTFail("should found the remote config")
            case .loading:
                loadingExpectation.fulfill()
            default:
                completedExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
        }
    }
}
