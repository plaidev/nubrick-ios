//
//  repository.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/06/30.
//

import Foundation

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
    let queryData: QueryDataRepository
    let trigger: TriggerRepository
    let experiment: ExperimentConfigsRepository

    init(config: Config) {
        self.image = ImageRepository(
            cacheStrategy: CacheStrategy()
        )
        self.component = ComponentRepository(config: config, cacheStrategy: CacheStrategy())
        self.queryData = QueryDataRepository(cache: CacheStrategy(), config: config)
        self.trigger = TriggerRepository(config: config, cacheStrategy: CacheStrategy())
        self.experiment = ExperimentConfigsRepository(config: config, cacheStrategy: CacheStrategy())
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
        let task = URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
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
        let task = URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
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

class TriggerData: NSObject {
    let componentId: String
    init(id: String) {
        self.componentId = id
    }
}

class TriggerRepository {
    private let cache: CacheStrategy<TriggerData>
    private let config: Config

    init(config: Config, cacheStrategy: CacheStrategy<TriggerData>) {
        self.config = config
        self.cache = cacheStrategy
    }

    func fetch(event: TriggerEvent, callback: @escaping (_ entry: Entry<TriggerData>) -> Void) async {
        let key = event.name

        if let entry = self.cache.get(key: key) {
            callback(entry)
            return
        }

        do {
            let propertyInputs: [PropertyInput] = []
            let triggerEventInput = TriggerEventInput(name: event.name, properties: propertyInputs)
            let data = try await getComponentByTrigger(
                query: getComponentByTriggerQuery(event: triggerEventInput),
                projectId: self.config.projectId,
                url: self.config.url
            )

            if let componentId = data.data?.trigger??.id {
                let entry = Entry<TriggerData>(
                    value: TriggerData(id: componentId)
                )
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            } else {
                let entry = Entry<TriggerData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            }
        } catch {
            let entry = Entry<TriggerData>()
            callback(entry)
            self.cache.set(entry: entry, forKey: key)
        }
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

    func trigger(event: TriggerEvent, callback: @escaping (_ entry: Entry<ExperimentConfigsData>) -> Void) async {
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

        let task = URLSession.shared.dataTask(with: requestUrl) { (data, response, error) in
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

class JSONData: NSObject {
    let data: JSON?
    init(data: JSON?) {
        self.data = data
    }
}
class QueryDataRepository {
    private let cache: CacheStrategy<JSONData>
    private let config: Config

    init(cache: CacheStrategy<JSONData>, config: Config) {
        self.cache = cache
        self.config = config
    }

    func fetch(query: String, placeholder: PlaceholderInput, callback: @escaping (_ entry: Entry<JSONData>) -> Void) async {
        let key = query + ":" + placeholderInputToString(input: placeholder)

        if let entry = self.cache.get(key: key) {
            callback(entry)
            return
        }

        do {
            let data = try await getData(
                query: getDataQuery(query: query, placeholder: placeholder),
                projectId: self.config.projectId,
                url: self.config.url
            )
            if let data = data.data?.data {
                let entry = Entry<JSONData>(
                    value: JSONData(data: data)
                )
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            } else {
                let entry = Entry<JSONData>()
                callback(entry)
                self.cache.set(entry: entry, forKey: key)
                return
            }
        } catch {
            let entry = Entry<JSONData>()
            callback(entry)
            self.cache.set(entry: entry, forKey: key)
        }
    }
}

func placeholderInputToString(input: PlaceholderInput) -> String {
    guard let properties = input.properties else {
        return ""
    }
    var query = ""
    properties.forEach({ property in
        query += property.name + property.value
    })
    return query
}

