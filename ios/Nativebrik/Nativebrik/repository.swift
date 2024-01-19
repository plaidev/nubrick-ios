//
//  repository.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/06/30.
//

import Foundation

let nativebrikSession: URLSession = {
    let sessionConfig = URLSessionConfiguration.default
    sessionConfig.timeoutIntervalForRequest = 10.0
    sessionConfig.timeoutIntervalForResource = 30.0
    return URLSession(configuration: sessionConfig)
}()

class CacheStrategy<V: NSObject> {
    private let cache = NSCache<NSString, Entry<V>>()

    fileprivate func get(key: String) -> Entry<V>? {
        return cache.object(forKey: key as NSString)
    }

    fileprivate func set(entry: Entry<V>, forKey: String) {
        cache.setObject(entry, forKey: forKey as NSString)
    }
}

enum EntryState {
    case COMPLETED
    case FAILED
}
class Entry<V: NSObject> {
    let state: EntryState
    let value: V?
    init(value: V) {
        self.state = .COMPLETED
        self.value = value
    }
    init() {
        self.state = .FAILED
        self.value = nil
    }
}

class Repositories {
    let image: ImageRepository
    let component: ComponentRepository
    let experiment: ExperimentConfigsRepository
    let track: TrackRespository
    let httpRequest: ApiHttpRequestRepository

    init(config: Config, user: NativebrikUser, interceptor: NativebrikHttpRequestInterceptor?) {
        self.image = ImageRepository(
            cacheStrategy: CacheStrategy()
        )
        self.component = ComponentRepository(config: config, cacheStrategy: CacheStrategy())
        self.experiment = ExperimentConfigsRepository(config: config, cacheStrategy: CacheStrategy())
        self.track = TrackRespository(config: config, user: user)
        self.httpRequest = ApiHttpRequestRepository(projectId: config.projectId, interceptor: interceptor)
    }
}

class ImageData: NSObject {
    let data: Data
    let contentType: String
    init(data: Data, contentType: String) {
        self.data = data
        self.contentType = contentType
    }
}

class ImageRepository {
    private let cache: CacheStrategy<ImageData>

    init(cacheStrategy: CacheStrategy<ImageData>) {
        self.cache = cacheStrategy
    }

    func fetch(url: String, callback: @escaping (_ entry: Entry<ImageData>) -> Void) {
        if let dataFromCache = self.cache.get(key: url) {
            callback(dataFromCache)
            return
        }
        guard let requestUrl = URL(string: url) else {
            let entry = Entry<ImageData>()
            callback(entry)
            return
        }
        let task = nativebrikSession.dataTask(with: requestUrl) { (data, response, error) in
            if error != nil {
                let entry = Entry<ImageData>()
                callback(entry)
                return
            }
            if let imageData = data {
                let entry = Entry(
                    value: ImageData(
                        data: imageData,
                        contentType: getContentType(response)
                    )
                )
                callback(entry)
                self.cache.set(entry: entry, forKey: url)
                return
            } else {
                let entry = Entry<ImageData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: url)
                return
            }
        }
        task.resume()
    }
}

func getContentType(_ response: URLResponse?) -> String {
    guard let response = response else {
        return ""
    }
    let contentType = (response as! HTTPURLResponse).allHeaderFields["Content-Type"] as? String
    guard let contentType = contentType else {
        return ""
    }
    return contentType
}

class ComponentData: NSObject {
    let view: UIBlockJSON
    let id: String
    init(view: UIBlockJSON, id: String) {
        self.view = view
        self.id = id
    }
}

class ComponentRepository {
    private let cache: CacheStrategy<ComponentData>
    private let config: Config

    init(config: Config, cacheStrategy: CacheStrategy<ComponentData>) {
        self.config = config
        self.cache = cacheStrategy
    }

    func fetch(experimentId: String, id: String, callback: @escaping (_ entry: Entry<ComponentData>) -> Void) {
        if id == "" {
            return
        }
        if let entry = self.cache.get(key: id) {
            callback(entry)
            return
        }
        let url = self.config.cdnUrl + "/projects/" + self.config.projectId + "/experiments/components/" + experimentId + "/" + id
        guard let requestUrl = URL(string: url) else {
            return
        }
        let task = nativebrikSession.dataTask(with: requestUrl) { (data, response, error) in
            if error != nil {
                let entry = Entry<ComponentData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: id)
                return
            }

            if let viewData = data {
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(UIBlockJSON.self, from: viewData)
                    let entry = Entry<ComponentData>(
                        value: ComponentData(
                            view: result,
                            id: id
                        )
                    )
                    callback(entry)
                    self.cache.set(entry: entry, forKey: url)
                    return
                } catch {
                    let entry = Entry<ComponentData>()
                    callback(entry)
                    self.cache.set(entry: entry, forKey: id)
                    return
                }
            } else {
                let entry = Entry<ComponentData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: id)
                return
            }
        }
        task.resume()
    }
}

