//
//  sdk.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine

public let nativebrikSdkVersion = "0.3.3"
public let isNativebrikAvailable: Bool = {
    if #available(iOS 15.0, *) {
        return true
    } else {
        return false
    }
}()

func openLink(_ event: ComponentEvent) -> Void {
    guard let link = event.deepLink else {
        return
    }
    let url = URL(string: link)!
    if UIApplication.shared.canOpenURL(url) {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:])
        } else {
            UIApplication.shared.openURL(url)
        }
    }
}

class Config {
    let projectId: String
    var url: String = "https://nativebrik.com/client"
    var trackUrl: String = "https://track.nativebrik.com/track/v1"
    var cdnUrl: String = "https://cdn.nativebrik.com"
    static let defaultListeners: [((_ event: ComponentEvent) -> Void)] = [openLink]
    var eventListeners: [((_ event: ComponentEvent) -> Void)] = []

    init() {
        self.projectId = ""
    }

    init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) {
        self.projectId = projectId
        if let onEvent = onEvent {
            self.eventListeners.append(onEvent)
        }
    }

    func initFrom(onEvent: ((_ event: ComponentEvent) -> Void)?) -> Config {
        let config = Config(
            projectId: self.projectId
        )

        for listener in eventListeners {
            config.eventListeners.append(listener)
        }

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
        for listener in Config.defaultListeners {
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

public struct NativebrikEvent {
    public let name: String
    public init(_ name: String) {
        self.name = name
    }
}

public typealias NativebrikHttpRequestInterceptor = (_ request: URLRequest) -> URLRequest

public class NativebrikClient: ObservableObject {
    private let container: Container
    private let config: Config
    private let overlayVC: OverlayViewController
    public final let experiment: NativebrikExperiment
    public final let user: NativebrikUser

    public init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NativebrikHttpRequestInterceptor? = nil
    ) {
        let user = NativebrikUser()
        let config = Config(projectId: projectId, onEvent: onEvent)
        let persistentContainer = createNativebrikCoreDataHelper()
        self.user = user
        self.config = config
        self.container = ContainerImpl(
            config: config,
            user: user,
            persistentContainer: persistentContainer,
            intercepter: httpRequestInterceptor
        )
        self.overlayVC = OverlayViewController(user: self.user, container: self.container)
        self.experiment = NativebrikExperiment(container: self.container, overlay: self.overlayVC)
    }
}

public class NativebrikExperiment {
    private let container: Container
    private let overlayVC: OverlayViewController

    fileprivate init(container: Container, overlay: OverlayViewController) {
        self.container = container
        self.overlayVC = overlay
    }

    public func dispatch(event: NativebrikEvent) {
        self.overlayVC.triggerViewController.dispatch(event: event)
    }

    public func overlayViewController() -> UIViewController {
        if !isNativebrikAvailable {
            let vc = UIViewController()
            vc.view.frame = .zero
            return vc
        }
        return self.overlayVC
    }

    public func overlay() -> some View {
        if !isNativebrikAvailable {
            return AnyView(EmptyView())
        }
        return AnyView(OverlayViewControllerRepresentable(overlayVC: self.overlayVC).frame(width: 0, height: 0))
    }

    public func embedding(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(EmptyView())
        }
        return AnyView(EmbeddingSwiftView2(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController
        ))
    }

    public func embedding<V: View>(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ phase: AsyncEmbeddingPhase2) -> V)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(content(.notFound))
        }
        return AnyView(EmbeddingSwiftView2.init<V>(
            experimentId: id,
            componentId: nil,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            content: content
        ))
    }

    public func embeddingUIView(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView {
        if !isNativebrikAvailable {
            return UIView()
        }
        return EmbeddingUIView2(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }

    public func embeddingUIView(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        if !isNativebrikAvailable {
            return content(.notFound)
        }
        return EmbeddingUIView2(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            fallback: content
        )
    }

    public func remoteConfig(
        _ id: String,
        phase: @escaping ((_ phase: RemoteConfigPhase) -> Void)
    ) {
        if !isNativebrikAvailable {
            phase(.notFound)
            return
        }
        let _ = RemoteConfig(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            phase: phase
        )
    }

    public func remoteConfigAsView<V: View>(
        _ id: String,
        @ViewBuilder phase: @escaping ((_ phase: RemoteConfigPhase) -> V)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(phase(.notFound))
        }
        return AnyView(RemoteConfigAsView(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            content: phase
        ))
    }
    
    public func z__never_use_this_function_internal_embedding(
        _ id: String,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) {
        
    }
}

public struct NativebrikProvider<Content: View>: View {
    private let _content: Content
    private let context: NativebrikClient

    public init(client: NativebrikClient, @ViewBuilder content: () -> Content) {
        self._content = content()
        self.context = client
    }

    public var body: some View {
        ZStack(alignment: .top) {
            self.context.experiment.overlay()
            _content.environmentObject(self.context)
        }
    }
}
