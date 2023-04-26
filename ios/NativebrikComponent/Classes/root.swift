//
//  root.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit
import SwiftUI

class PageViewController: UIViewController {
    private let page: UIPageBlock?
    private let props: [Property]?
    private let config: Config
    private var data: JSON? = nil
    private var event: UIBlockEventManager? = nil
    private var fullScreenInitialNavItemVisibility = false

    required init?(coder: NSCoder) {
        self.page = nil
        self.props = nil
        self.config = Config(apiKey: "")
        super.init(coder: coder)
    }
    
    init(page: UIPageBlock?, props: [Property]?, event: UIBlockEventManager?, config: Config) {
        self.page = page
        self.props = props
        self.config = config
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }
    
    func showFullScreenInitialNavItem() {
        self.fullScreenInitialNavItemVisibility = true
    }
    
    override func viewDidLoad() {
        self.renderView()
        self.renderNavItems()
        self.loadData()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.yoga.applyLayout(preservingOrigin: true)
    }
    
    func renderView() {
        if let renderAs = self.page?.data?.renderAs {
            self.view = UIViewBlock(
                data: renderAs,
                context: UIBlockContext(
                    data: self.data,
                    event: self.event,
                    parentClickListener: nil,
                    parentDirection: nil
                )
            )
        }
    }
    
    func loadData() {
        let query = self.page?.data?.query ?? ""
        if query == "" {
            self.renderView()
            return
        }
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
                let data = try await getData(
                    query: getDataQuery(
                        query: query,
                        placeholder: placeholderInput
                    ),
                    apiKey: self.config.apiKey,
                    url: self.config.url
                )
                DispatchQueue.main.async {
                    if let data = data.data?.data {
                        self.data = data
                    }
                    self.renderView()
                }
            }
        }
    }
    
    func renderNavItems() {
        if !self.fullScreenInitialNavItemVisibility {
            return
        }
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Close", style: .plain, target: self, action: #selector(onDismiss))
    }
    
    @objc func onDismiss(){
        self.dismiss(animated: true)
    }
}

class RootViewController: UIViewController {
    private let id: String!
    private let pages: [UIPageBlock]!
    private let config: Config
    private var event: UIBlockEventManager? = nil
    private var currentPageId: String = ""
    private var currentNC: UINavigationController? = nil
    private var currentPVC: UIViewController? = nil

    required init?(coder: NSCoder) {
        self.id = ""
        self.pages = []
        self.config = Config(apiKey: "")
        super.init(coder: coder)
    }
    
    init(root: UIRootBlock?, config: Config) {
        self.id = root?.id ?? ""
        self.pages = root?.data?.pages ?? []
        let trigger = self.pages.first { page in
            return page.data?.kind == PageKind.TRIGGER
        }
        self.currentPageId = trigger?.id ?? root?.data?.currentPageId ?? ""
        self.config = config
        super.init(nibName: nil, bundle: nil)

        self.event = UIBlockEventManager(on: { event in
            if let destPageId = event.destinationPageId {
                self.presentPage(
                    pageId: destPageId,
                    props: event.payload
                )
            }
        })
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.configureLayout { layout in
            layout.isEnabled = true
            
            layout.display = .flex
            layout.alignItems = .center
            layout.justifyContent = .center
        }

        self.presentPage(pageId: self.currentPageId, props: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.parent?.viewDidLayoutSubviews()
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
        
        // when it's dismissed
        if page?.data?.kind == PageKind.DISMISSED {
            if let previous = self.currentPVC {
                previous.view.removeFromSuperview()
                previous.removeFromParentViewController()
            }
            self.dismiss(animated: true)
            return
        }
        
        let pageController = PageViewController(
            page: page,
            props: props,
            event: self.event,
            config: self.config
        )
        
        switch page?.data?.kind {
        case .PAGE_SHEET:
            if let sheet = pageController.sheetPresentationController {
                sheet.detents = [.medium(), .large()]
            }
            if let presentedVC = self.presentedViewController {
                presentedVC.present(pageController, animated: true, completion: nil)
            } else {
                self.present(pageController, animated: true, completion: nil)
            }
            break
        case .FULL_SCREEN:
            if self.presentedViewController == nil {
                self.currentNC = nil
            }
            if let nc = self.currentNC {
                nc.pushViewController(pageController, animated: true)
            } else {
                if self.currentPVC != nil {
                    pageController.showFullScreenInitialNavItem()
                }
                let currentNC = NavigationViewControlller(
                    rootViewController: pageController,
                    hasPrevious: self.currentPVC != nil
                )
                currentNC.modalPresentationStyle = .overFullScreen
                self.currentNC = currentNC
                if let presentedVC = self.presentedViewController {
                    presentedVC.present(currentNC, animated: true, completion: nil)
                } else {
                    self.present(currentNC, animated: true, completion: nil)
                }
            }
            break
        default:
            if let previous = self.currentPVC {
                previous.view.removeFromSuperview()
                previous.removeFromParentViewController()
            }
            self.dismiss(animated: true)
            let newPVC = pageController
            self.view.addSubview(newPVC.view)
            self.addChildViewController(newPVC)
            self.currentPVC = newPVC
            break
        }
    }
    
     @objc func dismissModal() {
         self.presentedViewController?.dismiss(animated: true)
    }
}

public class ComponentViewController: UIViewController {
    private let config: Config
    required init?(coder: NSCoder) {
        self.config = Config(apiKey: "")
        super.init(coder: coder)
    }
    
    init(componentId: String, config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        self.loadComponent(componentId: componentId)
    }
    
    override public func viewDidLoad() {
        self.view.configureLayout { layout in
            layout.isEnabled = true
            layout.alignItems = .center
            layout.justifyContent = .center
        }
    }
    
    private func loadComponent(componentId: String) {
        DispatchQueue.global().async {
            Task {
                let data = try await getComponent(
                    query: getComponentQuery(id: componentId),
                    apiKey: self.config.apiKey,
                    url: self.config.url
                )
                DispatchQueue.main.async {
                    if let view = data.data?.component??.view {
                        switch view {
                        case .EUIRootBlock(let root):
                            let rootController = RootViewController(
                                root: root,
                                config: self.config
                            )
                            self.addChildViewController(rootController)
                            self.view.addSubview(rootController.view)
                        default:
                            print("ERROR")
                        }
                    }
                }
            }
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.yoga.applyLayout(preservingOrigin: true)
    }
}

struct ComponentViewControllerRepresentable: UIViewControllerRepresentable {
    let componentId: String
    let config: Config

    func makeUIViewController(context: Context) -> ComponentViewController {
        return ComponentViewController(
            componentId: self.componentId,
            config: self.config
        )
    }

    func updateUIViewController(_ uiViewController: ComponentViewController, context: Context) {
    }
}
