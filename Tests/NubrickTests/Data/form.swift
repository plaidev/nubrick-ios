import XCTest
@testable import NubrickLocal

@MainActor
final class FormRepositoryTests: XCTestCase {
    func testSetValueWithNilRegexRemovesPreviousRegex() {
        let form = FormRepositoryImpl()
        form.setValue(key: "email", value: "not-an-email", regex: #"^\S+@\S+$"#)
        XCTAssertEqual(form.getFormRegexes()["email"], #"^\S+@\S+$"#)

        form.setValue(key: "email", value: "not-an-email", regex: nil)
        XCTAssertNil(form.getFormRegexes()["email"])
    }

    func testSetValueWithEmptyRegexRemovesPreviousRegex() {
        let form = FormRepositoryImpl()
        form.setValue(key: "email", value: "user@example.com", regex: #"^\S+@\S+$"#)

        form.setValue(key: "email", value: "user@example.com", regex: "")
        XCTAssertNil(form.getFormRegexes()["email"])
    }

    func testSetValueReplacesRegexForTheSameKey() {
        let form = FormRepositoryImpl()
        form.setValue(key: "code", value: "abc", regex: "^[a-z]+$")
        form.setValue(key: "code", value: "123", regex: "^[0-9]+$")
        XCTAssertEqual(form.getFormRegexes()["code"], "^[0-9]+$")
    }
}
