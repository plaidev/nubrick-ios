//
//  sdk.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2023/03/28.
//

import Foundation
import SwiftUI
import MetricKit
import Darwin.Mach

// For crash reporting
@MainActor
private final class AppMetrics: NSObject, MXMetricManagerSubscriber {

    // Keep exactly 1 subscriber per iOS process (prevents Flutter hot-restart duplicates)
    fileprivate static let shared = AppMetrics()
    private var isRegistered = false

    /// Create singleton only; registration is explicit and ordered by SDK initialization.
    private override init() {
        super.init()
    }

    @MainActor
    func register() {
        guard !isRegistered else { return }
        isRegistered = true

        let manager = MXMetricManager.shared
        manager.add(self)

        // Immediately receive crash reports generated since last app run / last manager allocation
        didReceive(manager.pastDiagnosticPayloads)
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            guard let crashDiagnostics = payload.crashDiagnostics else { continue }
            for crashDiagnostic in crashDiagnostics {
                let callStackTreeJSON = crashDiagnostic.callStackTree.jsonRepresentation()
                let terminationReason = crashDiagnostic.terminationReason
                let exceptionType = crashDiagnostic.exceptionType?.uint32Value

                Task { @MainActor in
                    NubrickSDK.runtime?.processMetricKitCrash(
                        callStackTreeJSON: callStackTreeJSON,
                        terminationReason: terminationReason,
                        exceptionType: exceptionType
                    )
                }
            }
        }
    }
}

// Default backend endpoints (used unless overridden per client instance)
public let nubrickTrackUrl = "https://track.nativebrik.com/track/v1"
public let nubrickCdnUrl = "https://cdn.nativebrik.com"
public let nubrickSdkVersion = "0.17.0"

@MainActor
private func openLink(_ event: ComponentEvent) {
    guard let link = event.deepLink,
          let url = URL(string: link),
          UIApplication.shared.canOpenURL(url) else {
        return
    }
    UIApplication.shared.open(url)
}

private func nubrickWarn(_ message: String) {
    print("[Nubrick] \(message)")
}

@MainActor
private func dispatchMainActor(_ event: NubrickEvent) {
    guard let runtime = NubrickSDK.requireRuntime() else {
        nubrickWarn("Dropping event before initialize: \(event.name)")
        return
    }
    runtime.dispatch(event)
}

final class Config : Sendable{
    let projectId: String
    let url: String
    let trackUrl: String
    let cdnUrl: String
    let cachePolicy: NubrickCachePolicy

    init(
        projectId: String,
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil
    ) {
        self.projectId = projectId
        self.url = "https://nativebrik.com/client"
        self.trackUrl = trackUrl ?? nubrickTrackUrl
        self.cdnUrl = cdnUrl ?? nubrickCdnUrl
        self.cachePolicy = cachePolicy ?? NubrickCachePolicy()
    }
}

public enum EventPropertyType: Sendable {
    case INTEGER
    case STRING
    case TIMESTAMPZ
    case UNKNOWN
}

public struct EventProperty: Sendable {
    public let name: String
    public let value: String
    public let type: EventPropertyType
}

public struct ComponentEvent: Sendable {
    public let name: String?
    public let deepLink: String?
    public let payload: [EventProperty]?
}

public struct NubrickEvent: Sendable {
    public let name: String
    public init(_ name: String) {
        self.name = name
    }
}

public typealias NubrickArguments = [String: any Sendable]

public typealias NubrickHttpRequestInterceptor = @Sendable (_ request: URLRequest) -> URLRequest

@MainActor
final class NubrickCore {
    private let dependencies: NubrickDependencyContainer
    private let overlayVC: OverlayViewController

