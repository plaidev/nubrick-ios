//
//  component.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/06.
//

import Foundation

protocol ComponentRepository2 {
    func fetchComponent(experimentId: String, id: String) async -> Result<UIBlock, NativebrikError>
}

class ComponentRepositoryImpl: ComponentRepository2 {
    private let config: Config
    private let cache: CacheStore
    init(config: Config, cache: CacheStore) {
        self.config = config
        self.cache = cache
    }

    func fetchComponent(experimentId: String, id: String) async -> Result<UIBlock, NativebrikError> {
        guard let url = URL(string: config.cdnUrl + "/projects/" + config.projectId + "/experiments/components/" + experimentId + "/" + id) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        
        let data = await getData(url: url, cache: self.cache)
        switch data {
        case .success(let data):
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(UIBlockJSON.self, from: data) else {
                return Result.failure(NativebrikError.failedToDecode)
            }
            return Result.success(result)
            
        case .failure(let error):
            return Result.failure(error)
        }
    }
}
