//
//  component.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/05/01.
//

import Foundation
import UIKit
import SwiftUI
import YogaKit

class ModalComponentViewController: UIViewController {
    private var currentModal: NavigationViewControlller? = nil

    func presentNavigation(
        pageView: PageView,
        modalPresentationStyle: ModalPresentationStyle?,
        modalScreenSize: ModalScreenSize?
    ) {
        if let modal = self.currentModal {
            if !isPresenting(presented: self.presentedViewController, vc: modal) {
                self.currentModal?.dismiss(animated: false)
                self.currentModal = nil
            }
        }

        let pageController = ModalPageViewController(pageView: pageView)

        if let modal = self.currentModal {
            modal.pushViewController(pageController, animated: true)
        } else {
            pageController.setIsFirstModalToTrue()
            let modal = NavigationViewControlller(
                rootViewController: pageController,
                hasPrevious: true
            )
            modal.modalPresentationStyle = parseModalPresentationStyle(modalPresentationStyle)
            if #available(iOS 15.0, *) {
                if let sheet = modal.sheetPresentationController {
                    sheet.detents = parseModalScreenSize(modalScreenSize)
                }
            }
            self.currentModal = modal
            self.presentToTop(modal)
        }
        return
    }

    func presentToTop(_ viewController: UIViewController) {
        self.view.window?.rootViewController?.present(viewController, animated: true)
    }

    @objc func dismissModal() {
         if let modal = self.currentModal {
             modal.dismiss(animated: true)
         }
         self.currentModal = nil
    }
}

public enum ComponentPhase {
    case loading
    case completed(UIView)
    case failure
}

class ComponentUIView: UIView {
    private let config: Config
    private let repositories: Repositories?
    private let fallback: ((_ phase: ComponentPhase) -> UIView)
    private var fallbackView: UIView = UIView()

    private var modalViewController: ModalComponentViewController? = nil

    required init?(coder: NSCoder) {
        self.config = Config()
        self.repositories = nil
        self.fallback = { (_ phase) in
            return UIProgressView()
        }
        super.init(coder: coder)
    }

    init(
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
        fallback: ((_ phase: ComponentPhase) -> UIView)?
    ) {
        self.config = config
        self.fallback = fallback ?? { (_ phase) in
            switch phase {
            case .completed(let view):
                return view
            default:
                return UIProgressView()
            }
        }
        self.repositories = repositories
        self.modalViewController = modalViewController
        super.init(frame: .zero)

        self.configureLayout { layout in
            layout.isEnabled = true
            layout.alignItems = .center
            layout.justifyContent = .center
        }
        
        let fallbackView = self.fallback(.loading)
        self.addSubview(fallbackView)
        self.fallbackView = fallbackView
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        self.yoga.applyLayout(preservingOrigin: true)
    }

    func loadAndTransition(experimentId: String, componentId: String) {
        DispatchQueue.global().async { [weak self] in
            Task {
                self?.repositories?.component.fetch(experimentId: experimentId, id: componentId) { entry in
                    DispatchQueue.main.async { [weak self] in
                        if self == nil {
                            return
                        }
                        if entry.state == .FAILED {
                            self?.renderFallback(phase: .failure)
                        }
                        if let view = entry.value?.view {
                            switch view {
                            case .EUIRootBlock(let root):
                                let rootView = RootView(
                                    root: root,
                                    config: self!.config,
                                    repositories: self!.repositories!,
                                    modalViewController: self?.modalViewController
                                )
                                self?.renderFallback(phase: .completed(rootView))
                            default:
                                self?.renderFallback(phase: .failure)
                            }
                        }
                    }
                }
            }
        }
    }

    func renderFallback(phase: ComponentPhase) {
        let view = self.fallback(phase)
        UIView.transition(
            from: self.fallbackView,
            to: view,
            duration: 0.2,
            options: .transitionCrossDissolve,
            completion: nil)
        self.fallbackView = view
    }
}

class ComponentSwiftViewModel: ObservableObject {
    @Published var phase: AsyncComponentPhase = .loading

    func fetchComponentAndUpdatePhase(
        experimentId: String,
        componentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?
    ) {
        DispatchQueue.global().async {
            Task {
                repositories.component.fetch(experimentId: experimentId, id: componentId, callback: { entry in
                    DispatchQueue.main.sync { [weak self] in
                        if let view = entry.value?.view {
                            switch view {
                            case .EUIRootBlock(let root):
                                self?.phase = .completed(
                                    ComponentView(content: RootViewRepresentable(
                                        root: root,
                                        config: config,
                                        repositories: repositories,
                                        modalViewController: modalViewController
                                    ))
                                )
                            default:
                                self?.phase = .failure
                            }
                        } else {
                            self?.phase = .failure
                        }
                    }
                })
            }
        }
    }
}

public struct ComponentView: View {
    let content: RootViewRepresentable
    public var body: some View {
        self.content
    }
}
public enum AsyncComponentPhase {
    case loading
    case completed(ComponentView)
    case failure
}
struct ComponentSwiftView: View {
    @ViewBuilder private let content: ((_ phase: AsyncComponentPhase) -> AnyView)
    @ObservedObject private var data: ComponentSwiftViewModel

    init(
        experimentId: String,
        componentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController
    ) {
        self.content = { phase in
            switch phase {
            case .completed(let component):
                return AnyView(component)
            default:
                if #available(iOS 14.0, *) {
                    return AnyView(ProgressView())
                } else {
                    return AnyView(EmptyView())
                }
            }
        }
        self.data = ComponentSwiftViewModel()
        self.data.fetchComponentAndUpdatePhase(experimentId: experimentId, componentId: componentId, config: config, repositories: repositories, modalViewController: modalViewController)
    }

    init<V: View>(
        experimentId: String,
        componentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController,
        content: @escaping ((_ phase: AsyncComponentPhase) -> V)
    ) {
        self.content = { phase in
            AnyView(content(phase))
        }
        self.data = ComponentSwiftViewModel()
        self.data.fetchComponentAndUpdatePhase(experimentId: experimentId, componentId: componentId, config: config, repositories: repositories, modalViewController: modalViewController)
    }

    init<I: View, P: View>(
        experimentId: String,
        componentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController,
        content: @escaping ((_ component: any View) -> I),
        placeholder: @escaping (() -> P)
    ) {
        self.content = { phase in
            switch phase {
            case .completed(let component):
                return AnyView(content(component))
            default:
                return AnyView(placeholder())
            }
        }
        self.data = ComponentSwiftViewModel()
        self.data.fetchComponentAndUpdatePhase(experimentId: experimentId, componentId: componentId, config: config, repositories: repositories, modalViewController: modalViewController)
    }

    var body: some View {
        self.content(data.phase)
    }
}
