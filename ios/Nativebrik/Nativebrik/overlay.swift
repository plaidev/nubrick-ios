//
//  overlay.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/07/05.
//

import Foundation
import SwiftUI

class OverlayViewController: UIViewController {
    let modalViewController: ModalComponentViewController = ModalComponentViewController()
    let modalForTriggerViewController: ModalComponentViewController = ModalComponentViewController()
    let triggerViewController: TriggerViewController
    
    init(user: NativebrikUser, config: Config, repositories: Repositories) {
        self.triggerViewController = TriggerViewController(user: user, config: config, repositories: repositories, modalViewController: self.modalForTriggerViewController)
        super.init(nibName: nil, bundle: nil)
        
        if !isNativebrikAvailable {
            return
        }
        
        self.addChild(self.modalViewController)
        self.addChild(self.modalForTriggerViewController)
        self.addChild(self.triggerViewController)
        
        self.view.frame = .zero
        self.view.addSubview(self.modalViewController.view)
        self.view.addSubview(self.modalForTriggerViewController.view)
    }
    
    override func viewDidLoad() {
        if !isNativebrikAvailable {
            return
        }

        self.triggerViewController.initialLoad()
    }
        
    required init?(coder: NSCoder) {
        self.triggerViewController = TriggerViewController(coder: coder)!
        super.init(coder: coder)
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
