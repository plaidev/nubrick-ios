//
//  root.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit
import SwiftUI

class ModalRootViewController: UIViewController {
    private let pages: [UIPageBlock]!
    private let config: Config
    private let repositories: Repositories?
    private let modalViewController: ModalComponentViewController?
    private var event: UIBlockEventManager? = nil

    init(root: UIRootBlock?, config: Config, repositories: Repositories, modalViewController: ModalComponentViewController?) {
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.config = config
        self.repositories = repositories
        self.modalViewController = modalViewController
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

        if let destId = trigger?.data?.triggerSetting?.onTrigger?.destinationPageId {
            self.presentPage(pageId: destId, props: nil)
        }
    }

    required init?(coder: NSCoder) {
        self.pages = []
        self.config = Config()
        self.repositories = nil
        self.modalViewController = nil
        super.init(coder: coder)
    }

    func presentPage(pageId: String, props: [Property]?) {
        var page = self.pages.first { page in
            return pageId == page.id
        }

        // when it's trigger
        if page?.data?.kind == PageKind.TRIGGER {
            page = self.pages.first { p in
                return p.id == page?.data?.triggerSetting?.onTrigger?.destinationPageId
            }
        }

        // when there are no pages
        if page == nil {
            return
        }

        // when it's dismissed
        if page?.data?.kind == PageKind.DISMISSED {
            self.modalViewController?.dismissModal()
            return
        }

        let pageView = PageView(
            page: page,
            props: props,
            event: self.event,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.modalViewController
        )

        switch page?.data?.kind {
        case .MODAL:
            self.modalViewController?.presentNavigation(
                pageView: pageView,
                modalPresentationStyle: page?.data?.modalPresentationStyle,
                modalScreenSize: page?.data?.modalScreenSize
            )
            break
        default:
            self.modalViewController?.dismissModal()
            break
        }
    }
}

struct RootViewRepresentable: UIViewRepresentable {
    typealias UIViewType = RootView
    let root: UIRootBlock?
    let config: Config
    let repositories: Repositories
    let modalViewController: ModalComponentViewController?

    func makeUIView(context: Self.Context) -> Self.UIViewType {
        return RootView(root: root, config: config, repositories: repositories, modalViewController: modalViewController)
    }

    // データの更新に応じてラップしている UIView を更新する
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) {

    }
}

class RootView: UIView {
    private let id: String!
    private let pages: [UIPageBlock]!
    private let config: Config
    private let repositories: Repositories?
    private var event: UIBlockEventManager? = nil
    private var currentEmbeddedPageId: String = ""
    private var view: UIView? = nil
    private var modalViewController: ModalComponentViewController? = nil

    required init?(coder: NSCoder) {
        self.id = ""
        self.pages = []
        self.config = Config()
        self.repositories = nil
        self.view = UIView()
        super.init(coder: coder)
    }

    init(root: UIRootBlock?, config: Config, repositories: Repositories?, modalViewController: ModalComponentViewController?) {
        self.id = root?.id ?? ""
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.config = config
        self.repositories = repositories
        self.modalViewController = modalViewController
        super.init(frame: .zero)

        self.configureLayout { layout in
            layout.isEnabled = true
        }

        self.event = UIBlockEventManager(on: { event in
            if let destPageId = event.destinationPageId {
                self.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self.config.dispatchUIBlockEvent(event: event)
        })

        if let destId = trigger?.data?.triggerSetting?.onTrigger?.destinationPageId {
            self.presentPage(pageId: destId, props: nil)
        }
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

        // when there are no pages
        if page == nil {
            return
        }

        // when it's dismissed
        if page?.data?.kind == PageKind.DISMISSED {
            self.modalViewController?.dismissModal()
//            if let previous = self.currentComponent {
//                previous.view.removeFromSuperview()
//                previous.removeFromParent()
//            }
            return
        }

        let pageView = PageView(
            page: page,
            props: props,
            event: self.event,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.modalViewController
        )

        switch page?.data?.kind {
        case .MODAL:
            self.modalViewController?.presentNavigation(
                pageView: pageView,
                modalPresentationStyle: page?.data?.modalPresentationStyle,
                modalScreenSize: page?.data?.modalScreenSize
            )
            break
        default:
            self.modalViewController?.dismissModal()
            if self.currentEmbeddedPageId == currentPageId {
                return
            }
            self.view?.removeFromSuperview()
            self.view = pageView
            self.addSubview(pageView)
            self.currentEmbeddedPageId = currentPageId
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.yoga.applyLayout(preservingOrigin: true)
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
