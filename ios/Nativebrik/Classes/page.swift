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
    private var data: JSON? = nil
    private var event: UIBlockEventManager? = nil
    private var fullScreenInitialNavItemVisibility = false
    private var loading: Bool = false
    private var view: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil

    required init?(coder: NSCoder) {
        self.page = nil
        self.props = nil
        self.config = Config()
        self.repositories = nil
        super.init(coder: coder)
    }

    init(
        page: UIPageBlock?,
        props: [Property]?,
        event: UIBlockEventManager?,
        config: Config,
        repositories: Repositories?,
        modalViewController: ModalComponentViewController?
    ) {
        self.page = page
        self.props = props
        self.config = config
        self.repositories = repositories
        self.event = event
        self.modalViewController = modalViewController
        super.init(frame: .zero)
        self.configureLayout { layout in
            layout.isEnabled = true
        }
        self.addSubview(self.view)

        self.loadDataAndTransition()
    }

    func loadDataAndTransition() {
        let query = self.page?.data?.query ?? ""
        if query == "" {
            self.loading = false
            self.renderView()
            return
        }

        // when it has query, render loading view, and then
        self.loading = true
        
        self.renderView()

        // build placeholder input
        let properties: [PropertyInput] = self.page?.data?.props?.enumerated().map { (index, property) in
            let propIndexInEvent = self.props?.firstIndex(where: { prop in
                return property.name == prop.name
            }) ?? -1
            let propInEvent = propIndexInEvent >= 0 ? self.props![propIndexInEvent] : nil

            return PropertyInput(
                name: property.name ?? "",
                value: propInEvent?.value ?? property.value ?? "",
                ptype: property.ptype ?? PropertyType.STRING
            )
        } ?? []
        let placeholderInput = PlaceholderInput(properties: properties)

        DispatchQueue.global().async {
            Task {
                await self.repositories?.queryData.fetch(query: query, placeholder: placeholderInput) { entry in
                    DispatchQueue.main.async {
                        if let data = entry.value?.data {
                            self.data = data
                        }
                        self.loading = false
                        self.renderView()
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
                    data: self.data,
                    event: self.event,
                    parentClickListener: nil,
                    parentDirection: nil,
                    loading: self.loading
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
