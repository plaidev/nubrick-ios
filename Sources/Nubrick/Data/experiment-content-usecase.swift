//
//  experiment-content-usecase.swift
//  Nubrick
//
//  Created by Codex on 2026/04/03.
//

import Foundation

private struct ExtractedVariant {
    let experimentId: String
    let kind: ExperimentKind?
    let variant: ExperimentVariant
}

protocol ExperimentContentUseCase : Sendable {
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NubrickError>
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError>
}

final class ExperimentContentUseCaseImpl: ExperimentContentUseCase {
    private let user: NubrickUser
    private let experimentRepository: ExperimentRepository2
    private let componentRepository: ComponentRepository2
    private let trackRepository: TrackRepository2
    private let databaseRepository: DatabaseRepository

    init(
        user: NubrickUser,
        experimentRepository: ExperimentRepository2,
        componentRepository: ComponentRepository2,
        trackRepository: TrackRepository2,
        databaseRepository: DatabaseRepository
    ) {
        self.user = user
        self.experimentRepository = experimentRepository
        self.componentRepository = componentRepository
        self.trackRepository = trackRepository
        self.databaseRepository = databaseRepository
    }

    func fetchEmbedding(experimentId: String, componentId: String? = nil) async -> Result<UIBlock, NubrickError> {
        if let componentId = componentId {
            let component = await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId)
            return component
        }

        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchExperimentConfigs(id: experimentId) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }

        var extracted: ExtractedVariant
        switch await self.extractVariant(configs: configs, kinds: [.EMBED]) {
        case .success(let it):
            extracted = it
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = extracted.variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }
        
        await self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: extracted.experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)

        guard let componentId = extractComponentId(variant: extracted.variant) else {
            return Result.failure(NubrickError.notFound)
        }

        return await self.componentRepository.fetchComponent(experimentId: extracted.experimentId, id: componentId)
    }

    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError> {
        await self.trackRepository.trackEvent(TrackUserEvent(name: trigger))
        await self.databaseRepository.appendUserEvent(name: trigger)

        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchTriggerExperimentConfigs(name: trigger) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }

        var extracted: ExtractedVariant
        switch await self.extractVariant(configs: configs, kinds: kinds) {
        case .success(let it):
            extracted = it
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = extracted.variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }

        await self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: extracted.experimentId, variantId: variantId
        ))
        // Tooltip is a Flutter-only flow. Persist tooltip history only after
        // Flutter confirms the tooltip actually started rendering.
        if extracted.kind != .TOOLTIP {
            self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)
        }

        guard let componentId = extractComponentId(variant: extracted.variant) else {
            return Result.failure(NubrickError.notFound)
        }

        switch await self.componentRepository.fetchComponent(experimentId: extracted.experimentId, id: componentId) {
        case .success(let block):
            return .success((extracted.experimentId, extracted.kind, block))
        case .failure(let error):
            return .failure(error)
        }
    }

    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError> {
        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchExperimentConfigs(id: experimentId) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }

        var extracted: ExtractedVariant
        switch await self.extractVariant(configs: configs, kinds: [.CONFIG]) {
        case .success(let it):
            extracted = it
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = extracted.variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }

        await self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: extracted.experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)

        return Result.success((extracted.experimentId, extracted.variant))
    }

    
    private func extractVariant(configs: ExperimentConfigs, kinds: [ExperimentKind]) async -> Result<ExtractedVariant, NubrickError> {
        guard let config = await extractExperimentConfigMatchedToProperties(
            configs: configs,
            kinds: kinds,
            properties: { seed in
                return await self.user.toEventProperties(seed: seed)
            },
            isNotInFrequency: { experimentId, frequency in
                return await self.databaseRepository.isNotInFrequency(experimentId: experimentId, frequency: frequency)
            },
            isMatchedToUserEventFrequencyConditions: { conditions in
                guard let conditions = conditions else {
                    return true
                }
                for condition in conditions {
                    if !(await self.databaseRepository.isMatchedToUserEventFrequencyCondition(condition: condition)) {
                        return false
                    }
                }
                return true
            }
        ) else {
            return Result.failure(NubrickError.notFound)
        }
        guard let experimentId = config.id else {
            return Result.failure(NubrickError.irregular("Couldn't get the experiment id"))
        }
        let normalizedUserRnd = await self.user.getSeededNormalizedUserRnd(seed: config.seed ?? 0)
        guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: normalizedUserRnd) else {
            return Result.failure(NubrickError.notFound)
        }
        return Result.success(ExtractedVariant(experimentId: experimentId, kind: config.kind, variant: variant))
    }
}
