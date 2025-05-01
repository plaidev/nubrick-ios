//
//  sdk.swift
//  Nativebrik
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine

// for development
public var nativebrikTrackUrl = "https://track.nativebrik.com/track/v1"
public var nativebrikCdnUrl = "https://cdn.nativebrik.com"
public let nativebrikSdkVersion = "0.9.5"

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
    guard let url = URL(string: link) else {
        return
    }
    if UIApplication.shared.canOpenURL(url) {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(url, options: [:])
        } else {
            UIApplication.shared.openURL(url)
        }
    }
}

func createDispatchNativebrikEvent(_ client: NativebrikClient) -> (_ event: ComponentEvent) -> Void {
    return { event in
        guard let name = event.name else {
            return
        }
        if name.isEmpty {
            return
        }
        client.experiment.dispatch(NativebrikEvent(name))
    }
}

class Config {
    let projectId: String
    var url: String = "https://nativebrik.com/client"
    var trackUrl: String = nativebrikTrackUrl
    var cdnUrl: String = nativebrikCdnUrl
    var eventListeners: [((_ event: ComponentEvent) -> Void)] = []
    var cachePolicy: NativebrikCachePolicy = NativebrikCachePolicy()

    init() {
        self.projectId = ""
    }

    init(
        projectId: String,
        onEvents: [((_ event: ComponentEvent) -> Void)?] = [],
        cachePolicy: NativebrikCachePolicy? = nil
    ) {
        self.projectId = projectId
        onEvents.forEach { onEvent in
            if let onEvent = onEvent {
                self.eventListeners.append(onEvent)
            }
        }
        if let cachePolicy = cachePolicy {
            self.cachePolicy = cachePolicy
        }
    }

    func addEventListner(_ onEvent: @escaping (_ event: ComponentEvent) -> Void) {
        self.eventListeners.append(onEvent)
    }

    func dispatchUIBlockEvent(event: UIBlockEventDispatcher) {
        let e = convertEvent(event)
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
        httpRequestInterceptor: NativebrikHttpRequestInterceptor? = nil,
        cachePolicy: NativebrikCachePolicy? = nil,
        onDispatch: ((_ event: NativebrikEvent) -> Void)? = nil
    ) {
        let user = NativebrikUser()
        let config = Config(projectId: projectId, onEvents: [
            openLink,
            onEvent
        ],
        cachePolicy: cachePolicy)
        let persistentContainer = createNativebrikCoreDataHelper()
        self.user = user
        self.config = config
        self.container = ContainerImpl(
            config: config,
            cache: CacheStore(policy: config.cachePolicy),
            user: user,
            persistentContainer: persistentContainer,
            intercepter: httpRequestInterceptor
        )
        self.overlayVC = OverlayViewController(user: self.user, container: self.container, onDispatch: onDispatch)
        self.experiment = NativebrikExperiment(container: self.container, overlay: self.overlayVC)

        config.addEventListner(createDispatchNativebrikEvent(self))
    }
}

public class NativebrikExperiment {
    private let container: Container
    private let overlayVC: OverlayViewController

    fileprivate init(container: Container, overlay: OverlayViewController) {
        self.container = container
        self.overlayVC = overlay
    }

    public func dispatch(_ event: NativebrikEvent) {
        self.overlayVC.triggerViewController.dispatch(event: event)
    }

    public func record(exception: NSException) {
        self.container.record(exception)
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
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(EmptyView())
        }
        return AnyView(EmbeddingSwiftView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent
        ))
    }

    public func embedding<V: View>(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: (@escaping (_ phase: AsyncEmbeddingPhase) -> V)
    ) -> some View {
        if !isNativebrikAvailable {
            return AnyView(content(.notFound))
        }
        return AnyView(EmbeddingSwiftView.init<V>(
            experimentId: id,
            componentId: nil,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            content: content
        ))
    }

    public func embeddingUIView(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView {
        if !isNativebrikAvailable {
            return UIView()
        }
        return EmbeddingUIView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: nil
        )
    }

    public func embeddingUIView(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        if !isNativebrikAvailable {
            return content(.notFound)
        }
        return EmbeddingUIView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
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

    // for flutter integration
    public func __do_not_use__fetch_tooltip_data(trigger: String) async -> Result<String, NativebrikError> {
        switch await self.container.fetchTooltip(trigger: trigger) {
        case .success(let result):
            do {
                let encoder = JSONEncoder()
                let jsonData = try encoder.encode(result)
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    return .success(jsonString)
                } else {
                    return .failure(.failedToEncode)
                }
            } catch let error {
                return .failure(.other(error))
            }
        case .failure(let error):
            return .failure(error)
        }
    }

    public func __do_not_use__render_uiview(
        json: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> __DO_NOT_USE__NativebrikBridgedViewAccessor {
        if !isNativebrikAvailable {
            return __DO_NOT_USE__NativebrikBridgedViewAccessor(uiview: UIView())
        }
        do {
            let decoder = JSONDecoder()
            let data = Data(json.utf8)
            let decoded = try decoder.decode(UIRootBlock.self, from: data)
            return __DO_NOT_USE__NativebrikBridgedViewAccessor(rootView: RootView(
                root: decoded,
                container: self.container,
                modalViewController: self.overlayVC.modalViewController,
                onEvent: { event in
                    onEvent?(convertEvent(event))
                },
                onNextTooltip: onNextTooltip,
                onDismiss: onDismiss
            ))
        } catch {
            return __DO_NOT_USE__NativebrikBridgedViewAccessor(uiview: UIView())
        }
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

