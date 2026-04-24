//
//  root.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import UIKit
internal import YogaKit

// For InAppMessage Experiment.
class ModalRootViewController: UIViewController {
    private let pages: [UIPageBlock]!
    private let modalViewController: ModalComponentViewController?
    private var actionHandler: UIBlockActionHandler? = nil
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

        self.actionHandler = { [weak self] action, _ in
            guard let self else {
                return
            }
            if let destinationPageId = action.destinationPageId {
                self.presentPage(pageId: destinationPageId, props: action.payload)
            }
            self.container.handleEvent(action)
        }

        if let onTrigger = trigger?.data?.triggerSetting?.onTrigger {
            self.actionHandler?(onTrigger, nil)
        }
    }

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(root:container:modalViewController:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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
                            actionHandler: self.actionHandler
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
            actionHandler: self.actionHandler,
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
                            actionHandler: self.actionHandler
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
    let onEvent: ((_ action: UIBlockAction) -> Void)?
    let onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)?
    @Binding var width: NubrickSize
    @Binding var height: NubrickSize

    @MainActor
    final class SizeCoordinator {
        private let w: Binding<NubrickSize>
        private let h: Binding<NubrickSize>
        var onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)?
        private var isActive = true

        init(
            w: Binding<NubrickSize>,
            h: Binding<NubrickSize>,
            onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)?
        ) {
            self.w = w
            self.h = h
            self.onSizeChange = onSizeChange
        }

        func deactivate() {
            isActive = false
        }

        func report(width: NubrickSize, height: NubrickSize) {
            guard isActive else { return }
            w.wrappedValue = width
            h.wrappedValue = height
            onSizeChange?(width, height)
        }
    }

    func makeCoordinator() -> SizeCoordinator {
        SizeCoordinator(w: $width, h: $height, onSizeChange: onSizeChange)
    }


    func makeUIView(context: Self.Context) -> Self.UIViewType {
        let onSizeChange: (NubrickSize, NubrickSize) -> Void = { [weak coordinator = context.coordinator] w, h in
            Task { @MainActor in
                coordinator?.report(width: w, height: h)
            }
        }
        return RootView(
            root: root, container: container, modalViewController: modalViewController,
            onEvent: onEvent, onSizeChange: onSizeChange)
    }

    // Update the wrapped UIView when SwiftUI state changes.
    func updateUIView(_ uiView: Self.UIViewType, context: Self.Context) {
        context.coordinator.onSizeChange = onSizeChange
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
    private var actionHandler: UIBlockActionHandler? = nil
    private var currentEmbeddedPageId: String = ""
    private var currentTooltipAnchorId: String? = nil
    private var onNextTooltip: ((_ pageId: String) -> Void) = { _ in }
    private var onDismiss: (() -> Void) = {}
    private var view: UIView? = nil
    private var currentPageView: PageView? = nil
    private var modalViewController: ModalComponentViewController? = nil
    private let container: Container
    // callback to transmit size to SwiftUI
    var onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)?

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(root:container:modalViewController:onEvent:onNextTooltip:onDismiss:onSizeChange:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        root: UIRootBlock?,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ action: UIBlockAction) -> Void)?,
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)? = nil
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

        self.actionHandler = { [weak self] action, _ in
            guard let self else {
                return
            }
            if let destinationPageId = action.destinationPageId {
                self.presentPage(pageId: destinationPageId, props: action.payload)
            }
            self.container.handleEvent(action)
            onEvent?(action)
        }

        if let onTrigger = trigger?.data?.triggerSetting?.onTrigger {
            self.actionHandler?(onTrigger, nil)
        }
    }

    // Canonical entrypoint for actions coming from UI gestures or bridge dispatch.
    func dispatchAction(_ action: UIBlockAction) {
        if let page = self.currentPageView {
            page.dispatchAction(action)
        } else {
            self.actionHandler?(action, nil)
        }
    }

    @available(*, deprecated, renamed: "dispatchAction(_:)")
    func dispatch(action: UIBlockAction) {
        self.dispatchAction(action)
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
                            actionHandler: self.actionHandler
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
            actionHandler: self.actionHandler,
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
                            actionHandler: self.actionHandler
                        )
                    )
                ) : nil
            )
        case .COMPONENT:
            // in case of embedding update size for swiftui
            let frameWidth = page?.data?.frameWidth ?? 0
            let frameHeight = page?.data?.frameHeight ?? 0
            let width: NubrickSize = frameWidth == 0 ? .fill : .fixed(CGFloat(frameWidth))
            let height: NubrickSize = frameHeight == 0 ? .fill : .fixed(CGFloat(frameHeight))
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
            let intrinsicWidth = page?.data?.frameWidth
                .flatMap { $0 == 0 ? nil : CGFloat($0) }
                ?? UIView.noIntrinsicMetric
            let intrinsicHeight = page?.data?.frameHeight
                .flatMap { $0 == 0 ? nil : CGFloat($0) }
                ?? UIView.noIntrinsicMetric
            return CGSize(
                width: intrinsicWidth,
                height: intrinsicHeight
            )
        default:
            return super.intrinsicContentSize
        }
    }
}

@MainActor
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

@MainActor
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
