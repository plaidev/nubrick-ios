//
//  sdk.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI

public struct Nativebrik {
    private let apiKey: String
    private let url: String = "http://localhost:8060/client"
    
    public init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    /**
     returns SwiftUI.View
     */
    public func Component(id: String) -> some View {
        return ComponentViewControllerRepresentable(componentId: id, apiKey: self.apiKey, url: self.url)
    }
    
    /**
     returns UIView.ViewController
     */
    public func ComponentVC(id: String) -> ComponentViewController {
        return ComponentViewController(componentId: id, apiKey: self.apiKey, url: self.url)
    }
}

