//
//  container.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation
import CoreData
import MetricKit

public enum NubrickError: Error {
    case notFound
    case failedToDecode
    case unexpected
    case skipRequest
    case irregular(String)
    case other(Error)
}

protocol Container {
    func handleEvent(_ it: UIBlockEventDispatcher)
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any?

    func getFormValue(key: String) -> Any?
    func getFormValues() -> [String: Any]
    func setFormValue(key: String, value: Any)
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener)
    func removeFormValueListener(_ id: String)

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError>
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NubrickError>
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(ExperimentKind?, UIBlock), NubrickError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError>
    
    @available(iOS 14.0, *)
    func processMetricKitCrash(_ crash: MXCrashDiagnostic)

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent)
}

class ContainerEmptyImpl: Container {
    func handleEvent(_ it: UIBlockEventDispatcher) {
    }
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any? {
        return nil
    }
    func getFormValue(key: String) -> Any? {
        return nil
    }
    func getFormValues() -> [String: Any] {
        return [:]
    }
    func setFormValue(key: String, value: Any) {
    }
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) { }
    func removeFormValueListener(_ id: String) { }


    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError> {
        return Result.failure(NubrickError.skipRequest)
    }
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NubrickError> {
        return Result.failure(NubrickError.notFound)
    }
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(ExperimentKind?, UIBlock), NubrickError> {
        return Result.failure(NubrickError.notFound)
    }
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError> {
        return Result.failure(NubrickError.notFound)
    }
    @available(iOS 14.0, *)
    func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
    }
}

class ContainerImpl: Container {
    private let config: Config
    private let user: NubrickUser
    private let persistentContainer: NSPersistentContainer

    private let experimentRepository: ExperimentRepository2
    private let componentRepository: ComponentRepository2
    private let trackRepository: TrackRepository2
    private let formRepository: FormRepository?
    private let databaseRepository: DatabaseRepository
    private let httpRequestRepository: HttpRequestRepository

    private let arguments: Any?

    init(config: Config, cache: CacheStore, user: NubrickUser, persistentContainer: NSPersistentContainer, intercepter: NubrickHttpRequestInterceptor? = nil) {
        self.config = config
        self.user = user
        self.persistentContainer = persistentContainer
        self.experimentRepository = ExperimentRepositoryImpl(config: config, cache: cache)
        self.componentRepository = ComponentRepositoryImpl(config: config, cache: cache)
        self.trackRepository = TrackRespositoryImpl(config: config, user: user)
        self.formRepository = FormRepositoryImpl()
        self.databaseRepository = DatabaseRepositoryImpl(persistentContainer: persistentContainer)
        self.httpRequestRepository = HttpRequestRepositoryImpl(intercepter: intercepter)

        self.arguments = nil
    }

    // should be refactored.
    // this is because, i wanted to initialize form instance for each component, not to share the same instance from every components.
    // this is called when component is instantiated.
    // bad code.
    init(_ container: ContainerImpl, arguments: Any?) {
        self.config = container.config
        self.user = container.user
        self.persistentContainer = container.persistentContainer
        self.experimentRepository = container.experimentRepository
        self.componentRepository = container.componentRepository
        self.trackRepository = container.trackRepository
        self.formRepository = FormRepositoryImpl()
        self.databaseRepository = container.databaseRepository
        self.httpRequestRepository = container.httpRequestRepository
        self.arguments = arguments
    }

    func handleEvent(_ it: UIBlockEventDispatcher) {
        self.config.dispatchUIBlockEvent(event: it)
    }

    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any? {
        return _createVariableForTemplate(
            user: self.user,
            data: data,
            properties: properties,
            form: self.formRepository?.getFormData(),
            arguments: self.arguments,
            projectId: self.config.projectId
        )
    }

    func getFormValue(key: String) -> Any? {
        return self.formRepository?.getValue(key: key)
    }

    func getFormValues() -> [String: Any] {
        return self.formRepository?.getFormData() ?? [:]
    }

    func setFormValue(key: String, value: Any) {
        self.formRepository?.setValue(key: key, value: value)
    }

    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) {
        self.formRepository?.addFormValueListener(id: id, listener: listener)
    }
    func removeFormValueListener(_ id: String) {
        self.formRepository?.removeFormValueListener(id: id)
    }

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

    func fetchEmbedding(experimentId: String, componentId: String? = nil) async -> Result<UIBlock, NubrickError> {
        if let componentId = componentId {
            let component = await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId)
            return component
        }

        // retrieve experiment config
        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchExperimentConfigs(id: experimentId) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }

        var experimentId: String
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kinds: [.EMBED]) {
        case .success(let (id, _, v)):
            experimentId = id
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }

        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)

        guard let componentId = extractComponentId(variant: variant) else {
            return Result.failure(NubrickError.notFound)
        }

        return await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId)
    }

    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(ExperimentKind?, UIBlock), NubrickError> {
        // send the user track event and save it to database
        self.trackRepository.trackEvent(TrackUserEvent(name: trigger))
        await self.databaseRepository.appendUserEvent(name: trigger)

        // fetch config from cdn
        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchTriggerExperimentConfigs(name: trigger) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }

        // select the best matching config for the specified kinds
        var experimentId: String
        var experimentKind: ExperimentKind?
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kinds: kinds) {
        case .success(let (id, kind, v)):
            experimentId = id
            experimentKind = kind
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }

        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)

        guard let componentId = extractComponentId(variant: variant) else {
            return Result.failure(NubrickError.notFound)
        }

        switch await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId) {
        case .success(let block):
            return .success((experimentKind, block))
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

        var experimentId: String
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kinds: [.CONFIG]) {
        case .success(let (id, _, v)):
            experimentId = id
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }

        guard let variantId = variant.id else {
            return Result.failure(NubrickError.irregular("ExperimentVariant.id is not found"))
        }

        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)

        return Result.success((experimentId, variant))
    }

    private func extractVariant(configs: ExperimentConfigs, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, ExperimentVariant), NubrickError> {
        guard let config = extractExperimentConfigMatchedToProperties(
            configs: configs,
            kinds: kinds,
            properties: { seed in
                return self.user.toEventProperties(seed: seed)
            },
            isNotInFrequency: { experimentId, frequency in
                return self.databaseRepository.isNotInFrequency(experimentId: experimentId, frequency: frequency)
            },
            isMatchedToUserEventFrequencyConditions: { conditions in
                guard let conditions = conditions else {
                    return true
                }
                return conditions.allSatisfy { condition in
                    return self.databaseRepository.isMatchedToUserEventFrequencyCondition(condition: condition)
                }
            }
        ) else {
            return Result.failure(NubrickError.notFound)
        }
        guard let experimentId = config.id else {
            return Result.failure(NubrickError.irregular("Couldn't get the experiment id"))
        }
        let normalizedUserRnd = self.user.getSeededNormalizedUserRnd(seed: config.seed ?? 0)
        guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: normalizedUserRnd) else {
            return Result.failure(NubrickError.notFound)
        }
        return Result.success((experimentId, config.kind, variant))
    }
    @available(iOS 14.0, *)
    func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
        self.trackRepository.processMetricKitCrash(crash)
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        self.trackRepository.sendFlutterCrash(crashEvent)
    }
}
