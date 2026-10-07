//
//  component.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import SwiftUI
import SafariServices

/// How a WEBVIEW_MODAL URL should be handled.
///
/// Goal of this resolver: never pass a non-http(s) URL to `SFSafariViewController`
/// (that crashes). WEBVIEW_MODAL is for web pages, so http/https → Safari VC is the
/// supported path; other schemes are best-effort only.
enum WebviewModalURLAction: Equatable {
    case presentInSafari(URL)
    case openExternally(URL)
    case ignore
}

func resolveWebviewModalURLAction(_ urlString: String?) -> WebviewModalURLAction {
    guard let urlString = urlString,
          let url = URL(string: urlString),
          let scheme = url.scheme?.lowercased(),
          !scheme.isEmpty else {
        return .ignore
    }
    if scheme == "http" || scheme == "https" {
        return .presentInSafari(url)
    }
    return .openExternally(url)
}

// vc for navigation view
class ModalComponentViewController: UIViewController {
    private var currentModal: NavigationViewControlller? = nil
    private let experimentSession = TriggerExperimentSession()
    private var standaloneSafari: SFSafariViewController?

    var hasPresentedContent: Bool { self.currentModal != nil || self.standaloneSafari != nil }

    var hasActiveTriggerExperiment: Bool { self.experimentSession.isActive }

    func ownsTriggerExperiment(_ session: String) -> Bool {
        self.experimentSession.owns(session)
    }

    func startTriggerExperiment(_ session: String = UUID().uuidString) -> String? {
        self.experimentSession.start(session)
    }

    func beginDisplayRecording(_ session: String) -> Bool {
        self.experimentSession.beginRecording(session)
    }

    func finishDisplayRecording(_ session: String) {
        self.experimentSession.finishRecording(session)
        self.releaseFinishedExperimentIfUnpresented()
    }

    func finishTriggerExperiment(_ session: String) {
        self.experimentSession.finish(session)
        self.releaseFinishedExperimentIfUnpresented()
    }

    func stopTriggerExperiment(_ session: String) {
        guard self.experimentSession.owns(session) else { return }
        self.finishTriggerExperiment(session)
        self.dismissModal()
    }

    func resetTriggerExperiment() {
        self.experimentSession.reset()
        self.dismissModal()
        self.currentModal = nil
        self.standaloneSafari = nil
    }

    private func releaseFinishedExperimentIfUnpresented() {
        guard !self.hasPresentedContent else { return }
        self.experimentSession.releaseIfFinished()
    }

    private func presentationDidEnd(
        _ controller: UIViewController,
        session: String?,
        suppressBackAction: Bool,
        backButtonActionHandler: ModalBackButtonActionHandler?,
        onDismissed: (@MainActor () -> Void)?
    ) {
        if self.currentModal === controller { self.currentModal = nil }
        if self.standaloneSafari === controller { self.standaloneSafari = nil }
        defer { self.releaseFinishedExperimentIfUnpresented() }
        guard self.experimentSession.id == session, !suppressBackAction else { return }
        // Run return navigation before deciding whether this flow has ended.
        backButtonActionHandler?()
        if let onDismissed {
            onDismissed()
        } else if let session, !self.hasPresentedContent {
            self.finishTriggerExperiment(session)
        }
    }
    private func activeModal() -> NavigationViewControlller? {
        guard let modal = self.currentModal else { return nil }
        guard !modal.isBeingDismissed else { return nil }
        guard modal.presentingViewController != nil else {
            self.currentModal = nil
            return nil
        }
        return modal
    }

    func popToExistingNavigation(pageId: String?) -> PageView? {
        guard let pageId,
              let modal = self.activeModal(),
              let pageController = modal.viewControllers
                .compactMap({ $0 as? ModalPageViewController })
                .first(where: { $0.pageId == pageId }) else {
            return nil
        }
        if modal.topViewController !== pageController {
            _ = modal.popToViewController(pageController, animated: true)
        }
        return pageController.representedPageView
    }

