//
//  network.swift
//  Nubrick
//
//  Created by Takuma Jimbo on 2025/03/13.
//
import Foundation

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

public enum CacheStorage {
    case INMEMORY
}

public class NativebrikCachePolicy {
    let cacheTime: TimeInterval
    let staleTime: TimeInterval
    let storage: CacheStorage

    public init(cacheTime: TimeInterval = 24 * 60 * 60, staleTime: TimeInterval = 0, storage: CacheStorage = .INMEMORY) {
        self.cacheTime = cacheTime
        self.staleTime = staleTime
        self.storage = storage
    }
}

class CacheObject {
    let staleTime: TimeInterval
    let data: Data
    let timestamp: Date

    init(staleTime: TimeInterval, data: Data, timestamp: Date) {
        self.staleTime = staleTime
        self.data = data
        self.timestamp = timestamp
    }

    func isStale() -> Bool {
        let staleAt = timestamp.addingTimeInterval(staleTime)
        return getCurrentDate() >= staleAt
    }
}

class CacheStore {
    private let policy: NativebrikCachePolicy
    private var cache: [String: (Data, Date)] = [:]
    private let lock = NSLock()

    init(policy: NativebrikCachePolicy) {
        self.policy = policy
    }

    func get(key: String) -> CacheObject? {
        lock.lock()
        defer { lock.unlock() }
        guard let (data, timestamp) = cache[key] else {
            return nil
        }

        let expiredAt = timestamp.addingTimeInterval(policy.cacheTime)
        if getCurrentDate() >= expiredAt {
            cache.removeValue(forKey: key)
            return nil
        }

        return CacheObject(staleTime: policy.staleTime, data: data, timestamp: timestamp)
    }

    func set(key: String, data: Data) {
        lock.lock()
        defer { lock.unlock() }
        cache[key] = (data, getCurrentDate())
    }

    func invalidate(key: String) {
        lock.lock()
        defer { lock.unlock() }
        cache.removeValue(forKey: key)
    }
}

func getData(url: URL, syncDateTime: Bool = false, cache: CacheStore) async -> Result<Data, NubrickError> {
    let urlStr = url.absoluteString

    guard let cached = cache.get(key: urlStr) else {
        switch await _getData(url: url, syncDateTime: syncDateTime) {
        case .success(let data):
            cache.set(key: urlStr, data: data)
            return Result.success(data)

        case .failure(let error):
            return Result.failure(error)
        }
    }

    if cached.isStale() {
        Task(priority: .background) {
            switch await _getData(url: url, syncDateTime: syncDateTime) {
            case .success(let data):
                cache.set(key: urlStr, data: data)

            case .failure(_):
                cache.invalidate(key: urlStr)
            }
        }
    }

    return Result.success(cached.data)
}


func _getData(url: URL, syncDateTime: Bool = false) async -> Result<Data, NubrickError> {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    do {
        let t0 = getCurrentDate()
        let (data, response) = try await nativebrikSession.data(for: request)
        guard let res = response as? HTTPURLResponse else {
            return Result.failure(NubrickError.irregular("Failed to parse as HttpURLResponse"))
        }
        if syncDateTime {
            syncDateFromHTTPURLResponse(t0: t0, res: res)
        }
        if res.statusCode == 404 {
            return Result.failure(NubrickError.notFound)
        }
        return Result.success(data)
    } catch {
        return Result.failure(NubrickError.other(error))
    }
}
