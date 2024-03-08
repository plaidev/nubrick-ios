//
//  experiment.swift
//  Nativebrik
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
    init(config: Config) {
        self.config = config
    }
    
    func fetchExperimentConfigs(id: String) async -> Result<ExperimentConfigs, NativebrikError> {
        guard let url = URL(string: self.config.cdnUrl + "/projects/" + self.config.projectId + "/experiments/id/" + id) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await nativebrikSession.data(for: request)
            guard let res = response as? HTTPURLResponse else {
                return Result.failure(NativebrikError.irregular("Failed to parse as HttpURLResponse"))
            }
            if res.statusCode == 404 {
                return Result.failure(NativebrikError.notFound)
            }
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(ExperimentConfigs.self, from: data) else {
                return Result.failure(NativebrikError.failedToDecode)
            }
            return Result.success(result)
        } catch {
            return Result.failure(NativebrikError.other(error))
        }
    }
    
    func fetchTriggerExperimentConfigs(name: String) async -> Result<ExperimentConfigs, NativebrikError> {
        guard let url = URL(string: config.cdnUrl + "/projects/" + config.projectId + "/experiments/trigger/" + name) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        do {
            let (data, response) = try await nativebrikSession.data(for: request)
            guard let res = response as? HTTPURLResponse else {
                return Result.failure(NativebrikError.irregular("Failed to parse as HttpURLResponse"))
            }
            if res.statusCode == 404 {
                return Result.failure(NativebrikError.notFound)
            }
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(ExperimentConfigs.self, from: data) else {
                return Result.failure(NativebrikError.failedToDecode)
            }
            return Result.success(result)
        } catch {
            return Result.failure(NativebrikError.other(error))
        }
    }
}
