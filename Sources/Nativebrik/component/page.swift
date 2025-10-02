//
//  page.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import YogaKit

// child of modal
class ModalPageViewController: UIViewController {
    private var isFirstModal = false
    private let pageView: PageView?

    required init?(coder: NSCoder) {
        self.pageView = nil
        super.init(coder: coder)
    }

    init(pageView: PageView) {
        self.pageView = pageView
        super.init(nibName: nil, bundle: nil)
        if pageView.page?.data?.kind == PageKind.MODAL {
            if #available(iOS 15.0, *) {
                if let sheet = self.sheetPresentationController {
                    sheet.detents = parseModalScreenSize(pageView.page?.data?.modalScreenSize)
                }
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
        self.navigationController?.popViewController(animated: true)
    }
}

class PageView: UIView {
    fileprivate let page: UIPageBlock?
    private let props: [Property]?
    private let container: Container
    private var data: Any? = nil
    private var event: UIBlockEventManager? = nil
    private var fullScreenInitialNavItemVisibility = false
    private var loading: Bool = false
    private var view: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil

    required init?(coder: NSCoder) {
        self.page = nil
        self.props = nil
        self.container = ContainerEmptyImpl()
        super.init(coder: coder)
    }

    init(
        page: UIPageBlock?,
        props: [Property]?,
        container: Container,
        event: UIBlockEventManager?,
        modalViewController: ModalComponentViewController?
    ) {
        self.page = page
        self.container = container
        self.modalViewController = modalViewController

        // build placeholder input. init.props is passed from other pages, and page.data.props are the page.props.
        // so merge them and create self.props.
        self.props =
            page?.data?.props?.enumerated().map { (index, property) in
                let propIndexInEvent =
                    props?.firstIndex(where: { prop in
                        return property.name == prop.name
                    }) ?? -1
                let propInEvent = propIndexInEvent >= 0 ? props![propIndexInEvent] : nil
                return Property(
                    name: property.name ?? "",
                    value: propInEvent?.value ?? property.value ?? "",
                    ptype: property.ptype ?? PropertyType.STRING
                )
            } ?? []

        self.data = container.createVariableForTemplate(data: nil, properties: self.props)
        super.init(frame: .zero)

        let parentEventManager = event
        // handle events that has http request, and then dispatch the event to parent.
        // here, we only process http request.
        self.event = UIBlockEventManager(on: { [weak self] dispatchedEvent, options in
            let variable = _mergeVariable(
                base: self?.data,
                self?.container.createVariableForTemplate(data: nil, properties: self?.props)
            )

            let assertion = dispatchedEvent.httpResponseAssertion
            let handleEvent = { () -> Void in
                Task { @MainActor in
                    parentEventManager?.dispatch(event: dispatchedEvent)
                }
            }
            if let httpRequest = dispatchedEvent.httpRequest {
                Task {
                    Task.detached { [weak self] in
                        let result = await self?.container.sendHttpRequest(
                            req: httpRequest,
                            assertion: assertion,
                            variable: variable
                        )
                        switch result {
                        case .success:
                            await MainActor.run {
                                options?.onHttpSettled?()
                                options?.onHttpSuccess?()
                            }
                            handleEvent()
                        case .failure:
                            await MainActor.run {
                                options?.onHttpSettled?()
                                options?.onHttpError?()
                            }
	                        // TODO: handle error
                            handleEvent()
                        default:
                            break
                        }
                    }
                }
            } else {
                handleEvent()
            }
        })

        // setup layout
        self.configureLayout { layout in
            layout.isEnabled = true
        }
        self.addSubview(self.view)
        self.loadDataAndTransition()
    }

    func dispatch(event: UIBlockEventDispatcher) {
        self.event?.dispatch(event: event)
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
            let variable = self.container.createVariableForTemplate(
                data: nil, properties: self.props)
            let result = await Task.detached {
                return await self.container.sendHttpRequest(
                    req: httpRequest, assertion: nil, variable: variable)
            }.value
            await MainActor.run { [weak self] in
                switch result {
                case .success(let response):
                    self?.data = self?.container.createVariableForTemplate(
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
                        container: self.container,
                        variable: self.data,
                        event: self.event,
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
//        self.yoga.applyLayout(preservingOrigin: true)
    }
}
