//
//  dependency-container.swift
//  Nubrick
//
//  Created by Codex on 2026/04/03.
//

import Foundation
import CoreData

struct NubrickDependencyContainer {
    let config: Config
    let user: NubrickUser
    let experimentRepository: ExperimentRepository2
    let componentRepository: ComponentRepository2
    let trackRepository: TrackRepository2
    let databaseRepository: DatabaseRepository
    let httpRequestRepository: HttpRequestRepository
    let experimentContentUseCase: ExperimentContentUseCase
    let httpRequestUseCase: HttpRequestUseCase

    init(
        config: Config,
        user: NubrickUser,
        persistentContainer: NSPersistentContainer,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil
    ) {
        let cache = CacheStore(policy: config.cachePolicy)

        self.config = config
        self.user = user
        self.experimentRepository = ExperimentRepositoryImpl(config: config, cache: cache)
        self.componentRepository = ComponentRepositoryImpl(config: config, cache: cache)
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
    }

    func makeRenderContext(arguments: Any? = nil) -> RenderContext {
        RenderContextImpl(
            config: config,
            user: user,
            experimentContentUseCase: experimentContentUseCase,
            httpRequestUseCase: httpRequestUseCase,
            arguments: arguments
        )
    }
}
