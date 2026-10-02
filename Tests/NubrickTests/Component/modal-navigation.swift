import UIKit
import XCTest
@testable import NubrickLocal

final class ModalNavigationTests: XCTestCase {
    @MainActor
    private func pageController(title: String = "Back", visible: Bool = true) throws -> ModalPageViewController {
        let page = try JSONDecoder().decode(UIPageBlock.self, from: Data("""
        {"id":"second","data":{"kind":"MODAL","modalNavigationBackButton":{"title":"\(title)","visible":\(visible)}}}
        """.utf8))
        let container = NubrickDependencyContainer(
            config: Config(projectId: PROJECT_ID_FOR_TEST), user: NubrickUser(),
            actionHandler: { _, _ in }, persistentContainerProvider: LazyPersistentContainerProvider(),
            httpRequestInterceptor: nil
        ).makeContainer()
        return ModalPageViewController(pageView: PageView(
            page: page, props: nil, container: container, arguments: nil,
            actionHandler: nil, modalViewController: nil
        ))
    }

    @MainActor
    private func backActionHandler(onAction: @escaping (UIBlockAction) -> Void) throws -> ModalBackButtonActionHandler {
        let container = NubrickDependencyContainer(
            config: Config(projectId: PROJECT_ID_FOR_TEST), user: NubrickUser(),
            actionHandler: { _, _ in }, persistentContainerProvider: LazyPersistentContainerProvider(),
            httpRequestInterceptor: nil
        ).makeContainer()
        let action = try JSONDecoder().decode(UIBlockAction.self, from: Data("""
        {"eventName":"back-clicked","destinationPageId":"third"}
        """.utf8))
        return try XCTUnwrap(makeBackButtonAction(event: action, context: UIBlockContext(
            UIBlockContextInit(container: container, actionHandler: { action, _ in onAction(action) })
        )))
    }

    @MainActor
    func testConfiguredBackButtonDispatchesActionInsteadOfPopping() throws {
        let first = UIViewController()
        let navigation = NavigationViewControlller(rootViewController: first, hasPrevious: true)
        let second = try pageController(title: "Continue")
        var received: [UIBlockAction] = []
        second.backButtonActionHandler = try backActionHandler { received.append($0) }
        navigation.pushViewController(second, animated: false)
        second.loadViewIfNeeded()

        let button = try XCTUnwrap(second.navigationItem.leftBarButtonItem)
        XCTAssertEqual(button.title, "Continue")
        let action = try XCTUnwrap(button.action)
        let target = try XCTUnwrap(button.target as? NSObject)
        XCTAssertTrue(target === second)
        XCTAssertTrue(target.responds(to: action))
        _ = target.perform(action)
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.eventName, "back-clicked")
        XCTAssertEqual(received.first?.destinationPageId, "third")
        XCTAssertTrue(navigation.topViewController === second)
    }

    @MainActor
    func testUnconfiguredBackStillPopsNormally() throws {
        let first = UIViewController()
        let navigation = NavigationViewControlller(rootViewController: first, hasPrevious: true)
        let second = try pageController()
        second.backButtonActionHandler = makeBackButtonAction(
            event: nil, context: UIBlockContext(UIBlockContextInit())
        )
        XCTAssertNil(second.backButtonActionHandler)
        navigation.pushViewController(second, animated: false)
        second.loadViewIfNeeded()
        XCTAssertNil(second.navigationItem.leftBarButtonItem)
        second.onClickBack()
        XCTAssertTrue(navigation.topViewController === first)
    }

    @MainActor
    func testBackActionReadsVariablesWhenInvoked() throws {
        var variableReads = 0
        var readsAtDispatch = [Int]()
        let action = try JSONDecoder().decode(UIBlockAction.self, from: Data("{}".utf8))
        let handler = try XCTUnwrap(makeBackButtonAction(
            event: action,
            context: UIBlockContext(UIBlockContextInit(actionHandler: { _, _ in
                readsAtDispatch.append(variableReads)
            })),
            variableProvider: { variableReads += 1; return nil }
        ))
        XCTAssertEqual(variableReads, 0)
        handler()
        handler()
        XCTAssertEqual(readsAtDispatch, [1, 2])
    }

    @MainActor
    func testHiddenBackButtonStaysHiddenWithAnAction() throws {
        let second = try pageController(visible: false)
        second.backButtonActionHandler = try backActionHandler { _ in XCTFail("Unexpected back action") }
        second.loadViewIfNeeded()
        XCTAssertTrue(second.navigationItem.hidesBackButton)
        XCTAssertNil(second.navigationItem.leftBarButtonItem)
    }
}
