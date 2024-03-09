//
//  form.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

protocol FormRepository {
    func getFormData() -> [String:Any]
    func setValue(key: String, value: Any)
    func getValue(key: String) -> Any?
}

class FormRepositoryImpl: FormRepository {
    private var map: [String:Any] = [:]
    
    func getFormData() -> [String : Any] {
        return self.map
    }
    
    func getValue(key: String) -> Any? {
        return self.map[key]
    }
    
    func setValue(key: String, value: Any) {
        self.map[key] = value
    }
}
