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
    private let user: NativebrikUser
    private let config: Config
    private let repositories: Repositories
    private var modalViewController: ModalComponentViewController? = nil
    private var currentVC: UIViewController? = nil

    required init?(coder: NSCoder) {
        self.user = NativebrikUser()
        self.config = Config()
        self.repositories = Repositories(config: config)
        super.init(coder: coder)
    }

    init(user: NativebrikUser, config: Config, repositories: Repositories, modalViewController: ModalComponentViewController?) {
        self.user = user
        self.config = config
        self.repositories = repositories
        self.modalViewController = modalViewController
        super.init(nibName: nil, bundle: nil)
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
        DispatchQueue.global().async {
            Task {

                await self.repositories.experiment.trigger(event: event) { entry in
                    guard let value = entry.value else {
                        return
                    }
                    let experimentConfigs = value.value
                    guard let extractedConfig = extractExperimentConfigMatchedToProperties(configs: experimentConfigs, properties: { seed in
                        return self.user.toEventProperties(seed: seed)
                    }) else {
                        return
                    }
                    guard let experimentId = extractedConfig.id else {
                        return
                    }
                    if extractedConfig.kind != .POPUP {
                        return
                    }
                    let normalizedUsrRnd = self.user.getSeededNormalizedUserRnd(seed: extractedConfig.seed ?? 0)
                    guard let extractedVariant = extractExperimentVariant(config: extractedConfig, normalizedUsrRnd: normalizedUsrRnd) else {
                        return
                    }
                    guard let variantConfig = extractedVariant.configs?[0] else {
                        return
                    }
                    guard let componentId = variantConfig.value else {
                        return
                    }

                    self.repositories.component.fetch(
                        experimentId: experimentId,
                        id: componentId
                    ) { entry in
                        DispatchQueue.main.sync {
                            guard let view = entry.value?.view else {
                                return
                            }
                            switch view {
                            case .EUIRootBlock(let root):
                                if let currentVC = self.currentVC {
                                    currentVC.dismiss(animated: true)
                                    currentVC.removeFromParent()
                                }
                                let rootController = ModalRootViewController(
                                    root: root,
                                    config: self.config,
                                    repositories: self.repositories,
                                    modalViewController: self.modalViewController
                                )
                                self.addChild(rootController)
                                self.currentVC = rootController
                            default:
                                return
                            }
                        }

                    }
                    
                }

            }
        }
    }
}

