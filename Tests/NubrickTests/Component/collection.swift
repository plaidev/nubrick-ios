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
        kind: String, direction: String, fullItemWidth: Bool, fullItemHeight: Bool = false
    ) throws
        -> UICollectionBlock
    {
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
              "width": \(direction == "COLUMN" ? 270 : 0),
              "height": \(direction == "COLUMN" ? 0 : 216),
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
        }
        """
        return try JSONDecoder().decode(UICollectionBlock.self, from: Data(json.utf8))
    }
}
