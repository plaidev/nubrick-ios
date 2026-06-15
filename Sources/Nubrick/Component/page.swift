//
//  page.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Combine
import Foundation
import UIKit
internal import YogaKit

private struct CompiledPageRequest: Equatable {
    struct Header: Equatable { let name: String; let value: String }
    let url: String
    let body: String
    let headers: [Header]
}

private struct PageHttpRequestSnapshot {
    let compiledRequest: CompiledPageRequest
    let variable: Variable?
}

// child of modal
class ModalPageViewController: UIViewController {
    private var isFirstModal = false
    private let pageView: PageView?
    var backButtonBehaviorDelegate: ModalBackButtonBehaviorDelegate? = nil

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
    private let container: Container
    private var arguments: NubrickArguments?
    private let variableStore: VariableStore
    private var responseData: Any? = nil
    private var actionHandler: UIBlockActionHandler? = nil
    private var fullScreenInitialNavItemVisibility = false
    private var view: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil
    private var cancellables = Set<AnyCancellable>()
    private var pageHttpRequestTask: Task<Void, Never>?
    private var pageHttpRequestSequence = 0

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(page:props:container:arguments:actionHandler:modalViewController:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        page: UIPageBlock?,
        props: [Property]?,
        container: Container,
        arguments: NubrickArguments?,
        actionHandler: UIBlockActionHandler?,
        modalViewController: ModalComponentViewController?
    ) {
        self.page = page
        self.container = container
        self.arguments = arguments
        self.modalViewController = modalViewController

        // build placeholder input. init.props is passed from other pages, and page.data.props are the page.props.
        // so merge them and create self.props.
        self.props = Self.mergeProps(pageProps: page?.data?.props, actionProps: props)
        self.variableStore = VariableStore(container.createVariableForTemplate(
            data: nil,
            properties: self.props,
            arguments: arguments
        ), loading: page?.data?.httpRequest != nil)
        super.init(frame: .zero)

        container.formDataPublisher()
            .dropFirst()
            .sink { [weak self] formData in
                self?.variableStore.updateForm(formData)
            }
            .store(in: &self.cancellables)

        container.userDataPublisher()
            .dropFirst()
            .sink { [weak self] userData in
                self?.variableStore.updateUser(userData)
            }
            .store(in: &self.cancellables)

        self.actionHandler = { [weak self] action, onHttpSettled in
            guard let self else {
                return
            }

            let variable = self.currentVariable()

            let assertion = action.httpResponseAssertion
            let forwardAction = { () -> Void in
                Task { @MainActor in
                    actionHandler?(action, nil)
                }
            }

            if let httpRequest = action.httpRequest {
                Task { [weak self] in
                    guard let self else {
                        return
                    }
                    let result = await self.container.sendHttpRequest(
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
                if let height = self.page?.data?.frameHeight, height != 0 {
                    layout.height = YGValue(value: Float(height), unit: .point)
                }

                if let width = self.page?.data?.frameWidth, width != 0 {
                    layout.width = YGValue(value: Float(width), unit: .point)
                }
            }
        }
        self.addSubview(self.view)
        self.loadDataAndTransition()
    }

    deinit {
        self.pageHttpRequestTask?.cancel()
    }

    func dispatchAction(_ action: UIBlockAction) {
        self.actionHandler?(action, nil)
    }

    func currentVariable() -> Variable? {
        self.variableStore.variable
    }

    func update(arguments: NubrickArguments?) {
        guard self.arguments != nil || arguments != nil else {
            return
        }
        self.arguments = arguments
        self.variableStore.update(self.createVariable())
    }

    @available(*, deprecated, renamed: "dispatchAction(_:)")
    func dispatch(action: UIBlockAction) {
        self.dispatchAction(action)
    }

    func loadDataAndTransition() {
        guard let httpRequest = self.page?.data?.httpRequest else {
            self.renderView()
            return
        }

        self.renderView()

        variableStore.publisher()
            .map { variable -> PageHttpRequestSnapshot in
                let compiledRequest = CompiledPageRequest(
                    url: compile(httpRequest.url ?? "", variable),
                    body: compile(httpRequest.body ?? "", variable),
                    headers: (httpRequest.headers ?? []).map {
                        .init(name: compile($0.name ?? "", variable),
                              value: compile($0.value ?? "", variable))
                    }
                )
                return PageHttpRequestSnapshot(compiledRequest: compiledRequest, variable: variable)
            }
            .removeDuplicates { previous, current in
                previous.compiledRequest == current.compiledRequest
            }
            .sink { [weak self] snapshot in
                guard let self else { return }
                let variable = snapshot.variable
                self.pageHttpRequestSequence += 1
                let requestSequence = self.pageHttpRequestSequence
                self.pageHttpRequestTask?.cancel()
                self.variableStore.updateLoading(true)
                let container = self.container
                self.pageHttpRequestTask = Task { [weak self, container] in
                    let result = await container.sendHttpRequest(
                        req: httpRequest,
                        assertion: nil,
                        variable: variable
                    )
                    await MainActor.run { [weak self] in
                        guard let self else { return }
                        guard self.pageHttpRequestSequence == requestSequence else {
                            return
                        }
                        defer {
                            if self.pageHttpRequestSequence == requestSequence {
                                self.variableStore.updateLoading(false)
                                self.pageHttpRequestTask = nil
                            }
                        }
                        guard !Task.isCancelled else {
                            return
                        }
                        if case .success(let response) = result {
                            self.responseData = response.data?.value
                            self.variableStore.updateData(response.data?.value)
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func renderView() {
        if let renderAs = self.page?.data?.renderAs {
            self.view.removeFromSuperview()
            self.view = UIViewBlock(
                data: renderAs,
                context: UIBlockContext(
                    UIBlockContextInit(
                        container: self.container,
                        variableStore: self.variableStore,
                        actionHandler: self.actionHandler,
                        layoutInvalidationRoot: self
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

    private func createVariable() -> Variable? {
        self.container.createVariableForTemplate(
            data: self.responseData,
            properties: self.props,
            arguments: self.arguments
        )
    }
}
