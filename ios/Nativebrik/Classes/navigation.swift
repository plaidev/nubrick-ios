//
//  navigation.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/04/24.
//

import Foundation
import UIKit

class NavigationViewControlller: UINavigationController {
    fileprivate var duringPushAnimation = false
    fileprivate var willDismiss = false

    init(rootViewController: UIViewController, hasPrevious: Bool) {
        if hasPrevious {
            self.willDismiss = true
        }
        super.init(rootViewController: rootViewController)
        delegate = self
    }

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)

        delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        delegate = self
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.configureLayout { layout in
            layout.isEnabled = true

            layout.display = .flex
            layout.alignItems = .center
            layout.justifyContent = .center
        }
        self.interactivePopGestureRecognizer?.delegate = self
        self.interactivePopGestureRecognizer?.isEnabled = true
    }

    deinit {
        delegate = nil
        interactivePopGestureRecognizer?.delegate = nil
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.parent?.viewDidLayoutSubviews()
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        duringPushAnimation = true

        super.pushViewController(viewController, animated: animated)
    }

    override func popViewController(animated: Bool) -> UIViewController? {
        if (self.children.count <= 1 && self.willDismiss) {
            self.dismiss(animated: true)
        }
        return super.popViewController(animated: animated)
    }

    override func popToViewController(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        if (self.children.count <= 1 && self.willDismiss) {
            self.dismiss(animated: true)
        }
        return super.popToViewController(viewController, animated: animated)
    }

    override func popToRootViewController(animated: Bool) -> [UIViewController]? {
        if (self.children.count <= 1 && self.willDismiss) {
            self.dismiss(animated: true)
        }
        return super.popToRootViewController(animated: animated)
    }
}

extension NavigationViewControlller: UINavigationControllerDelegate {

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard let swipeNavigationController = navigationController as? NavigationViewControlller else { return }

        swipeNavigationController.duringPushAnimation = false
    }

}

extension NavigationViewControlller: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == interactivePopGestureRecognizer else {
            return true
        }
        return viewControllers.count > 1 && duringPushAnimation == false
    }
}
