//
//  embedding.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation
import UIKit
import SwiftUI
internal import YogaKit

public enum UIKitEmbeddingPhase {
    case loading
    case completed(UIView)
    case notFound
    case failed(Error)
}

func convertEvent(_ event: UIBlockAction) -> ComponentEvent {
    let convertType: (_ t: PropertyType?) -> EventPropertyType = { t in
        switch t {
        case .INTEGER:
                return .INTEGER
        case .STRING:
                return .STRING
        case .TIMESTAMPZ:
                return .TIMESTAMPZ
        default:
                return .UNKNOWN
        }
    }
    return ComponentEvent(
        name: event.eventName ?? event.name,
        deepLink: event.deepLink,
        payload: event.payload?.map({ prop in
            return EventProperty(
                name: prop.name ?? "",
                value: prop.value ?? "",
                type: convertType(prop.ptype)
            )
        })
    )
}

class EmbeddingUIView: UIView {
    private let fallback: ((_ phase: UIKitEmbeddingPhase) -> UIView)
    private var fallbackView: UIView = UIView()
    
    @available(*, unavailable, message: "Storyboard/XIB initialization is not supported. Use init(experimentId:componentId:container:modalViewController:onEvent:fallback:onSizeChange:).")
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    init(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        fallback: ((_ phase: UIKitEmbeddingPhase) -> UIView)?,
        onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)? = nil
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
            let result = await container.fetchEmbedding(experimentId: experimentId, componentId: componentId)
            
            await MainActor.run { [weak self] in
                switch result {
                case .success(let view):
                    switch view {
                    case .EUIRootBlock(let root):
                        let rootView = RootView(
                            root: root,
                            container: container,
                            modalViewController: modalViewController,
                            onEvent: { event in
                                onEvent?(convertEvent(event))
                            },
                            onSizeChange: onSizeChange
                        )
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

    func renderFallback(phase: UIKitEmbeddingPhase) {
        let view = self.fallback(phase)
        self.fallbackView.removeFromSuperview()
        self.addSubview(view)
        self.fallbackView = view
        self.invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        fallbackView.intrinsicContentSize
    }
}

struct ComponentView: View {
    @State private var width: NubrickSize = .fill
    @State private var height: NubrickSize = .fill

    let root: UIRootBlock?
    let container: Container
    let modalViewController: ModalComponentViewController?
    let onEvent: ((_ event: ComponentEvent) -> Void)?
    let onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)?

    private var frameWidth: CGFloat? {
        switch width {
        case .fixed(let value):
            return value
        case .fill:
            return nil
        }
    }

    private var frameHeight: CGFloat? {
        switch height {
        case .fixed(let value):
            return value
        case .fill:
            return nil
        }
    }

    var body: some View {
        RootViewRepresentable(
            root: root,
            container: container,
            modalViewController: modalViewController,
            onEvent: { event in
                onEvent?(convertEvent(event))
            },
            onSizeChange: onSizeChange,
            width: $width,
            height: $height
        )
        .frame(width: frameWidth, height: frameHeight)
    }
}

public enum SwiftUIEmbeddingPhase {
    case loading
    case completed(AnyView)
    case notFound
    case failed(Error)
}

@MainActor
class EmbeddingSwiftViewModel: ObservableObject {
    @Published var phase: SwiftUIEmbeddingPhase = .loading

    func fetchEmbeddingAndUpdatePhase(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)? = nil
    ) {
        Task {
            let result = await container.fetchEmbedding(experimentId: experimentId, componentId: componentId)
            await MainActor.run { [weak self] in
                switch result {
                case .success(let view):
                    switch view {
                    case .EUIRootBlock(let root):
                        self?.phase = .completed(AnyView(
                            ComponentView(
                                root: root,
                                container: container,
                                modalViewController: modalViewController,
                                onEvent: onEvent,
                                onSizeChange: onSizeChange
                            )
                        ))
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

struct EmbeddingSwiftView: View {
    @ViewBuilder private let _content: ((_ phase: SwiftUIEmbeddingPhase) -> AnyView)
    @ObservedObject private var data: EmbeddingSwiftViewModel
    
    init(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)? = nil
    ) {
        self._content = { phase in
            switch phase {
            case .completed(let component):
                return component
            case .loading:
                return AnyView(ProgressView())
            default:
                return AnyView(EmptyView())
            }
        }
        self.data = EmbeddingSwiftViewModel()
        self.data.fetchEmbeddingAndUpdatePhase(
            experimentId: experimentId,
            container: container,
            modalViewController: modalViewController,
            onEvent: onEvent,
            onSizeChange: onSizeChange
        )
    }

    init<V: View>(
        experimentId: String,
        componentId: String? = nil,
        container: Container,
        modalViewController: ModalComponentViewController?,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        content: @escaping ((_ phase: SwiftUIEmbeddingPhase) -> V),
        onSizeChange: ((_ width: NubrickSize, _ height: NubrickSize) -> Void)? = nil
    ) {
        self._content = { phase in
            AnyView(content(phase))
        }
        self.data = EmbeddingSwiftViewModel()
        self.data.fetchEmbeddingAndUpdatePhase(
            experimentId: experimentId,
            container: container,
            modalViewController: modalViewController,
            onEvent: onEvent,
            onSizeChange: onSizeChange
        )
    }

    var body: some View {
        self._content(data.phase)
    }
}