    func presentWebview(
        url: String?,
        backButtonActionHandler: ModalBackButtonActionHandler?,
        onDismissed: (@MainActor () -> Void)? = nil,
        onShown: (() -> Void)? = nil
    ) {
        switch resolveWebviewModalURLAction(url) {
        case .ignore:
            return
        case .openExternally(let urlObj):
            // Non-http(s) URLs are opened externally as a best-effort fallback.
            // Custom schemes may return false unless the host app declares them in
            // LSApplicationQueriesSchemes. This is acceptable because WEBVIEW_MODAL
            // officially supports web URLs only.
            guard UIApplication.shared.canOpenURL(urlObj) else {
                return
            }
            UIApplication.shared.open(urlObj)
            return
        case .presentInSafari(let urlObj):
            let session = self.experimentSession.id
            let safariVC = ModalSafariViewController(url: urlObj)
            safariVC.onDismissed = { [weak self] controller in
                self?.presentationDidEnd(
                    controller,
                    session: session,
                    suppressBackAction: controller.suppressBackAction,
                    backButtonActionHandler: backButtonActionHandler,
                    onDismissed: onDismissed
                )
            }
            if let modal = self.activeModal() {
                guard modal.presentedViewController == nil else { return }
                modal.present(safariVC, animated: true, completion: onShown)
            } else if self.presentToTop(safariVC, onPresented: onShown) {
                self.standaloneSafari = safariVC
            }
        }
    }

    func presentNavigation(
        pageView: PageView,
        modalPresentationStyle: ModalPresentationStyle?,
        modalScreenSize: ModalScreenSize?,
        backButtonActionHandler: ModalBackButtonActionHandler?,
        onVisiblePageChanged: ((PageView) -> Void)? = nil,
        onDismissed: (@MainActor () -> Void)? = nil,
        onShown: (() -> Void)? = nil
    ) {
        // Don't push or present a new modal while the current stack is dismissing.
        guard self.currentModal?.isBeingDismissed != true else { return }
        let pageController = ModalPageViewController(pageView: pageView)
        if let backButtonActionHandler = backButtonActionHandler {
            pageController.backButtonActionHandler = backButtonActionHandler
        }
        pageController.onVisiblePageChanged = onVisiblePageChanged
        pageController.onPresentationDismissed = onDismissed

        if let modal = self.activeModal() {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.setIsFirstModalToTrue()
            let modal = NavigationViewControlller(rootViewController: pageController, hasPrevious: true)
            let session = self.experimentSession.id
            modal.onDismissed = { [weak self] controller in
                let page = controller.topViewController as? ModalPageViewController
                self?.presentationDidEnd(
                    controller,
                    session: session,
                    suppressBackAction: controller.suppressBackAction,
                    backButtonActionHandler: page?.backButtonActionHandler,
                    onDismissed: page?.onPresentationDismissed
                )
            }
            modal.modalPresentationStyle = parseModalPresentationStyle(modalPresentationStyle)
            modal.configureSheet(size: modalScreenSize) { [weak self] in
                self?.view.window?.bounds.height
            }
            modal.updateSheetBackground(for: pageController)
            self.currentModal = modal
            if !self.presentToTop(modal, onPresented: onShown) {
                self.currentModal = nil
            }
        }
        return
    }

    @discardableResult
    func presentToTop(_ viewController: UIViewController, onPresented: (() -> Void)? = nil) -> Bool {
        guard let root = self.view.window?.rootViewController else { return false }
        let top = findTopPresenting(root)
        guard top.viewIfLoaded?.window != nil,
              !top.isBeingDismissed, !top.isBeingPresented,
              top.presentedViewController == nil else { return false }
        top.present(viewController, animated: true, completion: onPresented)
        return viewController.presentingViewController != nil
    }

    @objc func dismissModal() {
        guard let modal = self.currentModal ?? self.standaloneSafari else { return }
        var controller: UIViewController? = modal
        while let presented = controller {
            (presented as? NavigationViewControlller)?.suppressBackAction = true
            (presented as? ModalSafariViewController)?.suppressBackAction = true
            controller = presented.presentedViewController
        }
        guard !modal.isBeingDismissed else { return }
        modal.dismiss(animated: true)
    }
}

private class ModalSafariViewController: SFSafariViewController {
    var onDismissed: ((ModalSafariViewController) -> Void)?
    var suppressBackAction = false

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if self.isBeingDismissed || self.presentingViewController == nil {
            let completion = self.onDismissed
            self.onDismissed = nil
            completion?(self)
        }
    }
}

typealias ModalBackButtonActionHandler = @MainActor () -> Void

@MainActor
func makeBackButtonAction(
    event: UIBlockAction?,
    context: UIBlockContext,
    variableProvider: @escaping @MainActor () -> Variable? = { nil }
) -> ModalBackButtonActionHandler? {
    guard let event else { return nil }
    return {
        let compiledAction = compileAction(action: event, variable: variableProvider())
        context.dispatch(action: compiledAction)
    }
}
