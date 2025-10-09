//
//  experiment.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation

protocol ExperimentRepository2 {
    func fetchExperimentConfigs(id: String) async -> Result<ExperimentConfigs, NativebrikError>
    func fetchTriggerExperimentConfigs(name: String) async -> Result<ExperimentConfigs, NativebrikError>
}

class ExperimentRepositoryImpl: ExperimentRepository2 {
    private let config: Config
    private let cache: CacheStore
    init(config: Config, cache: CacheStore) {
        self.config = config
        self.cache = cache
    }
    
    func fetchExperimentConfigs(id: String) async -> Result<ExperimentConfigs, NativebrikError> {
        guard let url = URL(string: self.config.cdnUrl + "/projects/" + self.config.projectId + "/experiments/id/" + id) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        
        let data = await getData(url: url, syncDateTime: true, cache: self.cache)
        switch data {
        case .success(let data):
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(ExperimentConfigs.self, from: data) else {
                return Result.failure(NativebrikError.failedToDecode)
            }
            return Result.success(result)
            
        case .failure(let error):
            return Result.failure(error)
        }
    }
    
    func fetchTriggerExperimentConfigs(name: String) async -> Result<ExperimentConfigs, NativebrikError> {
        guard let url = URL(string: config.cdnUrl + "/projects/" + config.projectId + "/experiments/trigger/" + name) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        
        let data = await getData(url: url, syncDateTime: true, cache: self.cache)
        switch data {
        case .success(let data):
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(ExperimentConfigs.self, from: data) else {
                return Result.failure(NativebrikError.failedToDecode)
            }
            return Result.success(result)
            
        case .failure(let error):
            return Result.failure(error)
        }
    }
}
