//
//  root.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

class RootViewController: UIViewController {
    private let id: String!
    private let pages: [UIPageBlock]!
    private let config: Config
    private var event: UIBlockEventManager? = nil
    private var initialPageId: String = ""
    private var currentComponent: UIViewController? = nil
    private var currentModal: NavigationViewControlller? = nil

    required init?(coder: NSCoder) {
        self.id = ""
        self.pages = []
        self.config = Config(apiKey: "")
        super.init(coder: coder)
    }

    init(root: UIRootBlock?, config: Config) {
        self.id = root?.id ?? ""
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.initialPageId = trigger?.id ?? root?.data?.currentPageId ?? ""
        self.config = config
        super.init(nibName: nil, bundle: nil)

        self.event = UIBlockEventManager(on: { event in
            if let destPageId = event.destinationPageId {
                self.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self.config.dispatchUIBlockEvent(event: event)
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.configureLayout { layout in
            layout.isEnabled = true

            layout.display = .flex
            layout.alignItems = .center
            layout.justifyContent = .center
        }

        self.presentPage(pageId: self.initialPageId, props: nil)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.parent?.viewDidLayoutSubviews()
    }

    func presentPage(pageId: String, props: [Property]?) {
        var page = self.pages.first { page in
            return pageId == page.id
        }
        var currentPageId = pageId

        // when it's trigger
        if page?.data?.kind == PageKind.TRIGGER {
            page = self.pages.first { p in
                return p.id == page?.data?.triggerSetting?.onTrigger?.destinationPageId
            }
            if let pageId = page?.id {
                currentPageId = pageId
            }
        }

        // when it's dismissed
        if page?.data?.kind == PageKind.DISMISSED {
            self.dismissModal()
            if let previous = self.currentComponent {
                previous.view.removeFromSuperview()
                previous.removeFromParent()
            }
            return
        }

        let pageController = PageController(
            page: page,
            props: props,
            event: self.event,
            config: self.config
        )

        switch page?.data?.kind {
        case .MODAL:
            self.presentNavigation(
                pageController: pageController,
                modalPresentationStyle: page?.data?.modalPresentationStyle,
                modalScreenSize: page?.data?.modalScreenSize
            )
            break
        default:
            if let previous = self.currentComponent {
                previous.view.removeFromSuperview()
                previous.removeFromParent()
            }
            self.dismissModal()
            let component = pageController
            self.view.addSubview(component.view)
            self.addChild(component)
            self.currentComponent = component
            break
        }
    }

    func presentNavigation(
        pageController: PageController,
        modalPresentationStyle: ModalPresentationStyle?,
        modalScreenSize: ModalScreenSize?
    ) {
        if let modal = self.currentModal {
            if !isPresenting(presented: self.presentedViewController, vc: modal) {
                self.currentModal = nil
            }
        }

        if let modal = self.currentModal {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.showFullScreenInitialNavItem()
            let modal = NavigationViewControlller(
                rootViewController: pageController,
                hasPrevious: true
            )
            modal.modalPresentationStyle = parseModalPresentationStyle(modalPresentationStyle)
            if let sheet = modal.sheetPresentationController {
                sheet.detents = parseModalScreenSize(modalScreenSize)
            }
            self.currentModal = modal
            self.presentToTop(modal)
        }
        return
    }

    func presentToTop(_ viewController: UIViewController) {
        let top = findTopPresenting(self)
        top.present(viewController, animated: true, completion: nil)
    }

    @objc func dismissModal() {
         if let modal = self.currentModal {
             modal.dismiss(animated: true)
         }
         self.currentModal = nil
    }
}



func findTopPresenting(_ viewContorller: UIViewController) ->  UIViewController {
    if let presented = viewContorller.presentedViewController {
        return findTopPresenting(presented)
    } else {
        return viewContorller
    }
}

func isPresenting(presented: UIViewController?, vc: UIViewController) -> Bool {
    if let presented = presented {
        if presented == vc {
            return true
        } else {
            return isPresenting(presented: presented.presentedViewController, vc: vc)
        }
    } else {
        return false
    }
}
