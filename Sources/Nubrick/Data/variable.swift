//
//  variable.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

// All leaf values are JSON-primitive types (String, Int, Double, Bool, [Any], [String: Any])
// which are inherently Sendable, but Swift can't prove that through [String: Any].
struct Variable: @unchecked Sendable {
    let value: [String: Any]
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

func _mergeVariable(base: Variable?, _ overlay: Variable?) -> Variable? {
    guard let base = base?.value else {
        return overlay
    }
    let overlay = overlay?.value
    return Variable(value: [
        "user": overlay?["user"] ?? base["user"] as Any,
        "props": overlay?["props"] ?? base["props"] as Any,
        "form": overlay?["form"] ?? base["form"] as Any,
        "args": overlay?["args"] ?? base["args"] as Any,
        "data": overlay?["data"] ?? base["data"] as Any,
        "project": overlay?["project"] ?? base["project"] as Any,
    ])
}
