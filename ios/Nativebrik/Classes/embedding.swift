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
    private let user: NativebrikUser
    required init?(coder: NSCoder) {
        self.user = NativebrikUser()
        super.init(coder: coder)
    }
    init(
        experimentId: String,
        user: NativebrikUser,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
        fallback: ((_ phase: ComponentPhase) -> UIView)?
    ) {
        self.user = user
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
                        guard let config = extractExperimentConfigMatchedToProperties(configs: configs, properties: { seed in
                            return self?.user.toEventProperties(seed: seed) ?? []
                        }) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        if config.kind != .EMBED {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        let normalizedUsrRnd = self?.user.getSeededNormalizedUserRnd(seed: config.seed ?? 0) ?? 0.0
                        guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: normalizedUsrRnd) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let variantId = variant.id else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let componentId = extractComponentId(variant: variant) else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        guard let experimentConfigId = config.id else {
                            self?.renderFallback(phase: .failure)
                            return
                        }
                        
                        repositories.track.trackExperimentEvent(
                            TrackExperimentEvent(
                                experimentId: experimentConfigId,
                                variantId: variantId
                            )
                        )
                        
                        self?.loadAndTransition(experimentId: experimentConfigId, componentId: componentId)
                    }
                }
            }
        }
    }
}

class EmbeddingSwiftViewModel: ComponentSwiftViewModel {
    private let user: NativebrikUser
    init(user: NativebrikUser) {
        self.user = user
    }
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
                        print("hello", experimentId, configs)
                        guard let experimentConfig = extractExperimentConfigMatchedToProperties(configs: configs, properties: { seed in
                            return self?.user.toEventProperties(seed: seed) ?? []
                        }) else {
                            self?.phase = .failure
                            return
                        }
                        if experimentConfig.kind != .EMBED {
                            self?.phase = .failure
                            return
                        }
                        let normalizedUsrRnd = self?.user.getSeededNormalizedUserRnd(seed: experimentConfig.seed ?? 0) ?? 0.0
                        guard let variant = extractExperimentVariant(config: experimentConfig, normalizedUsrRnd: normalizedUsrRnd) else {
                            self?.phase = .failure
                            return
                        }
                        guard let variantId = variant.id else {
                            self?.phase = .failure
                            return
                        }
                        guard let componentId = extractComponentId(variant: variant) else {
                            self?.phase = .failure
                            return
                        }
                        guard let experimentConfigId = experimentConfig.id else {
                            self?.phase = .failure
                            return
                        }
                        
                        repositories.track.trackExperimentEvent(
                            TrackExperimentEvent(
                                experimentId: experimentConfigId,
                                variantId: variantId
                            )
                        )
                        
                        self?.fetchComponentAndUpdatePhase(
                            experimentId: experimentConfigId,
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
        user: NativebrikUser,
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
        self.data = EmbeddingSwiftViewModel(user: user)
        self.data.fetchAndUpdatePhase(
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    init<V: View>(
        experimentId: String,
        user: NativebrikUser,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController?,
        content: @escaping ((_ phase: AsyncComponentPhase) -> V)
    ) {
        self.content = { phase in
            AnyView(content(phase))
        }
        self.data = EmbeddingSwiftViewModel(user: user)
        self.data.fetchAndUpdatePhase(
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    init<I: View, P: View>(
        experimentId: String,
        user: NativebrikUser,
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
        self.data = EmbeddingSwiftViewModel(user: user)
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
