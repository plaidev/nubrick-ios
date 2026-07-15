//
//  repository.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/11/02.
//

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

    func trackExperimentEvent(_ event: TrackExperimentEvent) {}

    func trackEvent(_ event: TrackUserEvent) {}

    func processMetricKitCrash(
        callStackTreeJSON: Data,
        terminationReason: String?,
        exceptionType: UInt32?
    ) {}

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {}

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

final class HttpRequestReposotiryTests: XCTestCase {
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
