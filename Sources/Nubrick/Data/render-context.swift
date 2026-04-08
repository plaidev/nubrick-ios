//
//  render-context.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation

public enum NubrickError: Error {
    case notFound
    case failedToDecode
    case unexpected
    case skipRequest
    case irregular(String)
    case other(Error)
}

protocol RenderContext : Sendable {
    @MainActor
    func handleEvent(_ it: UIBlockAction)
    @MainActor
    func makeContext(arguments: NubrickArguments?) -> RenderContext
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

final class RenderContextImpl: RenderContext {
    private let config: Config
    private let user: NubrickUser
    private let actionHandler: UIBlockActionHandler
    private let experimentContentUseCase: ExperimentContentUseCase
    private let httpRequestUseCase: HttpRequestUseCase
    private let formRepository: FormRepository
    private let arguments: NubrickArguments?

    @MainActor
    init(
        config: Config,
        user: NubrickUser,
        actionHandler: @escaping UIBlockActionHandler,
        experimentContentUseCase: ExperimentContentUseCase,
        httpRequestUseCase: HttpRequestUseCase,
        arguments: NubrickArguments? = nil
    ) {
        self.config = config
        self.user = user
        self.actionHandler = actionHandler
        self.experimentContentUseCase = experimentContentUseCase
        self.httpRequestUseCase = httpRequestUseCase
        self.formRepository = FormRepositoryImpl()
        self.arguments = arguments
    }

    @MainActor
    func handleEvent(_ it: UIBlockAction) {
        self.actionHandler(it, nil)
    }

    @MainActor
    func makeContext(arguments: NubrickArguments?) -> RenderContext {
        return RenderContextImpl(
            config: self.config,
            user: self.user,
            actionHandler: self.actionHandler,
            experimentContentUseCase: self.experimentContentUseCase,
            httpRequestUseCase: self.httpRequestUseCase,
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
}
