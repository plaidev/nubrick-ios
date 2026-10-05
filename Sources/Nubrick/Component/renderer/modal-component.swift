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
    private var triggerSession: UUID?
    private var isRecordingDisplay = false
    private var standaloneSafari: SFSafariViewController?

    var hasActiveTriggerExperiment: Bool { self.triggerSession != nil }

    func ownsTriggerExperiment(_ session: UUID) -> Bool { self.triggerSession == session }

    func startTriggerExperiment() -> UUID? {
        guard self.triggerSession == nil else { return nil }
        let session = UUID()
        self.triggerSession = session
        self.isRecordingDisplay = false
        return session
    }

    func beginDisplayRecording(_ session: UUID) -> Bool {
        guard self.triggerSession == session,
              !self.isRecordingDisplay else { return false }
        self.isRecordingDisplay = true
        return true
    }

    func finishDisplayRecording(_ session: UUID) {
        guard self.triggerSession == session,
              self.isRecordingDisplay else { return }
        self.isRecordingDisplay = false
        self.finishTriggerExperimentIfUnpresented(session)
    }

    func finishTriggerExperimentIfUnpresented(_ session: UUID) {
        guard self.triggerSession == session,
              !self.isRecordingDisplay,
              self.currentModal == nil,
              self.standaloneSafari == nil else { return }
        self.triggerSession = nil
    }

    func resetTriggerExperiment() {
        self.dismissModal()
        self.isRecordingDisplay = false
        self.triggerSession = nil
        self.currentModal = nil
        self.standaloneSafari = nil
    }

    private func presentationDidEnd(_ controller: UIViewController, session: UUID?, continuation: (() -> Void)? = nil) {
        let ownsSession = self.triggerSession == session
        if self.currentModal === controller { self.currentModal = nil }
        if self.standaloneSafari === controller { self.standaloneSafari = nil }
        // A Safari back action may open another page in this experiment. Keep the
        // session until that action has had a chance to present it.
        if ownsSession { continuation?() }
        if let activeSession = self.triggerSession {
            self.finishTriggerExperimentIfUnpresented(activeSession)
        }
    }
    private func activeModal() -> NavigationViewControlller? {
        guard let modal = self.currentModal else { return nil }
        guard !modal.isBeingDismissed else { return nil }
        guard modal.presentingViewController != nil else {
            modal.dismiss(animated: false)
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
            let session = self.triggerSession
            let safariVC = ModalSafariViewController(url: urlObj)
            safariVC.onDismissed = { [weak self] controller in
                self?.presentationDidEnd(controller, session: session) {
                    if !controller.suppressBackAction { backButtonActionHandler?() }
                }
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
        onShown: (() -> Void)? = nil
    ) {
        // Returning nil from activeModal must not turn a closing stack into a
        // fresh presentation while its dismissal is still running.
        guard self.currentModal?.isBeingDismissed != true else { return }
        let pageController = ModalPageViewController(pageView: pageView)
        if let backButtonActionHandler = backButtonActionHandler {
            pageController.backButtonActionHandler = backButtonActionHandler
        }
        pageController.onVisiblePageChanged = onVisiblePageChanged

        if let modal = self.activeModal() {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.setIsFirstModalToTrue()
            let modal = NavigationViewControlller(rootViewController: pageController, hasPrevious: true)
            let session = self.triggerSession
            modal.onDismissed = { [weak self] controller in
                self?.presentationDidEnd(controller, session: session)
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
        guard let modal = self.currentModal ?? self.standaloneSafari,
              !modal.isBeingDismissed else { return }
        var controller: UIViewController? = modal
        while let presented = controller {
            (presented as? ModalSafariViewController)?.suppressBackAction = true
            controller = presented.presentedViewController
        }
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
