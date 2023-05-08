//
//  sdk.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI

struct Config {
    let apiKey: String
    var url: String = "https://nativebrik.com/client"
}

public struct Nativebrik {
    private let config: Config

    public init(apiKey: String) {
        self.config = Config(
            apiKey: apiKey
        )
    }

    public init(apiKey: String, environment: String) {
        self.config = Config(
            apiKey: apiKey,
            url: environment
        )
    }

    /**
     returns SwiftUI.View
     */
    public func Component(id: String) -> some View {
        return ComponentViewControllerRepresentable(
            componentId: id,
            config: self.config,
            fallback: nil
        )
    }

    /**
     returns UIView.ViewController
     */
    public func ComponentVC(id: String) -> UIViewController {
        return ComponentViewController(
            componentId: id,
            config: self.config,
            fallback: nil
        )
    }
    
    public func ComponentVC(id: String, fallback: ((_ state: ComponentLoadingState) -> UIView)?) -> UIViewController {
        return ComponentViewController(
            componentId: id,
            config: self.config,
            fallback: fallback
        )
    }
}

