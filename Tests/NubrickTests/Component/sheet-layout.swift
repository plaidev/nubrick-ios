import UIKit
import XCTest
import YogaKit
@testable import NubrickLocal

final class SheetLayoutTests: XCTestCase {
    @MainActor
    private func makePage(style: String = "DEPENDS_ON_CONTEXT_OR_PAGE_SHEET", fillImage: Bool = false, screenSize: String = "MEDIUM") throws -> PageView {
        var page = try JSONDecoder().decode(UIPageBlock.self, from: Data("""
        {
          "id": "sheet",
          "data": {
            "kind": "MODAL",
            "modalPresentationStyle": "\(style)",
            "modalScreenSize": "\(screenSize)",
            "modalRespectSafeArea": true,
            "renderAs": {
              "__typename": "UIFlexContainerBlock",
              "id": "content",
              "data": {
                "direction": "COLUMN",
                "frame": { "width": 0, "height": 0, "paddingTop": 7 },
                "children": [{
                  "__typename": "UIFlexContainerBlock",
                  "id": "child",
                  "data": { "frame": { "width": 0, "height": 40 } }
                }]
              }
            }
          }
        }
        """.utf8))
        if fillImage {
            // Match the reported text + fill image layout without a network dependency.
            page.data?.renderAs = try JSONDecoder().decode(UIBlock.self, from: Data("""
            {
              "__typename": "UIFlexContainerBlock",
              "id": "0.9a6553efbc283",
              "data": {
                "alignItems": "CENTER", "direction": "COLUMN",
                "justifyContent": "CENTER", "overflow": "HIDDEN", "gap": 16,
                "frame": { "height": 0, "width": 0, "paddingBottom": 16,
                  "paddingLeft": 16, "paddingRight": 16, "paddingTop": 16 },
                "children": [
                  { "__typename": "UITextBlock", "id": "0.7d63fcf929c198", "data": {
                    "lineHeight": 19.2, "size": 16, "weight": "REGULAR",
                    "value": "Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world Hello world" } },
                  { "__typename": "UIImageBlock", "id": "0.2c14c86294663", "data": {
                    "contentMode": "FIT", "frame": { "height": 0, "width": 0 } } }
                ]
              }
            }
            """.utf8))
        }
        let db = try XCTUnwrap(createNativebrikCoreDataHelper())
        let dependencies = NubrickDependencyContainer(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            actionHandler: { _, _ in },
            persistentContainerProvider: TestPersistentContainerProvider(db),
            httpRequestInterceptor: nil
        )
        return PageView(
            page: page, props: nil, container: dependencies.makeContainer(),
            arguments: nil, actionHandler: nil, modalViewController: nil
        )
    }

    @MainActor
    private func renderedContent(_ page: PageView) throws -> UIView {
        try XCTUnwrap(page.subviews.first?.subviews.first)
    }

    @MainActor
    private func contentRoot(_ page: PageView) throws -> UIViewBlock {
        try XCTUnwrap(page.subviews.first as? UIViewBlock)
    }

