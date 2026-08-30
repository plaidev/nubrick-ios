//
//  repository.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/11/02.
//

import CoreData
import Foundation

import XCTest
@_spi(FlutterBridge) @testable import NubrickLocal

let HEALTH_CHECK_URL = "https://track.nativebrik.com/health"

private actor SurveyResponseTrackRepositorySpy: TrackRepository2 {
    struct Response {
        let experimentId: String
        let variantId: String
        let data: String
    }

    private var responses: [Response] = []
    private var responseWaiters: [CheckedContinuation<Response, Never>] = []

    func trackExperimentEvent(_ event: TrackExperimentEvent) async {}

    func trackEvent(_ event: TrackUserEvent) async {}

    func flushNow() async {}

    func processMetricKitCrash(
        callStackTreeJSON: Data,
        terminationReason: String?,
        exceptionType: UInt32?
    ) async {}

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) async {}

    func sendSurveyResponse(experimentId: String, variantId: String, response_data: String) async {
        let response = Response(
            experimentId: experimentId,
            variantId: variantId,
            data: response_data
        )
        if responseWaiters.isEmpty {
            responses.append(response)
        } else {
            responseWaiters.removeFirst().resume(returning: response)
        }
    }

    func nextResponse() async -> Response {
        if !responses.isEmpty {
            return responses.removeFirst()
        }
        return await withCheckedContinuation { continuation in
            responseWaiters.append(continuation)
        }
    }
}

private actor FlushCompletionFlag {
    private var complete = false

    func markComplete() {
        complete = true
    }

    func isComplete() -> Bool {
        complete
    }
}

private actor TrackingHTTPClientSpy: TrackingHTTPClient {
    enum Response {
        case statusCode(Int)
        case failure
    }

    private var response: Response
    private var queuedResponses: [Response] = []
    private var requests = [URLRequest]()
    private var holdFetches = false
    private var heldFetch: CheckedContinuation<Void, Never>?
    private var fetchStartWaiters: [CheckedContinuation<Void, Never>] = []

    init(response: Response, holdFetches: Bool = false) {
        self.response = response
        self.holdFetches = holdFetches
    }

    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if holdFetches {
            await withCheckedContinuation { continuation in
                heldFetch = continuation
                let waiters = fetchStartWaiters
                fetchStartWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume()
                }
            }
        }
        let response = nextResponse()
        switch response {
        case .statusCode(let statusCode):
            guard let url = request.url,
                  let response = HTTPURLResponse(
                url: url,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            ) else {
                throw URLError(.badURL)
            }
            return (Data(), response)
        case .failure:
            throw URLError(.notConnectedToInternet)
        }
    }

    func setResponse(_ response: Response) {
        self.response = response
    }

    func enqueueResponses(_ responses: [Response]) {
        queuedResponses.append(contentsOf: responses)
    }

    private func nextResponse() -> Response {
        guard !queuedResponses.isEmpty else {
            return response
        }
        return queuedResponses.removeFirst()
    }

    func waitForFetchStart() async {
        if heldFetch != nil {
            return
        }
        await withCheckedContinuation { continuation in
            fetchStartWaiters.append(continuation)
        }
    }

    func releaseHeldFetch() {
        let heldFetch = heldFetch
        self.heldFetch = nil
        heldFetch?.resume()
    }

    func recordedRequests() -> [URLRequest] {
        requests
    }
}

final class HttpRequestReposotiryTests: XCTestCase {
    @MainActor
    func testTrackingOutboxEvictsOnlyTheOldestEventAtCountLimit() throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let outbox = TrackOutbox(
            persistentContainer: persistentContainer,
            limits: TrackOutboxLimits(maxQueueSize: 2, maxQueueBytes: 1_000_000)
        )
        let first = makePendingTrackEvent(name: "first")
        let second = makePendingTrackEvent(name: "second")
        let third = makePendingTrackEvent(name: "third")

