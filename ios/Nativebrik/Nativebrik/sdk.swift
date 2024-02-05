//
//  sdk.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine

public let nativebrikSdkVersion = "0.3.1"
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

public class NativebrikClient: ObservableObject {
    private let config: Config
    private let repositories: Repositories
    private let overlayVC: OverlayViewController
    public final let experiment: NativebrikExperiment
    public final let user: NativebrikUser

    public init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NativebrikHttpRequestInterceptor? = nil
    ) {
        self.user = NativebrikUser()
        self.config = Config(
            projectId: projectId,
            onEvent: onEvent
        )
        self.repositories = Repositories(config: config, user: self.user, interceptor: httpRequestInterceptor)
        self.overlayVC = OverlayViewController(user: self.user, config: config, repositories: repositories)
        self.experiment = NativebrikExperiment(user: self.user, config: config, repositories: repositories, overlay: self.overlayVC)
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

    public func dispatch(event: NativebrikEvent) {
        self.overlayVC.triggerViewController.dispatch(event: event)
    }
}

public class NativebrikExperiment {
    private let user: NativebrikUser
    private let config: Config
    private let repositories: Repositories
    private let overlayVC: OverlayViewController

    fileprivate init(user: NativebrikUser, config: Config, repositories: Repositories, overlay: OverlayViewController) {
        self.user = user
        self.config = config
        self.repositories = repositories
        self.overlayVC = overlay
    }

    public func embedding(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(EmptyView())
        }
        return AnyView(EmbeddingSwiftView(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController
        ))
    }

    public func embedding<V: View>(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ phase: AsyncComponentPhase) -> V)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(content(.failure))
        }
        return AnyView(EmbeddingSwiftView.init<V>(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content
        ))
    }

    public func embedding<I: View, P: View>(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ component: any View) -> I),
        @ViewBuilder placeholder: (@escaping () -> P)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(placeholder())
        }
        return AnyView(EmbeddingSwiftView.init<I, P>(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content,
            placeholder: placeholder
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
        return EmbeddingUIView(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }

    public func embeddingUIView(
        _ id: String,
        arguments: [String:Any?]? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: ComponentPhase) -> UIView
    ) -> UIView {
        if !isNativebrikAvailable {
            return content(.failure)
        }
        return EmbeddingUIView(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: content
        )
    }

    public func remoteConfig(
        _ id: String,
        phase: @escaping ((_ phase: RemoteConfigPhase) -> Void)
    ) {
        if !isNativebrikAvailable {
            phase(.failure)
            return
        }
        let _ = RemoteConfig(
            user: self.user,
            experimentId: id,
            repositories: self.repositories,
            config: self.config,
            modalViewController: self.overlayVC.modalViewController,
            phase: phase
        )
    }

    public func remoteConfigAsView<V: View>(
        _ id: String,
        @ViewBuilder phase: @escaping ((_ phase: RemoteConfigPhase) -> V)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(phase(.failure))
        }
        return AnyView(RemoteConfigAsView(
            user: self.user,
            experimentId: id,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: phase
        ))
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
            self.context.overlay()
            _content.environmentObject(self.context)
        }
    }
}
