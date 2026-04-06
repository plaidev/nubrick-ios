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

final class RenderContextTests: XCTestCase {
    private func makeRenderContext(arguments: Any? = nil) -> RenderContext {
        let db = createNativebrikCoreDataHelper()
        let user = NubrickUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let dependencies = NubrickDependencyContainer(
            config: config,
            user: user,
            persistentContainer: db,
            httpRequestInterceptor: nil
        )
        return dependencies.makeRenderContext(arguments: arguments)
    }

    func testShouldCallApiHttpRequest() throws {
        let renderContext = makeRenderContext()
        let expectation = expectation(description: "Request should be expected.")

        Task {
            let result = await renderContext.fetchRemoteConfig(experimentId: REMOTE_CONFIG_ID_1_FOR_TEST)
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let err):
                XCTFail("should found the remote config \(err)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 30)
    }

    func testMakeContextShouldApplyArgumentsPerContext() {
        let root = makeRenderContext()
        let child = root.makeContext(arguments: ["bannerId": "banner_123"])

        let rootVariable = root.createVariableForTemplate(data: nil, properties: nil)
        let childVariable = child.createVariableForTemplate(data: nil, properties: nil)

        XCTAssertEqual("", compile("{{ args.bannerId }}", rootVariable))
        XCTAssertEqual("banner_123", compile("{{ args.bannerId }}", childVariable))
    }

    func testMakeContextShouldIsolateFormState() {
        let root = makeRenderContext()
        root.setFormValue(key: "email", value: "root@example.com")

        let child = root.makeContext(arguments: nil)
        XCTAssertEqual("root@example.com", root.getFormValue(key: "email") as? String)
        XCTAssertNil(child.getFormValue(key: "email"))

        child.setFormValue(key: "email", value: "child@example.com")
        XCTAssertEqual("root@example.com", root.getFormValue(key: "email") as? String)
        XCTAssertEqual("child@example.com", child.getFormValue(key: "email") as? String)
    }
}
