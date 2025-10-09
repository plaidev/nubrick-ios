//
//  form.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2024/03/07.
//

import Foundation

typealias FormValueListener = ([String: Any]) -> Void

protocol FormRepository {
    func getFormData() -> [String:Any]
    func setValue(key: String, value: Any)
    func getValue(key: String) -> Any?
    func addFormValueListener(id: String, listener: @escaping FormValueListener)
    func removeFormValueListener(id: String)
}

class FormRepositoryImpl: FormRepository {
    private var map: [String: Any] = [:]
    private var listeners: [String: FormValueListener] = [:]
    
    func getFormData() -> [String : Any] {
        return self.map
    }
    
    func getValue(key: String) -> Any? {
        return self.map[key]
    }
    
    func setValue(key: String, value: Any) {
        self.map[key] = value
        for callback in self.listeners.values {
            callback(map)
        }
    }
    
    func addFormValueListener(id: String, listener: @escaping FormValueListener) {
        self.listeners.updateValue(listener, forKey: id)
    }
    
    func removeFormValueListener(id: String) {
        self.listeners.removeValue(forKey: id)
    }
}
