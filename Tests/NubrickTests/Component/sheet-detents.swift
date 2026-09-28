import UIKit
import XCTest
@testable import NubrickLocal

@available(iOS 16.0, *)
@MainActor
private final class SheetDetentContext: NSObject, UISheetPresentationControllerDetentResolutionContext {
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
        let detent = try XCTUnwrap(parseModalScreenSize(.MEDIUM, windowHeight: { 852 }).first)
        let context = SheetDetentContext(maximum: 749.3333333)
        XCTAssertEqual(detent.resolvedValue(in: context), 426)
    }

    @MainActor
    func testMediumResolvesAgainWhenWindowSizeChanges() throws {
        guard #available(iOS 16.0, *) else { return }
        var windowHeight: CGFloat = 852
        let detent = try XCTUnwrap(parseModalScreenSize(.MEDIUM, windowHeight: { windowHeight }).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 750)), 426)
        windowHeight = 393
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 350)), 196.5)
    }

    @MainActor
    func testMediumIsLimitedToTheAvailablePresentationHeight() throws {
        guard #available(iOS 16.0, *) else { return }
        let detent = try XCTUnwrap(parseModalScreenSize(.MEDIUM, windowHeight: { 852 }).first)
        XCTAssertEqual(detent.resolvedValue(in: SheetDetentContext(maximum: 300)), 300)
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
        let detents = parseModalScreenSize(.MEDIUM_AND_LARGE, windowHeight: { 852 })
        let context = SheetDetentContext(maximum: 750)
        XCTAssertEqual(detents.count, 2)
        XCTAssertEqual(detents[0].resolvedValue(in: context), 426)
        XCTAssertEqual(detents[1].resolvedValue(in: context), 750)
    }
}
