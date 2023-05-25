//
//  trigger.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/05/08.
//

import Foundation
import UIKit
import SwiftUI

enum UserDefaultsKeys: String {
    case SDK_INITIALIZED_COUNT = "NATIVEBRIK_SDK_ININITALIZED_COUNT"
}

class TriggerViewController: UIViewController {
    private let config: Config
    private var currentVC: UIViewController? = nil

    required init?(coder: NSCoder) {
        self.config = Config()
        super.init(coder: coder)
    }

    init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        self.view.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        self.dispatchInitialized()
        self.dispatchUserFirstVisit()
    }

    func dispatchInitialized() {
        self.dispatch(event: TriggerEventFactory.sdkInitialized())
    }

    func dispatchUserFirstVisit() {
        let count = UserDefaults.standard.object(forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue) as? Int ?? 0
        UserDefaults.standard.set(count + 1, forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue)
        if count == 0 {
            self.dispatch(event: TriggerEventFactory.userFirstVisit())
        }

    }

    func dispatch(event: TriggerEvent) {
        let eventInput = TriggerEventInput(name: event.name)
        DispatchQueue.global().async {
            Task {
                do {
                    let data = try await getComponentByTrigger(
                        query: getComponentByTriggerQuery(event: eventInput),
                        apiKey: self.config.apiKey,
                        url: self.config.url
                    )
                    if data.errors != nil {
                        return
                    }
                    if let view = data.data?.trigger??.view {
                        switch view {
                        case .EUIRootBlock(let root):
                            if let currentVC = self.currentVC {
                                currentVC.dismiss(animated: true)
                                currentVC.removeFromParent()
                                currentVC.view.removeFromSuperview()
                            }
                            let rootController = RootViewController(root: root, config: self.config)
                            self.addChild(rootController)
                            self.view.addSubview(rootController.view)
                            self.currentVC = rootController
                        default:
                            return
                        }
                    }
                } catch {
                    return
                }
            }
        }
    }
}

struct TriggerViewControllerRepresentable: UIViewControllerRepresentable {
    let config: Config
    
    func makeUIViewController(context: Context) -> TriggerViewController {
        return TriggerViewController(
            config: self.config
        )
    }

    func updateUIViewController(_ uiViewController: TriggerViewController, context: Context) {
    }
}