        XCTAssertNotNil(insertOutboxEvent(outbox, first, enqueuedAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotNil(insertOutboxEvent(outbox, second, enqueuedAt: Date(timeIntervalSince1970: 2)))
        XCTAssertNotNil(insertOutboxEvent(outbox, third, enqueuedAt: Date(timeIntervalSince1970: 3)))

        XCTAssertEqual(
            try pendingTrackEventIDs(in: persistentContainer),
            [second.eventUuid, third.eventUuid]
        )
    }

    @MainActor
    func testTrackingOutboxEvictsOnlyTheOldestEventAtByteLimit() throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let first = makePendingTrackEvent(name: "first")
        let second = makePendingTrackEvent(name: "second")
        let byteLimit = max(
            try JSONEncoder().encode(first).count,
            try JSONEncoder().encode(second).count
        )
        let outbox = TrackOutbox(
            persistentContainer: persistentContainer,
            limits: TrackOutboxLimits(maxQueueSize: 10, maxQueueBytes: byteLimit)
        )

        XCTAssertNotNil(insertOutboxEvent(outbox, first, enqueuedAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotNil(insertOutboxEvent(outbox, second, enqueuedAt: Date(timeIntervalSince1970: 2)))

        XCTAssertEqual(try pendingTrackEventIDs(in: persistentContainer), [second.eventUuid])
    }

    @MainActor
    func testTrackingOutboxDoesNotLetCrashesOvertakeEarlierEvents() throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let outbox = TrackOutbox(persistentContainer: persistentContainer)
        let before = makePendingTrackEvent(name: "event-before")
        var crash = makePendingTrackEvent(name: "crash")
        crash.typename = .Crash
        crash.name = nil
        let after = makePendingTrackEvent(name: "event-after")

        XCTAssertNotNil(insertOutboxEvent(outbox, before, enqueuedAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotNil(insertOutboxEvent(outbox, crash, enqueuedAt: Date(timeIntervalSince1970: 2)))
        XCTAssertNotNil(insertOutboxEvent(outbox, after, enqueuedAt: Date(timeIntervalSince1970: 3)))

        XCTAssertEqual(try outbox.nextBatch(maxEvents: 50, maxPayloadBytes: 512 * 1024).map(\.eventID), [before.eventUuid])
        XCTAssertTrue(outbox.remove(eventIDs: [before.eventUuid]))
        XCTAssertEqual(try outbox.nextBatch(maxEvents: 50, maxPayloadBytes: 512 * 1024).map(\.eventID), [crash.eventUuid])
        XCTAssertTrue(outbox.remove(eventIDs: [crash.eventUuid]))
        XCTAssertEqual(try outbox.nextBatch(maxEvents: 50, maxPayloadBytes: 512 * 1024).map(\.eventID), [after.eventUuid])
    }

    @MainActor
    func testTrackingEventPersistsThenFlushesAfterSuccessfulResponse() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "persisted-event"))
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 1)

        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        let payload = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: payload) as? [String: Any])
        let events = try XCTUnwrap(body["events"] as? [[String: Any]])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?["name"] as? String, "persisted-event")
    }

    @MainActor
    func testTrackingFlushRetainsFailedEventAndRetriesIt() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .failure)
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "retry-event"))
        await repository.flushNow()
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 1)

        await client.setResponse(.statusCode(204))
        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    func testTrackingRetryPolicyRetriesTransientFailuresOnly() {
        XCTAssertTrue(isRetryableTrackingStatusCode(500))
        XCTAssertTrue(isRetryableTrackingStatusCode(503))
        XCTAssertTrue(isRetryableTrackingStatusCode(429))
        XCTAssertTrue(isRetryableTrackingStatusCode(408))
        XCTAssertFalse(isRetryableTrackingStatusCode(400))
        XCTAssertFalse(isRetryableTrackingStatusCode(401))
        XCTAssertFalse(isRetryableTrackingStatusCode(404))
        XCTAssertFalse(isRetryableTrackingStatusCode(413))
        XCTAssertFalse(isRetryableTrackingStatusCode(422))
    }

    @MainActor
    func testTrackingFlushDropsEventAfterNonRetryableHTTPResponse() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(400))
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "bad-event"))
        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func testTrackingFlushRetainsEventAfterRetryableHTTPResponse() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(503))
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "retry-http-event"))
        await repository.flushNow()
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 1)

        await client.setResponse(.statusCode(200))
        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
    }

    @MainActor
    func testTrackingFlushDropsBatchAfterNonRetryableHTTPResponseAndSendsLaterEvents() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let outbox = TrackOutbox(persistentContainer: persistentContainer)
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        await client.enqueueResponses([.statusCode(400)])
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )
        let first = makePendingTrackEvent(name: "poison-event")
        let second = makePendingTrackEvent(name: "same-batch-event")

        XCTAssertNotNil(insertOutboxEvent(outbox, first, enqueuedAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotNil(insertOutboxEvent(outbox, second, enqueuedAt: Date(timeIntervalSince1970: 2)))

        await repository.flushNow()
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)

        await repository.trackEvent(TrackUserEvent(name: "later-event"))
        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try eventNames(in: requests[0]), ["poison-event", "same-batch-event"])
        XCTAssertEqual(try eventNames(in: requests[1]), ["later-event"])
    }

    @MainActor
    func testTrackingFlushNowWaitsForInFlightDrain() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(200), holdFetches: true)
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "held-event"))
        let firstFlush = Task {
            await repository.flushNow()
        }
        await client.waitForFetchStart()
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 1)

        let secondFlushFinished = FlushCompletionFlag()
        let secondFlush = Task {
            await repository.flushNow()
            await secondFlushFinished.markComplete()
        }

        try await Task.sleep(nanoseconds: 200_000_000)
        let finishedWhileInFlight = await secondFlushFinished.isComplete()
        XCTAssertFalse(
            finishedWhileInFlight,
            "flushNow returned while a drain was still in flight"
        )
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 1)

        await client.releaseHeldFetch()
        await firstFlush.value
        await secondFlush.value
        let finishedAfterRelease = await secondFlushFinished.isComplete()
        XCTAssertTrue(finishedAfterRelease)
        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 1)
    }

    @MainActor
    func testTrackingFlushSplitsAnOversizedEnvelopeWithoutDroppingEvents() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let outbox = TrackOutbox(persistentContainer: persistentContainer)
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        let repository = TrackRespositoryImpl(
            config: Config(projectId: String(repeating: "p", count: 40_000)),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )
        let first = makePendingTrackEvent(name: String(repeating: "a", count: 245_000))
        let second = makePendingTrackEvent(name: String(repeating: "b", count: 245_000))

        XCTAssertNotNil(insertOutboxEvent(outbox, first, enqueuedAt: Date(timeIntervalSince1970: 1)))
        XCTAssertNotNil(insertOutboxEvent(outbox, second, enqueuedAt: Date(timeIntervalSince1970: 2)))

        await repository.flushNow()

        XCTAssertEqual(try pendingTrackEventCount(in: persistentContainer), 0)
        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        for request in requests {
            let body = try XCTUnwrap(request.httpBody)
            XCTAssertLessThanOrEqual(body.count, 512 * 1024)
            let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: body) as? [String: Any])
            XCTAssertEqual((json["events"] as? [[String: Any]])?.count, 1)
        }
    }

    @MainActor
    func testTrackingFlushUsesUserIdAndMetaCapturedAtTrackTime() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        let user = NubrickUser()
        user.setProperty(BuiltinUserProperty.userId.rawValue, value: "user-before")
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: user,
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "before-switch"))
        user.setProperty(BuiltinUserProperty.userId.rawValue, value: "user-after")
        await repository.flushNow()

        let requests = await client.recordedRequests()
        let body = try requestJSON(in: try XCTUnwrap(requests.first))
        XCTAssertEqual(body["userId"] as? String, "user-before")
        let meta = try XCTUnwrap(body["meta"] as? [String: Any])
        XCTAssertEqual(meta["sdkVersion"] as? String, NubrickConstants.sdkVersion)
        XCTAssertEqual(meta["platform"] as? String, "ios")
    }

    @MainActor
    func testTrackingFlushSendsSeparateRequestsWhenCapturedUserIdChanges() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        let user = NubrickUser()
        user.setProperty(BuiltinUserProperty.userId.rawValue, value: "user-a")
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: user,
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )

        await repository.trackEvent(TrackUserEvent(name: "event-a"))
        user.setProperty(BuiltinUserProperty.userId.rawValue, value: "user-b")
        await repository.trackEvent(TrackUserEvent(name: "event-b"))
        await repository.flushNow()

        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try requestJSON(in: requests[0])["userId"] as? String, "user-a")
        XCTAssertEqual(try eventNames(in: requests[0]), ["event-a"])
        XCTAssertEqual(try requestJSON(in: requests[1])["userId"] as? String, "user-b")
        XCTAssertEqual(try eventNames(in: requests[1]), ["event-b"])
    }

    @MainActor
    func testTrackingFlushSendsSeparateRequestsWhenCapturedMetaChanges() async throws {
        let storeURL = makeTemporaryStoreURL()
        let persistentContainer = try XCTUnwrap(createNativebrikCoreDataHelper(storeURL: storeURL))
        defer { closeAndRemovePersistentStore(persistentContainer, at: storeURL) }
        let outbox = TrackOutbox(persistentContainer: persistentContainer)
        let client = TrackingHTTPClientSpy(response: .statusCode(200))
        let repository = TrackRespositoryImpl(
            config: Config(projectId: PROJECT_ID_FOR_TEST),
            user: NubrickUser(),
            persistentContainer: persistentContainer,
            trackingHTTPClient: client
        )
        let firstMeta = TrackEventMeta(
            appId: "app.one",
            appVersion: "1.0.0",
            cfBundleVersion: "1",
            osName: "iOS",
            osVersion: "18.0",
            sdkVersion: "1.0.0"
        )
        let secondMeta = TrackEventMeta(
            appId: "app.one",
            appVersion: "2.0.0",
            cfBundleVersion: "2",
            osName: "iOS",
            osVersion: "18.1",
            sdkVersion: "1.1.0"
        )

        XCTAssertNotNil(insertOutboxEvent(
            outbox,
            makePendingTrackEvent(name: "old-app"),
            userId: "same-user",
            meta: firstMeta,
            enqueuedAt: Date(timeIntervalSince1970: 1)
        ))
        XCTAssertNotNil(insertOutboxEvent(
            outbox,
            makePendingTrackEvent(name: "new-app"),
            userId: "same-user",
            meta: secondMeta,
            enqueuedAt: Date(timeIntervalSince1970: 2)
        ))

        await repository.flushNow()

        let requests = await client.recordedRequests()
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(try requestJSON(in: requests[0])["meta"] as? [String: String], [
            "appId": "app.one",
            "appVersion": "1.0.0",
            "cfBundleVersion": "1",
            "osName": "iOS",
            "osVersion": "18.0",
            "sdkVersion": "1.0.0",
            "platform": "ios",
        ])
        XCTAssertEqual(try requestJSON(in: requests[1])["meta"] as? [String: String], [
            "appId": "app.one",
            "appVersion": "2.0.0",
            "cfBundleVersion": "2",
            "osName": "iOS",
            "osVersion": "18.1",
            "sdkVersion": "1.1.0",
            "platform": "ios",
        ])
    }

    @MainActor
    func testCoreDataMigratesOutboxStoreWithoutCapturedRequestContext() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeSQLiteStore(at: storeURL) }

        let previousModel = NSManagedObjectModel()
        previousModel.entities = [
            UserEventEntity.entityDescription(),
            ExperimentHistoryEntity.entityDescription(),
            previousOutboxEntityDescription(),
        ]
        let previousContainer = NSPersistentContainer(
            name: "com.nativebrik.sdk",
            managedObjectModel: previousModel
        )
        let previousDescription = NSPersistentStoreDescription(url: storeURL)
        previousDescription.shouldAddStoreAsynchronously = false
        previousContainer.persistentStoreDescriptions = [previousDescription]

        var previousLoadError: Error?
        previousContainer.loadPersistentStores { _, error in
            previousLoadError = error
        }
        XCTAssertNil(previousLoadError)

        let previousOutboxEntity = try XCTUnwrap(
            previousModel.entitiesByName["NativebrikPendingTrackEvent"]
        )
        let previousEvent = PendingTrackEventEntity(
            entity: previousOutboxEntity,
            insertInto: previousContainer.viewContext
        )
        previousEvent.eventID = "legacy-event"
        previousEvent.payload = Data("{}".utf8)
        previousEvent.eventType = "event"
        previousEvent.byteCount = Int64(previousEvent.payload.count)
        previousEvent.createdAt = Date(timeIntervalSince1970: 1)
        try previousContainer.viewContext.save()
        previousContainer.viewContext.reset()
        let previousStore = try XCTUnwrap(previousContainer.persistentStoreCoordinator.persistentStores.first)
        try previousContainer.persistentStoreCoordinator.remove(previousStore)

        let migratedContainer = try XCTUnwrap(
            createNativebrikCoreDataHelper(storeURL: storeURL),
            "Expected the current SDK to migrate the previous outbox store"
        )
        let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        let migratedEvents = try migratedContainer.viewContext.fetch(request)
        XCTAssertEqual(migratedEvents.map(\.eventID), ["legacy-event"])
        XCTAssertNil(migratedEvents.first?.userId)
        XCTAssertNil(migratedEvents.first?.metaPayload)
        migratedContainer.viewContext.reset()
        let migratedStore = try XCTUnwrap(migratedContainer.persistentStoreCoordinator.persistentStores.first)
        try migratedContainer.persistentStoreCoordinator.remove(migratedStore)
    }

    @MainActor
    func testCoreDataMigratesStoreCreatedByPreviousSDKVersion() throws {
        let storeURL = makeTemporaryStoreURL()
        defer { removeSQLiteStore(at: storeURL) }

        let legacyModel = NSManagedObjectModel()
        legacyModel.entities = [
            UserEventEntity.entityDescription(),
            ExperimentHistoryEntity.entityDescription(),
        ]
        let legacyContainer = NSPersistentContainer(
            name: "com.nativebrik.sdk",
            managedObjectModel: legacyModel
        )
        let legacyDescription = NSPersistentStoreDescription(url: storeURL)
        legacyDescription.shouldAddStoreAsynchronously = false
        legacyContainer.persistentStoreDescriptions = [legacyDescription]

        var legacyLoadError: Error?
        legacyContainer.loadPersistentStores { _, error in
            legacyLoadError = error
        }
        XCTAssertNil(legacyLoadError)

        let legacyUserEventEntity = try XCTUnwrap(
            legacyModel.entitiesByName["NativebrikUserEvent"]
        )
        let legacyEvent = UserEventEntity(
            entity: legacyUserEventEntity,
            insertInto: legacyContainer.viewContext
        )
        legacyEvent.name = "event-created-by-old-sdk"
        legacyEvent.timestamp = Date(timeIntervalSince1970: 0)
        try legacyContainer.viewContext.save()
        legacyContainer.viewContext.reset()
        let legacyStore = try XCTUnwrap(legacyContainer.persistentStoreCoordinator.persistentStores.first)
        try legacyContainer.persistentStoreCoordinator.remove(legacyStore)

        let migratedContainer = try XCTUnwrap(
            createNativebrikCoreDataHelper(storeURL: storeURL),
            "Expected the current SDK to migrate the previous store"
        )
        let migratedContext = migratedContainer.viewContext

        let legacyRequest = NSFetchRequest<UserEventEntity>(entityName: "NativebrikUserEvent")
        let migratedEvents = try migratedContext.fetch(legacyRequest)
        XCTAssertEqual(migratedEvents.map(\.name), ["event-created-by-old-sdk"])

        let migratedOutboxEntity = try XCTUnwrap(
            migratedContainer.managedObjectModel.entitiesByName["NativebrikPendingTrackEvent"]
        )
        let outboxEvent = PendingTrackEventEntity(
            entity: migratedOutboxEntity,
            insertInto: migratedContext
        )
        outboxEvent.eventID = UUID().uuidString
        outboxEvent.payload = Data("{}".utf8)
        outboxEvent.eventType = "event"
        outboxEvent.byteCount = Int64(outboxEvent.payload.count)
        outboxEvent.createdAt = Date()
        try migratedContext.save()

        let outboxRequest = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        XCTAssertEqual(try migratedContext.count(for: outboxRequest), 1)
        migratedContext.reset()
        let migratedStore = try XCTUnwrap(migratedContainer.persistentStoreCoordinator.persistentStores.first)
        try migratedContainer.persistentStoreCoordinator.remove(migratedStore)
    }

    @MainActor
    private func pendingTrackEventCount(in persistentContainer: NSPersistentContainer) throws -> Int {
        let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        return try persistentContainer.viewContext.count(for: request)
    }

    @MainActor
    private func pendingTrackEventIDs(in persistentContainer: NSPersistentContainer) throws -> [String] {
        let request = NSFetchRequest<PendingTrackEventEntity>(entityName: "NativebrikPendingTrackEvent")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try persistentContainer.viewContext.fetch(request).map(\.eventID)
    }

    private func eventNames(in request: URLRequest) throws -> [String] {
        let events = try XCTUnwrap(requestJSON(in: request)["events"] as? [[String: Any]])
        return events.map { $0["name"] as? String ?? "" }
    }

    private func requestJSON(in request: URLRequest) throws -> [String: Any] {
        let payload = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: payload) as? [String: Any])
    }

    private func insertOutboxEvent(
        _ outbox: TrackOutbox,
        _ event: TrackEvent,
        userId: String = "test-user",
        meta: TrackEventMeta = TrackEventMeta(
            appId: "test.app",
            appVersion: "1.0.0",
            cfBundleVersion: "1",
            osName: "iOS",
            osVersion: "18.0",
            sdkVersion: "0.0.0"
        ),
        enqueuedAt: Date
    ) -> Int? {
        outbox.insertAndGetPendingCount(event, userId: userId, meta: meta, enqueuedAt: enqueuedAt)
    }

    private func previousOutboxEntityDescription() -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = "NativebrikPendingTrackEvent"
        entity.managedObjectClassName = NSStringFromClass(PendingTrackEventEntity.self)

        let eventID = NSAttributeDescription()
        eventID.name = "eventID"
        eventID.attributeType = .stringAttributeType
        eventID.isOptional = false

        let payload = NSAttributeDescription()
        payload.name = "payload"
        payload.attributeType = .binaryDataAttributeType
        payload.isOptional = false

        let eventType = NSAttributeDescription()
        eventType.name = "eventType"
        eventType.attributeType = .stringAttributeType
        eventType.isOptional = false

        let byteCount = NSAttributeDescription()
        byteCount.name = "byteCount"
        byteCount.attributeType = .integer64AttributeType
        byteCount.isOptional = false

        let createdAt = NSAttributeDescription()
        createdAt.name = "createdAt"
        createdAt.attributeType = .dateAttributeType
        createdAt.isOptional = false

        entity.properties = [eventID, payload, eventType, byteCount, createdAt]
        return entity
    }

    private func makePendingTrackEvent(name: String) -> TrackEvent {
        TrackEvent(
            typename: .Event,
            experimentId: nil,
            variantId: nil,
            name: name,
            timestamp: "2026-01-01T00:00:00Z",
            exceptions: nil,
            threads: nil,
            platform: nil,
            flutterSdkVersion: nil,
            severity: nil,
            eventUuid: UUID().uuidString
        )
    }

    private func makeTemporaryStoreURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
    }

    private func removeSQLiteStore(at storeURL: URL) {
        for suffix in ["", "-shm", "-wal"] {
            try? FileManager.default.removeItem(atPath: storeURL.path + suffix)
        }
    }

    @MainActor
    private func closeAndRemovePersistentStore(
        _ persistentContainer: NSPersistentContainer,
        at storeURL: URL
    ) {
        persistentContainer.viewContext.reset()
        for store in persistentContainer.persistentStoreCoordinator.persistentStores {
            try? persistentContainer.persistentStoreCoordinator.remove(store)
        }
        removeSQLiteStore(at: storeURL)
    }

    func testNubrickCauseDetectionOnlyConsidersCrashAttributedMetricKitThread() {
        let appFrame = StackFrame(binaryName: "Runner")
        let nubrickFrame = StackFrame(binaryName: "Nubrick")
        let crashEvent = TrackCrashEvent(
            exceptions: [],
            threads: [
                ThreadRecord(isMain: true, stacktrace: [appFrame]),
                ThreadRecord(isMain: false, stacktrace: [nubrickFrame]),
            ],
            platform: "ios"
        )

        XCTAssertFalse(isNubrickCausedCrash(crashEvent))
    }

    func testNubrickCauseDetectionAcceptsNubrickOnCrashAttributedMetricKitThread() {
        let crashEvent = TrackCrashEvent(
            exceptions: [],
            threads: [
                ThreadRecord(isMain: true, stacktrace: [StackFrame(binaryName: "Nubrick")]),
            ],
            platform: "ios"
        )

        XCTAssertTrue(isNubrickCausedCrash(crashEvent))
    }

    func testShouldCallApiHttpRequest() throws {
        let expectation = expectation(description: "Request should be expected.")
        let repository = HttpRequestRepositoryImpl(intercepter: nil)

        Task {
            let result = await repository.request(req: ApiHttpRequest(url: HEALTH_CHECK_URL), assetion: nil)
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let err):
                XCTFail("should be succeeded \(err)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)
    }

    func testShouldAssertHttpRequest() throws {
        let expectation = expectation(description: "Request should be unexpected.")
        let repository = HttpRequestRepositoryImpl(intercepter: nil)

        Task {
            let result = await repository.request(
                req: ApiHttpRequest(url: HEALTH_CHECK_URL),
                assetion: ApiHttpResponseAssertion(statusCodes: [300])
            )
            switch result {
            case .success:
                XCTFail("should be failure")
            case .failure:
                XCTAssertTrue(true)
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)
    }
}

@MainActor
final class ContainerTests: XCTestCase {
    private func makeContainer() throws -> Container {
        let db = try XCTUnwrap(createNativebrikCoreDataHelper(), "Could not init DB")
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let dependencies = NubrickDependencyContainer(
            config: config,
            user: user,
            actionHandler: { _, _ in },
            persistentContainer: db,
            httpRequestInterceptor: nil
        )
        return dependencies.makeContainer()
    }

    func testShouldCallApiHttpRequest() async throws {
        let container = try makeContainer()

        let result = await container.fetchRemoteConfig(experimentId: REMOTE_CONFIG_ID_1_FOR_TEST)
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure(let err):
            XCTFail("should found the remote config \(err)")
        }
    }

    func testMakeContainerShouldApplyArgumentsPerContext() throws {
        let container = try makeContainer()
        let arguments: NubrickArguments = ["bannerId": "banner_123"]

        let noArgsVariable = container.createVariableForTemplate(data: nil, properties: nil, arguments: nil)
        let withArgsVariable = container.createVariableForTemplate(data: nil, properties: nil, arguments: arguments)

        XCTAssertEqual("", compile("{{ args.bannerId }}", noArgsVariable))
        XCTAssertEqual("banner_123", compile("{{ args.bannerId }}", withArgsVariable))
    }

    func testMakeContainerShouldIsolateFormState() throws {
        let root = try makeContainer()
        root.setFormValue(key: "email", value: "root@example.com")

        let child = root.makeContainer()
        let rootEmailBefore = root.getFormValue(key: "email") as? String
        let childEmailBefore = child.getFormValue(key: "email") as? String
        XCTAssertEqual("root@example.com", rootEmailBefore)
        XCTAssertNil(childEmailBefore)

        child.setFormValue(key: "email", value: "child@example.com")
        let rootEmailAfter = root.getFormValue(key: "email") as? String
        let childEmailAfter = child.getFormValue(key: "email") as? String
        XCTAssertEqual("root@example.com", rootEmailAfter)
        XCTAssertEqual("child@example.com", childEmailAfter)
    }

    func testHandleEventSubmitsSurveyResponseWhenRequested() async throws {
        let db = try XCTUnwrap(createNativebrikCoreDataHelper(), "Could not init DB")
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let trackRepository = SurveyResponseTrackRepositorySpy()
        var handledAction: UIBlockAction?
        let container = ContainerImpl(
            config: config,
            user: user,
            actionHandler: { action, _ in handledAction = action },
            experimentRepository: ExperimentRepositoryImpl(config: config),
            componentRepository: ComponentRepositoryImpl(config: config),
            trackRepository: trackRepository,
            databaseRepository: DatabaseRepositoryImpl(persistentContainer: db),
            httpRequestRepository: HttpRequestRepositoryImpl(),
            experimentId: "experiment-id",
            variantId: "variant-id"
        )
        container.setFormValue(key: "answer", value: "yes")
        let action = UIBlockAction(
            eventName: "survey-submitted",
            name: nil,
            destinationPageId: nil,
            deepLink: nil,
            payload: nil,
            requiredFields: nil,
            httpRequest: nil,
            httpResponseAssertion: nil,
            submitSurveyResponse: true
        )

        container.handleEvent(action)

        let response = await trackRepository.nextResponse()
        XCTAssertEqual(response.experimentId, "experiment-id")
        XCTAssertEqual(response.variantId, "variant-id")
        let responseData = try XCTUnwrap(response.data.data(using: .utf8))
        let responseJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: responseData) as? [String: String]
        )
        XCTAssertEqual(responseJSON, ["answer": "yes"])
        XCTAssertEqual(handledAction?.eventName, "survey-submitted")
    }

    func testRootViewAppliesExperimentContextToSurveyResponses() async throws {
        let db = try XCTUnwrap(createNativebrikCoreDataHelper(), "Could not init DB")
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let trackRepository = SurveyResponseTrackRepositorySpy()
        let container = ContainerImpl(
            config: config,
            user: user,
            actionHandler: { _, _ in },
            experimentRepository: ExperimentRepositoryImpl(config: config),
            componentRepository: ComponentRepositoryImpl(config: config),
            trackRepository: trackRepository,
            databaseRepository: DatabaseRepositoryImpl(persistentContainer: db),
            httpRequestRepository: HttpRequestRepositoryImpl()
        )
        let rootView = RootView(
            root: nil,
            experimentId: "tooltip-experiment-id",
            variantId: "tooltip-variant-id",
            container: container,
            modalViewController: nil,
            onEvent: nil
        )
        let action = UIBlockAction(
            eventName: "survey-submitted",
            name: nil,
            destinationPageId: nil,
            deepLink: nil,
            payload: nil,
            requiredFields: nil,
            httpRequest: nil,
            httpResponseAssertion: nil,
            submitSurveyResponse: true
        )

        rootView.dispatchAction(action)

        let response = await trackRepository.nextResponse()
        XCTAssertEqual(response.experimentId, "tooltip-experiment-id")
        XCTAssertEqual(response.variantId, "tooltip-variant-id")
    }
}
