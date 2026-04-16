//
//  container.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation

private struct ExtractedVariant {
    let experimentId: String
    let kind: ExperimentKind?
    let variant: ExperimentVariant
}

protocol Container : Sendable {
    @MainActor
    func handleEvent(_ it: UIBlockAction)
    @MainActor
    func makeContainer(arguments: NubrickArguments?) -> Container
    @MainActor
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any?
    @MainActor
    func getFormValue(key: String) -> Any?
    @MainActor
    func getFormValues() -> [String: Any]
    @MainActor
    func setFormValue(key: String, value: Any)
    @MainActor
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener)
    @MainActor
    func removeFormValueListener(_ id: String)

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError>
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NubrickError>
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError>
}

final class ContainerImpl: Container {
    private let config: Config
    private let user: NubrickUser
    private let actionHandler: UIBlockActionHandler
    private let experimentRepository: ExperimentRepository2
    private let componentRepository: ComponentRepository2
    private let trackRepository: TrackRepository2
    private let databaseRepository: DatabaseRepository
    private let httpRequestRepository: HttpRequestRepository
    private let formRepository: FormRepository
    private let arguments: NubrickArguments?

    @MainActor
    init(
        config: Config,
        user: NubrickUser,
        actionHandler: @escaping UIBlockActionHandler,
        experimentRepository: ExperimentRepository2,
        componentRepository: ComponentRepository2,
        trackRepository: TrackRepository2,
        databaseRepository: DatabaseRepository,
        httpRequestRepository: HttpRequestRepository,
        arguments: NubrickArguments? = nil
    ) {
        self.config = config
        self.user = user
        self.actionHandler = actionHandler
        self.experimentRepository = experimentRepository
        self.componentRepository = componentRepository
        self.trackRepository = trackRepository
        self.databaseRepository = databaseRepository
        self.httpRequestRepository = httpRequestRepository
        self.formRepository = FormRepositoryImpl()
        self.arguments = arguments
    }

    @MainActor
    func handleEvent(_ it: UIBlockAction) {
        self.actionHandler(it, nil)
    }

    @MainActor
    func makeContainer(arguments: NubrickArguments?) -> Container {
        return ContainerImpl(
            config: self.config,
            user: self.user,
            actionHandler: self.actionHandler,
            experimentRepository: self.experimentRepository,
            componentRepository: self.componentRepository,
            trackRepository: self.trackRepository,
            databaseRepository: self.databaseRepository,
            httpRequestRepository: self.httpRequestRepository,
            arguments: arguments
        )
    }

    @MainActor
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any? {
        return _createVariableForTemplate(
            user: self.user,
            data: data,
            properties: properties,
            form: self.formRepository.getFormData(),
            arguments: self.arguments,
            projectId: self.config.projectId
        )
    }

    @MainActor
    func getFormValue(key: String) -> Any? {
        return self.formRepository.getValue(key: key)
    }

    @MainActor
    func getFormValues() -> [String: Any] {
        return self.formRepository.getFormData()
    }

    @MainActor
    func setFormValue(key: String, value: Any) {
        self.formRepository.setValue(key: key, value: value)
    }

    @MainActor
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) {
        self.formRepository.addFormValueListener(id: id, listener: listener)
    }

    @MainActor
    func removeFormValueListener(_ id: String) {
        self.formRepository.removeFormValueListener(id: id)
    }

    // MARK: - HTTP Request

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError> {
        let request = ApiHttpRequest(
            url: compile(req.url ?? "", variable),
            method: req.method,
            headers: req.headers?.map { it in
                return ApiHttpHeader(name: compile(it.name ?? "", variable), value: compile(it.value ?? "", variable))
            },
            body: compile(req.body ?? "", variable)
        )
        return await self.httpRequestRepository.request(req: request, assetion: assertion)
    }

    // MARK: - Experiment Content

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
