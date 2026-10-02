import UIKit
import XCTest
@testable import NubrickLocal

final class ModalNavigationReuseTests: XCTestCase {
    @MainActor
    func testNavigationControllerPresentedByWindowTopIsReused() async throws {
        let animationsWereEnabled = UIView.areAnimationsEnabled
        UIView.setAnimationsEnabled(false)
        defer { UIView.setAnimationsEnabled(animationsWereEnabled) }

        let host = UIViewController()
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        let component = ModalComponentViewController()
        host.addChild(component)
        host.view.addSubview(component.view)
        component.didMove(toParent: host)
        let firstPage = try JSONDecoder().decode(UIPageBlock.self, from: Data("""
        {"id":"first","data":{"kind":"MODAL"}}
        """.utf8))
        let secondPage = try JSONDecoder().decode(UIPageBlock.self, from: Data("""
        {"id":"second","data":{"kind":"MODAL"}}
        """.utf8))
        let container = NubrickDependencyContainer(
            config: Config(projectId: PROJECT_ID_FOR_TEST), user: NubrickUser(),
            actionHandler: { _, _ in }, persistentContainerProvider: LazyPersistentContainerProvider(),
            httpRequestInterceptor: nil
        ).makeContainer()
        let firstPageView = PageView(page: firstPage, props: nil, container: container,
                                     arguments: nil, actionHandler: nil, modalViewController: component)
        component.presentNavigation(pageView: firstPageView, modalPresentationStyle: nil,
                                    modalScreenSize: nil, backButtonActionHandler: nil)
        try await Task.sleep(nanoseconds: 800_000_000)
        let navigation = try XCTUnwrap(host.presentedViewController as? NavigationViewControlller)

        let secondPageView = PageView(page: secondPage, props: nil, container: container,
                                      arguments: nil, actionHandler: nil, modalViewController: component)
        component.presentNavigation(pageView: secondPageView, modalPresentationStyle: nil,
                                    modalScreenSize: nil, backButtonActionHandler: nil)

        XCTAssertEqual(navigation.viewControllers.count, 2)
    }
}
