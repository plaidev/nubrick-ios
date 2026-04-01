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
@MainActor
final class AppMetrics: NSObject, @MainActor MXMetricManagerSubscriber {

    // Keep exactly 1 subscriber per iOS process (prevents Flutter hot-restart duplicates)
    static var shared: AppMetrics?

    private var recordCrash: (MXCrashDiagnostic) -> Void

    /// Create and subscribe immediately
    init(_ recordCrash: @escaping (MXCrashDiagnostic) -> Void) {
        self.recordCrash = recordCrash
        super.init()

        let manager = MXMetricManager.shared
        manager.add(self)

        // Immediately receive crash reports generated since last app run / last manager allocation
        didReceive(manager.pastDiagnosticPayloads)
    }

    /// Called during Flutter hot restart (Dart side changes, but iOS process stays alive)
    func updateCallback(_ recordCrash: @escaping (MXCrashDiagnostic) -> Void) {
        self.recordCrash = recordCrash
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            guard let crashDiagnostics = payload.crashDiagnostics else { continue }
            for crashDiagnostic in crashDiagnostics {
                recordCrash(crashDiagnostic)
            }
        }
    }
}




// Default backend endpoints (used unless overridden per client instance)
public let nubrickTrackUrl = "https://track.nativebrik.com/track/v1"
public let nubrickCdnUrl = "https://cdn.nativebrik.com"
public let nubrickSdkVersion = "0.16.4"

@MainActor
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
    let trackUrl: String
    let cdnUrl: String
    var eventListeners: [(@MainActor (_ event: ComponentEvent) -> Void)] = []
    var cachePolicy: NubrickCachePolicy = NubrickCachePolicy()

    init() {
        self.projectId = ""
        self.trackUrl = nubrickTrackUrl
        self.cdnUrl = nubrickCdnUrl
    }

    init(
        projectId: String,
        onEvents: [ (@MainActor(_ event: ComponentEvent) -> Void)?] = [],
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil
    ) {
        self.projectId = projectId
        self.trackUrl = trackUrl ?? nubrickTrackUrl
        self.cdnUrl = cdnUrl ?? nubrickCdnUrl
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

public struct NubrickEvent : Sendable {
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

    public convenience init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil,
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        trackCrashes: Bool = true
    ) {
        self.init(
            projectId: projectId,
            onEvent: onEvent,
            httpRequestInterceptor: httpRequestInterceptor,
            trackUrl: trackUrl,
            cdnUrl: cdnUrl,
            cachePolicy: cachePolicy,
            onDispatch: onDispatch,
            trackCrashes: trackCrashes,
            onTooltip: nil
        )
    }

    @_spi(FlutterBridge)
    public convenience init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil,
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        trackCrashes: Bool = true,
        onTooltip: @escaping ((_ data: String, _ experimentId: String) -> Void)
    ) {
        self.init(
            projectId: projectId,
            onEvent: onEvent,
            httpRequestInterceptor: httpRequestInterceptor,
            trackUrl: trackUrl,
            cdnUrl: cdnUrl,
            cachePolicy: cachePolicy,
            onDispatch: onDispatch,
            trackCrashes: trackCrashes,
            onTooltip: onTooltip as ((String, String) -> Void)?
        )
    }

    private init(
        projectId: String,
        onEvent: ((_ event: ComponentEvent) -> Void)?,
        httpRequestInterceptor: NubrickHttpRequestInterceptor?,
        trackUrl: String?,
        cdnUrl: String?,
        cachePolicy: NubrickCachePolicy?,
        onDispatch: ((_ event: NubrickEvent) -> Void)?,
        trackCrashes: Bool,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)?
    ) {
        let user = NubrickUser()
        let config = Config(projectId: projectId, onEvents: [
            openLink,
            onEvent
        ],
        trackUrl: trackUrl,
        cdnUrl: cdnUrl,
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
        self.overlayVC = OverlayViewController(user: self.user, container: self.container, onDispatch: onDispatch, onTooltip: onTooltip)
        self.experiment = NubrickExperiment(container: self.container, overlay: self.overlayVC)

        if trackCrashes {
            Task { @MainActor in
                if let existing = AppMetrics.shared {
                    existing.updateCallback(self.experiment.processMetricKitCrash)
                } else {
                    AppMetrics.shared = AppMetrics(self.experiment.processMetricKitCrash)
                }
            }
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
        let overlayVC = self.overlayVC
        Task { @MainActor in
            overlayVC.triggerViewController.dispatch(event: event)
        }
    }

    internal func processMetricKitCrash(_ crash: MXCrashDiagnostic) {
       self.container.processMetricKitCrash(crash)
    }

    /// Sends a crash event from Flutter
    ///
    /// - Parameter crashEvent: The crash event containing exceptions, platform, and SDK version
    @_spi(FlutterBridge)
    public func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        self.container.sendFlutterCrash(crashEvent)
    }

    @_spi(FlutterBridge)
    public func appendTooltipExperimentHistory(experimentId: String) {
        if experimentId.isEmpty {
            return
        }
        self.container.appendExperimentHistory(experimentId: experimentId)
    }

    @available(*, deprecated, message: "NSException-based crash reporting has been replaced by MetricKit. This method no longer reports crashes. Crash reporting now happens automatically via MetricKit on iOS 14+.")
    public func record(exception: NSException) {
        // No-op: MetricKit handles crash reporting automatically on iOS 14+
        // This method is kept for API compatibility but does nothing
    }

    public func overlayViewController() -> UIViewController {
        return self.overlayVC
    }

    public func overlay() -> some View {
        return AnyView(OverlayViewControllerRepresentable(overlayVC: self.overlayVC).frame(width: 0, height: 0))
    }

    @MainActor
    public func embedding(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        return AnyView(EmbeddingSwiftView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent
        ))
    }

    @MainActor
    public func embedding<V: View>(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: @escaping (_ phase: AsyncEmbeddingPhase) -> V
    ) -> some View {
        return AnyView(EmbeddingSwiftView(
            experimentId: id,
            componentId: nil,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            content: content
        ))
    }

    @MainActor
    public func embeddingUIView(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView {
        return EmbeddingUIView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: nil
        )
    }

    @MainActor
    public func embeddingUIView(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
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
        let _ = RemoteConfig(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            phase: phase
        )
    }

    @MainActor
    public func remoteConfigAsView<V: View>(
        _ id: String,
        @ViewBuilder phase: @escaping ((_ phase: RemoteConfigPhase) -> V)
    ) -> some View {
        return AnyView(RemoteConfigAsView(
            experimentId: id,
            container: self.container,
            modalViewController: self.overlayVC.modalViewController,
            content: phase
        ))
    }

    // Embedding function for flutter bridge
    // Same as embeddingUIView except it has a parameter to pass a callback to send embedding width and height updates
    @_spi(FlutterBridge)
    public func embeddingForFlutterBridge(
        _ id: String,
        arguments: Any? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        return EmbeddingUIView(
            experimentId: id,
            container: ContainerImpl(self.container as! ContainerImpl, arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: content,
            onSizeChange: onSizeChange
        )
    }

    @_spi(FlutterBridge)
    public func renderUIView(
        json: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> NubrickBridgedViewAccessor {
        do {
            let decoder = JSONDecoder()
            let data = Data(json.utf8)
            let decoded = try decoder.decode(UIRootBlock.self, from: data)
            return NubrickBridgedViewAccessor(rootView: RootView(
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
            return NubrickBridgedViewAccessor(uiview: UIView())
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
