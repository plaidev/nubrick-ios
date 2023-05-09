//
//  sdk.swift
//  NativebrikComponent
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI

class Config {
    let apiKey: String
    var url: String = "https://nativebrik.com/client"
    var eventListeners: [((_ event: ComponentEvent) -> Void)] = []
    
    init() {
        self.apiKey = ""
    }
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    init(
        apiKey: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) {
        self.apiKey = apiKey
        if let onEvent = onEvent {
            self.eventListeners.append(onEvent)
        }
    }
    
    // for internal use
    init(apiKey: String, url: String) {
        self.apiKey = apiKey
        self.url = url
    }
    
    func initFrom(onEvent: ((_ event: ComponentEvent) -> Void)?) -> Config {
        let config = Config(
            apiKey: self.apiKey,
            url: self.url
        )
        
        if let onEvent = onEvent {
            config.eventListeners.append(onEvent)
        }
        
        return config
    }
    
    func dispatchUIBlockEvent(event: UIBlockEventDispatcher) {
        let e = ComponentEvent(
            name: event.name,
            destinationPageId: event.destinationPageId,
            deepLink: event.deepLink,
            payload: event.payload?.map({ prop in
                var ptype: EventPropertyType = .UNKNOWN
                switch prop.ptype {
                case .INTEGER:
                    ptype = .INTEGER
                case .STRING:
                    ptype = .STRING
                case .TIMESTAMPZ:
                    ptype = .TIMESTAMPZ
                default:
                    ptype = .UNKNOWN
                }
                return EventProperty(
                    name: prop.name ?? "",
                    value: prop.value ?? "",
                    type: ptype
                )
            })
        )
        for listener in eventListeners {
            listener(e)
        }
    }
}

public enum LoadingState {
    case LOADING
    case ERROR
}

public enum EventPropertyType {
    case INTEGER
    case STRING
    case TIMESTAMPZ
    case UNKNOWN
}

public struct EventProperty {
    public let name: String
    public let value: String
    public let type: EventPropertyType
}

public struct ComponentEvent {
    public let name: String?
    public let destinationPageId: String?
    public let deepLink: String?
    public let payload: [EventProperty]?
}

public struct TriggerEvent {
    public let name: String
}

public struct TriggerEventFactory {
    public static func sdkInitialized() -> TriggerEvent {
        return TriggerEvent(name: TriggerEventNameDefs.NATIVEBRIK_SDK_INITIALIZED.rawValue)
    }
    
    public static func userFirstVisit() -> TriggerEvent {
        return TriggerEvent(name: TriggerEventNameDefs.NATOVEBRIK_SDK_USER_FIRST_VISIT.rawValue)
    }
    
    public static func custom(name: String) -> TriggerEvent {
        return TriggerEvent(name: name)
    }
}

public enum NativebrikError: Error {
    case triggerShouldBeInitialized
}

public class Nativebrik {
    private let config: Config
    private var triggerVC: TriggerViewController? = nil

    public init(apiKey: String) {
        self.config = Config(
            apiKey: apiKey
        )
    }
    
    public init(
        apiKey: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) {
        self.config = Config(
            apiKey: apiKey,
            onEvent: onEvent
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
        return ComponentViewControllerRepresentable<EmptyView>(
            componentId: id,
            config: self.config,
            fallback: nil
        )
    }

    public func Component<V: View>(
        id: String,
        fallback: ((_ state: LoadingState) -> V)?) -> some View {
        return ComponentViewControllerRepresentable(
            componentId: id,
            config: self.config,
            fallback: fallback
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
    
    public func ComponentVC(
        id: String,
        fallback: ((_ state: LoadingState) -> UIView)?,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) -> UIViewController {
        return ComponentViewController(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            fallback: fallback
        )
    }
    
    public func TriggerManagerVC() -> UIViewController {
        if let triggerVC = self.triggerVC {
            return triggerVC
        }
        let triggerVC = TriggerViewController(config: self.config)
        self.triggerVC = triggerVC
        return triggerVC
    }
    
    public func Dispatch(event: TriggerEvent) throws {
        if let triggerVC = triggerVC {
            triggerVC.dispatch(event: event)
        } else {
            throw NativebrikError.triggerShouldBeInitialized
        }
    }
}