    @MainActor
    func testHeightStretchDoesNotResizeFillImageOrWriteThePageFrame() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800.456))
        let page = try makePage(fillImage: true)
        let controller = ModalPageViewController(pageView: page)
        window.addSubview(controller.view)
        page.frame = CGRect(x: 0, y: 0, width: 370.123, height: 360.456)
        page.layoutIfNeeded()
        XCTAssertTrue(controller.view === page)
        XCTAssertFalse(page.yoga.isEnabled)
        XCTAssertEqual(page.subviews.count, 1)
        let root = try contentRoot(page)
        XCTAssertTrue(root.yoga.isEnabled)
        let contentFrame = root.frame
        XCTAssertEqual(contentFrame.height, window.bounds.height / 2, accuracy: 1 / UIScreen.main.scale)
        let image = try XCTUnwrap(try renderedContent(page).subviews.last as? ImageView)
        let imageFrame = image.frame

        for step in 0..<200 {
            let liveSize = CGSize(width: 370.123, height: 360.456 + Double(step % 9))
            page.bounds.size = liveSize
            page.layoutIfNeeded()
            XCTAssertEqual(page.bounds.size, liveSize)
            XCTAssertEqual(root.frame, contentFrame)
            XCTAssertEqual(image.frame, imageFrame)
        }

        page.renderView()
        page.layoutIfNeeded()
        XCTAssertFalse(try contentRoot(page) === root)
        XCTAssertEqual(try contentRoot(page).frame, contentFrame)
        XCTAssertEqual(try XCTUnwrap(try renderedContent(page).subviews.last as? ImageView).frame, imageFrame)
    }

    @MainActor
    func testFixedHeightStillAllowsContentAndWindowSizeChanges() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let page = try makePage()
        window.addSubview(page)
        page.frame = CGRect(x: 0, y: 0, width: 320, height: 360)
        page.layoutIfNeeded()
        let child = try XCTUnwrap(try renderedContent(page).subviews.first)
        child.yoga.height = YGValue(value: 80, unit: .point)
        page.setNeedsLayout()
        page.layoutIfNeeded()
        XCTAssertEqual(child.bounds.height, 80)
        XCTAssertEqual(try contentRoot(page).bounds.size, CGSize(width: 320, height: 400))

        window.bounds.size = CGSize(width: 800, height: 400)
        page.frame = CGRect(x: 0, y: 0, width: 600, height: 180)
        page.layoutIfNeeded()
        XCTAssertEqual(try contentRoot(page).bounds.size, CGSize(width: 600, height: 200))
    }

    @MainActor
    func testLargeSheetUsesResolvedHeightInsteadOfWindowApproximation() throws {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 400, height: 800))
        let page = try makePage(screenSize: "LARGE")
        page.sheetContentHeight = 734
        window.addSubview(page)
        for height in [700.0, 710.0, 695.0] {
            page.frame = CGRect(x: 0, y: 0, width: 370, height: height)
            page.layoutIfNeeded()
            XCTAssertEqual(try contentRoot(page).bounds.height, 734)
            XCTAssertEqual(page.bounds.height, height)
        }
    }

    @MainActor
    func testResolvedHeightReachesPushedAndPreviousPages() throws {
        guard #available(iOS 16.0, *) else { return }
        let page = try makePage()
        let navigation = NavigationViewControlller(
            rootViewController: ModalPageViewController(pageView: page), hasPrevious: true
        )
        navigation.modalPresentationStyle = .pageSheet
        navigation.configureSheet(size: .MEDIUM_AND_LARGE) { 852 }
        let detent = try XCTUnwrap(navigation.sheetPresentationController?.detents.last)
        _ = detent.resolvedValue(in: SheetDetentContext(maximum: 750))
        let next = try makePage()
        navigation.pushViewController(ModalPageViewController(pageView: next), animated: false)
        XCTAssertEqual(page.sheetContentHeight, 750)
        XCTAssertEqual(next.sheetContentHeight, 750)
        _ = detent.resolvedValue(in: SheetDetentContext(maximum: 350))
        XCTAssertEqual(page.sheetContentHeight, 350)
        XCTAssertEqual(next.sheetContentHeight, 350)
        _ = navigation.popViewController(animated: false)
        XCTAssertEqual(page.sheetContentHeight, 350)
    }

    @MainActor
    func testSheetPageBackgroundFollowsReusedNavigationPresentation() throws {
        let first = try makePage(style: "DEPENDS_ON_CONTEXT_OR_FULL_SCREEN")
        let navigation = NavigationViewControlller(
            rootViewController: ModalPageViewController(pageView: first), hasPrevious: true
        )
        navigation.modalPresentationStyle = .overFullScreen
        let next = try makePage()
        let nextController = ModalPageViewController(pageView: next)
        navigation.pushViewController(nextController, animated: false)
        navigation.updateSheetBackground(for: nextController)
        XCTAssertEqual(navigation.view.backgroundColor, .systemBackground)
        XCTAssertEqual(navigation.modalPresentationStyle, .overFullScreen)
        if #available(iOS 26.0, *) { XCTAssertNil(next.backgroundColor) }

        navigation.modalPresentationStyle = .pageSheet
        navigation.updateSheetBackground(for: nextController)
        XCTAssertEqual(navigation.view.backgroundColor, next.backgroundColor)
        next.backgroundColor = .blue
        navigation.updateSheetBackground(for: nextController)
        XCTAssertEqual(navigation.view.backgroundColor, .blue)
    }

    @MainActor
    func testFullScreenPageKeepsNormalLayout() throws {
        let page = try makePage(style: "DEPENDS_ON_CONTEXT_OR_FULL_SCREEN")
        XCTAssertTrue(page.yoga.isEnabled)
        for size in [CGSize(width: 320, height: 400), CGSize(width: 400, height: 700)] {
            page.frame = CGRect(origin: .zero, size: size)
            page.layoutIfNeeded()
            XCTAssertEqual(try renderedContent(page).bounds.size, size)
        }
    }
}