    init(
        projectId: String,
        onEvent: (@Sendable (_ event: ComponentEvent) -> Void)?,
        httpRequestInterceptor: NubrickHttpRequestInterceptor?,
        trackUrl: String?,
        cdnUrl: String?,
        cachePolicy: NubrickCachePolicy?,
        onDispatch: ((_ event: NubrickEvent) -> Void)?,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)?
    ) {
        let user = NubrickUser()
        let actionHandler: UIBlockActionHandler = { action, _ in
            // Terminal sdk pipeline: convert -> side effects -> trigger dispatch.
            let converted = convertEvent(action)
            openLink(converted)
            onEvent?(converted)

            guard let name = converted.name,
                  !name.isEmpty else {
                return
            }
            dispatchMainActor(NubrickEvent(name))
        }
        let config = Config(
            projectId: projectId,
            trackUrl: trackUrl,
            cdnUrl: cdnUrl,
            cachePolicy: cachePolicy
        )
        let persistentContainer = createNativebrikCoreDataHelper()
        let dependencies = NubrickDependencyContainer(
            config: config,
            user: user,
            actionHandler: actionHandler,
            persistentContainer: persistentContainer,
            httpRequestInterceptor: httpRequestInterceptor
        )

        self.dependencies = dependencies
        self.overlayVC = OverlayViewController(
            user: user,
            renderContext: dependencies.makeRenderContext(),
            onDispatch: onDispatch,
            onTooltip: onTooltip
        )
    }

    func dispatch(_ event: NubrickEvent) {
        self.overlayVC.triggerViewController.dispatch(event: event)
    }

    func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        Task {
            await self.dependencies.trackRepository.sendFlutterCrash(crashEvent)
        }
    }

    func appendTooltipExperimentHistory(experimentId: String) {
        guard !experimentId.isEmpty else { return }
        self.dependencies.databaseRepository.appendExperimentHistory(experimentId: experimentId)
    }

    func processMetricKitCrash(
        callStackTreeJSON: Data,
        terminationReason: String?,
        exceptionType: UInt32?
    ) {
        Task {
            await self.dependencies.trackRepository.processMetricKitCrash(
                callStackTreeJSON: callStackTreeJSON,
                terminationReason: terminationReason,
                exceptionType: exceptionType
            )
        }
    }

    private func makeRenderContext(arguments: NubrickArguments? = nil) -> RenderContext {
        self.dependencies.makeRenderContext(arguments: arguments)
    }

    func overlayViewController() -> UIViewController {
        self.overlayVC
    }

    func overlay() -> some View {
        AnyView(OverlayViewControllerRepresentable(overlayVC: self.overlayVC).frame(width: 0, height: 0))
    }

    func embedding(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        AnyView(EmbeddingSwiftView(
            experimentId: id,
            renderContext: self.makeRenderContext(arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent
        ))
    }

    func embedding<V: View>(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: @escaping (_ phase: AsyncEmbeddingPhase) -> V
    ) -> some View {
        AnyView(EmbeddingSwiftView(
            experimentId: id,
            componentId: nil,
            renderContext: self.makeRenderContext(arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            content: content
        ))
    }

    func embeddingUIView(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView {
        EmbeddingUIView(
            experimentId: id,
            renderContext: self.makeRenderContext(arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: nil
        )
    }

    func embeddingUIView(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        EmbeddingUIView(
            experimentId: id,
            renderContext: self.makeRenderContext(arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: content
        )
    }

    func remoteConfig(
        _ id: String,
        phase: @escaping (@Sendable (_ phase: RemoteConfigPhase) -> Void)
    ) {
        let _ = RemoteConfig(
            experimentId: id,
            renderContext: self.makeRenderContext(),
            modalViewController: self.overlayVC.modalViewController,
            phase: phase
        )
    }

    func remoteConfigAsView<V: View>(
        _ id: String,
        @ViewBuilder phase: @escaping ((_ phase: RemoteConfigPhase) -> V)
    ) -> some View {
        AnyView(RemoteConfigAsView(
            experimentId: id,
            renderContext: self.makeRenderContext(),
            modalViewController: self.overlayVC.modalViewController,
            content: phase
        ))
    }

    func embeddingForFlutterBridge(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        EmbeddingUIView(
            experimentId: id,
            renderContext: self.makeRenderContext(arguments: arguments),
            modalViewController: self.overlayVC.modalViewController,
            onEvent: onEvent,
            fallback: content,
            onSizeChange: onSizeChange
        )
    }

    func renderUIView(
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
                renderContext: self.makeRenderContext(),
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

public enum NubrickSDK {
    @MainActor
    fileprivate static var runtime: NubrickCore? = nil

    @MainActor
    private static func warnUninitialized() {
        let message = "Nubrick used before NubrickSDK.initialize(...)."
        #if DEBUG
        assertionFailure(message)
        #endif
        nubrickWarn(message)
    }

    @MainActor
    static func requireRuntime() -> NubrickCore? {
        guard let runtime else {
            warnUninitialized()
            return nil
        }
        return runtime
    }

    @MainActor
    static func initializeInternal(
        projectId: String,
        onEvent: (@Sendable (_ event: ComponentEvent) -> Void)?,
        httpRequestInterceptor: NubrickHttpRequestInterceptor?,
        trackUrl: String?,
        cdnUrl: String?,
        cachePolicy: NubrickCachePolicy?,
        onDispatch: ((_ event: NubrickEvent) -> Void)?,
        trackCrashes: Bool,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)?
    ) {
        guard runtime == nil else {
            nubrickWarn("NubrickSDK.initialize(...) called more than once. Ignoring subsequent call.")
            return
        }

        runtime = NubrickCore(
            projectId: projectId,
            onEvent: onEvent,
            httpRequestInterceptor: httpRequestInterceptor,
            trackUrl: trackUrl,
            cdnUrl: cdnUrl,
            cachePolicy: cachePolicy,
            onDispatch: onDispatch,
            onTooltip: onTooltip
        )

        if trackCrashes {
            AppMetrics.shared.register()
        }
    }

    @MainActor
    public static func initialize(
        projectId: String,
        onEvent: (@Sendable (_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil,
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        trackCrashes: Bool = true
    ) {
        initializeInternal(
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

    public nonisolated static func dispatch(_ event: NubrickEvent) {
        Task { @MainActor in
            dispatchMainActor(event)
        }
    }

    @MainActor
    public static func overlayViewController() -> UIViewController {
        guard let runtime = requireRuntime() else {
            return UIViewController()
        }
        return runtime.overlayViewController()
    }

    @MainActor
    public static func overlay() -> some View {
        guard let runtime = requireRuntime() else {
            return AnyView(EmptyView())
        }
        return AnyView(runtime.overlay())
    }

    @MainActor
    public static func embedding(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> some View {
        guard let runtime = requireRuntime() else {
            return AnyView(EmptyView())
        }
        return AnyView(runtime.embedding(id, arguments: arguments, onEvent: onEvent))
    }

    @MainActor
    public static func embedding<V: View>(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        @ViewBuilder content: @escaping (_ phase: AsyncEmbeddingPhase) -> V
    ) -> some View {
        guard let runtime = requireRuntime() else {
            return AnyView(EmptyView())
        }
        return AnyView(runtime.embedding(id, arguments: arguments, onEvent: onEvent, content: content))
    }

    @MainActor
    public static func embeddingUIView(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil
    ) -> UIView {
        guard let runtime = requireRuntime() else {
            return UIView()
        }
        return runtime.embeddingUIView(id, arguments: arguments, onEvent: onEvent)
    }

    @MainActor
    public static func embeddingUIView(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        content: @escaping (_ phase: EmbeddingPhase) -> UIView
    ) -> UIView {
        guard let runtime = requireRuntime() else {
            return UIView()
        }
        return runtime.embeddingUIView(id, arguments: arguments, onEvent: onEvent, content: content)
    }

    public static func remoteConfig(
        _ id: String,
        phase: @escaping (@Sendable (_ phase: RemoteConfigPhase) -> Void)
    ) {
        Task { @MainActor in
            guard let runtime = requireRuntime() else {
                return
            }
            runtime.remoteConfig(id, phase: phase)
        }
    }

    @MainActor
    public static func remoteConfigAsView<V: View>(
        _ id: String,
        @ViewBuilder phase: @escaping ((_ phase: RemoteConfigPhase) -> V)
    ) -> some View {
        guard let runtime = requireRuntime() else {
            return AnyView(EmptyView())
        }
        return AnyView(runtime.remoteConfigAsView(id, phase: phase))
    }

    /// Sends a crash event from Flutter
    ///
    /// - Parameter crashEvent: The crash event containing exceptions, platform, and SDK version
    @_spi(FlutterBridge)
    @MainActor
    public static func sendFlutterCrash(_ crashEvent: TrackCrashEvent) {
        guard let runtime = requireRuntime() else {
            return
        }
        runtime.sendFlutterCrash(crashEvent)
    }

    @_spi(FlutterBridge)
    @MainActor
    public static func appendTooltipExperimentHistory(experimentId: String) {
        guard let runtime = requireRuntime() else {
            return
        }
        runtime.appendTooltipExperimentHistory(experimentId: experimentId)
    }

    @available(*, deprecated, message: "NSException-based crash reporting has been replaced by MetricKit. This method no longer reports crashes. Crash reporting now happens automatically via MetricKit on iOS 14+.")
    public static func record(exception: NSException) {
        // No-op: MetricKit handles crash reporting automatically on iOS 14+
    }
}

@MainActor
public struct NubrickProvider<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        ZStack(alignment: .top) {
            NubrickSDK.overlay()
            content
        }
    }
}
