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
            context.dipatch(event: event)
        } else {
            context.propagate()
        }
    }
    target.addGestureRecognizer(gesture)
    
    return gesture
}
