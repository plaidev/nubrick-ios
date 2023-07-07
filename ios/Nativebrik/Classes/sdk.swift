//
//  sdk.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine

class Config {
    let projectId: String
    var url: String = "https://nativebrik.com/client"
    var cdnUrl: String = "https://cdn.nativebrik.com"
    var eventListeners: [((_ event: ComponentEvent) -> Void)] = []

    init() {
        self.projectId = ""
    }

    init(projectId: String) {
        self.projectId = projectId
    }

    init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) {
        self.projectId = projectId
        if let onEvent = onEvent {
            self.eventListeners.append(onEvent)
        }
    }

    // for internal use
    init(projectId: String, url: String) {
        self.projectId = projectId
        self.url = url
    }

    func initFrom(onEvent: ((_ event: ComponentEvent) -> Void)?) -> Config {
        let config = Config(
            projectId: self.projectId,
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
    public var properties: [EventProperty]? = nil
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
    
    public static func custom(name: String, properties: [EventProperty]) -> TriggerEvent {
        return TriggerEvent(name: name, properties: properties)
    }
}

public class Nativebrik: ObservableObject {
    private let config: Config
    private let repositories: Repositories
    private let overlayVC: OverlayViewController

    public init(projectId: String) {
        self.config = Config(
            projectId: projectId
        )
        self.repositories = Repositories(config: config)
        self.overlayVC = OverlayViewController(config: config, repositories: repositories)
    }

    public init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) {
        self.config = Config(
            projectId: projectId,
            onEvent: onEvent
        )
        self.repositories = Repositories(config: config)
        self.overlayVC = OverlayViewController(config: config, repositories: repositories)
    }

    public init(projectId: String, environment: String) {
        self.config = Config(
            projectId: projectId,
            url: environment
        )
        self.repositories = Repositories(config: config)
        self.overlayVC = OverlayViewController(config: config, repositories: repositories)
    }

    public func component(
        id: String
    ) -> some View {
        return ComponentSwiftView(
            componentId: id,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController
        )
    }

    public func component(
        id: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) -> some View {
        return ComponentSwiftView(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController
        )
    }

    public func component<V: View>(
        id: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        @ViewBuilder content: (@escaping (_ phase: AsyncComponentPhase) -> V)
    ) -> some View {
        return ComponentSwiftView.init<V>(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content
        )
    }

    public func component<I: View, P: View>(
        id: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        @ViewBuilder content: (@escaping (_ component: any View) -> I),
        @ViewBuilder placeholder: (@escaping () -> P)
    ) -> some View {
        return ComponentSwiftView.init<I, P>(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content,
            placeholder: placeholder
        )
    }

    public func componentView(id: String) -> UIView {
        return ComponentUIView(
            componentId: id,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }
    
    public func componentView(id: String, onEvent: ((_ event: ComponentEvent) -> Void)?) -> UIView {
        return ComponentUIView(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }
    
    public func componentView(id: String, onEvent: ((_ event: ComponentEvent) -> Void)?, content: @escaping (_ phase: ComponentPhase) -> UIView) -> UIView {
        return ComponentUIView(
            componentId: id,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: content
        )
    }

    public func overlayViewController() -> UIViewController {
        return self.overlayVC
    }

    public func overlay() -> some View {
        return OverlayViewControllerRepresentable(overlayVC: self.overlayVC)
    }

    public func dispatch(event: TriggerEvent) throws {
        self.overlayVC.triggerViewController.dispatch(event: event)
    }
}

public struct NativebrikProvider<Content: View>: View {
    private let _content: Content
    private let context: Nativebrik

    public init(client: Nativebrik, @ViewBuilder content: () -> Content) {
        self._content = content()
        self.context = client
    }

    public var body: some View {
        ZStack(alignment: .top) {
            self.context.overlay()
            _content.environmentObject(self.context)
        }
    }
}
