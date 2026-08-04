import XCTest
@testable import NubrickLocal
import YogaKit

final class FlexOverflowViewTests: XCTestCase {
    @MainActor
    func testDefaultRowMakesZeroWidthChildGrow() throws {
        let root = FlexView(
            block: try makeDefaultRowBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )

        let child = try XCTUnwrap(root.subviews.first)
        XCTAssertTrue(child.yoga.width.value.isNaN)
        XCTAssertEqual(child.yoga.flexGrow, 1)
        XCTAssertEqual(child.yoga.flexBasis.value, 0)
    }

    @MainActor
    func testHorizontalScrollWithHugHeightMeasuresContentHeight() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "ROW", width: 100, height: nil),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try XCTUnwrap(view.subviews.first)
        XCTAssertTrue(content.yoga.height.value.isNaN)
    }

    @MainActor
    func testHorizontalScrollWithFillHeightFillsViewportHeight() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "ROW", width: 100, height: 0),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try XCTUnwrap(view.subviews.first)
        XCTAssertEqual(content.yoga.height.value, 100)
    }

    @MainActor
    func testVerticalScrollWithHugWidthMeasuresContentWidth() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "COLUMN", width: nil, height: 100),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try XCTUnwrap(view.subviews.first)
        XCTAssertTrue(content.yoga.width.value.isNaN)
    }

    @MainActor
    func testVerticalScrollWithFillWidthFillsViewportWidth() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "COLUMN", width: 0, height: 100),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try XCTUnwrap(view.subviews.first)
        XCTAssertEqual(content.yoga.width.value, 100)
    }

    @MainActor
    func testScrollContentPreservesPercentageMinimums() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(
                direction: "COLUMN", width: 0, height: 100, childWidth: 0
            ),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try XCTUnwrap(view.subviews.first)
        let child = try XCTUnwrap(content.subviews.first)
        XCTAssertEqual(child.yoga.minWidth.unit, .percent)
    }

    private func makeScrollBlock(
        direction: String,
        width: Int?,
        height: Int?,
        childWidth: Int? = nil
    ) throws -> UIFlexContainerBlock {
        let frame = [
            width.map { "\"width\": \($0)" },
            height.map { "\"height\": \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ",")
        let childFrame = childWidth.map { "\"frame\": { \"width\": \($0) }" } ?? ""

        let json = """
        {
          "id": "scroll-container",
          "data": {
            "direction": "\(direction)",
            "overflow": "SCROLL",
            "frame": { \(frame) },
            "children": [{
              "__typename": "UIFlexContainerBlock",
              "id": "label",
              "data": { \(childFrame) }
            }]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }

    private func makeDefaultRowBlock() throws -> UIFlexContainerBlock {
        let json = """
        {
          "id": "parent",
          "data": {
            "children": [{
              "__typename": "UIFlexContainerBlock",
              "id": "child",
              "data": { "frame": { "width": 0 } }
            }]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }
}
