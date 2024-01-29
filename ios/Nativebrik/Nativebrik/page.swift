//
//  page.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import YogaKit

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
    }

    @objc func onClickBack() {
        self.navigationController?.popViewController(animated: true)
    }
}

class PageView: UIView {
    fileprivate let page: UIPageBlock?
    private let props: [Property]?
    private let config: Config
    private let repositories: Repositories?
    private var data: Any? = nil
    private let user: NativebrikUser?
    private var event: UIBlockEventManager? = nil
    private let form: UIBlockFormManager?
    private var fullScreenInitialNavItemVisibility = false
    private var loading: Bool = false
    private var view: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil

    required init?(coder: NSCoder) {
        self.page = nil
        self.props = nil
        self.config = Config()
        self.repositories = nil
        self.user = nil
        self.form = nil
        super.init(coder: coder)
    }

    init(
        page: UIPageBlock?,
        props: [Property]?,
        event: UIBlockEventManager?,
        form: UIBlockFormManager?,
        user: NativebrikUser?,
        config: Config,
        repositories: Repositories?,
        modalViewController: ModalComponentViewController?
    ) {
        self.page = page
        self.config = config
        self.repositories = repositories
        self.modalViewController = modalViewController
        self.user = user
        self.form = form

        // build placeholder input. init.props is passed from other pages, and page.data.props are the page.props.
        // so merge them and create self.props.
        self.props = page?.data?.props?.enumerated().map { (index, property) in
            let propIndexInEvent = props?.firstIndex(where: { prop in
                return property.name == prop.name
            }) ?? -1
            let propInEvent = propIndexInEvent >= 0 ? props![propIndexInEvent] : nil
            return Property(
                name: property.name ?? "",
                value: propInEvent?.value ?? property.value ?? "",
                ptype: property.ptype ?? PropertyType.STRING
            )
        } ?? []

        self.data = createDataForTemplate(CreateDataForTemplateOption(
            properties: self.props,
            user: self.user,
            form: self.form?.formValues
        ))

        super.init(frame: .zero)

        let parentEventManager = event
        // handle events that has http request, and then dispatch the event to parent.
        // here, we only process http request.
        self.event = UIBlockEventManager(on: { [weak self] dispatchedEvent in
            let context = UIBlockContext(UIBlockContextInit(
                data: createDataForTemplateFrom(base: self?.data, CreateDataForTemplateOption(
                    form: self?.form?.formValues
                ))
            ))

            let assertion = dispatchedEvent.httpResponseAssertion
            let handleEvent = { () -> () in
                DispatchQueue.main.async {
                    let event = UIBlockEventDispatcher(
                        name: dispatchedEvent.name,
                        destinationPageId: dispatchedEvent.destinationPageId,
                        deepLink: dispatchedEvent.deepLink,
                        payload: dispatchedEvent.payload?.map({ prop in
                            return Property(
                                name: prop.name ?? "",
                                value: compileTemplate(template: prop.value ?? "", getByPath: { key in
                                    return context.getByReferenceKey(key: key)
                                }),
                                ptype: prop.ptype ?? PropertyType.STRING
                            )
                        }),
                        httpRequest: dispatchedEvent.httpRequest,
                        httpResponseAssertion: dispatchedEvent.httpResponseAssertion
                    )
                    parentEventManager?.dispatch(event: dispatchedEvent)
                }
            }
            if let httpRequest = dispatchedEvent.httpRequest {
                Task {
                    self?.repositories?.httpRequest.fetch(request: httpRequest, assertion: assertion, placeholderReplacer: { key in
                        return context.getByReferenceKey(key: key)
                    }, callback: { entry in
                        if entry.state == .EXPECTED {
                            handleEvent()
                        }
                    })
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

    func loadDataAndTransition() {
        guard let httpRequest = self.page?.data?.httpRequest else {
            self.loading = false
            self.renderView()
            return
        }

        // when it has http request, render loading view, and then
        self.loading = true
        self.renderView()

        DispatchQueue.global().async {
            Task { [weak self] in
                let context = UIBlockContext(UIBlockContextInit(
                    data: createDataForTemplateFrom(base: self?.data, CreateDataForTemplateOption(
                        properties: self?.props,
                        user: self?.user,
                        form: self?.form?.formValues
                    ))
                ))
                self?.repositories?.httpRequest.fetch(request: httpRequest, assertion: nil, placeholderReplacer: { key in
                    return context.getByReferenceKey(key: key)
                }) { entry in
                    DispatchQueue.main.async { [weak self] in
                        if let data = entry.value?.data {
                            self?.data = createDataForTemplate(CreateDataForTemplateOption(
                                data: data.value,
                                properties: self?.props,
                                user: self?.user,
                                form: self?.form?.formValues
                            ))
                        }
                        self?.loading = false
                        self?.renderView()
                    }
                }
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
                        data: self.data,
                        event: self.event,
                        form: self.form,
                        loading: self.loading
                    )
                )
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
        self.yoga.applyLayout(preservingOrigin: true)
    }
}
