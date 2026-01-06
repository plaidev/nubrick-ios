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
public var nubrickTrackUrl = "https://track.nativebrik.com/track/v1"
public var nubrickCdnUrl = "https://cdn.nativebrik.com"
public let nubrickSdkVersion = "0.14.4"

public var isNubrickAvailable: Bool {
    if #available(iOS 15.0, *) { true } else { false }
}

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
    var trackCrashes : Bool = true

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
    private let appMetrics: Any?

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
        if #available(iOS 14.0, *), config.trackCrashes {
            self.appMetrics = AppMetrics(self.experiment.processMetricKitCrash)
        } else {
            self.appMetrics = nil
        }

        config.addEventListener(createDispatchNubrickEvent(self))
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
    internal func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
        if !isNubrickAvailable {
            return
        }
       self.container.processMetricKitCrash(crash)
    }

    /// Sends a crash event from Flutter
    ///
    /// - Parameter crashEvent: The crash event containing exceptions, platform, and SDK version
    @_spi(FlutterBridge)
    public func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        if !isNubrickAvailable {
            return
        }
        self.container.sendFlutterCrash(crashEvent)
    }

    /// Records a breadcrumb for crash reporting context.
    ///
    /// Breadcrumbs are persisted to disk and included in crash reports
    /// delivered by MetricKit in the next app session.
    ///
    /// - Parameter breadcrumb: The breadcrumb to record
    @_spi(FlutterBridge)
    public func recordBreadcrumb(_ breadcrumb: Breadcrumb) {
        if !isNubrickAvailable {
            return
        }
        self.container.recordBreadcrumb(breadcrumb)
    }
    
    /// Records a breadcrumb from Flutter Bridge data
    ///
    /// - Parameter data: Dictionary containing breadcrumb data from Flutter's method channel.
    ///
    /// Expected structure from Flutter (see `lib/breadcrumb.dart`):
    /// ```
    /// {
    ///   "message": String,              // Required: breadcrumb message
    ///   "category": String,             // Optional: "navigation", "ui", "http", "console", "custom"
    ///   "level": String,                // Optional: "debug", "info", "warning", "error", "fatal"
    ///   "data": [String: Any]?,         // Optional: additional key-value data
    ///   "timestamp": Int64              // Required: milliseconds since epoch
    /// }
    /// ```
    @_spi(FlutterBridge)
    public func recordBreadcrumb(_ data: [String: Any]) {
        if !isNubrickAvailable {
            return
        }
        // Flutter method channel passes String and Int64 from Dart
        guard let message = data["message"] as? String,
              let timestamp = data["timestamp"] as? Int64 else {
            return
        }
        // category and level are optional strings with defaults
        let categoryString = data["category"] as? String ?? "custom"
        let levelString = data["level"] as? String ?? "info"
        let category = BreadcrumbCategory(rawValue: categoryString) ?? .custom
        let level = BreadcrumbLevel(rawValue: levelString) ?? .info

        // data is an optional dictionary; we only keep String values
        var stringData: [String: String]? = nil
        if let rawData = data["data"] as? [String: Any] {
            stringData = rawData.compactMapValues { $0 as? String }
        }

        let breadcrumb = Breadcrumb(
            message: message,
            category: category,
            level: level,
            data: stringData,
           timestamp: timestamp
        )
        self.container.recordBreadcrumb(breadcrumb)
    }

    @available(*, deprecated, message: "NSException-based crash reporting has been replaced by MetricKit. This method no longer reports crashes. Crash reporting now happens automatically via MetricKit on iOS 14+.")
    public func record(exception: NSException) {
        // No-op: MetricKit handles crash reporting automatically on iOS 14+
        // This method is kept for API compatibility but does nothing
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
    @_spi(FlutterBridge)
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

    @_spi(FlutterBridge)
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
