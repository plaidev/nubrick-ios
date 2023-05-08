//
//  root.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit
import YogaKit

class RootViewController: UIViewController {
    private let id: String!
    private let pages: [UIPageBlock]!
    private let config: Config
    private var event: UIBlockEventManager? = nil
    private var currentPageId: String = ""
    private var currentNC: UINavigationController? = nil
    private var currentPVC: PageViewController? = nil
    private var currentPC: UIViewController? = nil

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
            self.config.dispatchUIBlockEvent(event: event)
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
        
        let pageController = PageController(
            page: page,
            props: props,
            event: self.event,
            config: self.config
        )
        
        switch page?.data?.kind {
        case .PAGE_SHEET:
            self.presentToTop(pageController)
            break
        case .FULL_SCREEN:
            if self.presentedViewController == nil {
                self.currentNC = nil
            }
            if let nc = self.currentNC {
                nc.pushViewController(pageController, animated: true)
            } else {
                if self.currentPC != nil {
                    pageController.showFullScreenInitialNavItem()
                }
                let currentNC = NavigationViewControlller(
                    rootViewController: pageController,
                    hasPrevious: self.currentPC != nil
                )
                currentNC.modalPresentationStyle = .overFullScreen
                self.currentNC = currentNC
                self.presentToTop(currentNC)
            }
            break
        case .PAGE_VIEW:
            if self.presentedViewController == nil {
                self.currentPVC = nil
            }
            if let pvc = self.currentPVC {
                if pvc.isInPage(id: pageId) {
                    pvc.goTo(id: pageId)
                    break
                } else {
                    pvc.dismiss(animated: true)
                    self.currentPVC = nil
                }
            }

            let pageBlocks = getLinkedPageViewsFromPages(pages: pages, id: pageId)
            let pageIds = pageBlocks.map { page in
                return page.id ?? ""
            }
            let controllers = pageBlocks.map { page in
                return PageController(
                    page: page,
                    props: props,
                    event: self.event,
                    config: self.config
                )
            }
            let pvc = PageViewController(controllers: controllers, ids: pageIds)
            pvc.modalPresentationStyle = .overFullScreen
            self.presentToTop(pvc)
            self.currentPVC = pvc
            break
        default:
            if let previous = self.currentPC {
                previous.view.removeFromSuperview()
                previous.removeFromParentViewController()
            }
            self.dismiss(animated: true)
            let newPC = pageController
            self.view.addSubview(newPC.view)
            self.addChildViewController(newPC)
            self.currentPC = newPC
            break
        }
    }
    
    func presentToTop(_ viewController: UIViewController) {
        if let presentedVC = self.presentedViewController {
            presentedVC.present(viewController, animated: true, completion: nil)
        } else {
            self.present(viewController, animated: true, completion: nil)
        }
    }
    
     @objc func dismissModal() {
         self.presentedViewController?.dismiss(animated: true)
    }
}

func getLinkedPageViewsFromPages(pages: [UIPageBlock], id: String) -> [UIPageBlock] {
    var result: [UIPageBlock] = []
    var currentId: String = id
    var trackedIds: [String] = []
    var counter: Int = 0
    let pageViewIds = pages.filter { page in
        return page.data?.kind == PageKind.PAGE_VIEW
    }.map { page in
        return page.id ?? ""
    }
    
    // add limit to while.
    while counter < 100 {
        counter += 1
        if trackedIds.contains(where: { id in
            return id == currentId
        }) {
            break
        }
        trackedIds.append(currentId)

        let page = pages.first { page in
            return page.id == currentId && page.data?.kind == PageKind.PAGE_VIEW
        }
        if let page = page {
            if let renderAs = page.data?.renderAs {
                let eventDispatchers = findEventDispatcherToPageView(
                    block: renderAs,
                    pageViewIds: pageViewIds
                )
                if let destId = eventDispatchers.first?.destinationPageId {
                    currentId = destId
                }
            }
            result.append(page)
        } else {
            break
        }
    }
    
    return result
}

func findEventDispatcherToPageView(block: UIBlock, pageViewIds: [String]) -> [UIBlockEventDispatcher] {
    var events: [UIBlockEventDispatcher] = []
    walkOnClick(block: block) { event in
        events.append(event)
    }
    return events.filter { event in
        return pageViewIds.contains { id in
            return event.destinationPageId == id
        }
    }
}

func walkOnClick(block: UIBlock, onWalk: ((_ event: UIBlockEventDispatcher) -> Void)) -> Void {
    switch block {
    case .EUIFlexContainerBlock(let block):
        if let event = block.data?.onClick {
            onWalk(event)
        }
        block.data?.children?.forEach({ block in
            walkOnClick(block: block, onWalk: onWalk)
        })
    case .EUICollectionBlock(let block):
        if let event = block.data?.onClick {
            onWalk(event)
        }
        block.data?.children?.forEach({ block in
            walkOnClick(block: block, onWalk: onWalk)
        })
    case .EUITextBlock(let block):
        if let event = block.data?.onClick {
            onWalk(event)
        }
    case .EUIImageBlock(let block):
        if let event = block.data?.onClick {
            onWalk(event)
        }
    default:
        return
    }
}
