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

        let content = try scrollContent(of: view)
        XCTAssertTrue(content.yoga.height.value.isNaN)
    }

    @MainActor
    func testHorizontalScrollWithFillHeightFillsViewportHeight() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "ROW", width: 100, height: 0),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try scrollContent(of: view)
        XCTAssertEqual(content.yoga.height.value, 100)
    }

    @MainActor
    func testVerticalScrollWithHugWidthMeasuresContentWidth() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "COLUMN", width: nil, height: 100),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try scrollContent(of: view)
        XCTAssertTrue(content.yoga.width.value.isNaN)
    }

    @MainActor
    func testVerticalScrollWithFillWidthFillsViewportWidth() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "COLUMN", width: 0, height: 100),
            context: UIBlockContext(UIBlockContextInit())
        )

        let content = try scrollContent(of: view)
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

        let content = try scrollContent(of: view)
        let child = try XCTUnwrap(content.subviews.first)
        XCTAssertEqual(child.yoga.minWidth.unit, .percent)
    }

    @MainActor
    func testHiddenFlexUsesNormalFlexLayoutAndClips() throws {
        let block = try makeOverflowBlock(overflow: "HIDDEN")
        let context = UIBlockContext(UIBlockContextInit())

        let view = uiblockToUIView(data: .EUIFlexContainerBlock(block), context: context)

        XCTAssertTrue(view is FlexView)
        XCTAssertFalse(view is FlexOverflowView)
        XCTAssertTrue(view.clipsToBounds)
    }

    @MainActor
    func testVisibleAndHiddenFlexHaveTheSameYogaSizing() throws {
        let context = UIBlockContext(UIBlockContextInit())
        let visible = FlexView(
            block: try makeOverflowBlock(overflow: "VISIBLE"), context: context
        )
        let hidden = FlexView(
            block: try makeOverflowBlock(overflow: "HIDDEN"), context: context
        )

        XCTAssertEqual(visible.yoga.width.value, hidden.yoga.width.value)
        XCTAssertEqual(visible.yoga.width.unit, hidden.yoga.width.unit)
        XCTAssertEqual(visible.yoga.height.value, hidden.yoga.height.value)
        XCTAssertEqual(visible.yoga.height.unit, hidden.yoga.height.unit)
        XCTAssertFalse(visible.clipsToBounds)
        XCTAssertTrue(hidden.clipsToBounds)
    }

    @MainActor
    func testBorderWidthIsIncludedInFlexYogaBoxModel() throws {
        let root = FlexView(
            block: try makeBorderedBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertEqual(root.yoga.borderWidth, 2)
    }

    @MainActor
    func testScrollContentDoesNotReserveTheContainerBorderTwice() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(
                direction: "COLUMN", width: 100, height: 100, borderWidth: 2
            ),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertEqual(view.yoga.borderWidth, 2)
        XCTAssertTrue(try scrollContent(of: view).yoga.borderWidth.isNaN)
    }

    @MainActor
    func testScrollLayoutWithoutBorderProducesFiniteGeometry() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(direction: "COLUMN", width: 100, height: 100),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame.size = CGSize(width: 100, height: 100)
        view.yoga.applyLayout(preservingOrigin: true)
        view.layoutSubviews()

        XCTAssertTrue(view.contentSize.width.isFinite)
        XCTAssertTrue(view.contentSize.height.isFinite)
    }

    @MainActor
    func testVerticalScrollContentFillsBorderAdjustedViewport() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(
                direction: "COLUMN", width: 100, height: 100, borderWidth: 2
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame.size = CGSize(width: 100, height: 100)
        view.yoga.applyLayout(preservingOrigin: true)
        view.layoutSubviews()

        XCTAssertEqual(try scrollContent(of: view).frame, CGRect(x: 2, y: 2, width: 96, height: 96))
        XCTAssertEqual(view.contentSize.height, 100)
    }

    @MainActor
    func testHorizontalScrollContentFillsBorderAdjustedViewport() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(
                direction: "ROW", width: 100, height: 100, borderWidth: 2
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame.size = CGSize(width: 100, height: 100)
        view.layoutSubviews()

        XCTAssertEqual(view.contentSize.width, 100)
    }

    @MainActor
    func testVerticalScrollContentSizeIncludesTrailingBorder() throws {
        let view = FlexOverflowView(
            block: try makeScrollBlock(
                direction: "COLUMN", width: 100, height: 100, childHeight: 200, borderWidth: 2
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame.size = CGSize(width: 100, height: 100)
        view.yoga.applyLayout(preservingOrigin: true)
        view.layoutSubviews()

        XCTAssertEqual(try scrollContent(of: view).frame, CGRect(x: 2, y: 2, width: 96, height: 200))
        XCTAssertEqual(view.contentSize, CGSize(width: 100, height: 204))
    }

    private func makeScrollBlock(
        direction: String,
        width: Int?,
        height: Int?,
        childWidth: Int? = nil,
        childHeight: Int? = nil,
        borderWidth: Int? = nil
    ) throws -> UIFlexContainerBlock {
        let frame = [
            width.map { "\"width\": \($0)" },
            height.map { "\"height\": \($0)" },
            borderWidth.map { "\"borderWidth\": \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ",")
        let childFrameValues = [
            childWidth.map { "\"width\": \($0)" },
            childHeight.map { "\"height\": \($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: ",")
        let childFrame = childFrameValues.isEmpty ? "" : "\"frame\": { \(childFrameValues) }"

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

    private func scrollContent(of view: FlexOverflowView) throws -> UIView {
        try XCTUnwrap(view.subviews.first { $0 is FlexView })
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

    private func makeOverflowBlock(overflow: String) throws -> UIFlexContainerBlock {
        let json = """
        {
          "id": "overflow-container",
          "data": {
            "direction": "COLUMN",
            "overflow": "\(overflow)",
            "frame": { "width": 0, "height": 0 },
            "children": []
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }

    private func makeBorderedBlock() throws -> UIFlexContainerBlock {
        let json = """
        {
          "id": "bordered-container",
          "data": {
            "frame": { "width": 100, "height": 100, "borderWidth": 2 },
            "children": []
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }
}
