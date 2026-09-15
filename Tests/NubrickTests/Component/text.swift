import UIKit
import XCTest
import YogaKit
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
    func testScaleWithDeviceFontSizeFalseKeepsAuthoredPointSize() throws {
        let view = TextView(
            block: try makeTextBlock(value: "Latin", scaleWithDeviceFontSize: false),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertFalse(view.label.adjustsFontForContentSizeCategory)
        XCTAssertEqual(view.label.font.pointSize, 13, accuracy: 0.01)
    }

    @MainActor
    func testScaleWithDeviceFontSizeDefaultsToScaling() throws {
        let view = TextView(
            block: try makeTextBlock(value: "Latin"),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertTrue(view.label.adjustsFontForContentSizeCategory)
    }

    @MainActor
    func testOnlyPositiveMaxLinesValuesClampAndEllipsize() throws {
        let capped = TextView(
            block: try makeTextBlock(value: "Line one", maxLines: 2),
            context: UIBlockContext(UIBlockContextInit())
        )
        let uncapped = TextView(
            block: try makeTextBlock(value: "Line one", maxLines: 0),
            context: UIBlockContext(UIBlockContextInit())
        )
        let negative = TextView(
            block: try makeTextBlock(value: "Line one", maxLines: -1),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertEqual(capped.label.numberOfLines, 2)
        XCTAssertEqual(capped.label.lineBreakMode, .byTruncatingTail)
        XCTAssertEqual(uncapped.label.numberOfLines, 0)
        XCTAssertEqual(uncapped.label.lineBreakMode, .byWordWrapping)
        XCTAssertEqual(negative.label.numberOfLines, 0)
        XCTAssertEqual(negative.label.lineBreakMode, .byWordWrapping)
    }

    @MainActor
    func testUnframedTextWrapsInConstrainedHorizontalFlex() throws {
        let row = FlexView(
            block: try makeConstrainedRowBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )
        row.frame.size = CGSize(width: 180, height: 200)
        row.yoga.applyLayout(preservingOrigin: true)

        let unframed = try XCTUnwrap(row.subviews.first as? TextView)
        let fixedWidth = try XCTUnwrap(row.subviews.last as? TextView)

        XCTAssertEqual(unframed.yoga.flexShrink, 1)
        XCTAssertEqual(unframed.yoga.minWidth.value, 0)
        XCTAssertEqual(unframed.yoga.minWidth.unit, .point)
        XCTAssertEqual(fixedWidth.frame.width, 120, accuracy: 0.01)
        XCTAssertEqual(unframed.frame.width, 60, accuracy: 0.01)
        XCTAssertEqual(unframed.label.frame.width, unframed.frame.width, accuracy: 0.01)
        XCTAssertGreaterThan(unframed.label.frame.height, unframed.label.font.lineHeight)
    }

    @MainActor
    func testUnframedTextsShrinkProportionallyToIntrinsicWidthsInHorizontalFlex() throws {
        let row = FlexView(
            block: try makeProportionalTextRowBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )
        row.frame.size = CGSize(width: 300, height: 300)
        row.yoga.applyLayout(preservingOrigin: true)

        let longText = try XCTUnwrap(row.subviews[0] as? TextView)
        let shortText = try XCTUnwrap(row.subviews[1] as? TextView)
        let fixedWidth = try XCTUnwrap(row.subviews[2] as? TextView)
        let textSpace = row.frame.width - fixedWidth.frame.width
        let totalBasis = CGFloat(longText.yoga.flexBasis.value + shortText.yoga.flexBasis.value)

        XCTAssertEqual(longText.yoga.maxWidth.unit, .undefined)
        XCTAssertGreaterThan(longText.yoga.flexBasis.value, shortText.yoga.flexBasis.value)
        XCTAssertEqual(fixedWidth.frame.width, 60, accuracy: 0.01)
        XCTAssertEqual(
            longText.frame.width,
            textSpace * CGFloat(longText.yoga.flexBasis.value) / totalBasis,
            accuracy: 1
        )
        XCTAssertEqual(
            shortText.frame.width,
            textSpace * CGFloat(shortText.yoga.flexBasis.value) / totalBasis,
            accuracy: 1
        )
    }

    @MainActor
    private func makeTextView(value: String, lineHeight: Float) throws -> TextView {
        TextView(
            block: try makeTextBlock(value: value, lineHeight: lineHeight),
            context: UIBlockContext(UIBlockContextInit())
        )
    }

    private func makeTextBlock(
        value: String,
        lineHeight: Float? = nil,
        scaleWithDeviceFontSize: Bool? = nil,
        maxLines: Int? = nil
    ) throws -> UITextBlock {
        let lineHeightJSON = lineHeight.map { ",\n            \"lineHeight\": \($0)" } ?? ""
        let scaleJSON = scaleWithDeviceFontSize.map {
            ",\n            \"scaleWithDeviceFontSize\": \($0)"
        } ?? ""
        let maxLinesJSON = maxLines.map { ",\n            \"maxLines\": \($0)" } ?? ""
        let json = """
        {
          "id": "text",
          "data": {
            "value": "\(value.replacingOccurrences(of: "\n", with: "\\n"))",
            "size": 13\(lineHeightJSON)\(scaleJSON)\(maxLinesJSON)
          }
        }
        """
        return try JSONDecoder().decode(UITextBlock.self, from: Data(json.utf8))
    }

    private func makeConstrainedRowBlock() throws -> UIFlexContainerBlock {
        let json = """
        {
          "id": "row",
          "data": {
            "direction": "ROW",
            "frame": { "width": 180 },
            "children": [
              {
                "__typename": "UITextBlock",
                "id": "unframed",
                "data": {
                  "value": "Long text that needs to wrap",
                  "size": 13
                }
              },
              {
                "__typename": "UITextBlock",
                "id": "fixed",
                "data": {
                  "value": "Fixed text",
                  "size": 13,
                  "frame": { "width": 120 }
                }
              }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }

    private func makeProportionalTextRowBlock() throws -> UIFlexContainerBlock {
        let json = """
        {
          "id": "row",
          "data": {
            "direction": "ROW",
            "frame": { "width": 300 },
            "children": [
              {
                "__typename": "UITextBlock",
                "id": "long",
                "data": {
                  "value": "This is a substantially longer text block that should receive more row space",
                  "size": 13
                }
              },
              {
                "__typename": "UITextBlock",
                "id": "short",
                "data": {
                  "value": "Shorter text block",
                  "size": 13
                }
              },
              {
                "__typename": "UITextBlock",
                "id": "fixed",
                "data": {
                  "value": "Fixed",
                  "size": 13,
                  "frame": { "width": 60 }
                }
              }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }
}
