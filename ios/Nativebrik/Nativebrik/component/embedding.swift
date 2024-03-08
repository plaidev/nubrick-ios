//
//  embedding.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation
import UIKit
import SwiftUI
import YogaKit

public enum EmbeddingPhase {
    case loading
    case completed(UIView)
    case notFound
    case failed(Error)
}

class EmbeddingUIView2: UIView {
    private let container: Container
    private let fallback: ((_ phase: EmbeddingPhase) -> UIView)
    private var fallbackView: UIView = UIView()
    private var modalViewController: ModalComponentViewController? = nil
    
    required init?(coder: NSCoder) {
        self.container = ContainerEmptyImpl()
        self.fallback = { (_ phase) in
            return UIProgressView()
        }
        super.init(coder: coder)
    }
    init(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        fallback: ((_ phase: EmbeddingPhase) -> UIView)?
    ) {
        self.fallback = fallback ?? { (_ phase) in
            switch phase {
            case .completed(let view):
                return view
            case .loading:
                return UIProgressView()
            default:
                return UIView()
            }
        }
        self.container = container
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
        
        Task {
            let result = await Task.detached {
                return await container.fetchEmbedding(experimentId: experimentId, componentId: componentId)
            }.value
            
            await MainActor.run { [weak self] in
                switch result {
                case .success(let view):
                    switch view {
                    case .EUIRootBlock(let root):
                        let rootView = RootView(coder: NSCoder())!
                        self?.renderFallback(phase: .completed(rootView))
                    default:
                        self?.renderFallback(phase: .notFound)
                    }
                case .failure(let err):
                    switch err {
                    case .notFound:
                        self?.renderFallback(phase: .notFound)
                    default:
                        self?.renderFallback(phase: .failed(err))
                    }
                }
            }
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        self.yoga.applyLayout(preservingOrigin: true)
    }

    func renderFallback(phase: EmbeddingPhase) {
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

public struct ComponentView: View {
    let content: RootViewRepresentable
    public var body: some View {
        self.content
    }
}

public enum AsyncEmbeddingPhase2 {
    case loading
    case completed(ComponentView)
    case notFound
    case failed(Error)
}

class EmbeddingSwiftViewModel2: ObservableObject {
    @Published var phase: AsyncEmbeddingPhase2 = .loading

    func fetchEmbeddingAndUpdatePhase(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?
    ) {
        Task {
            let result = await Task.detached {
                return await container.fetchEmbedding(experimentId: experimentId, componentId: componentId)
            }.value
    
            await MainActor.run { [weak self] in
                switch result {
                case .success(let view):
                    switch view {
                    case .EUIRootBlock(let root):
                        self?.phase = .completed(ComponentView(content: RootViewRepresentable(
                            root: root, container: container, modalViewController: modalViewController
                        )))
                    default:
                        self?.phase = .notFound
                    }
                case .failure(let err):
                    switch err {
                    case .notFound:
                        self?.phase = .notFound
                    default:
                        self?.phase = .failed(err)
                    }
                }
            }
        }
    }

}

struct EmbeddingSwiftView2: View {
    @ViewBuilder private let _content: ((_ phase: AsyncEmbeddingPhase2) -> AnyView)
    @ObservedObject private var data: EmbeddingSwiftViewModel2
    
    init(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?
    ) {
        self._content = { phase in
            switch phase {
            case .completed(let component):
                return AnyView(component)
            case .loading:
                if #available(iOS 14.0, *) {
                    return AnyView(ProgressView())
                } else {
                    return AnyView(EmptyView())
                }
            default:
                return AnyView(EmptyView())
            }
        }
        self.data = EmbeddingSwiftViewModel2()
        self.data.fetchEmbeddingAndUpdatePhase(
            experimentId: experimentId,
            container: container,
            modalViewController: modalViewController
        )
    }

    init<V: View>(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        content: @escaping ((_ phase: AsyncEmbeddingPhase2) -> V)
    ) {
        self._content = { phase in
            AnyView(content(phase))
        }
        self.data = EmbeddingSwiftViewModel2()
        self.data.fetchEmbeddingAndUpdatePhase(
            experimentId: experimentId,
            container: container,
            modalViewController: modalViewController
        )
    }

    public var body: some View {
        self._content(data.phase)
    }
}
