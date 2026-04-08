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
    private let renderContext: RenderContext

    init(
        root: UIRootBlock?, renderContext: RenderContext, modalViewController: ModalComponentViewController?
    ) {
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.modalViewController = modalViewController
        self.modalViewController?.dismissModal()
        self.renderContext = renderContext
        super.init(nibName: nil, bundle: nil)

        self.actionHandler = { [weak self] action, _ in
            guard let self else {
                return
            }
            if let destinationPageId = action.destinationPageId {
                self.presentPage(pageId: destinationPageId, props: action.payload)
            }
            self.renderContext.handleEvent(action)
        }

        if let onTrigger = trigger?.data?.triggerSetting?.onTrigger {
            self.actionHandler?(onTrigger, nil)
        }
    }

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(root:renderContext:modalViewController:).")
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
                            renderContext: self.renderContext,
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
            renderContext: self.renderContext,
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
                            renderContext: self.renderContext,
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
    let renderContext: RenderContext
    let modalViewController: ModalComponentViewController?
    let onEvent: ((_ action: UIBlockAction) -> Void)?
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
            root: root, renderContext: renderContext, modalViewController: modalViewController,
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
    private var actionHandler: UIBlockActionHandler? = nil
    private var currentEmbeddedPageId: String = ""
    private var currentTooltipAnchorId: String? = nil
    private var onNextTooltip: ((_ pageId: String) -> Void) = { _ in }
    private var onDismiss: (() -> Void) = {}
    private var view: UIView? = nil
    private var currentPageView: PageView? = nil
    private var modalViewController: ModalComponentViewController? = nil
    private let renderContext: RenderContext
    // callback to transmit size to SwiftUI
    var onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)?

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(root:renderContext:modalViewController:onEvent:onNextTooltip:onDismiss:onSizeChange:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        root: UIRootBlock?,
        renderContext: RenderContext,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ action: UIBlockAction) -> Void)?,
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)? = nil
    ) {
        self.id = root?.id ?? ""
        self.renderContext = renderContext
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
            self.renderContext.handleEvent(action)
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
                            renderContext: self.renderContext,
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
            renderContext: self.renderContext,
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
                            renderContext: self.renderContext,
                            actionHandler: self.actionHandler
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
