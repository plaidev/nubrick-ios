//
//  _for_bridge.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2025/04/24.
//
import Foundation
import UIKit

public class __DO_NOT_USE__NativebrikBridgedViewAccessor {
    private let rootOrUIView: UIView
    
    init(rootView: RootView) {
        self.rootOrUIView = rootView as UIView
    }
    
    init(uiview: UIView) {
        self.rootOrUIView = uiview
    }
    
    public var view: UIView {
        get {
            return self.rootOrUIView
        }
    }
    
    // event must be UIBlockEventDispatcher with json format.
    // this method is used to forcefully dispatch an event from the page view.
    public func dispatch(event: String) throws {
        guard let rootView = self.rootOrUIView as? RootView else {
            return
        }
        guard let data = event.data(using: .utf8) else {
            return
        }
        let dispatcher = try JSONDecoder().decode(UIBlockEventDispatcher.self, from: data)
        rootView.dispatch(event: dispatcher)
    }
}
