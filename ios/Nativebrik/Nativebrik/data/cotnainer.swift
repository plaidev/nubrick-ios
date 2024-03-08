//
//  cotnainer.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation
import CoreData

let nativebrikSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.waitsForConnectivity = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.allowsExpensiveNetworkAccess = true
    sessionConfig.allowsConstrainedNetworkAccess = true
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

public enum NativebrikError: Error {
    case notFound
    case failedToDecode
    case skipRequest
    case irregular(String)
    case other(Error)
}

protocol Container {
    func handleEvent(_ it: UIBlockEventDispatcher)
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any?

    func getFormValue(key: String) -> Any?
    func setFormValue(key: String, value: Any)

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NativebrikError>
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NativebrikError>
    func fetchInAppMessage(trigger: String) async -> Result<UIBlock, NativebrikError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NativebrikError>
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
    func setFormValue(key: String, value: Any) {
    }
    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NativebrikError> {
        return Result.failure(NativebrikError.skipRequest)
    }
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NativebrikError> {
        return Result.failure(NativebrikError.notFound)
    }
    func fetchInAppMessage(trigger: String) async -> Result<UIBlock, NativebrikError> {
        return Result.failure(NativebrikError.notFound)
    }
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NativebrikError> {
        return Result.failure(NativebrikError.notFound)
    }
}

class ContainerImpl: Container {
    private let config: Config
    private let user: NativebrikUser
    private let persistentContainer: NSPersistentContainer
    
    private let experimentRepository: ExperimentRepository2
    private let componentRepository: ComponentRepository2
    private let trackRepository: TrackRepository2
    private let formRepository: FormRepository
    private let databaseRepository: DatabaseRepository
    private let httpRequestRepository: HttpRequestRepository
    
    init(config: Config, user: NativebrikUser, persistentContainer: NSPersistentContainer, intercepter: NativebrikHttpRequestInterceptor? = nil) {
        self.config = config
        self.user = user
        self.persistentContainer = persistentContainer
        self.experimentRepository = ExperimentRepositoryImpl(config: config)
        self.componentRepository = ComponentRepositoryImpl(config: config)
        self.trackRepository = TrackRespositoryImpl(config: config, user: user)
        self.formRepository = FormRepositoryImpl()
        self.databaseRepository = DatabaseRepositoryImpl(persistentContainer: persistentContainer)
        self.httpRequestRepository = HttpRequestRepositoryImpl(intercepter: intercepter)
    }
    
    func handleEvent(_ it: UIBlockEventDispatcher) {
        self.config.dispatchUIBlockEvent(event: it)
    }
    
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any? {
        return _createVariableForTemplate(
            user: self.user,
            data: data,
            properties: properties,
            form: self.formRepository.getFormData(),
            projectId: self.config.projectId
        )
    }
    
    func getFormValue(key: String) -> Any? {
        return self.formRepository.getValue(key: key)
    }
    
    func setFormValue(key: String, value: Any) {
        self.formRepository.setValue(key: key, value: value)
    }
    
    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NativebrikError> {
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
    
    func fetchEmbedding(experimentId: String, componentId: String? = nil) async -> Result<UIBlock, NativebrikError> {
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
        
        var experimentId: String
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kind: ExperimentKind.EMBED) {
        case .success(let (id, v)):
            experimentId = id
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }
        
        guard let variantId = variant.id else {
            return Result.failure(NativebrikError.irregular("ExperimentVariant.id is not found"))
        }
        
        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)
        
        guard let componentId = extractComponentId(variant: variant) else {
            return Result.failure(NativebrikError.notFound)
        }
        
        return await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId)
    }
    
    func fetchInAppMessage(trigger: String) async -> Result<UIBlock, NativebrikError> {
        // send the user track event and save it to database
        self.trackRepository.trackEvent(TrackUserEvent(name: trigger))
        self.databaseRepository.appendUserEvent(name: trigger)

        // fetch config from cdn
        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchTriggerExperimentConfigs(name: trigger) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }
        
        var experimentId: String
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kind: ExperimentKind.POPUP) {
        case .success(let (id, v)):
            experimentId = id
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }
        
        guard let variantId = variant.id else {
            return Result.failure(NativebrikError.irregular("ExperimentVariant.id is not found"))
        }
        
        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)
        
        guard let componentId = extractComponentId(variant: variant) else {
            return Result.failure(NativebrikError.notFound)
        }
        
        return await self.componentRepository.fetchComponent(experimentId: experimentId, id: componentId)
    }
    
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NativebrikError> {
        var configs: ExperimentConfigs
        switch await self.experimentRepository.fetchExperimentConfigs(id: experimentId) {
        case .success(let it):
            configs = it
        case .failure(let it):
            return Result.failure(it)
        }
        
        var experimentId: String
        var variant: ExperimentVariant
        switch await self.extractVariant(configs: configs, kind: ExperimentKind.POPUP) {
        case .success(let (id, v)):
            experimentId = id
            variant = v
        case .failure(let it):
            return Result.failure(it)
        }
        
        guard let variantId = variant.id else {
            return Result.failure(NativebrikError.irregular("ExperimentVariant.id is not found"))
        }
        
        self.trackRepository.trackExperimentEvent(TrackExperimentEvent(
            experimentId: experimentId, variantId: variantId
        ))
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)

        return Result.success((experimentId, variant))
    }
    
    private func extractVariant(configs: ExperimentConfigs, kind: ExperimentKind) async -> Result<(String, ExperimentVariant), NativebrikError> {
        guard let config = extractExperimentConfigMatchedToProperties(
            configs: configs,
            properties: { seed in
                return self.user.toEventProperties(seed: seed)
            },
            isNotInFrequency: { experimentId, frequency in
                return self.databaseRepository.isNotInFrequency(experimentId: experimentId, frequency: frequency)
            }
        ) else {
            return Result.failure(NativebrikError.notFound)
        }
        guard let experimentId = config.id else {
            return Result.failure(NativebrikError.irregular("Couldn't get the experiment id"))
        }
        if (config.kind != kind) {
            return Result.failure(NativebrikError.notFound)
        }
        let normalizedUserRnd = self.user.getSeededNormalizedUserRnd(seed: config.seed ?? 0)
        guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: normalizedUserRnd) else {
            return Result.failure(NativebrikError.notFound)
        }
        return Result.success((experimentId, variant))
    }
}
