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
    private var backButtonBehaviorDelegate: ModalBackButtonBehaviorDelegate? = nil

    func presentWebview(url: String?, backButtonBehaviorDelegate: ModalBackButtonBehaviorDelegate?) {
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
            let safariVC = SFSafariViewController(url: urlObj)
            if let backButtonBehaviorDelegate = backButtonBehaviorDelegate {
                // keep the instance, because it will be deallocated after the function call.
                self.backButtonBehaviorDelegate = backButtonBehaviorDelegate
                safariVC.delegate = self.backButtonBehaviorDelegate
            }
            if let modal = self.currentModal {
                if !isPresenting(presented: self.presentedViewController, vc: modal) {
                    self.currentModal?.dismiss(animated: false)
                    self.currentModal = nil
                }
            }

            if let modal = self.currentModal {
                modal.present(safariVC, animated: true)
            } else {
                self.presentToTop(safariVC)
            }
        }
    }

    func presentNavigation(
        pageView: PageView,
        modalPresentationStyle: ModalPresentationStyle?,
        modalScreenSize: ModalScreenSize?,
        backButtonBehaviorDelegate: ModalBackButtonBehaviorDelegate?
    ) {
        if let modal = self.currentModal {
            if !isPresenting(presented: self.presentedViewController, vc: modal) {
                self.currentModal?.dismiss(animated: false)
                self.currentModal = nil
            }
        }

        let pageController = ModalPageViewController(pageView: pageView)
        if let backButtonBehaviorDelegate = backButtonBehaviorDelegate {
            pageController.backButtonBehaviorDelegate = backButtonBehaviorDelegate
        }

        if let modal = self.currentModal {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.setIsFirstModalToTrue()
            let modal = NavigationViewControlller(
                rootViewController: pageController,
                hasPrevious: true
            )
            modal.modalPresentationStyle = parseModalPresentationStyle(modalPresentationStyle)
            if let sheet = modal.sheetPresentationController {
                sheet.detents = parseModalScreenSize(modalScreenSize)
            }
            modal.updateSheetBackground(for: pageController)
            self.currentModal = modal
            self.presentToTop(modal)
        }
        return
    }

    func presentToTop(_ viewController: UIViewController) {
        guard let root = self.view.window?.rootViewController else {
            return
        }
        let top = findTopPresenting(root)
        top.present(viewController, animated: true)
    }

    @objc func dismissModal() {
         if let modal = self.currentModal {
             modal.dismiss(animated: true)
         }
         self.currentModal = nil
    }
}

@MainActor
class ModalBackButtonBehaviorDelegate: NSObject, SFSafariViewControllerDelegate {
    private let actionEvent: UIBlockAction?
    private let context: UIBlockContext
    private let variableProvider: @MainActor () -> Variable?

    init(
        event: UIBlockAction?,
        context: UIBlockContext,
        variableProvider: @escaping @MainActor () -> Variable? = { nil }
    ) {
        self.actionEvent = event
        self.context = context
        self.variableProvider = variableProvider
    }

    func onBackButtonClick() {
        guard let actionEvent else { return }
        let compiledAction = compileAction(action: actionEvent, variable: variableProvider())
        context.dispatch(action: compiledAction)
    }

    nonisolated func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        Task { @MainActor in
            self.onBackButtonClick()
        }
    }
}
