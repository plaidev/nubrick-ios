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

// For InAppMessage Experiment.
class ModalRootViewController: UIViewController {
    private let pages: [UIPageBlock]!
    private let modalViewController: ModalComponentViewController?
    private var event: UIBlockEventManager? = nil
    private let container: Container

    init(root: UIRootBlock?, container: Container, modalViewController: ModalComponentViewController?) {
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.modalViewController = modalViewController
        self.modalViewController?.dismissModal()
        self.container = container
        super.init(nibName: nil, bundle: nil)

        self.event = UIBlockEventManager(on: { [weak self] event in
            if let destPageId = event.destinationPageId {
                self?.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self?.container.handleEvent(event)
        })

        if let destId = trigger?.data?.triggerSetting?.onTrigger?.destinationPageId {
            self.presentPage(pageId: destId, props: nil)
        }
    }

    required init?(coder: NSCoder) {
        self.pages = []
        self.modalViewController = nil
        self.container = ContainerEmptyImpl()
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
        
        // when it's webview modal
        if page?.data?.kind == PageKind.WEBVIEW_MODAL {
            self.modalViewController?.presentWebview(url: page?.data?.webviewUrl)
            return
        }

        let pageView = PageView(
            page: page,
            props: props,
            container: self.container,
            event: self.event,
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
    let container: Container
    let modalViewController: ModalComponentViewController?
    let onEvent: ((_ event: UIBlockEventDispatcher) -> Void)?

    func makeUIView(context: Self.Context) -> Self.UIViewType {
        return RootView(root: root, container: container, modalViewController: modalViewController, onEvent: onEvent)
    }

    // データの更新に応じてラップしている UIView を更新する
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) {

    }
}

class RootView: UIView {
    private let id: String!
    private let pages: [UIPageBlock]!
    // use var instead of let, because to refer weak self.
    private var event: UIBlockEventManager? = nil
    private var currentEmbeddedPageId: String = ""
    private var currentTooltipAnchorId: String? = nil
    private var onNextTooltip: ((_ anchorId: String) -> Void) = { _ in }
    private var view: UIView? = nil
    private var modalViewController: ModalComponentViewController? = nil
    private let container: Container

    required init?(coder: NSCoder) {
        self.id = ""
        self.pages = []
        self.view = UIView()
        self.container = ContainerEmptyImpl()
        super.init(coder: coder)
    }

    init(
        root: UIRootBlock?,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ event: UIBlockEventDispatcher) -> Void)?,
        onNextTooltip: ((_ anchorId: String) -> Void)? = nil
    ) {
        self.id = root?.id ?? ""
        self.container = container
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.modalViewController = modalViewController
        self.onNextTooltip = onNextTooltip ?? { _ in }
        super.init(frame: .zero)

        self.configureLayout { layout in
            layout.isEnabled = true
        }

        self.event = UIBlockEventManager(on: { [weak self] event in
            if let destPageId = event.destinationPageId {
                self?.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self?.container.handleEvent(event)
            onEvent?(event)
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
            return
        }
        
        // when it's webview modal
        if page?.data?.kind == PageKind.WEBVIEW_MODAL {
            self.modalViewController?.presentWebview(url: page?.data?.webviewUrl)
            return
        }
        
        // when it's tooltip
        if page?.data?.kind == PageKind.TOOLTIP {
            let anchorId = page?.data?.tooltipAnchor ?? ""
            if let currentAnchorId = self.currentTooltipAnchorId {
                if currentAnchorId != anchorId { // when it's diffrent anchor, dismiss. and callback.
                    self.onNextTooltip(anchorId)
                    self.modalViewController?.dismissModal()
                    return
                }
            }
            self.currentTooltipAnchorId = anchorId
        }

        let pageView = PageView(
            page: page,
            props: props,
            container: self.container,
            event: self.event,
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
        if presented.isBeingDismissed {
            return viewContorller
        }
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
