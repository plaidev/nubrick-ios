//
//  variable.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Combine
import Foundation

// All leaf values are JSON-primitive types (String, Int, Double, Bool, [Any], [String: Any])
// which are inherently Sendable, but Swift can't prove that through [String: Any].
struct Variable: @unchecked Sendable {
    let value: [String: Any]
}

@MainActor
final class VariableStore {
    @Published private(set) var variable: Variable?
    @Published private(set) var loading: Bool = false
    private var cancellables = Set<AnyCancellable>()

    init(_ variable: Variable? = nil, loading: Bool = false) {
        self.variable = variable
        self.loading = loading
    }

    func update(_ variable: Variable?) {
        self.variable = variable
    }

    func updateLoading(_ loading: Bool) {
        self.loading = loading
    }

    func updateData(_ data: Any?) {
        guard var value = self.variable?.value else { return }
        value["data"] = data as Any
        self.variable = Variable(value: value)
    }

    func updateForm(_ form: [String: Any]) {
        guard var value = self.variable?.value else { return }
        value["form"] = form.isEmpty ? nil : form as Any
        self.variable = Variable(value: value)
    }

    func updateUser(_ userData: [String: Any]) {
        guard var value = self.variable?.value else { return }
        value["user"] = userData.isEmpty ? nil : userData as Any
        self.variable = Variable(value: value)
    }

    func publisher() -> AnyPublisher<Variable?, Never> {
        self.$variable.eraseToAnyPublisher()
    }

    func loadingPublisher() -> AnyPublisher<Bool, Never> {
        self.$loading.eraseToAnyPublisher()
    }

    func derived(_ map: @escaping (Variable?) -> Variable?) -> VariableStore {
        let store = VariableStore(map(self.variable), loading: self.loading)
        self.$variable
            .dropFirst()
            .map(map)
            .sink { [weak store] variable in
                store?.update(variable)
            }
            .store(in: &store.cancellables)
        self.$loading
            .dropFirst()
            .sink { [weak store] loading in
                store?.updateLoading(loading)
            }
            .store(in: &store.cancellables)
        return store
    }
}

@MainActor
func _createVariableForTemplate(
    user: NubrickUser? = nil,
    data: Any? = nil,
    properties: [Property]? = nil,
    form: [String: Any]? = nil,
    arguments: NubrickArguments? = nil,
    projectId: String? = nil
) -> Variable {
    var userData: [String: Any] = [:]
    if let user = user {
        userData["id"] = user.id
        user.getProperties().forEach { userData[$0.key] = $0.value }
    }
    
    let formData: [String:Any]? = form
    var propertiesData: [String:Any] = [:]
    if let properties = properties {
        properties.forEach { prop in
            guard let key = prop.name else {
                return
            }
            propertiesData[key] = prop.value
        }
    }
    let projectData: [String:Any] = [
        "id": projectId ?? "",
    ]
    return Variable(value: [
        "user": (userData.isEmpty ? nil : userData) as Any,
        "props": (propertiesData.isEmpty ? nil : propertiesData) as Any,
        "form": (formData?.isEmpty == true ? nil : formData) as Any,
        "args": arguments as Any,
        "data": data as Any,
        "project": projectData as Any,
    ])
}

func _replaceVariableData(base: Variable?, data: Any) -> Variable {
    var value = base?.value ?? [:]
    value["data"] = data
    return Variable(value: value)
}
