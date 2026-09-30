import UIKit
import XCTest
@testable import NubrickLocal

@available(iOS 16.0, *)
@MainActor
final class SheetDetentContext: NSObject, UISheetPresentationControllerDetentResolutionContext {
    let maximumDetentValue: CGFloat
    let containerTraitCollection = UITraitCollection()

    init(maximum: CGFloat) {
        maximumDetentValue = maximum
    }
}

final class SheetDetentTests: XCTestCase {
    @MainActor
    func testMediumUsesHalfWindowHeightInsteadOfHalfAvailableDetentHeight() throws {
        guard #available(iOS 16.0, *) else { return }
        var contentHeight: CGFloat = 0
        let detent = try XCTUnwrap(parseModalScreenSize(
            .MEDIUM, windowHeight: { 852 }, bottomInset: { 34 },
            onContentHeight: { contentHeight = $0 }
        ).first)
        let context = SheetDetentContext(maximum: 749.3333333)
        XCTAssertEqual(detent.resolvedValue(in: context), 392)
        XCTAssertEqual(contentHeight, 426)
    }

    @MainActor
    func testMediumResolvesAgainWhenWindowSizeChanges() throws {
        guard #available(iOS 16.0, *) else { return }
        var windowHeight: CGFloat = 852
        var bottomInset: CGFloat = 34
        var contentHeight: CGFloat = 0
        let detent = try XCTUnwrap(parseModalScreenSize(
            .MEDIUM, windowHeight: { windowHeight }, bottomInset: { bottomInset },
            onContentHeight: { contentHeight = $0 }
        ).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 750)), 392)
        XCTAssertEqual(contentHeight, 426)
        windowHeight = 393
        bottomInset = 0
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 350)), 196.5)
        XCTAssertEqual(contentHeight, 196.5)
        bottomInset = 21
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 350)), 175.5)
        XCTAssertEqual(contentHeight, 196.5)
    }

    @MainActor
    func testMediumIsLimitedToTheAvailablePresentationHeight() throws {
        guard #available(iOS 16.0, *) else { return }
        var contentHeight: CGFloat = 0
        let detent = try XCTUnwrap(parseModalScreenSize(
            .MEDIUM, windowHeight: { 852 }, bottomInset: { 34 },
            onContentHeight: { contentHeight = $0 }
        ).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 300)), 300)
        XCTAssertEqual(contentHeight, 334)
    }

    @MainActor
    func testMediumCannotResolveToANegativeHeight() throws {
        guard #available(iOS 16.0, *) else { return }
        let detent = try XCTUnwrap(parseModalScreenSize(
            .MEDIUM, windowHeight: { 40 }, bottomInset: { 34 }
        ).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 300)), 0)
    }

    @MainActor
    func testMissingWindowFallsBackToAvailableHeight() throws {
        guard #available(iOS 16.0, *) else { return }
        let detent = try XCTUnwrap(parseModalScreenSize(.MEDIUM).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 750)), 375)
    }

    @MainActor
    func testResizableSheetUsesSameMediumDetentAndKeepsLargeDetent() throws {
        guard #available(iOS 16.0, *) else { return }
        let context = SheetDetentContext(maximum: 750)
        for size in [ModalScreenSize.LARGE, .MEDIUM_AND_LARGE] {
            var heights: [CGFloat] = []
            let detents = parseModalScreenSize(
                size, windowHeight: { 852 }, bottomInset: { 34 },
                onContentHeight: { heights.append($0) }
            )
            XCTAssertEqual(detents.last?.resolvedValue(in: context), 750)
            XCTAssertEqual(heights, [784])
            if size == .MEDIUM_AND_LARGE {
                XCTAssertEqual(detents.first?.resolvedValue(in: context), 392)
                XCTAssertEqual(heights, [784], "The medium detent must not shrink resizable content")
            }
        }
    }
}
