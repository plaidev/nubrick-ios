//
//  sdk.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI

public struct Config {
    public let apiKey: String
    public let url: String = "http://localhost:8060/client"
}

public struct Nativebrik {
    private let config: Config

    public init(apiKey: String) {
        self.config = Config(
            apiKey: apiKey
        )
    }
    
    /**
     returns SwiftUI.View
     */
    public func Component(id: String) -> some View {
        return ComponentViewControllerRepresentable(
            componentId: id,
            config: self.config
        )
    }
    
    /**
     returns UIView.ViewController
     */
    public func ComponentVC(id: String) -> ComponentViewController {
        return ComponentViewController(
            componentId: id,
            config: self.config
        )
    }
}

