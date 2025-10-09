//
//  variable.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

func _createVariableForTemplate(
    user: NativebrikUser? = nil,
    data: Any? = nil,
    properties: [Property]? = nil,
    form: [String: Any]? = nil,
    arguments: Any? = nil,
    projectId: String? = nil
) -> Any {
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
    return [
        "user": (userData.isEmpty ? nil : userData) as Any,
        "props": (propertiesData.isEmpty ? nil : propertiesData) as Any,
        "form": (formData?.isEmpty == true ? nil : formData) as Any,
        "args": arguments as Any,
        "data": data as Any,
        "project": projectData as Any,
    ]
}

func _mergeVariable(base: Any?, _ overlay: Any?) -> Any? {
    guard let base = base as? [String:Any] else {
        return overlay
    }
    let overlay = overlay as? [String:Any]
    let data: [String:Any] = [
        "user": overlay?["user"] ?? base["user"] as Any,
        "props": overlay?["props"] ?? base["props"] as Any,
        "form": overlay?["form"] ?? base["form"] as Any,
        "args": overlay?["args"] ?? base["args"] as Any,
        "data": overlay?["data"] ?? base["data"] as Any,
        "project": overlay?["project"] ?? base["project"] as Any,
    ]
    return data
}
