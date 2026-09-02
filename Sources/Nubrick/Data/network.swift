//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/13.
//
import Foundation

/// In-memory last-good bodies for experiment config/component JSON.
/// Disk caching is disabled on [experimentContentSession]; this is the only cache.
actor ExperimentContentStore {
    static let shared = ExperimentContentStore()

    private var entries: [String: Entry] = [:]
    private var totalBytes = 0
    private let maximumEntryCount = 128
    private let maximumByteCount = 4 * 1024 * 1024
    private var revalidations: [String: Revalidation] = [:]
    private var currentFetchGenerations: [String: UInt64] = [:]
    private var nextGeneration: UInt64 = 0
    /// Matches Android: 1 initial attempt + 2 retries with 1s then 2s delays.
    private let maxRetries = 2
    private let retryDelays: [TimeInterval] = [1.0, 2.0]

    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    private struct Revalidation {
        let fetchGeneration: UInt64
        let task: Task<Void, Never>
    }

    func get(_ url: URL) -> Data? {
        cachedEntry(for: url)?.data
    }

    /// Returns the cached response and starts one background revalidation per URL.
    private func cachedResponseAndScheduleRevalidation(
        for url: URL,
        syncDateTime: Bool,
        contentClient: any HTTPClient
    ) -> Data? {
        guard let entry = cachedEntry(for: url) else { return nil }
        let key = url.absoluteString
        guard revalidations[key] == nil else { return entry.data }

        let fetchGeneration = beginFetch(for: url)
        let task = Task {
            _ = await self.fetchExperimentContentFromNetwork(
                url: url,
                fetchGeneration: fetchGeneration,
                syncDateTime: syncDateTime,
                contentClient: contentClient
            )
            self.finishRevalidation(for: url, fetchGeneration: fetchGeneration)
        }
        revalidations[key] = Revalidation(fetchGeneration: fetchGeneration, task: task)
        return entry.data
    }

    func set(_ url: URL, data: Data) {
        // A single response should not be allowed to consume the entire
        // process cache budget. Keep the previous last-good body intact.
        guard data.count <= maximumByteCount else { return }

        let now = getCurrentDate()
        removeExpiredEntries(now: now)

        let key = url.absoluteString
        invalidateInFlightFetches(for: key)
        store(url, data: data, key: key, now: now)
    }

    private func store(_ url: URL, data: Data, key: String, now: Date) {
        if let existing = entries.removeValue(forKey: key) {
            totalBytes -= existing.data.count
        }

        while entries.count >= maximumEntryCount || totalBytes > maximumByteCount - data.count {
            guard let oldest = entries.min(by: { $0.value.storedAt < $1.value.storedAt }) else {
                break
            }
            if let removed = entries.removeValue(forKey: oldest.key) {
                totalBytes -= removed.data.count
            }
        }
        entries[key] = Entry(data: data, storedAt: now)
        totalBytes += data.count
    }

    /// Reserves the current generation for a network request. Later responses
    /// may update the cache only while this remains the newest request.
    private func beginFetch(for url: URL) -> UInt64 {
        nextGeneration &+= 1
        currentFetchGenerations[url.absoluteString] = nextGeneration
        return nextGeneration
    }

    /// Updates only when this request is still the newest one for the URL.
    func set(_ url: URL, data: Data, ifGenerationMatches expectedGeneration: UInt64) {
        guard currentGeneration(for: url) == expectedGeneration else { return }
        guard data.count <= maximumByteCount else { return }
        let now = getCurrentDate()
        removeExpiredEntries(now: now)
        store(url, data: data, key: url.absoluteString, now: now)
    }

    func remove(_ url: URL) {
        invalidateInFlightFetches(for: url.absoluteString)
        removeEntry(for: url)
    }

    /// Removes only when this request is still the newest one for the URL.
    /// This prevents an older response (such as a late 404 revalidation) from
    /// deleting newer data.
    func remove(_ url: URL, ifGenerationMatches expectedGeneration: UInt64) {
        guard currentGeneration(for: url) == expectedGeneration else { return }
        removeEntry(for: url)
    }

    func removeAll() {
        for revalidation in revalidations.values {
            revalidation.task.cancel()
        }
        revalidations.removeAll()
        entries.removeAll()
        currentFetchGenerations.removeAll()
        totalBytes = 0
    }

    private func removeExpiredEntries(now: Date) {
        let expiredKeys = entries.compactMap { key, entry in
            now.timeIntervalSince(entry.storedAt) > NubrickConstants.defaultCacheRetentionSeconds ? key : nil
        }
        for key in expiredKeys {
            if let removed = entries.removeValue(forKey: key) {
                totalBytes -= removed.data.count
            }
        }
    }

    private func currentGeneration(for url: URL) -> UInt64? {
        currentFetchGenerations[url.absoluteString]
    }

    private func invalidateInFlightFetches(for key: String) {
        currentFetchGenerations.removeValue(forKey: key)
    }

    private func removeEntry(for url: URL) {
        if let removed = entries.removeValue(forKey: url.absoluteString) {
            totalBytes -= removed.data.count
        }
    }

    private func finishFetch(for url: URL, generation: UInt64) {
        let key = url.absoluteString
        guard currentFetchGenerations[key] == generation else {
            return
        }
        currentFetchGenerations.removeValue(forKey: key)
    }

    func __for_test_inFlightURLCount() -> Int {
        currentFetchGenerations.count
    }

    private func cachedEntry(for url: URL) -> Entry? {
        guard let entry = entries[url.absoluteString] else { return nil }
        if getCurrentDate().timeIntervalSince(entry.storedAt) > NubrickConstants.defaultCacheRetentionSeconds {
            remove(url)
            return nil
        }
        return entry
    }

    private func finishRevalidation(for url: URL, fetchGeneration: UInt64) {
        guard revalidations[url.absoluteString]?.fetchGeneration == fetchGeneration else { return }
        revalidations.removeValue(forKey: url.absoluteString)
    }

    /// Fetches experiment config/component JSON with in-memory SWR.
    fileprivate func fetchExperimentContent(
        url: URL,
        syncDateTime: Bool,
        contentClient: any HTTPClient
    ) async -> Result<Data, NubrickError> {
        if let cached = cachedResponseAndScheduleRevalidation(
            for: url,
            syncDateTime: syncDateTime,
            contentClient: contentClient
        ) {
            return .success(cached)
        }

        let fetchGeneration = beginFetch(for: url)
        return await fetchExperimentContentFromNetwork(
            url: url,
            fetchGeneration: fetchGeneration,
            syncDateTime: syncDateTime,
            contentClient: contentClient
        )
    }

    private func fetchExperimentContentFromNetwork(
        url: URL,
        fetchGeneration: UInt64,
        syncDateTime: Bool,
        contentClient: any HTTPClient
    ) async -> Result<Data, NubrickError> {
        defer { finishFetch(for: url, generation: fetchGeneration) }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData

        var lastFailure: NubrickError = .unexpected
        for attempt in 0...maxRetries {
            if attempt > 0 {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(retryDelays[attempt - 1] * 1_000_000_000)
                    )
                } catch {
                    return .failure(lastFailure)
                }
            }

            do {
                let t0 = Date()
                let (data, response) = try await contentClient.fetchData(for: request)
                guard let res = response as? HTTPURLResponse else {
                    return .failure(NubrickError.irregular("Failed to parse as HttpURLResponse"))
                }
                if syncDateTime {
                    syncDateFromHTTPURLResponse(t0: t0, res: res)
                }
                if 200 <= res.statusCode && res.statusCode <= 299 {
                    set(url, data: data, ifGenerationMatches: fetchGeneration)
                    return .success(data)
                }
                if res.statusCode == 404 {
                    // Definitive absence: drop memory so deleted UI is not revived.
                    remove(url, ifGenerationMatches: fetchGeneration)
                    return .failure(.notFound)
                }
                lastFailure = .unexpected
                if !isRetryableFailure(statusCode: res.statusCode) {
                    return .failure(lastFailure)
                }
            } catch {
                lastFailure = .other(error)
                if !isRetryableFailure(error: error) {
                    return .failure(lastFailure)
                }
            }
        }
        return .failure(lastFailure)
    }

    private func isRetryableFailure(statusCode: Int? = nil, error: Error? = nil) -> Bool {
        if let statusCode, statusCode >= 500 {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return true
        }
        return false
    }
}

