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
    private var onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?, _ sessionId: String) -> Void)? = nil
    private var didLoaded = false
    private var hasEnteredBackground = false

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(user:container:modalViewController:onDispatch:onTooltip:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        user: NubrickUser,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?, _ sessionId: String) -> Void)? = nil
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
        onTooltip: ((_ data: String, _ experimentId: String, _ variantId: String?, _ sessionId: String) -> Void)?
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
            await self.performDispatch(events: events)
        }

        // Startup counts as the first entry even when initialized in the background.
        // Only a background transition observed after initialization enables a return.
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc private func didEnterBackground() {
        self.hasEnteredBackground = true
    }

    @objc func willEnterForeground() {
        guard self.hasEnteredBackground else { return }
        self.hasEnteredBackground = false
        var events = [NubrickEvent(TriggerEventNameDefs.USER_ENTER_TO_FOREGROUND.rawValue)]
        events.append(contentsOf: self.userReturnEvents())
        Task {
            await self.performDispatch(events: events)
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
            await self.performDispatch(events: [event], sourceExperimentId: sourceExperimentId)
        }
    }

    @MainActor
    func performDispatch(events: [NubrickEvent], sourceExperimentId: String? = nil) async {
        let recordedTriggers = await self.container.recordTriggerEvents(
            triggers: events.map(\.name), sourceExperimentId: sourceExperimentId
        )
        for event in events {
            self.onDispatch?(event)
        }
        guard self.didLoaded else {
            print("nativebrik.dispatch should be called after nativebrik.overlay did load")
            return
        }
        if self.modalViewController?.hasActiveTriggerExperiment == true || recordedTriggers.isEmpty {
            return
        }
        // onTooltip is only set in the Flutter SDK. Tooltips are a Flutter-only feature,
        // so we fetch both popups and tooltips when running in Flutter, and popups only otherwise.
        let kinds: [ExperimentKind] = self.onTooltip != nil ? [.POPUP, .TOOLTIP] : [.POPUP]
        guard case .success(let content) = await self.container.fetchTriggerContent(
            triggers: recordedTriggers,
            kinds: kinds
        ) else { return }
        self.presentTriggerContent(content)
    }

    @MainActor
    private func presentTriggerContent(_ content: FetchedTriggerContent) {
        guard self.modalViewController?.hasActiveTriggerExperiment != true,
              case .EUIRootBlock(let root) = content.block else { return }
        if content.kind == .TOOLTIP {
            guard let onTooltip = self.onTooltip,
                  let modal = self.modalViewController else { return }
            let session = UUID().uuidString
            guard let jsonData = try? JSONEncoder().encode(content.block),
                  let jsonString = String(data: jsonData, encoding: .utf8),
                  modal.startTriggerExperiment(session) != nil else { return }
            onTooltip(jsonString, content.experimentId, content.variantId, session)
            return
        }
        // No suspension between checking and claiming: completed fetches compete
        // only when they are ready to start, never while content is loading.
        guard let modalViewController = self.modalViewController,
              let session = modalViewController.startTriggerExperiment() else { return }
        self.currentVC?.removeFromParent()
        self.currentVC = nil
        let rootViewController = ModalRootViewController(
            root: root,
            experimentId: content.experimentId,
            variantId: content.variantId,
            container: self.container,
            modalViewController: modalViewController,
            triggerSession: session
        )
        self.addChild(rootViewController)
        self.currentVC = rootViewController
    }
}
