import XCTest
@testable import Nubrick
import SwiftUI

let EMBEDDING_ID_1_FOR_TEST = "EMBEDDING_1"

final class EmbeddingUIViewTests: XCTestCase {
    func testEmbeddingShouldFetch() {
        let expLoading = expectation(description: "loading")
        let expDone    = expectation(description: "completed or failed")

        var didLoadingPhaseCome = false
        let client = NubrickClient(projectId: PROJECT_ID_FOR_TEST)
        let view = client.experiment.embeddingUIView(EMBEDDING_ID_1_FOR_TEST, onEvent: nil) { phase in
            switch phase {
            case .loading:
                didLoadingPhaseCome = true
                expLoading.fulfill()
                return UIView()
            case .completed:
                expDone.fulfill()
                return UIView()
            case .notFound, .failed:
                XCTFail("should find remote config")
                expDone.fulfill()
                return UIView()
            @unknown default:
                expDone.fulfill()
                return UIView()
            }
        }

        _ = view.frame   // keep alive

        wait(for: [expLoading, expDone], timeout: 10)
        XCTAssertTrue(didLoadingPhaseCome)
    }

    func testEmbeddingShouldNotFetch() {
        let expectation = expectation(description: "Fetch an embedding for test")

        var didLoadingPhaseCome = false
        let client = NubrickClient(projectId: PROJECT_ID_FOR_TEST)
        let view = client.experiment.embeddingUIView(UNKNOWN_EXPERIMENT_ID, onEvent: nil) { phase in
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
