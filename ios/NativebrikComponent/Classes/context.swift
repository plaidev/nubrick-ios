//
//  context.swift
//  NativebrikComponent
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

class UIBlockContext {
    private let data: JSON?
    private let event: UIBlockEventManager?
    private var parentClickListener: ClickListener?
    private var parentDirection: FlexDirection?
    
    init(
        data: JSON?,
        event: UIBlockEventManager?,
        parentClickListener: ClickListener?,
        parentDirection: FlexDirection?
    ) {
        self.data = data
        self.event = event
        self.parentClickListener = parentClickListener
        self.parentDirection = parentDirection
    }
    
    func instanciateFrom(
        data: JSON?,
        event: UIBlockEventManager?,
        parentClickListener: ClickListener?,
        parentDirection: FlexDirection?
    ) -> UIBlockContext {
        return UIBlockContext(
            data: data ?? self.data,
            event: event ?? self.event,
            parentClickListener: parentClickListener ?? self.parentClickListener,
            parentDirection: parentDirection ?? self.parentDirection
        )
    }
    
    func getParentDireciton() -> FlexDirection? {
        return self.parentDirection
    }
    
    func dipatch(event: UIBlockEventDispatcher) {
        self.event?.dispatch(event: event)
    }
    
    /**
            propaget onClick gesture to parent
     */
    func propagate() {
        if let onClick = self.parentClickListener?.onClick {
            onClick()
        }
    }
    
    func getByReferenceKey(key: String?) -> Any? {
        if let key = key {
            if key.count == 0 {
                return nil
            }
            if let data = data {
                let keys = key.split(separator: ".")
                var current: Any? = data.value
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
