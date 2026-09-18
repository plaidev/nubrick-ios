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
    private let user: NubrickUser
    private let container: Container
    private var modalViewController: ModalComponentViewController? = nil
    private var currentVC: ModalRootViewController? = nil
    private var onDispatch: ((_ event: NubrickEvent) -> Void)? = nil
    private var onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?) -> Void)? = nil
    private var didLoaded = false
    private var ignoreFirstUserEventToForegroundEvent = true

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(user:container:modalViewController:onDispatch:onTooltip:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        user: NubrickUser,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?) -> Void)? = nil
    ) {
        self.user = user
        self.container = container
        self.modalViewController = modalViewController
        self.onDispatch = onDispatch
        self.onTooltip = onTooltip
        super.init(nibName: nil, bundle: nil)
    }

    func updateCallbacks(
        onDispatch: ((_ event: NubrickEvent) -> Void)?,
        onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?) -> Void)?
    ) {
        if let onDispatch {
            self.onDispatch = onDispatch
        }
        if let onTooltip {
            self.onTooltip = onTooltip
        }
    }

    func clearCallbacks() {
        self.onDispatch = nil
        self.onTooltip = nil
    }

    func initialLoad() {
        self.didLoaded = true
        var events = [NubrickEvent(TriggerEventNameDefs.USER_BOOT_APP.rawValue)]

        let count = UserDefaults.standard.object(forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue) as? Int ?? 0
        UserDefaults.standard.set(
            count == Int.max ? Int.max : count + 1,
            forKey: UserDefaultsKeys.SDK_INITIALIZED_COUNT.rawValue
        )
        if count == 0 {
            events.append(NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_APP_FIRSTLY.rawValue))
        }
        events.append(contentsOf: self.userReturnEvents())
        Task {
            await self.dispatchPredefinedEvents(events)
        }

        // Dispatch a retention event when the user returns to the foreground from the background
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func willEnterForeground() {
        if self.ignoreFirstUserEventToForegroundEvent {
            self.ignoreFirstUserEventToForegroundEvent = false
            return
        }
        var events = [NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue)]
        events.append(contentsOf: self.userReturnEvents())
        Task {
            await self.dispatchPredefinedEvents(events)
        }
    }

    private func userReturnEvents() -> [NubrickEvent] {
        self.user.comeBack()
        var events = [NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_APP.rawValue)]

        let retention = self.user.retention
        if retention == 1 {
            events.append(NubrickEvent(TriggerEventNameDefs.RETENTION_1.rawValue))
        } else if 1 < retention && retention <= 3 {
            events.append(NubrickEvent(TriggerEventNameDefs.RETENTION_2_3.rawValue))
        } else if 3 < retention && retention <= 7 {
            events.append(NubrickEvent(TriggerEventNameDefs.RETENTION_4_7.rawValue))
        } else if 7 < retention && retention <= 14 {
            events.append(NubrickEvent(TriggerEventNameDefs.RETENTION_8_14.rawValue))
        } else if 14 < retention {
            events.append(NubrickEvent(TriggerEventNameDefs.RETENTION_15.rawValue))
        }
        return events
    }
    
    @MainActor
    func dispatch(event: NubrickEvent, sourceExperimentId: String? = nil) {
        Task {
            await self.performDispatch(event: event, sourceExperimentId: sourceExperimentId)
        }
    }

    @MainActor
    func performDispatch(event: NubrickEvent, sourceExperimentId: String? = nil) async {
        // onTooltip is only set in the Flutter SDK. Tooltips are a Flutter-only feature,
        // so we fetch both popups and tooltips when running in Flutter, and popups only otherwise.
        let kinds: [ExperimentKind] = self.onTooltip != nil ? [.POPUP, .TOOLTIP] : [.POPUP]
        let triggerResult = await self.container.fetchTriggerContent(
            trigger: event.name,
            kinds: kinds,
            sourceExperimentId: sourceExperimentId
        )
        self.onDispatch?(event)

        if !self.didLoaded {
            print("nativebrik.dispatch should be called after nativebrik.overlay did load")
            return
        }
        guard case .success(let content) = triggerResult else { return }
        self.presentTriggerContent(content)
    }

    @MainActor
    private func dispatchPredefinedEvents(_ events: [NubrickEvent]) async {
        let kinds: [ExperimentKind] = self.onTooltip != nil ? [.POPUP, .TOOLTIP] : [.POPUP]
        for event in events {
            self.onDispatch?(event)
        }
        guard self.didLoaded,
              case .success(let winner) = await self.container.fetchTriggerContent(
                triggers: events.map(\.name),
                kinds: kinds,
                sourceExperimentId: nil
              ) else { return }
        self.presentTriggerContent(winner)
    }

    @MainActor
    private func presentTriggerContent(_ content: FetchedTriggerContent) {
        guard case .EUIRootBlock(let root) = content.block else { return }
        if content.kind == .TOOLTIP,
           let onTooltip = self.onTooltip,
           let jsonData = try? JSONEncoder().encode(content.block),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            onTooltip(jsonString, content.experimentId, content.variantId)
            return
        }
        let rootViewController = ModalRootViewController(
            root: root,
            experimentId: content.experimentId,
            variantId: content.variantId,
            container: self.container,
            modalViewController: self.modalViewController
        )
        if let currentVC = self.currentVC {
            currentVC.removeFromParent()
            self.currentVC = nil
        }
        self.addChild(rootViewController)
        self.currentVC = rootViewController
    }
}
