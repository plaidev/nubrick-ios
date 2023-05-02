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
