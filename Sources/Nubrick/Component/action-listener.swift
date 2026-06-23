//
//  action-listener.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Combine
import Foundation
import UIKit

class AnimatedUIView: UIView {
    private var onClick: (() -> Void)?
    private var onTouchBegan: (() -> Void)?
    private var onTouchEnded: (() -> Void)?
    private var onTouchCanceled: (() -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        onTouchBegan?()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        onTouchEnded?()
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        onTouchCanceled?()
    }

    @objc private func handleTap() {
        onClick?()
    }

    @MainActor
    func configureOnClickGesture(context: UIBlockContext, uiBlockAction: UIBlockAction?) {
        onClick = { [weak self] in
            guard let uiBlockAction = uiBlockAction else { return }
            let compiledAction = compileAction(action: uiBlockAction, context: context)
            if uiBlockAction.httpRequest != nil {
                self?.isUserInteractionEnabled = false
                self?.alpha = 0.8
            }
            context.dispatch(
                action: compiledAction,
                onHttpSettled: { [weak self] in
                    self?.isUserInteractionEnabled = true
                    self?.alpha = 1
                }
            )
        }

        if uiBlockAction != nil {
            let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
            addGestureRecognizer(tap)
        }

        onTouchBegan = { [weak self] in
            if uiBlockAction != nil && context.hasParent() {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
                    self?.transform = CGAffineTransform(scaleX: 0.984, y: 0.984)
                }
            } else {
                context.getParentView()?.onTouchBegan?()
            }
        }
        onTouchEnded = { [weak self] in
            if uiBlockAction != nil && context.hasParent() {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
                    self?.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            } else {
                context.getParentView()?.onTouchEnded?()
            }
        }
        onTouchCanceled = { [weak self] in
            if uiBlockAction != nil && context.hasParent() {
                UIView.animate(withDuration: 0.1, delay: 0, options: .curveEaseInOut) {
                    self?.transform = CGAffineTransform(scaleX: 1, y: 1)
                }
            } else {
                context.getParentView()?.onTouchCanceled?()
            }
        }
    }
}

func isDisabled(requiredFields: [String], values: [String: Any]) -> Bool {
    return requiredFields.contains {
        if let value = values[$0] as? String {
            return value.isEmpty
        }
        return false
    }
}

@MainActor
func makeDisabledStateListener(target: UIView, context: UIBlockContext, requiredFields: [String]?) -> AnyCancellable? {
    guard let requiredFields, !requiredFields.isEmpty else { return nil }
    return context.formPublisher()
        .map { isDisabled(requiredFields: requiredFields, values: $0) }
        .removeDuplicates()
        .sink { [weak target] disabled in
            guard let target else { return }
            target.isUserInteractionEnabled = !disabled
            target.alpha = disabled ? 0.5 : 1.0
        }
}

@MainActor
func compileAction(action: UIBlockAction, context: UIBlockContext?) -> UIBlockAction {
    guard let context = context else { return action }

    return compileAction(action: action, variable: context.getVariable())
}

@MainActor
func compileAction(action: UIBlockAction, variable: Variable?) -> UIBlockAction {
    let deepLink = action.deepLink
    let eventName = action.eventName ?? action.name
    let legacyName = action.name ?? action.eventName
    return UIBlockAction(
        eventName: (eventName != nil) ? compile(eventName ?? "", variable) : nil,
        name: (legacyName != nil) ? compile(legacyName ?? "", variable) : nil,
        destinationPageId: action.destinationPageId,
        deepLink: (deepLink != nil) ? compile(deepLink ?? "", variable) : nil,
        payload: action.payload?.map({ prop in
            return Property(
                name: prop.name ?? "",
                value: compile(prop.value ?? "", variable),
                ptype: prop.ptype ?? PropertyType.STRING
            )
        }),
        requiredFields: action.requiredFields,
        httpRequest: action.httpRequest,
        httpResponseAssertion: action.httpResponseAssertion
    )
}
