//
//  container.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation
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
    @MainActor
    func handleEvent(_ it: UIBlockEventDispatcher)
    func createVariableForTemplate(data: Any?, properties: [Property]?) -> Any?

    func getFormValue(key: String) -> Any?
    func getFormValues() -> [String: Any]
    func setFormValue(key: String, value: Any)
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener)
    func removeFormValueListener(_ id: String)

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError>
    func fetchEmbedding(experimentId: String, componentId: String?) async -> Result<UIBlock, NubrickError>
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError>
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError>
    func appendExperimentHistory(experimentId: String)
    
    func processMetricKitCrash(_ crash: MXCrashDiagnostic)

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent)
}

class ContainerEmptyImpl: Container {
    @MainActor
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
    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError> {
        return Result.failure(NubrickError.notFound)
    }
    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError> {
        return Result.failure(NubrickError.notFound)
    }
    func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
    }

    func appendExperimentHistory(experimentId: String) {
    }
}

class ContainerImpl: Container {
    private let config: Config
    private let user: NubrickUser
    private let trackRepository: TrackRepository2
    private let databaseRepository: DatabaseRepository
    private let experimentContentUseCase: ExperimentContentUseCase
    private let httpRequestUseCase: HttpRequestUseCase

    private let formRepository: FormRepository
    private let arguments: Any?

    convenience init(
        config: Config,
        user: NubrickUser,
        experimentRepository: ExperimentRepository2,
        componentRepository: ComponentRepository2,
        trackRepository: TrackRepository2,
        databaseRepository: DatabaseRepository,
        httpRequestRepository: HttpRequestRepository
    ) {
        self.init(
            config: config,
            user: user,
            trackRepository: trackRepository,
            databaseRepository: databaseRepository,
            experimentContentUseCase: ExperimentContentUseCaseImpl(
                user: user,
                experimentRepository: experimentRepository,
                componentRepository: componentRepository,
                trackRepository: trackRepository,
                databaseRepository: databaseRepository
            ),
            httpRequestUseCase: HttpRequestUseCaseImpl(httpRequestRepository: httpRequestRepository),
            arguments: nil
        )
    }

    init(
        config: Config,
        user: NubrickUser,
        trackRepository: TrackRepository2,
        databaseRepository: DatabaseRepository,
        experimentContentUseCase: ExperimentContentUseCase,
        httpRequestUseCase: HttpRequestUseCase,
        arguments: Any? = nil
    ) {
        self.config = config
        self.user = user
        self.trackRepository = trackRepository
        self.databaseRepository = databaseRepository
        self.experimentContentUseCase = experimentContentUseCase
        self.httpRequestUseCase = httpRequestUseCase
        self.formRepository = FormRepositoryImpl()
        self.arguments = arguments
    }

    convenience init(_ container: ContainerImpl, arguments: Any?) {
        self.init(
            config: container.config,
            user: container.user,
            trackRepository: container.trackRepository,
            databaseRepository: container.databaseRepository,
            experimentContentUseCase: container.experimentContentUseCase,
            httpRequestUseCase: container.httpRequestUseCase,
            arguments: arguments
        )
    }

    @MainActor
    func handleEvent(_ it: UIBlockEventDispatcher) {
        self.config.dispatchUIBlockEvent(event: it)
    }

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

    func getFormValue(key: String) -> Any? {
        return self.formRepository.getValue(key: key)
    }

    func getFormValues() -> [String: Any] {
        return self.formRepository.getFormData()
    }

    func setFormValue(key: String, value: Any) {
        self.formRepository.setValue(key: key, value: value)
    }

    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) {
        self.formRepository.addFormValueListener(id: id, listener: listener)
    }
    func removeFormValueListener(_ id: String) {
        self.formRepository.removeFormValueListener(id: id)
    }

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError> {
        return await self.httpRequestUseCase.sendHttpRequest(req: req, assertion: assertion, variable: variable)
    }

    func fetchEmbedding(experimentId: String, componentId: String? = nil) async -> Result<UIBlock, NubrickError> {
        return await self.experimentContentUseCase.fetchEmbedding(experimentId: experimentId, componentId: componentId)
    }

    func fetchTriggerContent(trigger: String, kinds: [ExperimentKind]) async -> Result<(String, ExperimentKind?, UIBlock), NubrickError> {
        return await self.experimentContentUseCase.fetchTriggerContent(trigger: trigger, kinds: kinds)
    }

    func fetchRemoteConfig(experimentId: String) async -> Result<(String, ExperimentVariant), NubrickError> {
        return await self.experimentContentUseCase.fetchRemoteConfig(experimentId: experimentId)
    }

    func appendExperimentHistory(experimentId: String) {
        self.databaseRepository.appendExperimentHistory(experimentId: experimentId)
    }

    func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
        self.trackRepository.processMetricKitCrash(crash)
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        self.trackRepository.sendFlutterCrash(crashEvent)
    }
}
