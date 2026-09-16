import UIKit
import XCTest
@testable import NubrickLocal
import YogaKit

final class CollectionViewTests: XCTestCase {
    @MainActor
    func testHorizontalGridFillsWidthAndUsesItsGridHeight() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "GRID", direction: "ROW", fullItemWidth: false),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertTrue(view.yoga.isLeaf)
        XCTAssertEqual(view.yoga.width.unit, .percent)
        XCTAssertEqual(view.yoga.width.value, 100)
        XCTAssertEqual(view.yoga.height.unit, .point)
        XCTAssertEqual(view.yoga.height.value, 216)
    }

    @MainActor
    func testVerticalGridFillsHeightAndUsesItsGridWidth() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "GRID", direction: "COLUMN", fullItemWidth: false),
            context: UIBlockContext(UIBlockContextInit())
        )

        XCTAssertEqual(view.yoga.width.unit, .point)
        XCTAssertEqual(view.yoga.width.value, 270)
        XCTAssertEqual(view.yoga.height.unit, .percent)
        XCTAssertEqual(view.yoga.height.value, 100)
    }

    @MainActor
    func testHorizontalGridSharesRemainingSpaceInRowParent() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "GRID", direction: "ROW", fullItemWidth: false),
            context: UIBlockContext(UIBlockContextInit(parentDirection: .ROW))
        )

        XCTAssertTrue(view.yoga.width.value.isNaN)
        XCTAssertEqual(view.yoga.flexGrow, 1)
        XCTAssertEqual(view.yoga.flexBasis.value, 0)
    }

    @MainActor
    func testVerticalGridSharesRemainingSpaceInColumnParent() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "GRID", direction: "COLUMN", fullItemWidth: false),
            context: UIBlockContext(UIBlockContextInit(parentDirection: .COLUMN))
        )

        XCTAssertTrue(view.yoga.height.value.isNaN)
        XCTAssertEqual(view.yoga.flexGrow, 1)
        XCTAssertEqual(view.yoga.flexBasis.value, 0)
    }

    @MainActor
    func testHorizontalGridHugsInRowParentWhenWidthIsNull() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(
                kind: "GRID", direction: "ROW", fullItemWidth: false, mainAxisFrame: nil
            ),
            context: UIBlockContext(UIBlockContextInit(parentDirection: .ROW))
        )

        XCTAssertTrue(view.yoga.width.value.isNaN)
        XCTAssertEqual(view.yoga.flexGrow, 0)
    }

    @MainActor
    func testVerticalGridHugsInColumnParentWhenHeightIsNull() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(
                kind: "GRID", direction: "COLUMN", fullItemWidth: false, mainAxisFrame: nil
            ),
            context: UIBlockContext(UIBlockContextInit(parentDirection: .COLUMN))
        )

        XCTAssertTrue(view.yoga.height.value.isNaN)
        XCTAssertEqual(view.yoga.flexGrow, 0)
    }

    @MainActor
    func testHorizontalGridHugsToContentWidthInRowParentAfterLayout() throws {
        let row = FlexView(
            block: try makeRowWithCollectionBlock(direction: "ROW", mainAxisFrame: nil),
            context: UIBlockContext(UIBlockContextInit())
        )
        row.frame.size = CGSize(width: 300, height: 300)
        row.yoga.applyLayout(preservingOrigin: true)

        let collection = try XCTUnwrap(row.subviews.first as? CollectionView)
        let fixedSibling = try XCTUnwrap(row.subviews.last)

        XCTAssertEqual(collection.frame.width, 90, accuracy: 0.01)
        XCTAssertEqual(collection.frame.height, 216, accuracy: 0.01)
        XCTAssertEqual(fixedSibling.frame.width, 100, accuracy: 0.01)
        XCTAssertLessThan(collection.frame.width + fixedSibling.frame.width, row.frame.width)
    }

    @MainActor
    func testVerticalGridHugsToContentHeightInColumnParentAfterLayout() throws {
        let column = FlexView(
            block: try makeColumnWithCollectionBlock(direction: "COLUMN", mainAxisFrame: nil),
            context: UIBlockContext(UIBlockContextInit())
        )
        column.frame.size = CGSize(width: 300, height: 300)
        column.yoga.applyLayout(preservingOrigin: true)

        let collection = try XCTUnwrap(column.subviews.first as? CollectionView)
        let fixedSibling = try XCTUnwrap(column.subviews.last)

        XCTAssertEqual(collection.frame.width, 270, accuracy: 0.01)
        XCTAssertEqual(collection.frame.height, 66, accuracy: 0.01)
        XCTAssertEqual(fixedSibling.frame.height, 100, accuracy: 0.01)
        XCTAssertLessThan(collection.frame.height + fixedSibling.frame.height, column.frame.height)
    }

    @MainActor
    func testVerticalCollectionCellUsesWrapperRowLayoutAndCellBounds() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(
                kind: "GRID", direction: "COLUMN", fullItemWidth: false, childWidth: 0
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let indexPath = IndexPath(item: 0, section: 0)
        let cell = try XCTUnwrap(
            view.collectionView(collection, cellForItemAt: indexPath) as? CollectionViewCell
        )
        cell.frame = CGRect(x: 0, y: 0, width: 200, height: 80)
        cell.layoutIfNeeded()

        let wrapper = try XCTUnwrap(cell.contentView.subviews.first as? UIViewBlock)
        let renderedChild = try XCTUnwrap(wrapper.subviews.first)

        XCTAssertEqual(wrapper.frame, cell.contentView.bounds)
        XCTAssertTrue(renderedChild.yoga.width.value.isNaN)
        XCTAssertEqual(renderedChild.yoga.flexGrow, 1)
        XCTAssertEqual(renderedChild.yoga.flexBasis.value, 0)
    }

    @MainActor
    func testUIKitViewportFollowsParentResolvedBoundsAndFullItemWidth() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "CAROUSEL", direction: "ROW", fullItemWidth: true),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)

        XCTAssertEqual(collection.frame, view.bounds)
        XCTAssertFalse(collection.yoga.isEnabled)
        XCTAssertEqual(layout.itemSize, CGSize(width: 280, height: 40))
    }

    @MainActor
    func testCarouselPagingUsesResolvedItemSizeRatherThanFlowLayoutDefault() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "CAROUSEL", direction: "ROW", fullItemWidth: true),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        collection.reloadData()
        collection.layoutIfNeeded()
        let layout = try XCTUnwrap(collection.collectionViewLayout as? CarouselLayout)

        let target = layout.targetContentOffset(
            forProposedContentOffset: CGPoint(x: 300, y: 0), withScrollingVelocity: .zero
        )

        XCTAssertEqual(target.x, 290)
    }

    @MainActor
    func testVerticalFullHeightCarouselFillsItemHeightOnly() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(
                kind: "CAROUSEL", direction: "COLUMN", fullItemWidth: false, fullItemHeight: true
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 270, height: 320)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)

        XCTAssertEqual(layout.itemSize, CGSize(width: 50, height: 294))
    }

    @MainActor
    func testVerticalCarouselIgnoresFullItemWidth() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "CAROUSEL", direction: "COLUMN", fullItemWidth: true),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 270, height: 320)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)

        XCTAssertEqual(layout.itemSize, CGSize(width: 50, height: 40))
    }

    @MainActor
    func testHorizontalCarouselIgnoresFullItemHeight() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(
                kind: "CAROUSEL", direction: "ROW", fullItemWidth: false, fullItemHeight: true
            ),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 216)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)

        XCTAssertEqual(layout.itemSize, CGSize(width: 50, height: 40))
    }

    @MainActor
    func testGridDoesNotApplyCarouselFullItemSetting() throws {
        let view = CollectionView(
            block: try makeCollectionBlock(kind: "GRID", direction: "ROW", fullItemWidth: true),
            context: UIBlockContext(UIBlockContextInit())
        )
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 216)
        view.layoutIfNeeded()

        let collection = try XCTUnwrap(view.subviews.first as? UICollectionView)
        let layout = try XCTUnwrap(collection.collectionViewLayout as? UICollectionViewFlowLayout)

        XCTAssertEqual(layout.itemSize, CGSize(width: 50, height: 40))
    }

    private func makeCollectionBlock(
        kind: String, direction: String, fullItemWidth: Bool, fullItemHeight: Bool = false,
        childWidth: Int = 50, mainAxisFrame: Int? = 0
    ) throws
        -> UICollectionBlock
    {
        let mainAxisSize = mainAxisFrame.map { String($0) } ?? "null"
        let json = """
        {
          "id": "collection",
          "data": {
            "kind": "\(kind)",
            "direction": "\(direction)",
            "gridSize": 4,
            "gap": 10,
            "itemWidth": 50,
            "itemHeight": 40,
            "fullItemWidth": \(fullItemWidth),
            "fullItemHeight": \(fullItemHeight),
            "frame": {
              "width": \(direction == "COLUMN" ? "270" : mainAxisSize),
              "height": \(direction == "COLUMN" ? mainAxisSize : "216"),
              "paddingLeft": 16,
              "paddingRight": 24,
              "paddingTop": 8,
              "paddingBottom": 18
            },
            "children": [
              {
                "__typename": "UIFlexContainerBlock",
                "id": "one",
                "data": { "frame": { "width": \(childWidth), "height": 40 } }
              },
              {
                "__typename": "UIFlexContainerBlock",
                "id": "two",
                "data": { "frame": { "width": \(childWidth), "height": 40 } }
              }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UICollectionBlock.self, from: Data(json.utf8))
    }

    private func makeRowWithCollectionBlock(direction: String, mainAxisFrame: Int?) throws
        -> UIFlexContainerBlock
    {
        let mainAxisSize = mainAxisFrame.map { String($0) } ?? "null"
        let json = """
        {
          "id": "row",
          "data": {
            "direction": "ROW",
            "frame": { "width": 300 },
            "children": [
              {
                "__typename": "UICollectionBlock",
                "id": "collection",
                "data": {
                  "kind": "GRID",
                  "direction": "\(direction)",
                  "gridSize": 4,
                  "gap": 10,
                  "itemWidth": 50,
                  "itemHeight": 40,
                  "fullItemWidth": false,
                  "fullItemHeight": false,
                  "frame": {
                    "width": \(direction == "COLUMN" ? "270" : mainAxisSize),
                    "height": \(direction == "COLUMN" ? mainAxisSize : "216"),
                    "paddingLeft": 16,
                    "paddingRight": 24,
                    "paddingTop": 8,
                    "paddingBottom": 18
                  },
                  "children": [
                    {
                      "__typename": "UIFlexContainerBlock",
                      "id": "one",
                      "data": { "frame": { "width": 50, "height": 40 } }
                    },
                    {
                      "__typename": "UIFlexContainerBlock",
                      "id": "two",
                      "data": { "frame": { "width": 50, "height": 40 } }
                    }
                  ]
                }
              },
              {
                "__typename": "UIFlexContainerBlock",
                "id": "fixed",
                "data": { "frame": { "width": 100, "height": 50 } }
              }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }

    private func makeColumnWithCollectionBlock(direction: String, mainAxisFrame: Int?) throws
        -> UIFlexContainerBlock
    {
        let mainAxisSize = mainAxisFrame.map { String($0) } ?? "null"
        let json = """
        {
          "id": "column",
          "data": {
            "direction": "COLUMN",
            "frame": { "height": 300 },
            "children": [
              {
                "__typename": "UICollectionBlock",
                "id": "collection",
                "data": {
                  "kind": "GRID",
                  "direction": "\(direction)",
                  "gridSize": 4,
                  "gap": 10,
                  "itemWidth": 50,
                  "itemHeight": 40,
                  "fullItemWidth": false,
                  "fullItemHeight": false,
                  "frame": {
                    "width": \(direction == "COLUMN" ? "270" : mainAxisSize),
                    "height": \(direction == "COLUMN" ? mainAxisSize : "216"),
                    "paddingLeft": 16,
                    "paddingRight": 24,
                    "paddingTop": 8,
                    "paddingBottom": 18
                  },
                  "children": [
                    {
                      "__typename": "UIFlexContainerBlock",
                      "id": "one",
                      "data": { "frame": { "width": 50, "height": 40 } }
                    },
                    {
                      "__typename": "UIFlexContainerBlock",
                      "id": "two",
                      "data": { "frame": { "width": 50, "height": 40 } }
                    }
                  ]
                }
              },
              {
                "__typename": "UIFlexContainerBlock",
                "id": "fixed",
                "data": { "frame": { "width": 50, "height": 100 } }
              }
            ]
          }
        }
        """
        return try JSONDecoder().decode(UIFlexContainerBlock.self, from: Data(json.utf8))
    }
}
