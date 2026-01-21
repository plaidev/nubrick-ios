//
//  root.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import UIKit
@_implementationOnly import YogaKit

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
            let onBackButtonClick = page?.data?.triggerSetting?.onTrigger
            self.modalViewController?.presentWebview(
                url: page?.data?.webviewUrl,
                backButtonBehaviorDelegate: (onBackButtonClick != nil) ? ModalBackButtonBehaviorDelegate(
                    event: onBackButtonClick,
                    context: UIBlockContext(
                        UIBlockContextInit(
                            container: self.container,
                            event: self.event,
                        )
                    )
                ) : nil
            )
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
            let onBackButtonClick = page?.data?.triggerSetting?.onTrigger
            self.modalViewController?.presentNavigation(
                pageView: pageView,
                modalPresentationStyle: page?.data?.modalPresentationStyle,
                modalScreenSize: page?.data?.modalScreenSize,
                backButtonBehaviorDelegate: (onBackButtonClick != nil) ? ModalBackButtonBehaviorDelegate(
                    event: onBackButtonClick,
                    context: UIBlockContext(
                        UIBlockContextInit(
                            container: self.container,
                            event: self.event,
                        )
                    )
                ) : nil
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
    @Binding var width: CGFloat?
    @Binding var height: CGFloat?

    @MainActor
    final class SizeCoordinator {
        private let w: Binding<CGFloat?>
        private let h: Binding<CGFloat?>
        private var isActive = true

        init(w: Binding<CGFloat?>, h: Binding<CGFloat?>) {
            self.w = w
            self.h = h
        }

        func deactivate() {
            isActive = false
        }

        func report(width: CGFloat?, height: CGFloat?) {
            Task { @MainActor [weak self] in
                guard let self, self.isActive else { return }
                self.w.wrappedValue = width
                self.h.wrappedValue = height
            }
        }
    }

    func makeCoordinator() -> SizeCoordinator {
        SizeCoordinator(w: $width, h: $height)
    }


    func makeUIView(context: Self.Context) -> Self.UIViewType {
        let onSizeChange : (CGFloat?, CGFloat?) -> Void = { [weak coordinator = context.coordinator] w, h in
            coordinator?.report(width: w, height: h)
        }
        return RootView(
            root: root, container: container, modalViewController: modalViewController,
            onEvent: onEvent, onSizeChange: onSizeChange)
    }

    // データの更新に応じてラップしている UIView を更新する
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) {

    }

    static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: SizeCoordinator) {
        uiView.onSizeChange = nil   // to avoid callback after view is destroyed
        coordinator.deactivate()
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
    // callback to transmit size to SwiftUI
    var onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)?

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
        onDismiss: (() -> Void)? = nil,
        onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)? = nil
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
        self.onSizeChange = onSizeChange
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
            let onBackButtonClick = page?.data?.triggerSetting?.onTrigger
            self.modalViewController?.presentWebview(
                url: page?.data?.webviewUrl,
                backButtonBehaviorDelegate: (onBackButtonClick != nil) ? ModalBackButtonBehaviorDelegate(
                    event: onBackButtonClick,
                    context: UIBlockContext(
                        UIBlockContextInit(
                            container: self.container,
                            event: self.event,
                        )
                    )
                ) : nil
            )
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
            let onBackButtonClick = page?.data?.triggerSetting?.onTrigger
            self.modalViewController?.presentNavigation(
                pageView: pageView,
                modalPresentationStyle: page?.data?.modalPresentationStyle,
                modalScreenSize: page?.data?.modalScreenSize,
                backButtonBehaviorDelegate: (onBackButtonClick != nil) ? ModalBackButtonBehaviorDelegate(
                    event: onBackButtonClick,
                    context: UIBlockContext(
                        UIBlockContextInit(
                            container: self.container,
                            event: self.event,
                        )
                    )
                ) : nil
            )
        case .COMPONENT:
            // in case of embedding update size for swiftui
            let width = page?.data?.frameWidth.map(CGFloat.init)
            let height = page?.data?.frameHeight.map(CGFloat.init)
            self.onSizeChange?(width, height)
            fallthrough
        default:
            self.modalViewController?.dismissModal()
            if self.currentEmbeddedPageId == currentPageId {
                return
            }
            self.view?.removeFromSuperview()
            self.view = pageView
            self.addSubview(pageView)
            self.currentEmbeddedPageId = currentPageId
            self.invalidateIntrinsicContentSize()
            self.superview?.invalidateIntrinsicContentSize() // we need to invalidate intrinsic for the EmbeddingUIView for relayout
            break
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.yoga.applyLayout(preservingOrigin: true)
    }

    override var intrinsicContentSize: CGSize {
        let page = self.pages.first { page in
            return currentEmbeddedPageId == page.id
        }
        switch page?.data?.kind {
        case .COMPONENT:
            let width = page?.data?.frameWidth.map(CGFloat.init)
            let height = page?.data?.frameHeight.map(CGFloat.init)
            return CGSize(width: width ?? UIView.noIntrinsicMetric, height: height ?? UIView.noIntrinsicMetric)
        default:
            return super.intrinsicContentSize
        }
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
