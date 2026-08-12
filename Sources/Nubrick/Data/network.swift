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
        let key = url.absoluteString
        let previous = entries[key]?.data
        entries[key] = Entry(data: data, storedAt: Date())
        lock.unlock()

        // When experiment config changes, drop component last-good so generations stay aligned.
        if isExperimentConfigURL(url), previous != data {
            if let prefix = componentCachePrefix(from: url) {
                removeByPrefix(prefix)
            }
        }
    }

    func remove(_ url: URL) {
        lock.lock()
        defer { lock.unlock() }
        entries.removeValue(forKey: url.absoluteString)
    }

    func removeByPrefix(_ prefix: String) {
        lock.lock()
        defer { lock.unlock() }
        for key in entries.keys where key.hasPrefix(prefix) {
            entries.removeValue(forKey: key)
        }
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entries.removeAll()
    }
}

func isExperimentConfigURL(_ url: URL) -> Bool {
    let path = url.path
    return path.contains("/experiments/id/") || path.contains("/experiments/trigger/")
}

func componentCachePrefix(from configURL: URL) -> String? {
    let absolute = configURL.absoluteString
    guard let projectsRange = absolute.range(of: "/projects/") else { return nil }
    let afterProjects = absolute[projectsRange.upperBound...]
    guard let slash = afterProjects.firstIndex(of: "/") else { return nil }
    let projectId = String(afterProjects[..<slash])
    guard !projectId.isEmpty else { return nil }
    let origin = String(absolute[..<projectsRange.lowerBound])
    return origin + "/projects/" + projectId + "/experiments/components/"
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
        // Offline / transport failure: keep last-good when available.
        if let cached = MemoryResponseCache.shared.get(url) {
            return Result.success(cached)
        }
        if let cached = URLCache.shared.cachedResponse(for: request)?.data {
            return Result.success(cached)
        }
        return Result.failure(NubrickError.other(error))
    }
}
