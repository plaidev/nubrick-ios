//
//  network.swift
//  NubrickTests
//
//  Created by Takuma Jimbo on 2025/03/14.
//

import Foundation
import XCTest
@testable import NubrickLocal

private actor ScriptedHTTPClient: HTTPClient {
    struct Step: Sendable {
        let statusCode: Int
        let body: Data
        let delay: TimeInterval
        let error: URLError?

        init(statusCode: Int = 200, body: String = "", delay: TimeInterval = 0, error: URLError? = nil) {
            self.statusCode = statusCode
            self.body = Data(body.utf8)
            self.delay = delay
            self.error = error
        }
    }

    private var steps: [Step]
    private var requestCount = 0

    init(steps: [Step]) {
        self.steps = steps
    }

    func count() -> Int {
        return requestCount
    }

    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard !steps.isEmpty else { throw URLError(.badServerResponse) }

        let index = requestCount
        requestCount += 1
        let step = steps[min(index, steps.count - 1)]
        if step.delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(step.delay * 1_000_000_000))
        }
        if let error = step.error {
            throw error
        }

        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: step.statusCode,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/plain"]
              ) else {
            throw URLError(.badServerResponse)
        }
        return (step.body, response)
    }
}

final class GetDataTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        await ExperimentContentStore.shared.removeAll()
        __for_test_sync_datetime_offset(offset: 0)
    }

    override func tearDown() async throws {
        __for_test_sync_datetime_offset(offset: 0)
        await ExperimentContentStore.shared.removeAll()
        try await super.tearDown()
    }

    func testGetDataReturnsResponse() async {
        let url = URL(string: "https://example.com")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "response"),
        ])
        let result = await getExperimentContent(url: url, contentClient: httpClient)

        switch result {
        case .success(let data):
            XCTAssertEqual(data, Data("response".utf8))
        case .failure(let error):
            XCTFail("Expected a response, got \(error)")
        }
    }

    func testGetRetriesServerErrorsThenSucceeds() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 500, body: ""),
            .init(statusCode: 502, body: ""),
            .init(statusCode: 200, body: "ok"),
        ])

        let result = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? result.get(), Data("ok".utf8))
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 3)
    }

    func testGetDoesNotRetryNotFound() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 404, body: ""),
            .init(statusCode: 200, body: "should-not-be-fetched"),
        ])

        let result = await getExperimentContent(url: url, contentClient: httpClient)
        guard case .failure(.notFound) = result else {
            XCTFail("Expected notFound, got \(result)")
            return
        }
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 1)
    }

    func testGetDoesNotRetryClientErrors() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 400, body: "bad request"),
            .init(statusCode: 200, body: "should-not-be-fetched"),
        ])

        let result = await getExperimentContent(url: url, contentClient: httpClient)
        guard case .failure(.unexpected) = result else {
            XCTFail("Expected unexpected, got \(result)")
            return
        }
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 1)
    }

    func testGetRetriesTimeoutThenSucceeds() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(error: URLError(.timedOut)),
            .init(statusCode: 200, body: "ok"),
        ])

        let result = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? result.get(), Data("ok".utf8))
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 2)
    }

    func testMemoryCacheReturnsLastGoodWithinTTL() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/e")!
        let body = Data("{\"ok\":true}".utf8)
        await ExperimentContentStore.shared.set(url, data: body)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, body)
    }

    func testMemoryCacheRemoveClearsEntry() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/e")!
        await ExperimentContentStore.shared.set(url, data: Data("x".utf8))
        await ExperimentContentStore.shared.remove(url)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertNil(cached)
    }

    func testMemoryCacheEvictsOldEntriesToHonorByteBudget() async {
        let first = URL(string: "https://cdn.example/first")!
        let second = URL(string: "https://cdn.example/second")!
        await ExperimentContentStore.shared.set(first, data: Data(repeating: 1, count: 4 * 1024 * 1024))
        await ExperimentContentStore.shared.set(second, data: Data([2]))

        let firstCached = await ExperimentContentStore.shared.get(first)
        let secondCached = await ExperimentContentStore.shared.get(second)
        XCTAssertNil(firstCached)
        XCTAssertEqual(secondCached, Data([2]))
    }

    func testMemoryCacheKeepsLastGoodEntryWhenNewResponseExceedsBudget() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/large")!
        await ExperimentContentStore.shared.set(url, data: Data("old".utf8))
        await ExperimentContentStore.shared.set(
            url,
            data: Data(repeating: 1, count: 4 * 1024 * 1024 + 1)
        )

        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("old".utf8))
    }

    func testFetchGenerationStateIsReleasedAfterRequestsFinish() async {
        let httpClient = ScriptedHTTPClient(steps: [.init(statusCode: 200, body: "ok")])

        for _ in 0..<200 {
            let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
            _ = await getExperimentContent(url: url, contentClient: httpClient)
        }

        let inFlightURLCount = await ExperimentContentStore.shared.__for_test_inFlightURLCount()
        XCTAssertEqual(inFlightURLCount, 0)
    }

    func testMemoryCacheExpiresAfterRetention() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/expired")!
        await ExperimentContentStore.shared.set(url, data: Data("old".utf8))
        __for_test_sync_datetime_offset(offset: Int64((NubrickConstants.defaultCacheRetentionSeconds + 1) * 1000))
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertNil(cached)
    }

    func testMemoryCacheRetainsContentBeyondTenMinutes() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/custom")!
        await ExperimentContentStore.shared.set(url, data: Data("old".utf8))

        __for_test_sync_datetime_offset(offset: 10 * 60 * 1000 + 1)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("old".utf8))
    }

    func testCacheHitReturnsImmediatelyAndRevalidates() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 200, body: "new", delay: 0.2),
        ])

        let first = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? first.get(), Data("old".utf8))

        let second = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? second.get(), Data("old".utf8))

        var updated = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if await ExperimentContentStore.shared.get(url) == Data("new".utf8) {
                updated = true
                break
            }
        }
        XCTAssertTrue(updated)
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 2)
    }

    func testExpiredCacheFetchesFromNetwork() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 200, body: "fresh"),
        ])

        let first = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? first.get(), Data("old".utf8))

        __for_test_sync_datetime_offset(offset: Int64((NubrickConstants.defaultCacheRetentionSeconds + 1) * 1000))
        let second = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? second.get(), Data("fresh".utf8))
        let requestCount = await httpClient.count()
        XCTAssertEqual(requestCount, 2)
    }

    func testRevalidate404DeletesCacheEntry() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 404, body: ""),
        ])

        let first = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? first.get(), Data("old".utf8))

        let second = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? second.get(), Data("old".utf8))

        var deleted = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if await ExperimentContentStore.shared.get(url) == nil {
                deleted = true
                break
            }
        }
        XCTAssertTrue(deleted)
    }

    func testLateRevalidate404DoesNotDeleteNewerCacheEntry() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 404, body: "", delay: 0.2),
        ])

        _ = await getExperimentContent(url: url, contentClient: httpClient)
        _ = await getExperimentContent(url: url, contentClient: httpClient)

        try? await Task.sleep(nanoseconds: 50_000_000)
        await ExperimentContentStore.shared.set(url, data: Data("new".utf8))

        try? await Task.sleep(nanoseconds: 300_000_000)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("new".utf8))
    }

    func testLateRevalidationDoesNotOverwriteNewerCacheEntry() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 200, body: "stale", delay: 0.2),
        ])

        _ = await getExperimentContent(url: url, contentClient: httpClient)
        _ = await getExperimentContent(url: url, contentClient: httpClient)

        try? await Task.sleep(nanoseconds: 50_000_000)
        await ExperimentContentStore.shared.set(url, data: Data("new".utf8))

        try? await Task.sleep(nanoseconds: 300_000_000)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("new".utf8))
    }

    func testLateColdFetchDoesNotOverwriteNewerResponse() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old", delay: 0.2),
            .init(statusCode: 200, body: "new"),
        ])

        let oldFetch = Task {
            await getExperimentContent(url: url, contentClient: httpClient)
        }
        var firstFetchStarted = false
        for _ in 0..<20 {
            if await httpClient.count() == 1 {
                firstFetchStarted = true
                break
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertTrue(firstFetchStarted)

        let newFetch = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? newFetch.get(), Data("new".utf8))
        _ = await oldFetch.value

        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("new".utf8))
    }

    func testRevalidateNetworkFailureKeepsCache() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 500, body: ""),
        ])

        let first = await getExperimentContent(url: url, contentClient: httpClient)
        XCTAssertEqual(try? first.get(), Data("old".utf8))
        _ = await getExperimentContent(url: url, contentClient: httpClient)

        try? await Task.sleep(nanoseconds: 300_000_000)
        let cached = await ExperimentContentStore.shared.get(url)
        XCTAssertEqual(cached, Data("old".utf8))
    }

    func testRevalidateCoalescesInFlightRequests() async {
        let url = URL(string: "https://cdn.example/projects/p/experiments/id/\(UUID().uuidString)")!
        let httpClient = ScriptedHTTPClient(steps: [
            .init(statusCode: 200, body: "old"),
            .init(statusCode: 200, body: "new", delay: 0.3),
            .init(statusCode: 200, body: "new", delay: 0.3),
            .init(statusCode: 200, body: "new", delay: 0.3),
        ])

        _ = await getExperimentContent(url: url, contentClient: httpClient)
        for _ in 0..<5 {
            let result = await getExperimentContent(url: url, contentClient: httpClient)
            XCTAssertEqual(try? result.get(), Data("old".utf8))
        }

        var updated = false
        for _ in 0..<50 {
            try? await Task.sleep(nanoseconds: 50_000_000)
            if await ExperimentContentStore.shared.get(url) == Data("new".utf8) {
                updated = true
                break
            }
        }
        XCTAssertTrue(updated)
        let requestCount = await httpClient.count()
        XCTAssertLessThanOrEqual(requestCount, 3)
    }

    func testImageSessionKeepsDiskCacheWhileExperimentContentDoesNot() {
        XCTAssertNotNil(imageSession.configuration.urlCache)
        XCTAssertEqual(imageSession.configuration.urlCache?.diskCapacity, 50 * 1024 * 1024)
        XCTAssertNil(experimentContentSession.configuration.urlCache)
        XCTAssertEqual(experimentHttpSession.configuration.requestCachePolicy, .useProtocolCachePolicy)
        XCTAssertNotNil(experimentHttpSession.configuration.urlCache)
    }
}
