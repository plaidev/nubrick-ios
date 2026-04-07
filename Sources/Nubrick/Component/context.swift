//
//  context.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation

typealias UIBlockActionHandler = @MainActor (_ action: UIBlockAction, _ onHttpSettled: (() -> Void)?) -> Void

struct UIBlockContextInit {
    var renderContext: RenderContext? = nil
    var variable: Any? = nil
    var childData: Any? = nil
    var properties: [Property]? = nil
    var actionHandler: UIBlockActionHandler? = nil
    var parentClickListener: ClickListener? = nil
    var parentDirection: FlexDirection? = nil
    var loading: Bool? = false
}

struct UIBlockContextChildInit {
    var childData: Any? = nil
    var properties: [Property]? = nil
    var actionHandler: UIBlockActionHandler? = nil
    var parentClickListener: ClickListener? = nil
    var parentDirection: FlexDirection? = nil
    var loading: Bool? = false
}

@MainActor
class UIBlockContext {
    // variable that page fetched with http request
    private let variable: Any?
    // page properties
    private let properties: [Property]?
    private let renderContext: RenderContext?
    private let actionHandler: UIBlockActionHandler?
    private var parentClickListener: ClickListener?
    private var parentDirection: FlexDirection?
    private var loading: Bool = false
    
    init(_ args: UIBlockContextInit) {
        self.variable = args.variable
        self.properties = args.properties
        self.actionHandler = args.actionHandler
        self.parentClickListener = args.parentClickListener
        self.parentDirection = args.parentDirection
        self.loading = args.loading ?? false
        self.renderContext = args.renderContext
    }

    func instanciateFrom(_ args: UIBlockContextChildInit) -> UIBlockContext {
        var v = self.variable
        if let childData = args.childData {
            v = _mergeVariable(
                base: v, self.renderContext?.createVariableForTemplate(data: childData, properties: nil)
            )
        }
        return UIBlockContext(
            UIBlockContextInit(
                renderContext: self.renderContext,
                variable: v,
                properties: args.properties ?? self.properties,
                actionHandler: args.actionHandler ?? self.actionHandler,
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

    // Entry point for UI-block actions created by gestures and triggers.
    func dispatch(action: UIBlockAction, onHttpSettled: (() -> Void)? = nil) {
        self.actionHandler?(action, onHttpSettled)
    }

    func writeToForm(key: String, value: Any) {
        self.renderContext?.setFormValue(key: key, value: value)
    }

    func getFormValueByKey(key: String) -> Any? {
        return self.renderContext?.getFormValue(key: key)
    }
    
    func getFormValues() -> [String: Any] {
        return self.renderContext?.getFormValues() ?? [:]
    }
        
    
    func addFormValueListener(_ id: String, _ listener: @escaping FormValueListener) {
        self.renderContext?.addFormValueListener(id, listener)
    }
    
    func removeFormValueListener(_ id: String) {
        self.renderContext?.removeFormValueListener(id)
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
        let value = self.getByReferenceKey(key: key)
        if let value = value as? Double {
            return Float(value)
        }
        if let value = value as? Int {
            return Float(value)
        }
        return nil
    }

    func getIntByReferenceKey(key: String?) -> Int? {
        let value = self.getByReferenceKey(key: key)
        if let value = value as? Int {
            return value
        }
        if let value = value as? Double {
            return Int(value)
        }
        return nil
    }
}
