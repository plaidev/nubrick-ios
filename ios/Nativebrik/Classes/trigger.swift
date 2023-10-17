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
    private let repositories: Repositories?
    private var modalViewController: ModalComponentViewController? = nil
    private var currentVC: UIViewController? = nil
    private var didLoaded = false

    required init?(coder: NSCoder) {
        self.user = NativebrikUser()
        self.config = Config()
        self.repositories = nil
        super.init(coder: coder)
    }

    init(user: NativebrikUser, config: Config, repositories: Repositories, modalViewController: ModalComponentViewController?) {
        self.user = user
        self.config = config
        self.repositories = repositories
        self.modalViewController = modalViewController
        super.init(nibName: nil, bundle: nil)
    }

    func initialLoad() {
        self.didLoaded = true

        // dispatch an event when the user is only booted
        self.dispatch(event: TriggerEvent(TriggerEventNameDefs.USER_BOOT_APP.rawValue))

        // dispatch user enter the app firtly
        let count = UserDefaults.standard.object(forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue) as? Int ?? 0
        UserDefaults.standard.set(count + 1, forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue)
        if count == 0 {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY.rawValue))
        }

        // dispatch retention event
        self.callWhenUserComeBack()

        // dipatch retention event when user come back to foreground
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func willEnterForeground() {
        self.dispatch(event: TriggerEvent(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue))
        self.callWhenUserComeBack()
    }

    func callWhenUserComeBack() {
        self.user.comeBack()
        
        // dispatch the event when every time the user is activated
        self.dispatch(event: TriggerEvent(TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue))

        let retention = self.user.retention
        if retention == 1 {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.RETENTION_1.rawValue))
        } else if 1 < retention && retention <= 3 {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.RETENTION_2_3.rawValue))
        } else if 3 < retention && retention <= 7 {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.RETENTION_4_7.rawValue))
        } else if 7 < retention && retention <= 14 {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.RETENTION_8_14.rawValue))
        } else if 14 < retention {
            self.dispatch(event: TriggerEvent(TriggerEventNameDefs.RETENTION_15.rawValue))
        }
    }

    func dispatch(event: TriggerEvent) {
        DispatchQueue.global().async {
            Task {
                if event.name.isEmpty {
                    return
                }
                self.repositories?.track.trackEvent(TrackUserEvent(name: event.name))
            }
        }

        if !self.didLoaded {
            print("nativebrik.dispatch should be called after nativebrik.overlay did load")
            return
        }
        DispatchQueue.global().async {
            Task {
                await self.repositories?.experiment.trigger(event: event) { [weak self] entry in
                    guard let value = entry.value else {
                        return
                    }
                    let experimentConfigs = value.value
                    guard let extractedConfig = extractExperimentConfigMatchedToProperties(configs: experimentConfigs, properties: { seed in
                        return self?.user.toEventProperties(seed: seed) ?? []
                    }, records: { experimentId in
                        return self?.user.getExperimentHistoryRecord(experimentId: experimentId) ?? []
                    }) else {
                        return
                    }
                    guard let experimentId = extractedConfig.id else {
                        return
                    }
                    if extractedConfig.kind != .POPUP {
                        return
                    }
                    guard let normalizedUsrRnd = self?.user.getSeededNormalizedUserRnd(seed: extractedConfig.seed ?? 0) else {
                        return
                    }
                    guard let extractedVariant = extractExperimentVariant(config: extractedConfig, normalizedUsrRnd: normalizedUsrRnd) else {
                        return
                    }
                    guard let variantConfig = extractedVariant.configs?[0] else {
                        return
                    }
                    guard let variantId = extractedVariant.id else {
                        return
                    }
                    guard let componentId = variantConfig.value else {
                        return
                    }
                    
                    self?.user.addExperimentHistoryRecord(experimentId: experimentId)

                    self?.repositories?.track.trackExperimentEvent(
                        TrackExperimentEvent(
                            experimentId: experimentId,
                            variantId: variantId
                        )
                    )

                    self?.repositories?.component.fetch(
                        experimentId: experimentId,
                        id: componentId
                    ) { entry in
                        DispatchQueue.main.sync {
                            guard let view = entry.value?.view else {
                                return
                            }
                            switch view {
                            case .EUIRootBlock(let root):
                                if let currentVC = self?.currentVC {
                                    currentVC.dismiss(animated: true)
                                    currentVC.removeFromParent()
                                }
                                guard let config = self?.config else {
                                    return
                                }
                                guard let repositories = self?.repositories else {
                                    return
                                }
                                let rootController = ModalRootViewController(
                                    root: root,
                                    config: config,
                                    repositories: repositories,
                                    modalViewController: self?.modalViewController
                                )
                                self?.addChild(rootController)
                                self?.currentVC = rootController
                            default:
                                return
                            }
                        } // END DispatchQueue.main.sync
                    } // END self.repositories?.component.fetch
                } // END self.repositories?.experiment.trigger
            } // END Task
        } // END DispatchQueue.global().async {
    } // END dispatch
}

