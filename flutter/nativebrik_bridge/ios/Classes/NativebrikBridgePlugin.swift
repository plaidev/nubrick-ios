import Flutter
import UIKit
import Nativebrik

let EMEBEDDING_VIEW_ID = "nativebrik-embedding-view"
let EMBEDDING_PHASE_UPDATE_METHOD = "embedding-phase-update"
let ON_EVENT_METHOD = "on-event"

public class NativebrikBridgePlugin: NSObject, FlutterPlugin {
    private let manager: NativebrikBridgeManager
    private let messenger: FlutterBinaryMessenger
    init(messenger: FlutterBinaryMessenger, manager: NativebrikBridgeManager) {
        self.messenger = messenger
        self.manager = manager
        super.init()
    }
    public static func register(with registrar: FlutterPluginRegistrar) {
        let manager = NativebrikBridgeManager()
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(name: "nativebrik_bridge", binaryMessenger: messenger)
        let instance = NativebrikBridgePlugin(messenger: messenger, manager: manager)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(
            FLNativeViewFactory(messenger: messenger, manager: manager),
            withId: EMEBEDDING_VIEW_ID
        )
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getNativebrikSDKVersion":
            result(nativebrikSdkVersion)
        case "connectClient":
            let projectId = call.arguments as! String
            self.manager.setNativebrikClient(nativebrik: NativebrikClient(projectId: projectId))
            result("ok")
        case "connectEmbedding":
            let args = call.arguments as! [String:String]
            let id = args["id"]!
            let channelId = args["channelId"]!
            self.manager.connectEmbedding(id: id, channelId: channelId, messenger: self.messenger)
            result("ok")
        case "disconnectEmbedding":
            let channelId = call.arguments as! String
            self.manager.disconnectEmbedding(channelId: channelId)
            result("ok")
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
