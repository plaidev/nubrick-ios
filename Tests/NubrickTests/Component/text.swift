import UIKit
import XCTest
@testable import NubrickLocal

final class TextViewTests: XCTestCase {
    @MainActor
    func testLineHeightMakesSingleLineHeightIndependentOfGlyphs() throws {
        let latinView = TextView(
            block: try makeTextBlock(value: "Latin", lineHeight: 15.6),
            context: UIBlockContext(UIBlockContextInit())
        )
        let mixedView = TextView(
            block: try makeTextBlock(value: "日本語", lineHeight: 15.6),
            context: UIBlockContext(UIBlockContextInit())
        )

        let latinHeight = measuredHeight(of: latinView)
        let mixedHeight = measuredHeight(of: mixedView)
        XCTAssertEqual(latinHeight, mixedHeight, accuracy: 0.5)
        XCTAssertEqual(latinHeight, 15.6, accuracy: 1)
    }

    @MainActor
    func testLineHeightMakesMultilineHeightIndependentOfGlyphs() throws {
        let latinView = TextView(
            block: try makeTextBlock(value: "Latin\nText", lineHeight: 15.6),
            context: UIBlockContext(UIBlockContextInit())
        )
        let mixedView = TextView(
            block: try makeTextBlock(value: "Latin\n日本語", lineHeight: 15.6),
            context: UIBlockContext(UIBlockContextInit())
        )

        let latinHeight = measuredHeight(of: latinView)
        let mixedHeight = measuredHeight(of: mixedView)
        let singleLineHeight = measuredHeight(
            of: try makeTextView(value: "Latin", lineHeight: 15.6)
        )
        XCTAssertEqual(latinHeight, mixedHeight, accuracy: 0.5)
        XCTAssertEqual(latinHeight, 2 * singleLineHeight, accuracy: 0.5)
    }

    @MainActor
    func testExplicitLineHeightCanBeSmallerThanTheFontNaturalHeight() throws {
        let view = TextView(
            block: try makeTextBlock(value: "Latin", lineHeight: 12),
            context: UIBlockContext(UIBlockContextInit())
        )
        let naturalLineHeightView = TextView(
            block: try makeTextBlock(value: "Latin"),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertLessThan(measuredHeight(of: view), measuredHeight(of: naturalLineHeightView))
    }

    @MainActor
    private func measuredHeight(of view: TextView) -> CGFloat {
        view.label.sizeThatFits(
            CGSize(width: 200, height: CGFloat.greatestFiniteMagnitude)
        ).height
    }

    @MainActor
    private func makeTextView(value: String, lineHeight: Float) throws -> TextView {
        TextView(
            block: try makeTextBlock(value: value, lineHeight: lineHeight),
            context: UIBlockContext(UIBlockContextInit())
        )
    }

    private func makeTextBlock(value: String, lineHeight: Float? = nil) throws -> UITextBlock {
        let lineHeightJSON = lineHeight.map { ",\n            \"lineHeight\": \($0)" } ?? ""
        let json = """
        {
          "id": "text",
          "data": {
            "value": "\(value.replacingOccurrences(of: "\n", with: "\\n"))",
            "size": 13\(lineHeightJSON)
          }
        }
        """
        return try JSONDecoder().decode(UITextBlock.self, from: Data(json.utf8))
    }
}
