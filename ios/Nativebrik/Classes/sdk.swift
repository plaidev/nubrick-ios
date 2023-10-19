//
//  sdk.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine

public let nativebrikSdkVersion = "0.1.5"

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

public struct TriggerEvent {
    public let name: String
    init(_ name: String) {
        self.name = name
    }
}

public class NativebrikClient: ObservableObject {
    private let config: Config
    private let repositories: Repositories
    private let overlayVC: OverlayViewController
    public final let experiment: NativebrikExperiment
    public final let user: NativebrikUser

    public init(projectId: String) {
        self.user = NativebrikUser()
        self.config = Config(
            projectId: projectId
        )
        self.repositories = Repositories(config: config, user: self.user)
        self.overlayVC = OverlayViewController(user: self.user, config: config, repositories: repositories)
        self.experiment = NativebrikExperiment(user: self.user, config: config, repositories: repositories, overlay: self.overlayVC)
    }

    public init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?
    ) {
        self.user = NativebrikUser()
        self.config = Config(
            projectId: projectId,
            onEvent: onEvent
        )
        self.repositories = Repositories(config: config, user: self.user)
        self.overlayVC = OverlayViewController(user: self.user, config: config, repositories: repositories)
        self.experiment = NativebrikExperiment(user: self.user, config: config, repositories: repositories, overlay: self.overlayVC)
    }

    public func overlayViewController() -> UIViewController {
        return self.overlayVC
    }

    public func overlay() -> some View {
        return OverlayViewControllerRepresentable(overlayVC: self.overlayVC).frame(width: 0, height: 0)
    }

    public func dispatch(event: TriggerEvent) throws {
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

    public func embedding(_ id: String) -> some View {
        return EmbeddingSwiftView(
            experimentId: id,
            user: self.user,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController
        )
    }
    
    public func embedding(_ id: String, onEvent: ((_ event: ComponentEvent) -> Void)?) -> some View {
        return EmbeddingSwiftView(
            experimentId: id,
            user: self.user,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController
        )
    }

    public func embedding<V: View>(
        _ id: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        @ViewBuilder content: (@escaping (_ phase: AsyncComponentPhase) -> V)
    ) -> some View {
        return EmbeddingSwiftView.init<V>(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content
        )
    }

    public func embedding<I: View, P: View>(
        _ id: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        @ViewBuilder content: (@escaping (_ component: any View) -> I),
        @ViewBuilder placeholder: (@escaping () -> P)
    ) -> some View {
        return EmbeddingSwiftView.init<I, P>(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: content,
            placeholder: placeholder
        )
    }

    public func embeddingUIView(_ id: String) -> UIView {
        return EmbeddingUIView(
            experimentId: id,
            user: self.user,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }

    public func embeddingUIView(_ id: String, onEvent: ((_ event: ComponentEvent) -> Void)?) -> UIView {
        return EmbeddingUIView(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: nil
        )
    }

    public func embeddingUIView(_ id: String, onEvent: ((_ event: ComponentEvent) -> Void)?, content: @escaping (_ phase: ComponentPhase) -> UIView) -> UIView {
        return EmbeddingUIView(
            experimentId: id,
            user: self.user,
            config: self.config.initFrom(onEvent: onEvent),
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            fallback: content
        )
    }

    public func remoteConfig(_ id: String, phase: @escaping ((_ phase: RemoteConfigPhase) -> Void)) {
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
        return RemoteConfigAsView(
            user: self.user,
            experimentId: id,
            config: self.config,
            repositories: self.repositories,
            modalViewController: self.overlayVC.modalViewController,
            content: phase
        )
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
