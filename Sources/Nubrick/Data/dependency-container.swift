//
//  dependency-container.swift
//  Nubrick
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
        let trackRepository = TrackRespositoryImpl(
            config: config,
            user: user,
            persistentContainer: persistentContainer
        )
        self.trackRepository = trackRepository
        self.databaseRepository = DatabaseRepositoryImpl(persistentContainer: persistentContainer)
        self.httpRequestRepository = HttpRequestRepositoryImpl(intercepter: httpRequestInterceptor)
        self.actionHandler = actionHandler
    }

    @MainActor
    func makeContainer() -> Container {
        ContainerImpl(
            config: config,
            user: user,
            actionHandler: actionHandler,
            experimentRepository: experimentRepository,
            componentRepository: componentRepository,
            trackRepository: trackRepository,
            databaseRepository: databaseRepository,
            httpRequestRepository: httpRequestRepository
        )
    }
}
