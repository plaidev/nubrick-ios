import XCTest
@testable import NubrickLocal

final class WebviewModalURLActionTests: XCTestCase {
    func testHttpAndHttpsPresentInSafari() {
        XCTAssertEqual(
            resolveWebviewModalURLAction("https://example.com/path"),
            .presentInSafari(URL(string: "https://example.com/path")!)
        )
        XCTAssertEqual(
            resolveWebviewModalURLAction("http://example.com"),
            .presentInSafari(URL(string: "http://example.com")!)
        )
        XCTAssertEqual(
            resolveWebviewModalURLAction("HTTPS://EXAMPLE.COM"),
            .presentInSafari(URL(string: "HTTPS://EXAMPLE.COM")!)
        )
    }

    func testNonHttpSchemesOpenExternally() {
        XCTAssertEqual(
            resolveWebviewModalURLAction("mailto:test@example.com"),
            .openExternally(URL(string: "mailto:test@example.com")!)
        )
        XCTAssertEqual(
            resolveWebviewModalURLAction("tel:1234567890"),
            .openExternally(URL(string: "tel:1234567890")!)
        )
        XCTAssertEqual(
            resolveWebviewModalURLAction("myapp://deeplink"),
            .openExternally(URL(string: "myapp://deeplink")!)
        )
    }

    func testInvalidOrEmptyUrlsAreIgnored() {
        XCTAssertEqual(resolveWebviewModalURLAction(nil), .ignore)
        XCTAssertEqual(resolveWebviewModalURLAction(""), .ignore)
        XCTAssertEqual(resolveWebviewModalURLAction("not a url"), .ignore)
    }
}
