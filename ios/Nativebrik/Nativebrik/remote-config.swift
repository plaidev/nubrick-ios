//
//  remote-config.swift
//  Nativebrik
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
    private let config: Config
    private let user: NativebrikUser
    private let repositories: Repositories
    private let modalViewController: ModalComponentViewController

    init(experimentId: String, variantId: String, configs: [VariantConfig], config: Config, user: NativebrikUser, repositories: Repositories, modalViewController: ModalComponentViewController) {
        self.experimentId = experimentId
        self.variantId = variantId
        self.configs = configs
        self.config = config
        self.user = user
        self.repositories = repositories
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

    public func getAsView(_ key: String) -> some View {
        let componentId = self.get(key)
        return ComponentSwiftView(
            experimentId: self.experimentId,
            componentId: componentId ?? "",
            config: self.config,
            user: self.user,
            repositories: self.repositories,
            modalViewController: self.modalViewController
        )
    }

    public func getAsView<V: View>(
        _ key: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ phase: AsyncComponentPhase) -> V)
    ) -> some View {
        let componentId = self.get(key)
        return ComponentSwiftView(
            experimentId: self.experimentId,
            componentId: componentId ?? "",
            config: self.config.initFrom(onEvent: onEvent),
            user: self.user,
            repositories: self.repositories,
            modalViewController: self.modalViewController,
            content: content
        )
    }

    public func getAsUIView(_ key: String) -> UIView? {
        guard let componentId = self.get(key) else {
            return nil
        }
        let uiview =  ComponentUIView(
            config: self.config,
            user: self.user,
            repositories: self.repositories,
            modalViewController: self.modalViewController,
            fallback: nil
        )
        uiview.loadAndTransition(experimentId: self.experimentId, componentId: componentId)
        return uiview
    }

    public func getAsUIView(
        _ key: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: ComponentPhase) -> UIView
    ) -> UIView? {
        guard let componentId = self.get(key) else {
            return nil
        }
        let uiview =  ComponentUIView(
            config: self.config.initFrom(onEvent: onEvent),
            user: self.user,
            repositories: self.repositories,
            modalViewController: self.modalViewController,
            fallback: content
        )
        uiview.loadAndTransition(experimentId: self.experimentId, componentId: componentId)
        return uiview
    }
}

public enum RemoteConfigPhase {
    case loading
    case completed(RemoteConfigVariant)
    case failure
}

class RemoteConfig {
    init(
        user: NativebrikUser,
        experimentId: String,
        repositories: Repositories,
        config: Config,
        modalViewController: ModalComponentViewController,
        phase: @escaping ((_ phase: RemoteConfigPhase) -> Void)
    ) {
        phase(.loading)
        Task(priority: .userInitiated) {
            await repositories.experiment.fetch(
                id: experimentId,
                callback: { entry in
                    guard let configs = entry.value?.value else {
                        phase(.failure)
                        return
                    }
                    guard let matchedConfig = extractExperimentConfigMatchedToProperties(configs: configs, properties: { seed in
                        return user.toEventProperties(seed: seed)
                    }, records: { experimentId in
                        return user.getExperimentHistoryRecord(experimentId: experimentId)
                    }) else {
                        phase(.failure)
                        return
                    }
                    let normalizedUsrRnd = user.getSeededNormalizedUserRnd(seed: matchedConfig.seed ?? 0)
                    guard let variant = extractExperimentVariant(config: matchedConfig, normalizedUsrRnd: normalizedUsrRnd) else {
                        phase(.failure)
                        return
                    }
                    guard let variantId = variant.id else {
                        phase(.failure)
                        return
                    }
                    guard let variantConfigs = variant.configs else {
                        phase(.failure)
                        return
                    }
                    guard let experimentConfigId = matchedConfig.id else {
                        phase(.failure)
                        return
                    }
                    
                    user.addExperimentHistoryRecord(experimentId: experimentConfigId)
                    
                    repositories.track.trackExperimentEvent(
                        TrackExperimentEvent(
                            experimentId: experimentConfigId,
                            variantId: variantId
                        )
                    )

                    phase(.completed(RemoteConfigVariant(
                        experimentId: experimentConfigId,
                        variantId: variantId,
                        configs: variantConfigs,
                        config: config,
                        user: user,
                        repositories: repositories,
                        modalViewController: modalViewController
                    )))
                }
            )
        }
    }
}

class RemoteConfigSwiftViewModel: ObservableObject {
    @Published var phase: RemoteConfigPhase = .loading

    func fetchAndUpdate(
        user: NativebrikUser,
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController
    ) {
        let _ = RemoteConfig(
            user: user,
            experimentId: experimentId,
            repositories: repositories,
            config: config,
            modalViewController: modalViewController) { phase in
                DispatchQueue.main.async { [weak self] in
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
        user: NativebrikUser,
        experimentId: String,
        config: Config,
        repositories: Repositories,
        modalViewController: ModalComponentViewController,
        content: @escaping (_: RemoteConfigPhase) -> V
    ) {
        self.content = { phase in
            AnyView(content(phase))
        }
        self.data = RemoteConfigSwiftViewModel()
        self.data.fetchAndUpdate(
            user: user,
            experimentId: experimentId,
            config: config,
            repositories: repositories,
            modalViewController: modalViewController
        )
    }

    var body: some View {
        self.content(data.phase)
    }
}
