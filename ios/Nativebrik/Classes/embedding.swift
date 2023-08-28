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


class EmbeddingUIView: ComponentUIView {
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    init(
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
        fallback: ((_ phase: ComponentPhase) -> UIView)?
    ) {
        super.init(
            config: config,
            repositories: repositories,
            modalViewController: modalViewController,
            fallback: fallback
        )
        DispatchQueue.global().async { [weak self] in
            Task {
                await repositories.experiment.fetch(id: experimentId) { entry in
                    DispatchQueue.main.async { [weak self] in
                        guard let configs = entry.value?.value else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let config = extractExperimentConfigMatchedToProperties(configs: configs, properties: []) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        if config.kind != .EMBED {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: 1.0) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let componentId = extractComponentId(variant: variant) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        self?.loadAndTransition(experimentId: experimentId, componentId: componentId)
                    }
                }
            }
        }
    }
}

class EmbeddingSwiftViewModel: ComponentSwiftViewModel {
    func fetchAndUpdatePhase(
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?
    ) {
        DispatchQueue.global().async {
            Task {
                await repositories.experiment.fetch(id: experimentId) { entry in
                    DispatchQueue.main.async { [weak self] in
                        guard let configs = entry.value?.value else {
                            self?.phase = .failure
                            return
                        }
                        guard let experimentConfig = extractExperimentConfigMatchedToProperties(configs: configs, properties: []) else {
                            self?.phase = .failure
                            return
                        }
                        if experimentConfig.kind != .EMBED {
                            self?.phase = .failure
                            return
                        }
                        guard let variant = extractExperimentVariant(config: experimentConfig, normalizedUsrRnd: 1.0) else {
                            self?.phase = .failure
                            return
                        }
                        guard let componentId = extractComponentId(variant: variant) else {
                            self?.phase = .failure
                            return
                        }
                        self?.fetchComponentAndUpdatePhase(
                            experimentId: experimentId,
                            componentId: componentId,
                            config: config,
                            repositories: repositories,
                            modalViewController: modalViewController
                        )
                    }
                }
            }
        }
    }
}


struct EmbeddingSwiftView: View {
    @ViewBuilder private let content: ((_ phase: AsyncComponentPhase) -> AnyView)
    @ObservedObject private var data: EmbeddingSwiftViewModel

    init(
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?
    ) {
        self.content = { phase in
            switch phase {
            case .completed(let component):
                return AnyView(component)
            default:
                return AnyView(ProgressView())
            }
        }
        self.data = EmbeddingSwiftViewModel()
        self.data.fetchAndUpdatePhase(
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    init<V: View>(
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
        content: @escaping ((_ phase: AsyncComponentPhase) -> V)
    ) {
        self.content = { phase in
            AnyView(content(phase))
        }
        self.data = EmbeddingSwiftViewModel()
        self.data.fetchAndUpdatePhase(
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    init<I: View, P: View>(
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
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
        self.data = EmbeddingSwiftViewModel()
        self.data.fetchAndUpdatePhase(
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    public var body: some View {
        self.content(data.phase)
    }

}
