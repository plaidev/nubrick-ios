//
//  trigger.swift
//  Nubrick
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
    private let container: Container
    private var modalViewController: ModalComponentViewController? = nil
    private var currentVC: ModalRootViewController? = nil
    private var onDispatch: ((_ event: NubrickEvent) -> Void)? = nil
    private var didLoaded = false
    private var ignoreFirstUserEventToForegroundEvent = true

    required init?(coder: NSCoder) {
        self.user = NativebrikUser()
        self.container = ContainerEmptyImpl()
        super.init(coder: coder)
    }

    init(user: NativebrikUser, container: Container, modalViewController: ModalComponentViewController?, onDispatch: ((_ event: NubrickEvent) -> Void)? = nil) {
        self.user = user
        self.container = container
        self.modalViewController = modalViewController
        self.onDispatch = onDispatch
        super.init(nibName: nil, bundle: nil)
    }

    func initialLoad() {
        self.didLoaded = true

        // dispatch an event when the user is only booted
        self.dispatch(event: NubrickEvent(TriggerEventNameDefs.USER_BOOT_APP.rawValue))

        // dispatch user enter the app firtly
        let count = UserDefaults.standard.object(forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue) as? Int ?? 0
        UserDefaults.standard.set(count + 1, forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue)
        if count == 0 {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY.rawValue))
        }

        // dispatch retention event
        self.callWhenUserComeBack()

        // Dispatch a retention event when the user returns to the foreground from the background
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func willEnterForeground() {
        if self.ignoreFirstUserEventToForegroundEvent {
            self.ignoreFirstUserEventToForegroundEvent = false
            return
        }
        self.dispatch(event: NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue))
        self.callWhenUserComeBack()
    }

    func callWhenUserComeBack() {
        self.user.comeBack()

        // dispatch the event when every time the user is activated
        self.dispatch(event: NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue))

        let retention = self.user.retention
        if retention == 1 {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.RETENTION_1.rawValue))
        } else if 1 < retention && retention <= 3 {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.RETENTION_2_3.rawValue))
        } else if 3 < retention && retention <= 7 {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.RETENTION_4_7.rawValue))
        } else if 7 < retention && retention <= 14 {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.RETENTION_8_14.rawValue))
        } else if 14 < retention {
            self.dispatch(event: NubrickEvent(TriggerEventNameDefs.RETENTION_15.rawValue))
        }
    }

    func dispatch(event: NubrickEvent) {
        Task {
            let result = await Task.detached {
                return await self.container.fetchInAppMessage(trigger: event.name)
            }.value

            self.onDispatch?(event)

            await MainActor.run { [weak self] in
                let didLoaded = self?.didLoaded ?? false
                if !didLoaded {
                    print("nativebrik.dispatch should be called after nativebrik.overlay did load")
                    return
                }
                guard let container = self?.container else {
                    return
                }
                switch result {
                case .success(let block):
                    switch block {
                    case .EUIRootBlock(let root):
                        let root = ModalRootViewController(
                            root: root,
                            container: ContainerImpl(container as! ContainerImpl, arguments: nil),
                            modalViewController: self?.modalViewController
                        )
                        if let currentVC = self?.currentVC {
                            currentVC.removeFromParent()
                            self?.currentVC = nil
                        }
                        self?.addChild(root)
                        self?.currentVC = root
                    default:
                        break
                    }
                default:
                    break
                }
            }
        }
    } // END dispatch
}

