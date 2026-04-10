//
//  _for_bridge.swift
//  Nubrick
//
//  Created by Ryosuke Suzuki on 2025/04/24.
//
import Foundation
import UIKit

@_spi(FlutterBridge)
@MainActor
public final class NubrickBridgedViewAccessor {
    private let rootOrUIView: UIView
    
    init(rootView: RootView) {
        self.rootOrUIView = rootView as UIView
    }
    
    init(uiview: UIView) {
        self.rootOrUIView = uiview
    }
    
    public var view: UIView {
        get {
            return self.rootOrUIView
        }
    }
    
    // actionJSON must be UIBlockAction with json format.
    // this method force-dispatches a UI block action from the page view.
    public func dispatchAction(_ actionJSON: String) throws {
        guard let rootView = self.rootOrUIView as? RootView else {
            return
        }
        guard let data = actionJSON.data(using: .utf8) else {
            return
        }
        let action = try JSONDecoder().decode(UIBlockAction.self, from: data)
        rootView.dispatchAction(action)
    }

    @available(*, deprecated, renamed: "dispatchAction(_:)")
    public func dispatch(event: String) throws {
        try self.dispatchAction(event)
    }
}

@_spi(FlutterBridge)
@MainActor
public enum NubrickBridge {
    public static func initialize(
        projectId: String,
        onEvent: (@Sendable (_ event: ComponentEvent) -> Void)? = nil,
        httpRequestInterceptor: NubrickHttpRequestInterceptor? = nil,
        trackUrl: String? = nil,
        cdnUrl: String? = nil,
        cachePolicy: NubrickCachePolicy? = nil,
        onDispatch: ((_ event: NubrickEvent) -> Void)? = nil,
        trackCrashes: Bool = true,
        onTooltip: ((_ data: String, _ experimentId: String) -> Void)? = nil
    ) {
        NubrickSDK.initializeBridge(
            projectId: projectId,
            onEvent: onEvent,
            httpRequestInterceptor: httpRequestInterceptor,
            trackUrl: trackUrl,
            cdnUrl: cdnUrl,
            cachePolicy: cachePolicy,
            onDispatch: onDispatch,
            trackCrashes: trackCrashes,
            onTooltip: onTooltip
        )
    }

    public static func embeddingForFlutterBridge(
        _ id: String,
        arguments: NubrickArguments? = nil,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onSizeChange: ((_ width: CGFloat?, _ height: CGFloat?) -> Void)? = nil,
        content: @escaping (_ phase: UIKitEmbeddingPhase) -> UIView
    ) -> UIView {
        guard let runtime = NubrickSDK.requireRuntime() else {
            return UIView()
        }
        return runtime.embeddingForFlutterBridge(
            id,
            arguments: arguments,
            onEvent: onEvent,
            onSizeChange: onSizeChange,
            content: content
        )
    }

    public static func renderUIView(
        json: String,
        onEvent: ((_ event: ComponentEvent) -> Void)? = nil,
        onNextTooltip: ((_ pageId: String) -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> NubrickBridgedViewAccessor {
        guard let runtime = NubrickSDK.requireRuntime() else {
            return NubrickBridgedViewAccessor(uiview: UIView())
        }
        return runtime.renderUIView(
            json: json,
            onEvent: onEvent,
            onNextTooltip: onNextTooltip,
            onDismiss: onDismiss
        )
    }
}
