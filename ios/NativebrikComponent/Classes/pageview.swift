//
//  pageview.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit

class PageViewController: UIPageViewController, UIPageViewControllerDelegate {
    fileprivate let controllers: [UIViewController]
    fileprivate let controllersIdMap: Dictionary<String, UIViewController>
    fileprivate let pageControl: UIPageControl
    
    init(controllers: [UIViewController], ids: [String]) {
        self.controllers = controllers
        self.controllersIdMap = Dictionary(uniqueKeysWithValues: ids.enumerated().map({ (index, id) in
            return (id, controllers[index])
        }))
        self.pageControl = UIPageControl(frame: CGRect(x: 0,y: UIScreen.main.bounds.maxY - 140, width: UIScreen.main.bounds.width, height: 30))
        self.pageControl.numberOfPages = self.controllers.count
        self.pageControl.currentPage = 0
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    override init(transitionStyle style: UIPageViewControllerTransitionStyle, navigationOrientation: UIPageViewControllerNavigationOrientation, options: [String : Any]? = nil) {
        self.controllers = []
        self.controllersIdMap = [:]
        self.pageControl = UIPageControl()
        super.init(transitionStyle: style, navigationOrientation: navigationOrientation, options: options)
    }
    
    required init?(coder: NSCoder) {
        self.controllers = []
        self.controllersIdMap = [:]
        self.pageControl = UIPageControl()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.configureLayout { layout in
            layout.isEnabled = true
            layout.display = .flex
            layout.alignItems = .center
            layout.justifyContent = .center
        }
        view.backgroundColor = .systemBackground
        self.dataSource = self
        self.delegate = self
        if let first = self.controllers.first {
            self.setViewControllers([first], direction: .forward, animated: true)
        }
        self.pageControl.addTarget(self, action: #selector(self.pageControlSelectionAction(_:)), for: .touchUpInside)
        self.pageControl.addTarget(self, action: #selector(self.pageControlSelectionAction(_:)), for: .touchDragInside)

        self.view.addSubview(self.pageControl)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.parent?.viewDidLayoutSubviews()
    }
    
    func isInPage(id: String) -> Bool {
        return self.controllersIdMap.contains { (key: String, value: UIViewController) in
            return key == id
        }
    }
    
    func goTo(id: String) {
        if let vc = self.controllersIdMap[id] {
            let currentIndex = self.pageControl.currentPage
            let nextIndex = self.controllers.firstIndex(of: vc) ?? 0
            if currentIndex == nextIndex {
                return
            }
            let direction = currentIndex > nextIndex ? NavigationDirection.reverse : NavigationDirection.forward
            self.setViewControllers([vc], direction: direction, animated: true)
        }
    }
    
    func goToByIndex(index: Int, from: Int) {
        if index < 0 || self.controllers.count <= index {
            return
        }
        let vc = self.controllers[index]
        if from == index {
            return
        }
        let direction = from > index ? NavigationDirection.reverse : NavigationDirection.forward
        self.setViewControllers([vc], direction: direction, animated: true)
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        if completed {
            if let currentViewController = pageViewController.viewControllers?[0] {
                let index = self.controllers.firstIndex(of: currentViewController)
                self.pageControl.currentPage = index ?? 0
            }
        }
    }
    
    override func setViewControllers(_ viewControllers: [UIViewController]?, direction: UIPageViewControllerNavigationDirection, animated: Bool, completion: ((Bool) -> Void)? = nil) {
        super.setViewControllers(viewControllers, direction: direction, animated: animated, completion: completion)
        if let vc = viewControllers?.first {
            let index = self.controllers.firstIndex(of: vc)
            self.pageControl.currentPage = index ?? 0
        }
    }
    
    @objc func pageControlSelectionAction(_ sender: UIPageControl) {
        let fromIndex = sender.currentPage
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
            let index = sender.currentPage
            self.goToByIndex(index: index, from: fromIndex)
        })
    }
}

extension PageViewController: UIPageViewControllerDataSource {
    func presentationCount(for pageViewController: UIPageViewController) -> Int {
        return self.controllers.count
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let index = self.controllers.firstIndex(of: viewController),
            index < self.controllers.count - 1 {
            return self.controllers[index + 1]
        } else {
            return nil
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let index = self.controllers.firstIndex(of: viewController),
            index > 0 {
            return self.controllers[index - 1]
        } else {
            return nil
        }
    }
}
