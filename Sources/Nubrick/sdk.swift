//
//  sdk.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import Combine
import MetricKit
import Darwin.Mach

// For crash reporting
@available(iOS 14.0, *)
class AppMetrics: NSObject, MXMetricManagerSubscriber {
   private let recordCrash: (_ crash: MXCrashDiagnostic) -> Void

   init(_ recordCrash: @escaping (_ crash: MXCrashDiagnostic) -> Void) {
       self.recordCrash = recordCrash
       super.init()
       
       let shared = MXMetricManager.shared
       shared.add(self)

       // Immediately receive crash reports generated since
       // the last allocation of the shared manager instance
       didReceive(shared.pastDiagnosticPayloads)
   }

   deinit {
       let shared = MXMetricManager.shared
       shared.remove(self)
   }

   func didReceive(_ payloads: [MXDiagnosticPayload]) {
       
       payloads.forEach { payload in
            payload.crashDiagnostics?.forEach { crashDiagnostic in
                recordCrash(crashDiagnostic)
            }
        }
    }
}


// for development
public var nubrickTrackUrl = "http://172.16.11.240:8070/track/v1"
public var nubrickCdnUrl = "https://cdn.nativebrik.com"
public let nubrickSdkVersion = "0.12.3"

public let isNubrickAvailable: Bool = {
    if #available(iOS 15.0, *) {
        return true
    } else {
        return false
    }
}()

private func openLink(_ event: ComponentEvent) -> Void {
    guard let link = event.deepLink,
          let url = URL(string: link),
          UIApplication.shared.canOpenURL(url) else {
        return
    }
    UIApplication.shared.open(url)
}

private func createDispatchNubrickEvent(_ client: NubrickClient) -> (_ event: ComponentEvent) -> Void {
    return { [weak client] event in
        guard let client,
              let name = event.name,
              !name.isEmpty else {
            return
        }
        client.experiment.dispatch(NubrickEvent(name))
    }
}

final class Config {
    let projectId: String
    var url: String = "https://nativebrik.com/client"
    var trackUrl: String = nubrickTrackUrl
    var cdnUrl: String = nubrickCdnUrl
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

    func addEventListener(_ onEvent: @escaping (_ event: ComponentEvent) -> Void) {
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

public struct NubrickEvent {
    public let name: String
    public init(_ name: String) {
        self.name = name
    }
}

public typealias NubrickHttpRequestInterceptor = (_ request: URLRequest) -> URLRequest

public final class NubrickClient: ObservableObject {
    private let container: Container
    private let config: Config
    private let overlayVC: OverlayViewController
    public final let experiment: NubrickExperiment
    public final let user: NubrickUser
    private var appMetrics: Any?

    public init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil,
        cachePolicy: NativebrikCachePolicy? = nil,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil
    ) {
        let user = NubrickUser()
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
        self.experiment = NubrickExperiment(container: self.container, overlay: self.overlayVC)

        // Initialize AppMetrics only for iOS 14+
        if #available(iOS 14.0, *) {
            self.appMetrics = AppMetrics(self.experiment.report)
        }


        config.addEventListener(createDispatchNubrickEvent(self))
    }
    
    public func simulateCrash() {
        // let p = UnsafeMutablePointer<Int>(bitPattern: 0)!
        // _ = p.pointee      // <-- expect this exact line in atos/Sentry
        fatalError("unreachable") // never reached; just silences Noreturn warnings
    }
}

public class NubrickExperiment {
    private let container: Container
    private let overlayVC: OverlayViewController

    fileprivate init(container: Container, overlay: OverlayViewController) {
        self.container = container
        self.overlayVC = overlay
    }

    public func dispatch(_ event: NubrickEvent) {
        if !isNubrickAvailable {
            return
        }
        self.overlayVC.triggerViewController.dispatch(event: event)
    }
    
    @available(iOS 14.0, *)
    public func report(crash: MXCrashDiagnostic) {
        if !isNubrickAvailable {
            return
        }
       self.container.report(crash)
    }

    public func overlayViewController() -> UIViewController {
        if !isNubrickAvailable {
            let vc = UIViewController()
            vc.view.frame = .zero
            return vc
        }
        return self.overlayVC
    }

    public func overlay() -> some View {
        if !isNubrickAvailable {
            return AnyView(EmptyView())
        }
        return AnyView(OverlayViewControllerRepresentable(overlayVC: self.overlayVC).frame(width: 0, height: 0))
    }

    public func embedding(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        if !isNubrickAvailable {
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
        if !isNubrickAvailable {
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
        if !isNubrickAvailable {
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
        if !isNubrickAvailable {
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
        if !isNubrickAvailable {
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
        if !isNubrickAvailable {
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
    public func __do_not_use__fetch_tooltip_data(trigger: String) async -> Result<String, NubrickError> {
        if !isNubrickAvailable {
            return .failure(.notFound)
        }
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
        if !isNubrickAvailable {
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

public struct NubrickProvider<Content: View>: View {
    private let content: Content
    private let client: NubrickClient

    public init(client: NubrickClient, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.client = client
    }

    public var body: some View {
        ZStack(alignment: .top) {
            self.client.experiment.overlay()
            content.environmentObject(self.client)
        }
    }
}
