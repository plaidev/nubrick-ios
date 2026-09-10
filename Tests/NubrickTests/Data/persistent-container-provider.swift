import CoreData
@testable import NubrickLocal

final class TestPersistentContainerProvider: PersistentContainerProvider, @unchecked Sendable {
    private let persistentContainer: NSPersistentContainer

    init(_ persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    func persistentContainer() async -> NSPersistentContainer? {
        persistentContainer
    }
}

extension DatabaseRepositoryImpl {
    convenience init(persistentContainer: NSPersistentContainer) {
        self.init(persistentContainerProvider: TestPersistentContainerProvider(persistentContainer))
    }
}

extension TrackRespositoryImpl {
    init(
        config: Config,
        user: NubrickUser,
        persistentContainer: NSPersistentContainer,
        trackingHTTPClient: any HTTPClient = trackingSession
    ) {
        self.init(
            config: config,
            user: user,
            persistentContainerProvider: TestPersistentContainerProvider(persistentContainer),
            trackingHTTPClient: trackingHTTPClient
        )
    }
}
