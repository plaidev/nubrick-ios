//
//  remote-config.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/08/28.
//

import Foundation

public class RemoteConfigVariant: NSObject {
    private let configs: [VariantConfig]
    init(configs: [VariantConfig]) {
        self.configs = configs
    }
    
    public func get(_ key: String) -> String? {
        let config = self.configs.first { config in
            if config.key == key {
                return true
            }
            return false
        }
        
        return config?.value
    }
    
    public func getAsString(_ key: String) -> String? {
        return self.get(key)
    }
    
    public func getAsBool(_ key: String) -> Bool? {
        guard let value = self.get(key) else {
            return nil
        }
        return value == "TRUE"
    }
    
    public func getAsInt(_ key: String) -> Int? {
        guard let value = self.get(key) else {
            return nil
        }
        return Int(value) ?? 0
    }
    
    public func getAsDouble(_ key: String) -> Float? {
        guard let value = self.get(key) else {
            return nil
        }
        return Float(value) ?? 0.0
    }
    
    public func getAsDouble(_ key: String) -> Double? {
        guard let value = self.get(key) else {
            return nil
        }
        return Double(value) ?? 0.0
    }
    
    public func getAsData(_ key: String) -> Data? {
        guard let value = self.get(key) else {
            return nil
        }
        let data = Data(value.utf8)
        return data
    }
    
}

public enum AsyncRemoteConfigPhase {
    case loading
    case completed(RemoteConfigVariant)
    case failure
}

public class RemoteConfig {
    private let experimentId: String
    private let repositories: Repositories
    
    init(experimentId: String, repositories: Repositories, phase: @escaping ((_ phase: AsyncRemoteConfigPhase) -> Void)) {
        self.experimentId = experimentId
        self.repositories = repositories
        phase(.loading)
        Task {
            await self.repositories.experiment.fetch(
                id: self.experimentId,
                callback: { entry in
                    guard let configs = entry.value?.value else {
                        phase(.failure)
                        return
                    }
                    guard let config = extractExperimentConfigMatchedToProperties(configs: configs, properties: []) else {
                        phase(.failure)
                        return
                    }
                    guard let variant = extractExperimentVariant(config: config, normalizedUsrRnd: 1.0) else {
                        phase(.failure)
                        return
                    }
                    guard let variantConfigs = variant.configs else {
                        phase(.failure)
                        return
                    }
                    
                    phase(.completed(RemoteConfigVariant(
                        configs: variantConfigs
                    )))
                }
            )
        }
    }
}

class RemoteConfigAsView {
    
}
