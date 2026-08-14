//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/13.
//
import Foundation

/// In-memory last-good bodies for CDN JSON (mirrors Android CacheStore keep window).
/// Used so offline / transport failures can still render after URLCache freshness expires.
final class MemoryResponseCache: @unchecked Sendable {
    static let shared = MemoryResponseCache()

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    /// Align with Android memory CACHE_TIME (10 minutes).
    private let ttl: TimeInterval = 10 * 60

    private struct Entry {
        let data: Data
        let storedAt: Date
    }

    func get(_ url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[url.absoluteString] else { return nil }
        if Date().timeIntervalSince(entry.storedAt) > ttl {
            entries.removeValue(forKey: url.absoluteString)
            return nil
        }
        return entry.data
    }

    func set(_ url: URL, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        entries[url.absoluteString] = Entry(data: data, storedAt: Date())
    }

    func remove(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: url.absoluteString)
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}

let nativebrikSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
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

protocol TrackingHTTPClient: Sendable {
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: TrackingHTTPClient {
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

func invalidateCachedResponse(for request: URLRequest) {
    if let url = request.url {
        MemoryResponseCache.shared.remove(url)
    }
    URLCache.shared.removeCachedResponse(for: request)
    nativebrikSession.configuration.urlCache?.removeCachedResponse(for: request)
}

func getData(url: URL, syncDateTime: Bool = false) async -> Result<Data, NubrickError> {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    do {
        let t0 = Date()
        let (data, response) = try await nativebrikSession.data(for: request)
        guard let res = response as? HTTPURLResponse else {
            return Result.failure(NubrickError.irregular("Failed to parse as HttpURLResponse"))
        }
        if syncDateTime {
            syncDateFromHTTPURLResponse(t0: t0, res: res)
        }
        if 200 <= res.statusCode && res.statusCode <= 299 {
            MemoryResponseCache.shared.set(url, data: data)
            return Result.success(data)
        }
        if res.statusCode == 404 {
            // Definitive absence: drop memory + URLCache so deleted UI is not revived.
            invalidateCachedResponse(for: request)
            return Result.failure(NubrickError.notFound)
        }
        return Result.failure(NubrickError.unexpected)
    } catch {
        // Offline / transport failure: only the in-memory last-good (TTL-bounded).
        // Do not read URLCache here — cachedResponse(for:) ignores HTTP freshness and
        // could revive arbitrarily old / deleted UI after the memory window expires.
        if let cached = MemoryResponseCache.shared.get(url) {
            return Result.success(cached)
        }
        return Result.failure(NubrickError.other(error))
    }
}
