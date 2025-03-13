//
//  network.swift
//  Nativebrik
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

func getData(url: URL, syncDateTime: Bool = false) async -> Result<Data, NativebrikError> {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    do {
        let t0 = getCurrentDate()
        let (data, response) = try await nativebrikSession.data(for: request)
        guard let res = response as? HTTPURLResponse else {
            return Result.failure(NativebrikError.irregular("Failed to parse as HttpURLResponse"))
        }
        if syncDateTime {
            syncDateFromHTTPURLResponse(t0: t0, res: res)
        }
        if res.statusCode == 404 {
            return Result.failure(NativebrikError.notFound)
        }
        return Result.success(data)
    } catch {
        return Result.failure(NativebrikError.other(error))
    }
}
