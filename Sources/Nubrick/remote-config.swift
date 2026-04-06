//
//  remote-config.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation
import SwiftUI
import UIKit

public class RemoteConfigVariant {
    public let experimentId: String
    public let variantId: String
    private let configs: [VariantConfig]
    private let renderContext: RenderContext
    private let modalViewController: ModalComponentViewController

    init(
        experimentId: String,
        variantId: String,
        configs: [VariantConfig],
        renderContext: RenderContext,
        modalViewController: ModalComponentViewController
    ) {
        self.experimentId = experimentId
        self.variantId = variantId
        self.configs = configs
        self.renderContext = renderContext
        self.modalViewController = modalViewController
    }

    public func get(_ key: String) -> String? {
        let config = self.configs.first { config in
            if config.key == key {
                return true
            }
            return false
        }

        return config?.value
    }

    public func getAsString(_ key: String) -> String? {
        return self.get(key)
    }

    public func getAsBool(_ key: String) -> Bool? {
        guard let value = self.get(key) else {
            return nil
        }
        return value == "TRUE"
    }

    public func getAsInt(_ key: String) -> Int? {
        guard let value = self.get(key) else {
            return nil
        }
        return Int(value) ?? 0
    }

    public func getAsFloat(_ key: String) -> Float? {
        guard let value = self.get(key) else {
            return nil
        }
        return Float(value) ?? 0.0
    }

    public func getAsDouble(_ key: String) -> Double? {
        guard let value = self.get(key) else {
            return nil
        }
        return Double(value) ?? 0.0
    }

    public func getAsData(_ key: String) -> Data? {
        guard let value = self.get(key) else {
            return nil
        }
        let data = Data(value.utf8)
        return data
    }

    @MainActor
    public func getAsView(
        _ key: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        let componentId = self.get(key)
        return EmbeddingSwiftView(
            experimentId: self.experimentId,
            componentId: componentId,
            renderContext: self.renderContext.makeContext(arguments: arguments),
            modalViewController: self.modalViewController,
            onEvent: onEvent
        )
    }

    @MainActor
    public func getAsView<V: View>(
        _ key: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ phase: AsyncEmbeddingPhase) -> V)
    ) -> some View {
        let componentId = self.get(key)
        return EmbeddingSwiftView(
            experimentId: self.experimentId,
            componentId: componentId,
            renderContext: self.renderContext.makeContext(arguments: arguments),
            modalViewController: self.modalViewController,
            onEvent: onEvent,
            content: content
        )
    }

    @MainActor
    public func getAsUIView(
        _ key: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView? {
        guard let componentId = self.get(key) else {
            return nil
        }
        let uiview = EmbeddingUIView(
            experimentId: self.experimentId,
            componentId: componentId,
            renderContext: self.renderContext.makeContext(arguments: arguments),
            modalViewController: self.modalViewController,
            onEvent: onEvent,
            fallback: nil
        )
        return uiview
    }

    @MainActor
    public func getAsUIView(
        _ key: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView? {
        guard let componentId = self.get(key) else {
            return nil
        }
        let uiview = EmbeddingUIView(
            experimentId: self.experimentId,
            componentId: componentId,
            renderContext: self.renderContext.makeContext(arguments: arguments),
            modalViewController: self.modalViewController,
            onEvent: onEvent,
            fallback: content
        )
        return uiview
    }
}

public enum RemoteConfigPhase {
    case loading
    case completed(RemoteConfigVariant)
    case notFound
    case failed(NubrickError)
}

class RemoteConfig {
    init(
        experimentId: String,
        renderContext: RenderContext,
        modalViewController: ModalComponentViewController,
        phase: @escaping ((_ phase: RemoteConfigPhase) -> Void)
    ) {
        phase(.loading)
        Task { @MainActor in
            let result = await renderContext.fetchRemoteConfig(experimentId: experimentId)
            switch result {
            case .success(let (experimentId, variant)):
                guard let variantId = variant.id else {
                    phase(.notFound)
                    return
                }
                phase(.completed(RemoteConfigVariant(
                    experimentId: experimentId,
                    variantId: variantId,
                    configs: variant.configs ?? [],
                    renderContext: renderContext,
                    modalViewController: modalViewController
                )))
                break
            case .failure(let err):
                switch err {
                case .notFound:
                    phase(.notFound)
                default:
                    phase(.failed(err))
                }
            }
        }
    }
}

class RemoteConfigSwiftViewModel: ObservableObject {
    @Published var phase: RemoteConfigPhase = .loading

    func fetchAndUpdate(
        experimentId: String,
        renderContext: RenderContext,
        modalViewController: ModalComponentViewController
    ) {
        let _ = RemoteConfig(
            experimentId: experimentId,
            renderContext: renderContext,
            modalViewController: modalViewController) { phase in
                Task { @MainActor [weak self] in
                    switch phase {
                    case .loading:
                        return
                    default:
                        self?.phase = phase
                        return
                    }
                }
            }
    }
}


struct RemoteConfigAsView: View {
    @ViewBuilder private let content: ((_ phase: RemoteConfigPhase) -> AnyView)
    @ObservedObject private var data: RemoteConfigSwiftViewModel
    
    init<V: View>(
        experimentId: String,
        renderContext: RenderContext,
        modalViewController: ModalComponentViewController,
        content: @escaping (_: RemoteConfigPhase) -> V
    ) {
        self.content = { phase in
            AnyView(content(phase))
        }
        self.data = RemoteConfigSwiftViewModel()
        self.data.fetchAndUpdate(
            experimentId: experimentId,
            renderContext: renderContext,
            modalViewController: modalViewController
        )
    }

    var body: some View {
        self.content(data.phase)
    }
}
