import XCTest
@testable import NubrickLocal
import SwiftUI

let EMBEDDING_ID_1_FOR_TEST = "EMBEDDING_1"

final class EmbeddingUIViewTests: XCTestCase {
    @MainActor
    func testEmbeddingShouldFetch() {
        let expectation = expectation(description: "Fetch an embedding for test")

        var didLoadingPhaseCome = false
        Nubrick.initialize(projectId: PROJECT_ID_FOR_TEST)
        let view = Nubrick.embeddingUIView(EMBEDDING_ID_1_FOR_TEST, onEvent: nil) { phase in
            switch phase {
            case .completed:
                expectation.fulfill()
                return UIView()
            case .loading:
                didLoadingPhaseCome = true
                return UIView()
            default:
                XCTFail("should found the remote config")
                return UIView()
            }
        }
        // because internally we use [weak self] and if it is `let _ =`, weak self will be nil.
        print("it must be `let view = client` to pass the test.", view.frame)
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
            XCTAssertTrue(didLoadingPhaseCome)
        }
    }

    @MainActor
    func testEmbeddingShouldNotFetch() {
        let expectation = expectation(description: "Fetch an embedding for test")

        var didLoadingPhaseCome = false
        Nubrick.initialize(projectId: PROJECT_ID_FOR_TEST)
        let view = Nubrick.embeddingUIView(UNKNOWN_EXPERIMENT_ID, onEvent: nil) { phase in
            switch phase {
            case .completed:
                XCTFail("should found the remote config")
                return UIView()
            case .loading:
                didLoadingPhaseCome = true
                return UIView()
            default:
                expectation.fulfill()
                return UIView()
            }
        }
        // because internally we use [weak self] and if it is `let _ =`, weak self will be nil.
        print("it must be `let view = client` to pass the test.", view.frame)
        waitForExpectations(timeout: 30) { error in
            if let error = error {
                XCTFail("waitForExpectationsWithTimeout errored: \(error)")
            }
            XCTAssertTrue(didLoadingPhaseCome)
        }
    }
}
