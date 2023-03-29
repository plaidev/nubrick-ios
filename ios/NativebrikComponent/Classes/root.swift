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
    private var event: UIBlockEventManager? = nil

    required init?(coder: NSCoder) {
        self.page = nil
        super.init(coder: coder)
    }
    
    init(page: UIPageBlock?, event: UIBlockEventManager?) {
        self.page = page
        self.event = event
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidLoad() {
        if let renderAs = self.page?.data?.renderAs {
            self.view.addSubview(
                UIViewBlock(
                    data: renderAs,
                    context: UIBlockContext(
                        data: nil,
                        event: self.event,
                        parentClickListener: nil
                    )
                )
            )
        }
        
        self.view.yoga.isEnabled = true
        self.view.yoga.display = .flex
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.yoga.applyLayout(preservingOrigin: true)
    }
    
}

class RootViewController: UIViewController {
    private let id: String!
    private let pages: [UIPageBlock]!
    private var event: UIBlockEventManager? = nil
    private var currentPageId: String = ""
    private var currentPVC: PageViewController? = nil

    required init?(coder: NSCoder) {
        self.id = ""
        self.pages = []
        super.init(coder: coder)
    }
    
    init(root: UIRootBlock?) {
        self.id = root?.id ?? ""
        self.pages = root?.data?.pages ?? []
        self.currentPageId = root?.data?.currentPageId ?? ""
        super.init(nibName: nil, bundle: nil)

        self.event = UIBlockEventManager(on: { event in
            if let destPageId = event.destinationPageId {
                self.presentPage(pageId: destPageId)
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

        self.presentPage(pageId: self.currentPageId)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.parent?.viewDidLayoutSubviews()
    }
    
    func presentPage(pageId: String) {
        if let previous = self.currentPVC {
//            self.view.transform = CGAffineTransform(translationX: 0, y: 0)
//            UIView.animate(
//                withDuration: 0.28,
//                delay: 0.1,
//                options: .curveEaseInOut,
//                animations: {
//                    self.view.transform = CGAffineTransform(translationX: 400, y: 0)
//                },
//                completion: {_ in
//                    previous.view.removeFromSuperview()
//                    previous.removeFromParent()
//                }
//            )
            previous.view.removeFromSuperview()
            previous.removeFromParentViewController()
        }
        
        print("presentPage", pageId)
        let page = self.pages.first { page in
            return pageId == page.id
        }
        let pageController = PageViewController(page: page, event: self.event)
        self.addChildViewController(pageController)
        self.currentPVC = pageController
        self.view.addSubview(pageController.view)
    }
}

public class ComponentViewController: UIViewController {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    init(componentId: String, apiKey: String, url: String) {
        super.init(nibName: nil, bundle: nil)
        
        self.loadComponent(componentId: componentId, apiKey: apiKey, url: url)
    }
    
    override public func viewDidLoad() {
        self.view.configureLayout { layout in
            layout.isEnabled = true
            layout.alignItems = .center
            layout.justifyContent = .center
        }
    }
    
    func loadComponent(componentId: String, apiKey: String, url: String) {
        DispatchQueue.global().async {
            Task {
                let data = try await getComponent(
                    query: getComponentQuery(id: componentId),
                    apiKey: apiKey,
                    url: url
                )
                DispatchQueue.main.async {
                    if let view = data.data?.component??.view {
                        switch view {
                        case .EUIRootBlock(let root):
                            let rootController = RootViewController(root: root)
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
    let apiKey: String
    let url: String

    func makeUIViewController(context: Context) -> ComponentViewController {
        return ComponentViewController(
            componentId: self.componentId,
            apiKey: self.apiKey,
            url: self.url
        )
    }

    func updateUIViewController(_ uiViewController: ComponentViewController, context: Context) {
    }
}
