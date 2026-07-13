//
//  container.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Combine
import Foundation

private struct ExtractedVariant {
    let experimentId: String
    let kind: ExperimentKind?
    let variant: ExperimentVariant
}

struct FetchedEmbedding {
    let experimentId: String?
    let variantId: String?
    let block: UIBlock
}

struct FetchedTriggerContent {
    let experimentId: String
    let variantId: String
    let kind: ExperimentKind?
    let block: UIBlock
}

protocol Container : Sendable {
    var experimentId: String? { get }
    var variantId: String? { get }

    @MainActor
    func handleEvent(_ it: UIBlockAction)
    @MainActor
    func makeContainer() -> Container
    @MainActor
    func makeContainer(experimentId: String?, variantId: String?) -> Container
    @MainActor
    func createVariableForTemplate(data: Any?, properties: [Property]?, arguments: NubrickArguments?) -> Variable?
    @MainActor
    func getFormValue(key: String) -> Any?
    @MainActor
    func getFormValues() -> [String: Any]
    @MainActor
    func setFormValue(key: String, value: Any)
    @MainActor
    func formDataPublisher() -> AnyPublisher<[String: Any], Never>
    @MainActor
    func userDataPublisher() -> AnyPublisher<[String: Any], Never>

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Variable?) async -> Result<JSONData, NubrickError>
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<FetchedEmbedding, NubrickError>
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<FetchedTriggerContent, NubrickError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError>
}

final class ContainerImpl: Container {
    let experimentId: String?
    let variantId: String?
    private let config: Config
    private let user: NubrickUser
    private let actionHandler: UIBlockActionHandler
    private let experimentRepository: ExperimentRepository2
    private let componentRepository: ComponentRepository2
    private let trackRepository: TrackRepository2
    private let databaseRepository: DatabaseRepository
    private let httpRequestRepository: HttpRequestRepository
    private let formRepository: FormRepository

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
        experimentId: String? = nil,
        variantId: String? = nil
    ) {
        self.experimentId = experimentId
        self.variantId = variantId
        self.config = config
        self.user = user
        self.actionHandler = actionHandler
        self.experimentRepository = experimentRepository
        self.componentRepository = componentRepository
        self.trackRepository = trackRepository
        self.databaseRepository = databaseRepository
        self.httpRequestRepository = httpRequestRepository
        self.formRepository = FormRepositoryImpl()
    }

    @MainActor
    func handleEvent(_ it: UIBlockAction) {
        if it.submitSurveyResponse == true {
            self.sendSurveyResponse()
        }
        self.actionHandler(it, nil)
    }

    @MainActor
    func makeContainer() -> Container {
        makeContainer(experimentId: experimentId, variantId: variantId)
    }

    @MainActor
    func makeContainer(experimentId: String?, variantId: String?) -> Container {
        return ContainerImpl(
            config: self.config,
            user: self.user,
            actionHandler: self.actionHandler,
            experimentRepository: self.experimentRepository,
            componentRepository: self.componentRepository,
            trackRepository: self.trackRepository,
            databaseRepository: self.databaseRepository,
            httpRequestRepository: self.httpRequestRepository,
            experimentId: experimentId,
            variantId: variantId
        )
    }

    @MainActor
    func createVariableForTemplate(data: Any?, properties: [Property]?, arguments: NubrickArguments?) -> Variable? {
        return _createVariableForTemplate(
            user: self.user,
            data: data,
            properties: properties,
            form: self.formRepository.getFormData(),
            arguments: arguments,
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
    func formDataPublisher() -> AnyPublisher<[String: Any], Never> {
        self.formRepository.formDataPublisher
    }

    @MainActor
    func userDataPublisher() -> AnyPublisher<[String: Any], Never> {
        self.user.userDataPublisher
    }

    // MARK: - HTTP Request

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Variable?) async -> Result<JSONData, NubrickError> {
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

    func fetchEmbedding(experimentId: String, componentId: String? = nil) async -> Result<FetchedEmbedding, NubrickError> {
        if let componentId = componentId {
            switch await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId) {
            case .success(let block):
                return .success(FetchedEmbedding(
                    experimentId: experimentId,
                    variantId: self.variantId,
                    block: block
                ))
            case .failure(let error):
                return .failure(error)
            }
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
        await self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)

        guard let componentId = extractComponentId(variant: extracted.variant) else {
            return Result.failure(NubrickError.notFound)
        }

        switch await self.componentRepository.fetchComponent(experimentId: extracted.experimentId, id: componentId) {
        case .success(let block):
            return .success(FetchedEmbedding(
                experimentId: extracted.experimentId,
                variantId: variantId,
                block: block
            ))
        case .failure(let error):
            return .failure(error)
        }
    }

    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<FetchedTriggerContent, NubrickError> {
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
            await self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)
        }

        guard let componentId = extractComponentId(variant: extracted.variant) else {
            return Result.failure(NubrickError.notFound)
        }

        switch await self.componentRepository.fetchComponent(experimentId: extracted.experimentId, id: componentId) {
        case .success(let block):
            return .success(FetchedTriggerContent(
                experimentId: extracted.experimentId,
                variantId: variantId,
                kind: extracted.kind,
                block: block
            ))
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
        await self.databaseRepository.appendExperimentHistory(experimentId: extracted.experimentId)

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

    @MainActor
    private func sendSurveyResponse() {
        guard let experimentId, let variantId else {
            return
        }
        guard let response_data = try? makeJsonString(self.formRepository.getFormData()) else {
            return
        }
        let trackRepository = self.trackRepository
        Task {
            await trackRepository.sendSurveyResponse(
                experimentId: experimentId,
                variantId: variantId,
                response_data: response_data
            )
        }
    }
}
