import Foundation
import XCTest
@testable import NubrickLocal

final class ActionListenerTests: XCTestCase {
    func testHTTPActionHasTapFeedback() {
        let action = UIBlockAction(
            eventName: nil,
            name: nil,
            destinationPageId: nil,
            deepLink: nil,
            payload: nil,
            requiredFields: nil,
            httpRequest: ApiHttpRequest(
                url: "https://example.com",
                method: .POST,
                headers: nil,
                body: nil
            ),
            httpResponseAssertion: nil,
            submitSurveyResponse: nil
        )

        XCTAssertTrue(hasTapFeedback(action))
    }

    func testRequiredFieldsTreatMissingAndEmptyValuesAsDisabled() {
        XCTAssertTrue(isDisabled(requiredFields: ["answer"], values: [:]))
        XCTAssertTrue(isDisabled(requiredFields: ["answer"], values: ["answer": ""]))
        XCTAssertTrue(isDisabled(requiredFields: ["answer"], values: ["answer": [String]()]))
        XCTAssertTrue(isDisabled(requiredFields: ["answer"], values: ["answer": NSNull()]))
    }

    func testRequiredFieldsTreatPresentValuesAsEnabled() {
        XCTAssertFalse(isDisabled(requiredFields: ["answer"], values: ["answer": "yes"]))
        XCTAssertFalse(isDisabled(requiredFields: ["answer"], values: ["answer": ["yes"]]))
        XCTAssertFalse(isDisabled(requiredFields: ["answer"], values: ["answer": false]))
    }

    @MainActor
    func testRequestCompletionDoesNotOverrideInvalidRequiredFields() {
        let view = AnimatedUIView()

        view.setRequestPending(true)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 0.8, accuracy: 0.001)

        view.setRequiredFieldsInvalid(true)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001)

        view.setRequestPending(false)
        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 0.5, accuracy: 0.001)

        view.setRequiredFieldsInvalid(false)
        XCTAssertTrue(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 1, accuracy: 0.001)
    }

    @MainActor
    func testValidationDoesNotEnableViewWhileRequestIsPending() {
        let view = AnimatedUIView()

        view.setRequestPending(true)
        view.setRequiredFieldsInvalid(true)
        view.setRequiredFieldsInvalid(false)

        XCTAssertFalse(view.isUserInteractionEnabled)
        XCTAssertEqual(view.alpha, 0.8, accuracy: 0.001)
    }
}
