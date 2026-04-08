//
//  page.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
internal import YogaKit

// child of modal
class ModalPageViewController: UIViewController {
    private var isFirstModal = false
    private let pageView: PageView?
    public var backButtonBehaviorDelegate: ModalBackButtonBehaviorDelegate? = nil

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(pageView:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(pageView: PageView) {
        self.pageView = pageView
        super.init(nibName: nil, bundle: nil)
        if pageView.page?.data?.kind == PageKind.MODAL {
            if let sheet = self.sheetPresentationController {
                sheet.detents = parseModalScreenSize(pageView.page?.data?.modalScreenSize)
            }
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        if let pageView = self.pageView {
            self.view = pageView
        }
        self.renderNavItems()
    }

    func setIsFirstModalToTrue() {
        self.isFirstModal = true
    }

    func renderNavItems() {
        let page = self.pageView?.page
        let buttonData = page?.data?.modalNavigationBackButton
        if buttonData?.visible == false {
            self.navigationItem.setHidesBackButton(true, animated: true)
            return
        } else {
            self.navigationItem.setHidesBackButton(false, animated: true)
        }
        let leftButton = UIBarButtonItem(
            title: "",
            style: .plain,
            target: self,
            action: #selector(onClickBack)
        )

        if let color = buttonData?.color {
            leftButton.tintColor = parseColor(color)
        }

        if self.isFirstModal {
            leftButton.title = "Close"
            if let title = buttonData?.title {
                if title != "" {
                    leftButton.title = title
                }
            }
            self.navigationItem.leftBarButtonItem = leftButton
        } else {
            leftButton.title = "Back"
            if let title = buttonData?.title {
                if title != "" {
                    leftButton.title = title
                }
            }
            self.navigationController?.navigationBar.topItem?.backBarButtonItem = leftButton
        }

        // set background of navigation bar to transparent
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        self.navigationController?.navigationBar.scrollEdgeAppearance = appearance
        self.navigationController?.navigationBar.standardAppearance = appearance
    }

    @objc func onClickBack() {
        if let backButtonBehaviorDelegate = self.backButtonBehaviorDelegate {
            backButtonBehaviorDelegate.onBackButtonClick()
        } else {
            self.navigationController?.popViewController(animated: true)
        }
    }
}

final class PageView: UIView {
    fileprivate let page: UIPageBlock?
    private let props: [Property]?
    private let renderContext: RenderContext
    private var data: Any? = nil
    private var actionHandler: UIBlockActionHandler? = nil
    private var fullScreenInitialNavItemVisibility = false
    private var loading: Bool = false
    private var view: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(page:props:renderContext:actionHandler:modalViewController:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        page: UIPageBlock?,
        props: [Property]?,
        renderContext: RenderContext,
        actionHandler: UIBlockActionHandler?,
        modalViewController: ModalComponentViewController?
    ) {
        self.page = page
        self.renderContext = renderContext
        self.modalViewController = modalViewController

        // build placeholder input. init.props is passed from other pages, and page.data.props are the page.props.
        // so merge them and create self.props.
        self.props = Self.mergeProps(pageProps: page?.data?.props, actionProps: props)

        self.data = renderContext.createVariableForTemplate(data: nil, properties: self.props)
        super.init(frame: .zero)

        let parentActionHandler = actionHandler
        self.actionHandler = { [weak self] action, onHttpSettled in
            guard let self else {
                return
            }

            let variable = _mergeVariable(
                base: self.data,
                self.renderContext.createVariableForTemplate(data: nil, properties: self.props)
            )

            let assertion = action.httpResponseAssertion
            let forwardAction = { () -> Void in
                Task { @MainActor in
                    parentActionHandler?(action, nil)
                }
            }

            if let httpRequest = action.httpRequest {
                Task { [weak self] in
                    guard let self else {
                        return
                    }
                    let result = await self.renderContext.sendHttpRequest(
                        req: httpRequest,
                        assertion: assertion,
                        variable: variable
                    )
                    switch result {
                    case .success:
                        await MainActor.run { onHttpSettled?() }
                        forwardAction()
                    case .failure:
                        await MainActor.run { onHttpSettled?() }
                        // TODO: handle error
                        forwardAction()
                    }
                }
            } else {
                forwardAction()
            }
        }

        // setup layout
        self.configureLayout { layout in
            layout.isEnabled = true
            if self.page?.data?.kind == .COMPONENT {
                if let height = self.page?.data?.frameHeight {
                    if height != 0 {
                        layout.height = YGValue(value: Float(height), unit: .point)
                    }
                }

                if let width = self.page?.data?.frameWidth {
                    if width != 0 {
                        layout.width = YGValue(value: Float(width), unit: .point)
                    }
                }
            }
        }
        self.addSubview(self.view)
        self.loadDataAndTransition()
    }

    func dispatchAction(_ action: UIBlockAction) {
        self.actionHandler?(action, nil)
    }

    @available(*, deprecated, renamed: "dispatchAction(_:)")
    func dispatch(action: UIBlockAction) {
        self.dispatchAction(action)
    }

    func loadDataAndTransition() {
        guard let httpRequest = self.page?.data?.httpRequest else {
            self.loading = false
            self.renderView()
            return
        }

        // when it has http request, render loading view, and then
        self.loading = true
        self.renderView()

        Task {
            let variable = self.renderContext.createVariableForTemplate(
                data: nil, properties: self.props)
            let result = await self.renderContext.sendHttpRequest(
                req: httpRequest,
                assertion: nil,
                variable: variable
            )
            await MainActor.run { [weak self] in
                switch result {
                case .success(let response):
                    self?.data = self?.renderContext.createVariableForTemplate(
                        data: response.data?.value, properties: self?.props)
                default:
                    break
                }
                self?.loading = false
                self?.renderView()
            }
        }
    }

    func renderView() {
        if let renderAs = self.page?.data?.renderAs {
            self.view.removeFromSuperview()
            self.view = UIViewBlock(
                data: renderAs,
                context: UIBlockContext(
                    UIBlockContextInit(
                        renderContext: self.renderContext,
                        variable: self.data,
                        actionHandler: self.actionHandler,
                        loading: self.loading
                    )
                ),
                respectSafeArea: self.page?.data?.modalRespectSafeArea
            )
            self.addSubview(self.view)

            // if it's transparent and it's modal, use systemBgColor as the background.
            // i think this should be refactored someday.
            if self.view.backgroundColor == nil && self.page?.data?.kind == .MODAL {
                self.view.backgroundColor = .systemBackground
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.updateModalYogaHeight()
        self.yoga.applyLayout(preservingOrigin: true)
    }

    private func updateModalYogaHeight() {
        guard self.page?.data?.kind == .MODAL,
              self.page?.data?.modalPresentationStyle == .DEPENDS_ON_CONTEXT_OR_PAGE_SHEET else {
            return
        }

        // Pin Yoga height to the host window size so it stays stable when a sheet detent changes,
        // while still respecting iPad multitasking / rotation (window size changes).
        guard let window = self.window ?? self.modalViewController?.view.window else {
            return
        }

        let availableHeight = window.bounds.height
        let safeAreaTop = window.safeAreaInsets.top

        let targetHeight: CGFloat
        switch self.page?.data?.modalScreenSize {
        case .MEDIUM:
            targetHeight = availableHeight * 0.5
        case .LARGE:
            targetHeight = availableHeight - safeAreaTop
        default:
            // Resizable (both MEDIUM and LARGE): use LARGE size
            targetHeight = availableHeight - safeAreaTop
        }

        self.yoga.height = YGValue(value: Float(max(0, targetHeight)), unit: .point)
    }

    private static func mergeProps(pageProps: [Property]?, actionProps: [Property]?) -> [Property] {
        guard let pageProps = pageProps else {
            return []
        }

        return pageProps.map { property in
            let actionProp = actionProps?.first { $0.name == property.name }
            return Property(
                name: property.name ?? "",
                value: actionProp?.value ?? property.value ?? "",
                ptype: property.ptype ?? PropertyType.STRING
            )
        }
    }
}
