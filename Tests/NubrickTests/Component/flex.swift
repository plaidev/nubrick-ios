import UIKit
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
    func testOmittedOverflowDefaultsToHiddenAndClips() {
        let view = FlexView(
            block: UIFlexContainerBlock(),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertEqual(parseOverflow(nil), .hidden)
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

    @MainActor
    func testVerticalScrollFillImageDoesNotUseIntrinsicHeight() throws {
        let block = try JSONDecoder().decode(
            UIFlexContainerBlock.self,
            from: Data(
                """
                {
                  "id": "root",
                  "data": {
                    "direction": "COLUMN",
                    "frame": { "height": 0, "width": 390 },
                    "overflow": "SCROLL",
                    "children": [
                      {
                        "__typename": "UIFlexContainerBlock",
                        "id": "image-container",
                        "data": {
                          "direction": "COLUMN",
                          "frame": { "height": 0, "width": 0 },
                          "children": [{
                            "__typename": "UIImageBlock",
                            "id": "image",
                            "data": {
                              "contentMode": "FIT",
                              "frame": { "height": 0, "width": 0 }
                            }
                          }]
                        }
                      },
                      {
                        "__typename": "UIFlexContainerBlock",
                        "id": "copy-container",
                        "data": {
                          "direction": "COLUMN",
                          "frame": {
                            "height": 0,
                            "paddingBottom": 16,
                            "paddingLeft": 16,
                            "paddingRight": 16,
                            "paddingTop": 16,
                            "width": 0
                          },
                          "alignItems": "CENTER",
                          "justifyContent": "CENTER",
                          "gap": 16,
                          "overflow": "VISIBLE",
                          "children": [
                            {
                              "__typename": "UITextBlock",
                              "id": "title",
                              "data": { "size": 16, "value": "English test 1", "weight": "HEAVY" }
                            },
                            {
                              "__typename": "UITextBlock",
                              "id": "body",
                              "data": {
                                "size": 16,
                                "value": "ダウンロードありがとうございました！\\nおすすめ機能・お得な情報のご紹介です🙌"
                              }
                            },
                            {
                              "__typename": "UIFlexContainerBlock",
                              "id": "button",
                              "data": {
                                "direction": "ROW",
                                "justifyContent": "CENTER",
                                "frame": {
                                  "width": 0, "paddingLeft": 12, "paddingRight": 12,
                                  "paddingTop": 12, "paddingBottom": 12
                                },
                                "children": [{
                                  "__typename": "UITextBlock", "id": "button-label",
                                  "data": { "size": 16, "value": "Button", "weight": "BOLD" }
                                }]
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
                """.utf8
            )
        )
        let view = FlexOverflowView(
            block: block,
            context: UIBlockContext(UIBlockContextInit())
        )
        let content = try scrollContent(of: view)
        let imageContainer = try XCTUnwrap(content.subviews.first)
        let image = try XCTUnwrap(imageContainer.subviews.first)
        let uiImageView = try XCTUnwrap(image.subviews.first as? UIImageView)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 640, height: 620))
        uiImageView.image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 640, height: 620))
        }
        view.frame.size = CGSize(width: 390, height: 422)
        view.layoutSubviews()

        let copyContainer = try XCTUnwrap(content.subviews.dropFirst().first)
        XCTAssertEqual(content.frame.width, 390, accuracy: 0.01)
        XCTAssertEqual(content.frame.height, 422, accuracy: 0.01)
        XCTAssertGreaterThan(imageContainer.frame.height, 0)
        XCTAssertLessThan(imageContainer.frame.height, 422)
        XCTAssertEqual(image.frame.height, imageContainer.frame.height, accuracy: 0.01)
        XCTAssertEqual(uiImageView.frame, image.bounds)
        XCTAssertEqual(imageContainer.frame.height + copyContainer.frame.height, 422, accuracy: 0.01)
        XCTAssertEqual(view.contentSize, CGSize(width: 390, height: 422))

        // Loading/replacing the bitmap and resizing the viewport must not turn
        // its intrinsic dimensions into a flex basis on subsequent passes.
        uiImageView.image = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 900)).image { _ in }
        uiImageView.yoga.markDirty()
        view.frame.size.height = 600
        view.layoutSubviews()
        XCTAssertGreaterThan(imageContainer.frame.height, 0)
        XCTAssertLessThan(imageContainer.frame.height, 600)
        XCTAssertEqual(imageContainer.frame.height + copyContainer.frame.height, 600, accuracy: 0.01)
        XCTAssertEqual(uiImageView.frame, image.bounds)
        XCTAssertEqual(view.contentSize.height, 600, accuracy: 0.01)
    }

    @MainActor
    func testScrollFillSharesRemainingSpaceAfterFixedHugGapsAndPadding() throws {
        for direction in ["COLUMN", "ROW"] {
            let view = FlexOverflowView(
                block: try makeMixedScrollBlock(direction: direction),
                context: UIBlockContext(UIBlockContextInit())
            )
            let isColumn = direction == "COLUMN"
            let content = try scrollContent(of: view)
            func mainSize(_ view: UIView) -> CGFloat {
                isColumn ? view.frame.height : view.frame.width
            }
            func mainStart(_ view: UIView) -> CGFloat {
                let rect = view.convert(view.bounds, to: content.superview)
                return isColumn ? rect.minY : rect.minX
            }

            // 40 fixed + 60 hug + 3*8 gaps + 2*10 padding = 144.
            // Unpadded fill children share (240 - 144) / 2.
            for viewportSize: CGFloat in [240, 100, 300] {
                view.frame.size = CGSize(width: viewportSize, height: viewportSize)
                view.layoutSubviews()
                let expectedFillSize = max(0, viewportSize - 144) / 2
                XCTAssertEqual(mainSize(content.subviews[0]), 40, accuracy: 0.01, direction)
                XCTAssertEqual(mainSize(content.subviews[1]), 60, accuracy: 0.01, direction)
                XCTAssertEqual(mainSize(content.subviews[2]), expectedFillSize, accuracy: 0.01, direction)
                XCTAssertEqual(mainSize(content.subviews[3]), expectedFillSize, accuracy: 0.01, direction)
                XCTAssertEqual(mainStart(content.subviews[0]), 10, accuracy: 0.01, direction)
                XCTAssertEqual(mainSize(content), max(144, viewportSize), accuracy: 0.01, direction)
                XCTAssertEqual(
                    isColumn ? view.contentSize.height : view.contentSize.width,
                    max(144, viewportSize), accuracy: 0.01, direction
                )
            }
        }
    }

    @MainActor
    func testCappedHugAndSiblingOverflowRemainReachableWithCenterAndEndAlignment() throws {
        for direction in ["COLUMN", "ROW"] {
            for alignment in ["CENTER", "END"] {
                let view = FlexOverflowView(
                    block: try makeMixedScrollBlock(direction: direction, hugSize: 260, justify: alignment),
                    context: UIBlockContext(UIBlockContextInit())
                )
                let parent = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
                parent.configureLayout { $0.isEnabled = true }
                parent.addSubview(view)
                parent.yoga.applyLayout(preservingOrigin: true)
                view.layoutSubviews()
                let content = try scrollContent(of: view)
                let isColumn = direction == "COLUMN"
                // The hug child is capped at the viewport's 80-point content
                // box. Together with its sibling, gaps and padding, it still
                // overflows: 40 + 80 + 3*8 + 20 = 164.
                let hug = content.subviews[1]
                XCTAssertEqual(isColumn ? hug.frame.height : hug.frame.width, 80, accuracy: 0.01)
                for child in content.subviews {
                    XCTAssertEqual(child.yoga.maxWidth.unit, .percent)
                    XCTAssertEqual(child.yoga.maxWidth.value, 100)
                    XCTAssertEqual(child.yoga.maxHeight.unit, .percent)
                    XCTAssertEqual(child.yoga.maxHeight.value, 100)
                }
                XCTAssertEqual(isColumn ? content.frame.height : content.frame.width, 164, accuracy: 0.01)
                let first = content.subviews[0]
                let firstRect = first.convert(first.bounds, to: view)
                XCTAssertEqual(
                    isColumn ? firstRect.minY : firstRect.minX,
                    10, accuracy: 0.01
                )
                let point = CGPoint(x: firstRect.midX, y: firstRect.midY)
                XCTAssertTrue(view.hitTest(point, with: nil) === first)
                XCTAssertEqual(isColumn ? view.contentSize.height : view.contentSize.width, 164, accuracy: 0.01)

                // Reset the translated bounds on each layout, including when
                // the viewport grows enough that overflow disappears.
                for size: CGFloat in [100, 400, 100] {
                    parent.frame.size = CGSize(width: size, height: size)
                    parent.yoga.applyLayout(preservingOrigin: true)
                    view.layoutSubviews()
                    XCTAssertEqual(
                        isColumn ? hug.frame.height : hug.frame.width,
                        min(260, size - 20), accuracy: 0.01
                    )
                    XCTAssertEqual(
                        isColumn ? view.contentSize.height : view.contentSize.width,
                        size == 100 ? 164 : 400, accuracy: 0.01
                    )
                    if size == 400 {
                        XCTAssertEqual(content.bounds.origin, .zero)
                    }
                }
            }
        }
    }

    @MainActor
    func testScrollIncludesNestedVisibleFlexOverflow() throws {
        try assertNestedScrollExtent(overflow: "VISIBLE")
    }

    @MainActor
    func testScrollExcludesNestedHiddenFlexOverflow() throws {
        try assertNestedScrollExtent(overflow: "HIDDEN")
    }

    @MainActor
    func testScrollExcludesNestedScrollerContent() throws {
        try assertNestedScrollExtent(overflow: "SCROLL")
    }

    @MainActor
    private func assertNestedScrollExtent(overflow: String) throws {
        for direction in ["COLUMN", "ROW"] {
            let isColumn = direction == "COLUMN"
            let main = isColumn ? "height" : "width"
            let cross = isColumn ? "width" : "height"
            let json = """
            { "data": {
              "direction": "\(direction)", "overflow": "SCROLL", "justifyContent": "START",
              "frame": { "width": 0, "height": 0 },
              "children": [{ "__typename": "UIFlexContainerBlock", "data": {
                "direction": "\(direction)", "overflow": "\(overflow)", "justifyContent": "START",
                "frame": { "\(cross)": 0 },
                "children": [{ "__typename": "UIFlexContainerBlock", "data": {
                  "direction": "\(direction)", "overflow": "VISIBLE", "justifyContent": "START",
                  "frame": { "\(cross)": 0 },
                  "children": [
                    { "__typename": "UIFlexContainerBlock", "data": {
                      "frame": { "\(main)": 80, "\(cross)": 0 }
                    } },
                    { "__typename": "UIFlexContainerBlock", "data": {
                      "frame": { "\(main)": 80, "\(cross)": 0 }
                    } }
                  ]
                } }]
              } }]
            } }
            """
            let block = try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
            let view = FlexOverflowView(block: block, context: UIBlockContext(UIBlockContextInit()))
            let content = try scrollContent(of: view)
            let wrapper = try XCTUnwrap(content.subviews.first)
            for size: CGFloat in [100, 200, 100] {
                view.frame.size = CGSize(width: size, height: size)
                view.layoutSubviews()
                let expectedExtent = overflow == "VISIBLE" ? max(size, 160) : size
                XCTAssertEqual(
                    isColumn ? view.contentSize.height : view.contentSize.width,
                    expectedExtent, accuracy: 0.01, "\(direction), \(overflow), \(size)"
                )
                // Extending the scroll surface must preserve the child's cap.
                XCTAssertEqual(
                    isColumn ? wrapper.frame.height : wrapper.frame.width,
                    min(size, 160), accuracy: 0.01
                )
                XCTAssertEqual(wrapper.yoga.maxHeight.unit, .percent)
                XCTAssertEqual(wrapper.yoga.maxHeight.value, 100)
                XCTAssertEqual(wrapper.yoga.maxWidth.unit, .percent)
                XCTAssertEqual(wrapper.yoga.maxWidth.value, 100)
            }
        }
    }

    @MainActor
    func testScrollAllocationRespectsInsetsAndBorder() throws {
        var block = try makeMixedScrollBlock(direction: "COLUMN")
        block.data?.frame?.borderWidth = 2
        let view = FlexOverflowView(block: block, context: UIBlockContext(UIBlockContextInit()))
        view.frame.size = CGSize(width: 300, height: 300)
        view.setSafeAreaInsets(UIEdgeInsets(top: 20, left: 0, bottom: 36, right: 0))
        view.layoutSubviews()
        let content = try scrollContent(of: view)
        XCTAssertEqual(content.frame, CGRect(x: 2, y: 2, width: 296, height: 240))
        XCTAssertEqual(content.subviews[2].frame.height, 48, accuracy: 0.01)
        XCTAssertEqual(content.subviews[3].frame.height, 48, accuracy: 0.01)
        XCTAssertEqual(view.contentSize.height + view.contentInset.top + view.contentInset.bottom, 300)
    }

    @MainActor
    func testScrollHugMainAxisRemeasuresAfterContentChanges() throws {
        try assertScrollHugRemeasures(mainAxis: true)
    }

    @MainActor
    func testScrollHugCrossAxisRemeasuresAfterContentChanges() throws {
        try assertScrollHugRemeasures(mainAxis: false)
    }

    @MainActor
    private func assertScrollHugRemeasures(mainAxis: Bool) throws {
        for direction in ["COLUMN", "ROW"] {
            let hugHeight = (direction == "COLUMN") == mainAxis
            let parent = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
            parent.configureLayout { layout in
                layout.isEnabled = true
                layout.flexDirection = direction == "COLUMN" ? .column : .row
                layout.alignItems = .flexStart
            }
            let view = FlexOverflowView(
                block: try makeScrollBlock(
                    direction: direction,
                    width: hugHeight ? 100 : nil,
                    height: hugHeight ? nil : 100,
                    childWidth: 40, childHeight: 40
                ),
                context: UIBlockContext(UIBlockContextInit())
            )
            parent.addSubview(view)
            let content = try scrollContent(of: view)
            let child = try XCTUnwrap(content.subviews.first)
            let originalStyle = [
                content.yoga.width, content.yoga.height,
                content.yoga.maxWidth, content.yoga.maxHeight
            ]

            for size: Float in [40, 80, 20, 80] {
                let dimension = YGValue(value: size, unit: .point)
                if hugHeight {
                    child.yoga.height = dimension
                    child.yoga.minHeight = dimension
                } else {
                    child.yoga.width = dimension
                    child.yoga.minWidth = dimension
                }
                // Exercise parent measurement followed by the inner scroll
                // layout, not just a manually assigned scroll-view frame.
                parent.yoga.applyLayout(preservingOrigin: true)
                view.layoutSubviews()
                XCTAssertEqual(
                    hugHeight ? view.bounds.height : view.bounds.width,
                    CGFloat(size), accuracy: 0.01, "\(direction), size \(size)"
                )
                XCTAssertEqual(
                    hugHeight ? view.contentSize.height : view.contentSize.width,
                    CGFloat(size), accuracy: 0.01, "\(direction), size \(size)"
                )
                let currentStyle = [
                    content.yoga.width, content.yoga.height,
                    content.yoga.maxWidth, content.yoga.maxHeight
                ]
                for (original, current) in zip(originalStyle, currentStyle) {
                    XCTAssertEqual(current.unit, original.unit)
                    if original.value.isNaN {
                        XCTAssertTrue(current.value.isNaN)
                    } else {
                        XCTAssertEqual(current.value, original.value)
                    }
                }
            }
        }
    }

    private func makeMixedScrollBlock(
        direction: String, hugSize: Int = 60, justify: String = "CENTER"
    ) throws -> UIFlexContainerBlock {
        let main = direction == "COLUMN" ? "height" : "width"
        let cross = direction == "COLUMN" ? "width" : "height"
        let json = """
        {
          "data": {
            "direction": "\(direction)", "overflow": "SCROLL", "gap": 8,
            "justifyContent": "\(justify)",
            "frame": { "width": 0, "height": 0, "paddingTop": 10, "paddingBottom": 10,
                       "paddingLeft": 10, "paddingRight": 10 },
            "children": [
              { "__typename": "UIFlexContainerBlock", "data": {
                "frame": { "\(main)": 40, "\(cross)": 0 }
              } },
              { "__typename": "UIFlexContainerBlock", "data": {
                "direction": "\(direction)", "frame": { "\(cross)": 0 },
                "children": [{ "__typename": "UIFlexContainerBlock", "data": {
                  "frame": { "\(main)": \(hugSize), "\(cross)": 0 }
                } }]
              } },
              { "__typename": "UIFlexContainerBlock", "data": {
                "frame": { "width": 0, "height": 0 }
              } },
              { "__typename": "UIFlexContainerBlock", "data": {
                "frame": { "width": 0, "height": 0 }
              } }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
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

    @MainActor
    private func scrollContent(of view: FlexOverflowView) throws -> UIView {
        let content = view.subviews.first { $0 is FlexView }
        return try XCTUnwrap(content)
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
