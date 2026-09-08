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
    func setValue(key: String, value: Any, regex: String?)
    func getValue(key: String) -> Any?
    func getFormRegexes() -> [String: String]
}

@MainActor
final class FormRepositoryImpl: FormRepository {
    @Published private var formData: [String: Any] = [:]
    private var regexByKey: [String: String] = [:]

    var formDataPublisher: AnyPublisher<[String: Any], Never> {
        $formData.eraseToAnyPublisher()
    }

    func getFormData() -> [String: Any] {
        return formData
    }

    func getValue(key: String) -> Any? {
        return formData[key]
    }

    func setValue(key: String, value: Any, regex: String? = nil) {
        if let regex {
            if regex.isEmpty {
                regexByKey.removeValue(forKey: key)
            } else {
                regexByKey[key] = regex
            }
        }
        formData[key] = value
    }

    func getFormRegexes() -> [String: String] {
        return regexByKey
    }
}
