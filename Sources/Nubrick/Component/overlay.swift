//
//  overlay.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/07/05.
//

import Foundation
import SwiftUI

class OverlayViewController: UIViewController {
    let modalViewController: ModalComponentViewController = ModalComponentViewController()
    let modalForTriggerViewController: ModalComponentViewController = ModalComponentViewController()
    let triggerViewController: TriggerViewController

    init(
        user: NubrickUser,
        container: Container,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)? = nil
    ) {
        self.triggerViewController = TriggerViewController(
            user: user,
            container: container,
            modalViewController: self.modalForTriggerViewController,
            onDispatch: onDispatch,
            onTooltip: onTooltip
        )
        super.init(nibName: nil, bundle: nil)

        self.addChild(self.modalViewController)
        self.addChild(self.modalForTriggerViewController)
        self.addChild(self.triggerViewController)

        self.view.frame = .zero
        self.view.addSubview(self.modalViewController.view)
        self.view.addSubview(self.modalForTriggerViewController.view)
    }

    override func viewDidLoad() {
        self.triggerViewController.initialLoad()
    }

    func updateCallbacks(
        onDispatch: ((_ event: NubrickEvent) -> Void)?,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)?
    ) {
        self.triggerViewController.updateCallbacks(
            onDispatch: onDispatch,
            onTooltip: onTooltip
        )
    }

    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(user:container:onDispatch:onTooltip:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct OverlayViewControllerRepresentable: UIViewControllerRepresentable {
    let overlayVC: OverlayViewController

    func makeUIViewController(context: Context) -> OverlayViewController {
        return self.overlayVC
    }

    func updateUIViewController(_ uiViewController: OverlayViewController, context: Context) {
    }
}
