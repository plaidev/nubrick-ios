//
//  form.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Combine
import Foundation

@MainActor
protocol FormRepository: Sendable {
    var formDataPublisher: AnyPublisher<[String: Any], Never> { get }
    func getFormData() -> [String: Any]
    func setValue(key: String, value: Any)
    func getValue(key: String) -> Any?
}

@MainActor
final class FormRepositoryImpl: FormRepository {
    @Published private var formData: [String: Any] = [:]

    var formDataPublisher: AnyPublisher<[String: Any], Never> {
        $formData.eraseToAnyPublisher()
    }

    func getFormData() -> [String: Any] {
        return formData
    }

    func getValue(key: String) -> Any? {
        return formData[key]
    }

    func setValue(key: String, value: Any) {
        formData[key] = value
    }
}
