//
//  component.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import SwiftUI
import YogaKit

class ComponentViewController: UIViewController {
    private let componentId: String
    private let config: Config
    private let fallback: ((_ state: LoadingState) -> UIView)?
    private var fallbackView: UIView = UIView()
    required init?(coder: NSCoder) {
        self.config = Config(apiKey: "")
        self.fallback = nil
        self.componentId = ""
        super.init(coder: coder)
    }
    
    init(
        componentId: String,
        config: Config,
        fallback: ((_ state: LoadingState) -> UIView)?
    ) {
        self.config = config
        self.fallback = fallback
        self.componentId = componentId
        super.init(nibName: nil, bundle: nil)
    }
    
    override public func viewDidLoad() {
        self.view.configureLayout { layout in
            layout.isEnabled = true
            layout.alignItems = .center
            layout.justifyContent = .center
        }
        if let fallback = self.fallback {
            let fallbackView = fallback(.LOADING)
            self.view.addSubview(fallbackView)
            self.fallbackView = fallbackView
        }
        self.loadComponent(componentId: self.componentId)
    }
    
    private func loadComponent(componentId: String) {
        DispatchQueue.global().async {
            Task {
                do {
                    let data = try await getComponent(
                        query: getComponentQuery(id: componentId),
                        apiKey: self.config.apiKey,
                        url: self.config.url
                    )
                    DispatchQueue.main.async {
                        if data.errors != nil {
                            self.renderFallback(state: .ERROR)
                        }
                        if let view = data.data?.component??.view {
                            switch view {
                            case .EUIRootBlock(let root):
                                let rootController = RootViewController(
                                    root: root,
                                    config: self.config
                                )
                                self.addChildViewController(rootController)
                                UIView.transition(
                                    from: self.fallbackView,
                                    to: rootController.view,
                                    duration: 0.2,
                                    options: .transitionCrossDissolve)
                            default:
                                self.renderFallback(state: .ERROR)
                            }
                        }
                    }
                } catch {
                    self.renderFallback(state: .ERROR)
                }
            }
        }
    }
    
    func renderFallback(state: LoadingState) {
        if let fallback = self.fallback {
            let fallbackView = fallback(state)
            UIView.transition(
                from: self.fallbackView,
                to: fallbackView,
                duration: 0.1,
                options: .transitionCrossDissolve,
                completion: nil)
            self.fallbackView = fallbackView
        }
    }
    
    override public func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.view.yoga.applyLayout(preservingOrigin: true)
    }
}

struct ComponentViewControllerRepresentable<V: View>: UIViewControllerRepresentable {
    let componentId: String
    let config: Config
    let fallback: ((_ state: LoadingState) -> V)?

    func makeUIViewController(context: Context) -> ComponentViewController {
        var fallbackFunc: ((_ state: LoadingState) -> UIView)? = nil
        if let fallback = self.fallback {
            fallbackFunc = { state in
                let hostingController = UIHostingController(rootView: fallback(state))
                return hostingController.view
            }
        }
        return ComponentViewController(
            componentId: self.componentId,
            config: self.config,
            fallback: fallbackFunc
        )
    }

    func updateUIViewController(_ uiViewController: ComponentViewController, context: Context) {
    }
}