/// Custom HTTP requests from experiment UI. Freshness follows HTTP cache headers.
let experimentHttpSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.requestCachePolicy = .useProtocolCachePolicy
    sessionConfig.waitsForConnectivity = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.allowsExpensiveNetworkAccess = true
    sessionConfig.allowsConstrainedNetworkAccess = true
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

/// Experiment images. Freshness follows HTTP cache headers.
/// Size is capped; URLCache owns the on-disk directory.
let imageSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.urlCache = URLCache(
        memoryCapacity: 10 * 1024 * 1024,
        diskCapacity: 50 * 1024 * 1024,
        directory: nil
    )
    sessionConfig.requestCachePolicy = .useProtocolCachePolicy
    sessionConfig.waitsForConnectivity = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.allowsExpensiveNetworkAccess = true
    sessionConfig.allowsConstrainedNetworkAccess = true
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

/// Experiment config/component JSON. In-memory SWR only; no URLSession cache.
let experimentContentSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.ephemeral
    sessionConfig.urlCache = nil
    sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
    sessionConfig.waitsForConnectivity = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.allowsExpensiveNetworkAccess = true
    sessionConfig.allowsConstrainedNetworkAccess = true
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

/// Tracking has an independent, longer deadline so a slow acknowledgement does
/// not cause analytics batches to be discarded with the SDK's other requests.
let trackingSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.waitsForConnectivity = true
    sessionConfig.allowsCellularAccess = true
    sessionConfig.allowsExpensiveNetworkAccess = true
    sessionConfig.allowsConstrainedNetworkAccess = true
    sessionConfig.timeoutIntervalForRequest = 30.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

protocol HTTPClient: Sendable {
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPClient {
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

func fetchImageData(from url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.cachePolicy = .useProtocolCachePolicy
    let (data, _) = try await imageSession.data(for: request)
    return data
}

/// Fetches experiment config/component JSON with in-memory SWR.
/// `contentClient` defaults to [experimentContentSession]; tests pass a fake.
func getExperimentContent(
    url: URL,
    syncDateTime: Bool = false,
    contentClient: any HTTPClient = experimentContentSession
) async -> Result<Data, NubrickError> {
    await ExperimentContentStore.shared.fetchExperimentContent(
        url: url,
        syncDateTime: syncDateTime,
        contentClient: contentClient
    )
}
