//
//  context.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation

struct UIBlockEventDispatchOptions {
    var onHttpSuccess: (() -> Void)? = nil
    var onHttpError: (() -> Void)? = nil
    var onHttpSettled: (() -> Void)? = nil
}

class UIBlockEventManager {
    private let callback:
        (_ event: UIBlockEventDispatcher, _ options: UIBlockEventDispatchOptions?) -> Void
    init(
        on: @escaping (_ event: UIBlockEventDispatcher, _ options: UIBlockEventDispatchOptions?) ->
            Void
    ) {
        self.callback = on
    }

    func dispatch(event: UIBlockEventDispatcher, options: UIBlockEventDispatchOptions? = nil) {
        self.callback(event, options)
    }
}

struct UIBlockContextInit {
    var container: Container? = nil
    var variable: Any? = nil
    var childData: Any? = nil
    var properties: [Property]? = nil
    var event: UIBlockEventManager? = nil
    var parentClickListener: ClickListener? = nil
    var parentDirection: FlexDirection? = nil
    var loading: Bool? = false
}

struct UIBlockContextChildInit {
    var childData: Any? = nil
    var properties: [Property]? = nil
    var event: UIBlockEventManager? = nil
    var parentClickListener: ClickListener? = nil
    var parentDirection: FlexDirection? = nil
    var loading: Bool? = false
}

class UIBlockContext {
    // variable that page fetched with http request
    private let variable: Any?
    // page properties
    private let properties: [Property]?
    private let container: Container?
    private let event: UIBlockEventManager?
    private var parentClickListener: ClickListener?
    private var parentDirection: FlexDirection?
    private var loading: Bool = false
    
    init(_ args: UIBlockContextInit) {
        self.variable = args.variable
        self.properties = args.properties
        self.event = args.event
        self.parentClickListener = args.parentClickListener
        self.parentDirection = args.parentDirection
        self.loading = args.loading ?? false
        self.container = args.container
    }

    func instanciateFrom(_ args: UIBlockContextChildInit) -> UIBlockContext {
        var v = self.variable
        if let childData = args.childData {
            v = _mergeVariable(
                base: v, self.container?.createVariableForTemplate(data: childData, properties: nil)
            )
        }
        return UIBlockContext(
            UIBlockContextInit(
                container: self.container,
                variable: v,
                properties: args.properties ?? self.properties,
                event: args.event ?? self.event,
                parentClickListener: args.parentClickListener ?? self.parentClickListener,
                parentDirection: args.parentDirection ?? self.parentDirection,
                loading: args.loading ?? self.loading
            ))
    }

    func getVariable() -> Any? {
        return self.variable
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

    func dispatch(event: UIBlockEventDispatcher, options: UIBlockEventDispatchOptions? = nil) {
        self.event?.dispatch(event: event, options: options)
    }

    func writeToForm(key: String, value: Any) {
        self.container?.setFormValue(key: key, value: value)
    }

    func getFormValueByKey(key: String) -> Any? {
        return self.container?.getFormValue(key: key)
    }
    
    func getFormValues() -> [String: Any] {
        return self.container?.getFormValues() ?? [:]
    }
        
    
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) {
        self.container?.addFormValueListener(id, listener)
    }
    
    func removeFormValueListener(_ id: String) {
        self.container?.removeFormValueListener(id)
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
        return variableByPath(path: key ?? "", variable: self.variable)
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
