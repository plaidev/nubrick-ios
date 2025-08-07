import Foundation
import Flutter
import UIKit
import Nativebrik

class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    let messenger: FlutterBinaryMessenger
    let manager: NativebrikBridgeManager

    init(messenger: FlutterBinaryMessenger, manager: NativebrikBridgeManager) {
        self.messenger = messenger
        self.manager = manager
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            manager: self.manager
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        manager: NativebrikBridgeManager
    ) {
        self._view = UIView(frame: frame)
        super.init()

        guard let args = args as? [String:Any] else {
            return
        }
        guard let channelId = args["channelId"] as? String else {
            return
        }
        guard let entity = manager.getEmbeddingEntity(channelId: channelId) else {
            return
        }
        self._view = entity.uiview
    }

    func view() -> UIView {
        return _view
    }
}
