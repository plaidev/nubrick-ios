//
//  root.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import UIKit
import YogaKit

// For InAppMessage Experiment.
class ModalRootViewController: UIViewController {
    private let pages: [UIPageBlock]!
    private let modalViewController: ModalComponentViewController?
    private var event: UIBlockEventManager? = nil
    private let container: Container

    init(
        root: UIRootBlock?, container: Container, modalViewController: ModalComponentViewController?
    ) {
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.modalViewController = modalViewController
        self.modalViewController?.dismissModal()
        self.container = container
        super.init(nibName: nil, bundle: nil)

        self.event = UIBlockEventManager(on: { [weak self] event, _ in
            if let destPageId = event.destinationPageId {
                self?.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self?.container.handleEvent(event)
        })

        if let onTrigger = trigger?.data?.triggerSetting?.onTrigger {
            self.event?.dispatch(event: onTrigger)
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
        return RootView(
            root: root, container: container, modalViewController: modalViewController,
            onEvent: onEvent)
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
    private var onNextTooltip: ((_ pageId: String) -> Void) = { _ in }
    private var onDismiss: (() -> Void) = {}
    private var view: UIView? = nil
    private var currentPageView: PageView? = nil
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
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.id = root?.id ?? ""
        self.container = container
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.modalViewController = modalViewController
        self.onNextTooltip = onNextTooltip ?? { _ in }
        self.onDismiss = onDismiss ?? {}
        super.init(frame: .zero)

        self.configureLayout { layout in
            layout.isEnabled = true
        }

        self.event = UIBlockEventManager(on: { [weak self] event, _ in
            if let destPageId = event.destinationPageId {
                self?.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
            self?.container.handleEvent(event)
            onEvent?(event)
        })

        if let onTrigger = trigger?.data?.triggerSetting?.onTrigger {
            self.event?.dispatch(event: onTrigger)
        }
    }

    func dispatch(event: UIBlockEventDispatcher) {
        if let page = self.currentPageView {
            // call event dispatch from the page view.
            page.dispatch(event: event)
        } else {
            // fallback
            self.event?.dispatch(event: event)
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
            self.currentPageView = nil
            self.modalViewController?.dismissModal()
            self.onDismiss()
            return
        }

        // when it's webview modal
        if page?.data?.kind == PageKind.WEBVIEW_MODAL {
            self.modalViewController?.presentWebview(url: page?.data?.webviewUrl)
            return
        }

        // when it's tooltip
        if page?.data?.kind == PageKind.TOOLTIP {
            self.onNextTooltip(pageId)
            let anchorId = page?.data?.tooltipAnchor ?? ""
            self.currentTooltipAnchorId = anchorId
        }

        let pageView = PageView(
            page: page,
            props: props,
            container: self.container,
            event: self.event,
            modalViewController: self.modalViewController
        )
        self.currentPageView = pageView

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

func findTopPresenting(_ viewContorller: UIViewController) -> UIViewController {
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
