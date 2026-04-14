//
//  dependency-container.swift
//  Nubrick
//
//  Created by Codex on 2026/04/03.
//

import Foundation
import CoreData

struct NubrickDependencyContainer : Sendable {
    let config: Config
    let user: NubrickUser
    let experimentRepository: ExperimentRepository2
    let componentRepository: ComponentRepository2
    let trackRepository: TrackRepository2
    let databaseRepository: DatabaseRepository
    let httpRequestRepository: HttpRequestRepository
    let experimentContentUseCase: ExperimentContentUseCase
    let httpRequestUseCase: HttpRequestUseCase
    private let actionHandler: UIBlockActionHandler

    init(
        config: Config,
        user: NubrickUser,
        actionHandler: @escaping UIBlockActionHandler,
        persistentContainer: NSPersistentContainer,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil
    ) {
        self.config = config
        self.user = user
        self.experimentRepository = ExperimentRepositoryImpl(config: config)
        self.componentRepository = ComponentRepositoryImpl(config: config)
        self.trackRepository = TrackRespositoryImpl(config: config, user: user)
        self.databaseRepository = DatabaseRepositoryImpl(persistentContainer: persistentContainer)
        self.httpRequestRepository = HttpRequestRepositoryImpl(intercepter: httpRequestInterceptor)
        self.experimentContentUseCase = ExperimentContentUseCaseImpl(
            user: user,
            experimentRepository: self.experimentRepository,
            componentRepository: self.componentRepository,
            trackRepository: self.trackRepository,
            databaseRepository: self.databaseRepository
        )
        self.httpRequestUseCase = HttpRequestUseCaseImpl(
            httpRequestRepository: self.httpRequestRepository
        )
        self.actionHandler = actionHandler
    }

    @MainActor
    func makeRenderContext(arguments: NubrickArguments? = nil) -> RenderContext {
        RenderContextImpl(
            config: config,
            user: user,
            actionHandler: actionHandler,
            experimentContentUseCase: experimentContentUseCase,
            httpRequestUseCase: httpRequestUseCase,
            arguments: arguments
        )
    }
}