class ExperimentConfigsData: NSObject {
    let value: ExperimentConfigs
    init(value: ExperimentConfigs) {
        self.value = value
    }
}

class ExperimentConfigsRepository {
    private let cache: CacheStrategy<ExperimentConfigsData>
    private let config: Config

    init(config: Config, cacheStrategy: CacheStrategy<ExperimentConfigsData>) {
        self.config = config
        self.cache = cacheStrategy
    }

    func trigger(event: NativebrikEvent, callback: @escaping (_ entry: Entry<ExperimentConfigsData>) -> Void) async {
        let url = self.config.cdnUrl + "/projects/" + self.config.projectId + "/experiments/trigger/" + event.name
        await self._fetch(key: event.name, url: url, callback: callback)
    }

    func fetch(id: String, callback: @escaping (_ entry: Entry<ExperimentConfigsData>) -> Void) async {
        let url = self.config.cdnUrl + "/projects/" + self.config.projectId + "/experiments/id/" + id
        await _fetch(key: id, url: url, callback: callback)
    }

    private func _fetch(key: String, url: String, callback: @escaping (_ entry: Entry<ExperimentConfigsData>) -> Void) async {
        if let entry = self.cache.get(key: key) {
            callback(entry)
            return
        }

        guard let requestUrl = URL(string: url) else {
            return
        }

        let task = nativebrikSession.dataTask(with: requestUrl) { (data, response, error) in
            if error != nil {
                let entry = Entry<ExperimentConfigsData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            }

            if let experimentRawData = data {
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(ExperimentConfigs.self, from: experimentRawData)
                    let entry = Entry<ExperimentConfigsData>(
                        value: ExperimentConfigsData(
                            value: result
                        )
                    )
                    callback(entry)
                    self.cache.set(entry: entry, forKey: key)
                    return
                } catch {
                    let entry = Entry<ExperimentConfigsData>()
                    callback(entry)
                    self.cache.set(entry: entry, forKey: key)
                    return
                }
            } else {
                let entry = Entry<ExperimentConfigsData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            }
        }
        task.resume()
    }
}

struct TrackRequest: Encodable {
    var projectId: String
    var userId: String
    var timestamp: DateTime
    var events: [TrackEvent]
}

struct TrackEvent: Encodable {
    enum Typename: String, Encodable {
        case Event = "event"
        case Experiment = "experiment"
    }
    var typename: Typename
    var experimentId: String?
    var variantId: String?
    var name: String?
    var timestamp: DateTime
}

struct TrackUserEvent {
    var name: String
}

struct TrackExperimentEvent {
    var experimentId: String
    var variantId: String
}

class TrackRespository {
    private let maxQueueSize: Int
    private let maxBatchSize: Int
    private let config: Config
    private let user: NativebrikUser
    private let queueLock: NSLock
    private var timer: Timer?
    private var buffer: [TrackEvent]
    init(config: Config, user: NativebrikUser) {
        self.maxQueueSize = 300
        self.maxBatchSize = 50
        self.config = config
        self.user = user
        self.queueLock = NSLock()
        self.buffer = []
        self.timer = nil
    }
    
    deinit {
        self.timer?.invalidate()
    }
    
    func trackExperimentEvent(_ event: TrackExperimentEvent) {
        self.pushToQueue(TrackEvent(
            typename: .Experiment,
            experimentId: event.experimentId,
            variantId: event.variantId,
            timestamp: formatToISO8601(getCurrentDate())
        ))
    }
    
    func trackEvent(_ event: TrackUserEvent) {
        self.pushToQueue(TrackEvent(
            typename: .Event,
            name: event.name,
            timestamp: formatToISO8601(getCurrentDate())
        ))
    }
    
    private func pushToQueue(_ event: TrackEvent) {
        self.queueLock.lock()
        if self.timer == nil {
            // here, use async not sync. main.sync will break the app.
            DispatchQueue.main.async {
                self.timer?.invalidate()
                self.timer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true, block: { _ in
                    Task(priority: .low) {
                        try await self.sendAndFlush()
                    }
                })
            }
        }

        if self.buffer.count >= self.maxBatchSize {
            Task(priority: .low) {
                try await self.sendAndFlush()
            }
        }
        self.buffer.append(event)
        if self.buffer.count >= self.maxQueueSize {
            self.buffer.removeFirst(self.maxQueueSize - self.buffer.count)
        }
        
