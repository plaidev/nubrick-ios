//
//  navigation.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/04/24.
//

import Foundation
import UIKit

class NavigationViewControlller: UINavigationController {
    var onDismissed: ((NavigationViewControlller) -> Void)?
    var suppressBackAction = false
    fileprivate var duringPushAnimation = false
    fileprivate var willDismiss = false
    private var sheetContentHeight: CGFloat?
    private var sheetWindowSize: CGSize?
    private var sheetBottomInset: CGFloat = 0

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        guard isBeingDismissed || presentingViewController == nil else { return }
        let callback = onDismissed
        onDismissed = nil
        callback?(self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.updateSheetGeometry()
        self.parent?.viewDidLayoutSubviews()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        self.updateSheetGeometry()
    }

    func configureSheet(size: ModalScreenSize?, windowHeight: @escaping () -> CGFloat?) {
        self.sheetPresentationController?.detents = parseModalScreenSize(
            size, windowHeight: windowHeight,
            bottomInset: { [weak self] in self?.viewIfLoaded?.safeAreaInsets.bottom ?? 0 },
            onContentHeight: { [weak self] height in
                guard let self, self.sheetContentHeight != height else { return }
                self.sheetContentHeight = height
                for case let page as ModalPageViewController in self.viewControllers {
                    page.representedPageView?.sheetContentHeight = height
                }
            }
        )
    }

    private func updateSheetGeometry() {
        guard #available(iOS 16.0, *), let window = self.viewIfLoaded?.window,
              self.sheetContentHeight != nil else { return }
        let bottomInset = self.view.safeAreaInsets.bottom
        guard self.sheetWindowSize != window.bounds.size || self.sheetBottomInset != bottomInset else { return }
        self.sheetWindowSize = window.bounds.size
        self.sheetBottomInset = bottomInset
        self.sheetPresentationController?.invalidateDetents()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            if #available(iOS 16.0, *) {
                // The half-height detent depends on the window's new size.
                self?.sheetPresentationController?.invalidateDetents()
            }
        }
    }

    func updateSheetBackground(for viewController: UIViewController) {
        // Pushed pages inherit this controller's presentation style.
        let fallback: UIColor? = self.modalPresentationStyle == .overFullScreen ? .systemBackground : nil
        self.view.backgroundColor = viewController.view.backgroundColor ?? fallback
    }

    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        duringPushAnimation = true
        (viewController as? ModalPageViewController)?.representedPageView?.sheetContentHeight = self.sheetContentHeight

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

    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        guard let swipeNavigationController = navigationController as? NavigationViewControlller else { return }

        swipeNavigationController.updateSheetBackground(for: viewController)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        guard let swipeNavigationController = navigationController as? NavigationViewControlller else { return }

        swipeNavigationController.duringPushAnimation = false
        swipeNavigationController.updateSheetBackground(for: viewController)
        if let pageController = viewController as? ModalPageViewController,
           let pageView = pageController.representedPageView {
            pageController.onVisiblePageChanged?(pageView)
        }
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
