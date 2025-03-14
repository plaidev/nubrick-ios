//
//  repository.swift
//  NativebrikTests
//
//  Created by Ryosuke Suzuki on 2023/11/02.
//

import Foundation

import XCTest
@testable import Nativebrik

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

        wait(for: [expectation], timeout: 5)
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
        
        wait(for: [expectation], timeout: 5)
    }
}

final class ContainerTests: XCTestCase {
    func testShouldCallApiHttpRequest() throws {
        let db = createNativebrikCoreDataHelper()
        let user = NativebrikUser()
        let config = Config(projectId: PROJECT_ID_FOR_TEST)
        let cache = CacheStore(policy: NativebrikCachePolicy())
        let container = ContainerImpl(config: config, cache: cache, user: user, persistentContainer: db)
        let expectation = expectation(description: "Request should be expected.")
        
        Task {
            let result = await container.fetchRemoteConfig(experimentId: REMOTE_CONFIG_ID_1_FOR_TEST)
            switch result {
            case .success:
                XCTAssertTrue(true)
            case .failure(let err):
                XCTFail("should found the remote config \(err)")
            }
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 5)
    }
}
