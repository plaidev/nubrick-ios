//
//  repository.swift
//  NubrickTests
//
//  Created by Ryosuke Suzuki on 2023/11/02.
//

import Foundation

import XCTest
@testable import NubrickLocal

let HEALTH_CHECK_URL = "https://track.nativebrik.com/health"

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
final class RenderContextTests: XCTestCase {
    private func makeRenderContext(arguments: NubrickArguments? = nil) -> RenderContext {
        let db = createNativebrikCoreDataHelper()
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let dependencies = NubrickDependencyContainer(
            config: config,
            user: user,
            actionHandler: { _, _ in },
            persistentContainer: db,
            httpRequestInterceptor: nil
        )
        return dependencies.makeRenderContext(arguments: arguments)
    }

    func testShouldCallApiHttpRequest() async throws {
        let renderContext = makeRenderContext()

        let result = await renderContext.fetchRemoteConfig(experimentId: REMOTE_CONFIG_ID_1_FOR_TEST)
        switch result {
        case .success:
            XCTAssertTrue(true)
        case .failure(let err):
            XCTFail("should found the remote config \(err)")
        }
    }

    func testMakeContextShouldApplyArgumentsPerContext() {
        let root = makeRenderContext()
        let arguments: NubrickArguments = ["bannerId": "banner_123"]
        let child = root.makeContext(arguments: arguments)

        let rootVariable = root.createVariableForTemplate(data: nil, properties: nil)
        let childVariable = child.createVariableForTemplate(data: nil, properties: nil)

        XCTAssertEqual("", compile("{{ args.bannerId }}", rootVariable))
        XCTAssertEqual("banner_123", compile("{{ args.bannerId }}", childVariable))
    }

    func testMakeContextShouldIsolateFormState() {
        let root = makeRenderContext()
        root.setFormValue(key: "email", value: "root@example.com")

        let child = root.makeContext(arguments: nil)
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
}
