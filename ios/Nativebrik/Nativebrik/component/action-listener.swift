//
//  action-listener.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit

class AnimatedUIControl: UIControl {
    fileprivate var defaultOpacity: Float? = nil
    fileprivate var clickListener: ClickListener? = nil
    func setClickListener(clickListener: ClickListener) {
        self.clickListener = clickListener
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        if let process = self.clickListener?.onTouchBegan {
            process()
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let process = self.clickListener?.onTouchEnded {
            process()
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if let process = self.clickListener?.onTouchCanceled {
            process()
        }
    }
    @objc func onClicked(sender: ClickListener) {
        if sender.state == .ended {
            if let onClick = sender.onClick {
                onClick()
            }
        }
    }
}

class ClickListener: UITapGestureRecognizer {
    var onClick: (() -> Void)? = nil
    var onTouchBegan: (() -> Void)? = nil
    var onTouchEnded: (() -> Void)? = nil
    var onTouchCanceled: (() -> Void)? = nil
}

// configureOnClickGesture sets up a click listener for the target view.
func configureOnClickGesture(
    target: UIView, action: Selector, context: UIBlockContext, event: UIBlockEventDispatcher?
) -> ClickListener {
    let gesture = ClickListener(target: target, action: action)
    gesture.onClick = {
        guard let event = event else { return }

        let variable = context.getVariable()
        let deepLink = event.deepLink
        let name = event.name
        let compiledEvent = UIBlockEventDispatcher(
            name: (name != nil) ? compile(name ?? "", variable) : nil,
            destinationPageId: event.destinationPageId,
            deepLink: (deepLink != nil) ? compile(deepLink ?? "", variable) : nil,
            payload: event.payload?.map({ prop in
                return Property(
                    name: prop.name ?? "",
                    value: compile(prop.value ?? "", variable),
                    ptype: prop.ptype ?? PropertyType.STRING
                )
            }),
            httpRequest: event.httpRequest,
            httpResponseAssertion: event.httpResponseAssertion
        )

        if event.httpRequest != nil {
            // set loading UI
            target.isUserInteractionEnabled = false
            target.alpha = 0.8
        }
        context.dispatch(
            event: compiledEvent,
            options: UIBlockEventDispatchOptions(
                onHttpSettled: {
                    // reset loading UI
                    target.isUserInteractionEnabled = true
                    target.alpha = 1
                }
            ))
    }
    if event != nil {
        target.addGestureRecognizer(gesture)
    }

    gesture.onTouchBegan = {
        if event != nil && context.hasParent() {
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: .curveEaseInOut,
                animations: { [weak target] in
                    target?.transform = CGAffineTransform(scaleX: 0.984, y: 0.984)
                })
        } else {
            if let onTouchBegan = context.getParentClickListener()?.onTouchBegan {
                onTouchBegan()
            }
        }
    }
    gesture.onTouchEnded = {
        if event != nil && context.hasParent() {
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: .curveEaseInOut,
                animations: { [weak target] in
                    target?.transform = CGAffineTransform(scaleX: 1, y: 1)
                })
        } else {
            if let onTouchBegan = context.getParentClickListener()?.onTouchEnded {
                onTouchBegan()
            }
        }

    }
    gesture.onTouchCanceled = {
        if event != nil && context.hasParent() {
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                options: .curveEaseInOut,
                animations: { [weak target] in
                    target?.transform = CGAffineTransform(scaleX: 1, y: 1)
                })
        } else {
            if let onTouchBegan = context.getParentClickListener()?.onTouchCanceled {
                onTouchBegan()
            }
        }
    }

    if target is AnimatedUIControl {
        let animatedTarget = target as! AnimatedUIControl
        animatedTarget.setClickListener(clickListener: gesture)
    }

    return gesture
}

func getIsDisabled(requiredFields: [String]) -> (([String: Any]) -> Boolean) {
    return { values in
        return requiredFields.contains {
            if let value = values[$0] as? String {
                return value.isEmpty
            }
            return false
        }
    }
}

func configureDisabled(target: UIView, context: UIBlockContext, requiredFields: [String]?) -> FormValueListener? {
    guard let requiredFields = requiredFields, !requiredFields.isEmpty else { return nil }
    let isDisabled = getIsDisabled(requiredFields: requiredFields)
    
    let handleFormValueChange: FormValueListener = { values in
        DispatchQueue.main.async {
            if isDisabled(values) {
                target.isUserInteractionEnabled = false
                target.alpha = 0.5
            } else {
                target.isUserInteractionEnabled = true
                target.alpha = 1.0
            }
        }
    }
    
    // apply the initial state
    let values = context.getFormValues()
    handleFormValueChange(values)
    
    return handleFormValueChange
}
    
