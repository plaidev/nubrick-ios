//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/14.
//

import Foundation
import XCTest
@testable import NubrickLocal

final class GetDataTests: XCTestCase {
    override func setUp() {
        super.setUp()
        MemoryResponseCache.shared.removeAll()
    }

    func testGetDataReturnsResponse() async {
        let url = URL(string: "https://example.com")!
        let result = await getData(url: url)

        switch result {
        case .success(let data):
            XCTAssertFalse(data.isEmpty)
        case .failure(let error):
            XCTFail("Expected a response, got \(error)")
        }
    }

    func testMemoryCacheReturnsLastGoodWithinTTL() {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/e")!
        let body = Data("{\"ok\":true}".utf8)
        MemoryResponseCache.shared.set(url, data: body)
        XCTAssertEqual(MemoryResponseCache.shared.get(url), body)
    }

    func testMemoryCacheRemoveClearsEntry() {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/e")!
        MemoryResponseCache.shared.set(url, data: Data("x".utf8))
        MemoryResponseCache.shared.remove(url)
        XCTAssertNil(MemoryResponseCache.shared.get(url))
    }

    func testInvalidateCachedResponseClearsMemory() {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/gone")!
        MemoryResponseCache.shared.set(url, data: Data("stale".utf8))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        invalidateCachedResponse(for: request)
        XCTAssertNil(MemoryResponseCache.shared.get(url))
    }

    func testComponentCachePrefixFromConfigURL() {
        let config = URL(string: "https://cdn.nativebrik.com/projects/p1/experiments/id/e1")!
        XCTAssertEqual(
            componentCachePrefix(from: config),
            "https://cdn.nativebrik.com/projects/p1/experiments/components/"
        )
        XCTAssertTrue(isExperimentConfigURL(config))
        XCTAssertFalse(
            isExperimentConfigURL(
                URL(string: "https://cdn.nativebrik.com/projects/p1/experiments/components/e1/c1")!
            )
        )
    }

    func testChangedExperimentConfigDropsComponentCache() {
        let config = URL(string: "https://cdn.example/projects/p1/experiments/id/e1")!
        let component = URL(string: "https://cdn.example/projects/p1/experiments/components/e1/c1")!
        MemoryResponseCache.shared.set(config, data: Data("v1".utf8))
        MemoryResponseCache.shared.set(component, data: Data("component-v1".utf8))

        MemoryResponseCache.shared.set(config, data: Data("v2".utf8))

        XCTAssertNil(MemoryResponseCache.shared.get(component))
        XCTAssertEqual(MemoryResponseCache.shared.get(config), Data("v2".utf8))
    }
}
