//
//  component.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import SwiftUI
import YogaKit
import SafariServices

// vc for navigation view
class ModalComponentViewController: UIViewController {
    private var currentModal: NavigationViewControlller? = nil
    
    func presentWebview(url: String?) {
        guard let url = url else {
            return
        }
        guard let urlObj = URL(string: url) else {
            return
        }
        let safariVC = SFSafariViewController(url: urlObj)
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

    func presentNavigation(
        pageView: PageView,
        modalPresentationStyle: ModalPresentationStyle?,
        modalScreenSize: ModalScreenSize?
    ) {
        if let modal = self.currentModal {
            if !isPresenting(presented: self.presentedViewController, vc: modal) {
                self.currentModal?.dismiss(animated: false)
                self.currentModal = nil
            }
        }

        let pageController = ModalPageViewController(pageView: pageView)

        if let modal = self.currentModal {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.setIsFirstModalToTrue()
            let modal = NavigationViewControlller(
                rootViewController: pageController,
                hasPrevious: true
            )
            modal.modalPresentationStyle = parseModalPresentationStyle(modalPresentationStyle)
            if #available(iOS 15.0, *) {
                if let sheet = modal.sheetPresentationController {
                    sheet.detents = parseModalScreenSize(modalScreenSize)
                }
            }
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
    
    override func viewDidLayoutSubviews() {
        self.view.yoga.applyLayout(preservingOrigin: true)
    }

    @objc func dismissModal() {
         if let modal = self.currentModal {
             modal.dismiss(animated: true)
         }
         self.currentModal = nil
    }
}
