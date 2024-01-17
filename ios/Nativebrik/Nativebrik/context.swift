//
//  context.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation

class UIBlockEventManager {
    private let callback: (_ event: UIBlockEventDispatcher) -> Void
    init(on: @escaping (_ event: UIBlockEventDispatcher) -> Void) {
        self.callback = on
    }

    func dispatch(event: UIBlockEventDispatcher) {
        self.callback(event)
    }
}

class UIBlockFormManager {
    var formValues: [String:Any] = [:]
    func write(key: String, value: Any) {
        formValues[key] = value
    }
    func getByKey(key: String) -> Any? {
        return formValues[key]
    }
}

struct UIBlockContextInit {
    var data: Any? = nil
    var properties: [Property]? = nil
    var event: UIBlockEventManager? = nil
    var form: UIBlockFormManager? = nil
    var parentClickListener: ClickListener? = nil
    var parentDirection: FlexDirection? = nil
    var loading: Bool? = false
}

class UIBlockContext {
    // data that page fetched with http request
    private let data: Any?
    // page properties
    private let properties: [Property]?
    private let event: UIBlockEventManager?
    private let form: UIBlockFormManager?
    private var parentClickListener: ClickListener?
    private var parentDirection: FlexDirection?
    private var loading: Bool = false
    
    init(_ args: UIBlockContextInit) {
        self.data = args.data
        self.properties = args.properties
        self.event = args.event
        self.form = args.form
        self.parentClickListener = args.parentClickListener
        self.parentDirection = args.parentDirection
        self.loading = args.loading ?? false
    }

    func instanciateFrom(_ args: UIBlockContextInit) -> UIBlockContext {
        return UIBlockContext(UIBlockContextInit(
            data: args.data ?? self.data,
            properties: args.properties ?? self.properties,
            event: args.event ?? self.event,
            form: args.form ?? self.form,
            parentClickListener: args.parentClickListener ?? self.parentClickListener,
            parentDirection: args.parentDirection ?? self.parentDirection,
            loading: args.loading ?? self.loading
        ))
    }

    func isLoading() -> Bool {
        return self.loading
    }

    func hasParent() -> Bool {
        return self.parentClickListener != nil
    }

    func getParentDireciton() -> FlexDirection? {
        return self.parentDirection
    }

    func dipatch(event: UIBlockEventDispatcher) {
        self.event?.dispatch(event: event)
    }
    
    func writeToForm(key: String, value: Any) {
        self.form?.write(key: key, value: value)
    }
    
    func getFormValueByKey(key: String) -> Any? {
        self.form?.getByKey(key: key)
    }

    /**
            propaget onClick gesture to parent
     */
    func propagate() {
        if let onClick = self.parentClickListener?.onClick {
            onClick()
        }
    }

    func getParentClickListener() -> ClickListener? {
        return self.parentClickListener
    }

    func getByReferenceKey(key: String?) -> Any? {
        if let key = key {
            if key.count == 0 {
                return nil
            }
            if let data = data {
                let keys = key.split(separator: ".")
                var current: Any? = data
                for key in keys {
                    if current == nil {
                        return nil
                    }
                    if let dictionary = current as? [String: Any] {
                        let child = dictionary.first(where: { $0.key == key })
                        current = child?.value
                    } else {
                        return nil
                    }
                }
                return current
            }
        }
        return nil
    }

    func getArrayByReferenceKey(key: String?) -> [Any]? {
        if let value = self.getByReferenceKey(key: key) as? [Any] {
            return value
        }
        return nil
    }

    func getStringByReferenceKey(key: String?) -> String? {
        if let value = self.getByReferenceKey(key: key) as? String {
            return value
        }
        return nil
    }

    func getFloatByReferenceKey(key: String?) -> Float? {
        if let value = self.getByReferenceKey(key: key) as? Double {
            return Float(value)
        }
        return nil
    }

    func getIntByReferenceKey(key: String?) -> Int? {
        if let value = self.getByReferenceKey(key: key) as? Double {
            return Int(value)
        }
        return nil
    }
}
