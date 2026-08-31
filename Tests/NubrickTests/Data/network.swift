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

    func testMemoryCacheEvictsOldEntriesToHonorByteBudget() {
        let first = URL(string: "https://cdn.example/first")!
        let second = URL(string: "https://cdn.example/second")!
        MemoryResponseCache.shared.set(first, data: Data(repeating: 1, count: 4 * 1024 * 1024))
        MemoryResponseCache.shared.set(second, data: Data([2]))

        XCTAssertNil(MemoryResponseCache.shared.get(first))
        XCTAssertEqual(MemoryResponseCache.shared.get(second), Data([2]))
    }

    func testInvalidateCachedResponseClearsMemory() {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/gone")!
        MemoryResponseCache.shared.set(url, data: Data("stale".utf8))
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        invalidateCachedResponse(for: request)
        XCTAssertNil(MemoryResponseCache.shared.get(url))
    }


}
