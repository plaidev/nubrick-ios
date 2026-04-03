//
//  http-request-usecase.swift
//  Nubrick
//
//  Created by Codex on 2026/04/03.
//

import Foundation

protocol HttpRequestUseCase {
    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError>
}

final class HttpRequestUseCaseImpl: HttpRequestUseCase {
    private let httpRequestRepository: HttpRequestRepository

    init(httpRequestRepository: HttpRequestRepository) {
        self.httpRequestRepository = httpRequestRepository
    }

    func sendHttpRequest(req: ApiHttpRequest, assertion: ApiHttpResponseAssertion?, variable: Any?) async -> Result<JSONData, NubrickError> {
        let request = ApiHttpRequest(
            url: compile(req.url ?? "", variable),
            method: req.method,
            headers: req.headers?.map { it in
                return ApiHttpHeader(name: compile(it.name ?? "", variable), value: compile(it.value ?? "", variable))
            },
            body: compile(req.body ?? "", variable)
        )
        return await self.httpRequestRepository.request(req: request, assetion: assertion)
    }
}
