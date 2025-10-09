//
//  request.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/08.
//

import Foundation

class JSONData: NSObject {
    let data: JSON?
    init(data: JSON?) {
        self.data = data
    }
    
    init(expected: Bool) {
        self.data = nil
    }
}


enum HttpRequestAssertionError: Error {
    case unexpected
}

protocol HttpRequestRepository {
    func request(req: ApiHttpRequest, assetion: ApiHttpResponseAssertion?) async -> Result<JSONData, NativebrikError>
}

class HttpRequestRepositoryImpl: HttpRequestRepository {
    private let intercepter: NativebrikHttpRequestInterceptor
    init(intercepter: NativebrikHttpRequestInterceptor? = nil) {
        self.intercepter = intercepter ?? { req in return req }
    }
    
    func request(req: ApiHttpRequest, assetion: ApiHttpResponseAssertion?) async -> Result<JSONData, NativebrikError> {
        guard let url = req.url else {
            return Result.failure(NativebrikError.skipRequest)
        }
        guard let url = URL(string: url) else {
            return Result.failure(NativebrikError.irregular("Failed to create URL object"))
        }
        var request = URLRequest(url: url)
        let method = req.method ?? ApiHttpRequestMethod.GET
        request.httpMethod = method.rawValue
        if (method != ApiHttpRequestMethod.GET && method != ApiHttpRequestMethod.TRACE) {
            let body = (req.body ?? "").data(using: .utf8)
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(String(body?.count ?? 0), forHTTPHeaderField: "Content-Length")
        }
        req.headers?.forEach({ header in
            guard let name = header.name else {
                return
            }
            request.setValue(header.value, forHTTPHeaderField: name)
        })
        
        do {
            let (data, response) = try await nativebrikSession.data(for: self.intercepter(request))
            guard let res = response as? HTTPURLResponse else {
                return Result.failure(NativebrikError.irregular("Failed to parse as HttpURLResponse"))
            }
            
            var expected = false
            if let expectedStatusCodes = assetion?.statusCodes {
                let matched = expectedStatusCodes.first { expectedStatusCode in
                    return expectedStatusCode == res.statusCode
                }
                if matched == nil {
                    return Result.failure(NativebrikError.other(HttpRequestAssertionError.unexpected))
                } else {
                    expected = true
                }
            } else {
                if 200 <= res.statusCode && res.statusCode <= 299 {
                    expected = true
                }
            }
            
            let decoder = JSONDecoder()
            guard let result = try? decoder.decode(JSON.self, from: data) else {
                if expected {
                    return Result.success(JSONData(data: nil))
                } else {
                    return Result.failure(NativebrikError.unexpected)
                }
            }
            return Result.success(JSONData(data: result))
        } catch {
            return Result.failure(NativebrikError.other(error))
        }
    }
}
