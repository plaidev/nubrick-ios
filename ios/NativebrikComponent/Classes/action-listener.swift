//
//  action-listener.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import UIKit

class ClickListener: UITapGestureRecognizer {
    var onClick : (() -> Void)? = nil
}

func configureOnClickGesture(target: UIView, action: Selector, context: UIBlockContext, event: UIBlockEventDispatcher?) -> ClickListener {
    let gesture = ClickListener(target: target, action: action)
    gesture.onClick = {
        if let event = event {
            let compiledPayload = event.payload?.map { property -> Property in
                let value = compileTemplate(template: property.value ?? "") { placeholder in
                    return context.getByReferenceKey(key: placeholder)
                }
                
                return Property(
                    name: property.name,
                    value: value,
                    ptype: property.ptype
                )
            }
            
            let compiledEvent = UIBlockEventDispatcher(
                name: event.name,
                destinationPageId: event.destinationPageId,
                payload: compiledPayload
            )
            
            context.dipatch(event: compiledEvent)
        } else {
            context.propagate()
        }
    }
    target.addGestureRecognizer(gesture)
    
    return gesture
}