        self.queueLock.unlock()
    }
    
    private func sendAndFlush() async throws {
        if self.buffer.count == 0 {
            return
        }
        let events = self.buffer
        self.buffer = []
        let trackRequest = TrackRequest(
            projectId: self.config.projectId,
            userId: self.user.id,
            timestamp: formatToISO8601(getCurrentDate()),
            events: events
        )
        
        do {
            let url = URL(string: config.trackUrl)!
            let jsonData = try JSONEncoder().encode(trackRequest)
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let _ = try await nativebrikSession.data(for: request)
            
            self.timer?.invalidate()
            self.timer = nil
        } catch {
            self.buffer.append(contentsOf: events)
        }
    }
}

enum HttpEntryState {
    case EXPECTED
    case UNEXPECTED
}
class HttpEntry<V: NSObject> {
    let state: HttpEntryState
    let value: V?
    init(value: V, state: HttpEntryState) {
        self.state = state
        self.value = value
    }
    init(state: HttpEntryState) {
        self.state = state
        self.value = nil
    }
}

public typealias NativebrikHttpRequestInterceptor = (_ request: URLRequest) -> URLRequest
class ApiHttpRequestRepository {
    private let projectId: String
    private let requestInterceptor: NativebrikHttpRequestInterceptor
    
    init(projectId: String, interceptor: NativebrikHttpRequestInterceptor?) {
        self.projectId = projectId
        self.requestInterceptor = interceptor ?? { request in
            return request
        }
    }
    
    init(interceptor: NativebrikHttpRequestInterceptor?) {
        self.projectId = ""
        self.requestInterceptor = interceptor ?? { request in
            return request
        }
    }
    
    func fetch(request: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, placeholderReplacer: @escaping (String) -> Any?, callback: @escaping (_ entry: HttpEntry<JSONData>) -> Void) {
        guard let requestUrl = URL(string: compileTemplate(template: request.url ?? "", getByPath: placeholderReplacer)) else {
            return
        }
        var urlRequest = URLRequest(url: requestUrl)
        urlRequest.httpMethod = request.method?.rawValue ?? "GET"
        if request.method != .GET && request.method != .TRACE {
            var body: Data? = nil
            if let reqBody = request.body {
                let bodyStr = compileTemplate(template: reqBody, getByPath: placeholderReplacer)
                body = bodyStr.data(using: .utf8)
            }
            if let body = body {
                urlRequest.httpBody = body
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
        }
        urlRequest.setValue(self.projectId, forHTTPHeaderField: "X-Project-Id")
        request.headers?.forEach({ header in
            guard let name = header.name else {
                return
            }
            let value = compileTemplate(template: header.value ?? "", getByPath: placeholderReplacer)
            urlRequest.setValue(value, forHTTPHeaderField: name)
        })
        
        let task = nativebrikSession.dataTask(with: self.requestInterceptor(urlRequest)) { (data, response, error) in
            // when it's error and it's expected, then this should be updated to .expected.
            var httpStatusWhenError: HttpEntryState = .UNEXPECTED

            // assertion
            if let expectedStatusCodes = assertion?.statusCodes {
                if let response = response as? HTTPURLResponse {
                    let matched = expectedStatusCodes.first { expectedStatusCode in
                        return expectedStatusCode == response.statusCode
                    }
                    // if it's not expeted, then callback empty entry.
                    if matched == nil {
                        let entry = HttpEntry<JSONData>(state: .UNEXPECTED)
                        callback(entry)
                        return
                    } else {
                        httpStatusWhenError = .EXPECTED
                    }
                }
            }

            if error != nil {
                let entry = HttpEntry<JSONData>(state: httpStatusWhenError)
                callback(entry)
                return
            }

            if let viewData = data {
                do {
                    let decoder = JSONDecoder()
                    let result = try decoder.decode(JSON.self, from: viewData)
                    let entry = HttpEntry<JSONData>(
                        value: JSONData(data: result),
                        state: .EXPECTED
                    )
                    callback(entry)
                    return
                } catch {
                    let entry = HttpEntry<JSONData>(state: .EXPECTED)
                    callback(entry)
                    return
                }
            } else {
                let entry = HttpEntry<JSONData>(state: .EXPECTED)
                callback(entry)
                return
            }
        }
        task.resume()
    }
}

class JSONData: NSObject {
    let data: JSON?
    init(data: JSON?) {
        self.data = data
    }
    
    init(expected: Bool) {
        self.data = nil
    }
}
