//
//  context.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Combine
import Foundation
import UIKit

typealias UIBlockActionHandler = @MainActor (_ action: UIBlockAction, _ onHttpSettled: (() -> Void)?) -> Void

struct UIBlockContextInit {
    var container: Container? = nil
    var variableStore: VariableStore? = nil
    var properties: [Property]? = nil
    var actionHandler: UIBlockActionHandler? = nil
    var parentView: AnimatedUIView? = nil
    var parentDirection: FlexDirection? = nil
    var layoutInvalidationRoot: UIView? = nil
}

struct UIBlockContextChildInit {
    var variable: Variable? = nil
    var variableMapper: ((_ variable: Variable?) -> Variable?)? = nil
    var properties: [Property]? = nil
    var actionHandler: UIBlockActionHandler? = nil
    var parentView: AnimatedUIView? = nil
    var parentDirection: FlexDirection? = nil
    var layoutInvalidationRoot: UIView? = nil
}

@MainActor
class UIBlockContext {
    // page properties
    private let properties: [Property]?
    private let container: Container?
    private let actionHandler: UIBlockActionHandler?
    private let variableStore: VariableStore
    private weak var parentView: AnimatedUIView?
    private var parentDirection: FlexDirection?
    private weak var layoutInvalidationRoot: UIView?

    init(_ args: UIBlockContextInit) {
        self.variableStore = args.variableStore ?? VariableStore()
        self.properties = args.properties
        self.actionHandler = args.actionHandler
        self.parentView = args.parentView
        self.parentDirection = args.parentDirection
        self.layoutInvalidationRoot = args.layoutInvalidationRoot
        self.container = args.container
    }

    func instanciateFrom(_ args: UIBlockContextChildInit) -> UIBlockContext {
        let variableStore: VariableStore
        if let variableMapper = args.variableMapper {
            variableStore = self.variableStore.derived(variableMapper)
        } else if let variable = args.variable {
            variableStore = VariableStore(variable)
        } else {
            variableStore = self.variableStore
        }

        return UIBlockContext(
            UIBlockContextInit(
                container: self.container,
                variableStore: variableStore,
                properties: args.properties ?? self.properties,
                actionHandler: args.actionHandler ?? self.actionHandler,
                parentView: args.parentView ?? self.parentView,
                parentDirection: args.parentDirection ?? self.parentDirection,
                layoutInvalidationRoot: args.layoutInvalidationRoot ?? self.layoutInvalidationRoot
            ))
    }

    func getVariable() -> Variable? {
        return self.variableStore.variable
    }

    func variablePublisher() -> AnyPublisher<Variable?, Never> {
        return self.variableStore.publisher()
    }

    func getLayoutInvalidationRoot() -> UIView? {
        return self.layoutInvalidationRoot
    }

    func loadingPublisher() -> AnyPublisher<Bool, Never> {
        return self.variableStore.loadingPublisher()
    }

    func hasParent() -> Bool {
        return self.parentView != nil
    }

    func getParentDireciton() -> FlexDirection? {
        return self.parentDirection
    }

    // Entry point for UI-block actions created by gestures and triggers.
    func dispatch(action: UIBlockAction, onHttpSettled: (() -> Void)? = nil) {
        self.actionHandler?(action, onHttpSettled)
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


    func formPublisher() -> AnyPublisher<[String: Any], Never> {
        self.container?.formDataPublisher() ?? Just([:]).eraseToAnyPublisher()
    }

    func getParentView() -> AnimatedUIView? {
        return self.parentView
    }

}
