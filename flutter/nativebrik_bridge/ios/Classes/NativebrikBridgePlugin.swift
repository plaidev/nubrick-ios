import Flutter
import UIKit
import Nativebrik

let EMEBEDDING_VIEW_ID = "nativebrik-embedding-view"
let EMBEDDING_PHASE_UPDATE_METHOD = "embedding-phase-update"
let ON_EVENT_METHOD = "on-event"

public class NativebrikBridgePlugin: NSObject, FlutterPlugin {
    private let manager: NativebrikBridgeManager
    private let messenger: FlutterBinaryMessenger
    private let channel: FlutterMethodChannel
    init(messenger: FlutterBinaryMessenger, manager: NativebrikBridgeManager, channel: FlutterMethodChannel) {
        self.messenger = messenger
        self.manager = manager
        self.channel = channel
        super.init()
    }
    public static func register(with registrar: FlutterPluginRegistrar) {
        let manager = NativebrikBridgeManager()
        let messenger = registrar.messenger()
        let channel = FlutterMethodChannel(name: "nativebrik_bridge", binaryMessenger: messenger)
        let instance = NativebrikBridgePlugin(messenger: messenger, manager: manager, channel: channel)
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
            self.manager.setNativebrikClient(nativebrik: NativebrikClient(projectId: projectId, onEvent: { [weak self] event in
                self?.channel.invokeMethod(ON_EVENT_METHOD, arguments: [
                    "name": event.name as Any?,
                    "deepLink": event.deepLink as Any?,
                    "payload": event.payload?.map({ prop in
                        return [
                            "name": prop.name,
                            "value": prop.value,
                            "type": prop.type
                        ]
                    }),
                ])
            }))
            result("ok")

        // user
        case "getUserId":
            let id = self.manager.getUserId()
            result(id)
        case "setUserProperties":
            let props = call.arguments as! [String:String]
            self.manager.setUserProperties(properties: props)
            result("ok")
        case "getUserProperties":
            let props = self.manager.getUserProperties()
            result(props)

        // embedding
        case "connectEmbedding":
            let args = call.arguments as! [String:Any]
            let id = args["id"] as! String
            let channelId = args["channelId"] as! String
            let arguments = args["arguments"] as Any?
            self.manager.connectEmbedding(id: id, channelId: channelId, arguments: arguments, messenger: self.messenger)
            result("ok")
        case "disconnectEmbedding":
            let channelId = call.arguments as! String
            self.manager.disconnectEmbedding(channelId: channelId)
            result("ok")

        // remote config
        case "connectRemoteConfig":
            let args = call.arguments as! [String:String]
            let id = args["id"]!
            let channelId = args["channelId"]!
            self.manager.connectRemoteConfig(id: id, channelId: channelId, onPhase: { phase in
                switch phase {
                case .completed:
                    result("completed")
                case .failed:
                    result("failed")
                case .notFound:
                    result("not-found")
                case .loading:
                    break
                }
            })
        case "disconnectRemoteConfig":
            let channelId = call.arguments as! String
            self.manager.disconnectRemoteConfig(channelId: channelId)
            result("ok")
        case "getRemoteConfigValue":
            let args = call.arguments as! [String:String]
            let channelId = args["channelId"]!
            let key = args["key"]!
            let value = self.manager.getRemoteConfigValue(channelId: channelId, key: key)
            result(value)
        case "connectEmbeddingInRemoteConfigValue":
            let args = call.arguments as! [String:Any]
            let key = args["key"] as! String
            let channelId = args["channelId"] as! String
            let embeddingChannelId = args["embeddingChannelId"] as! String
            let arguments = args["arguments"] as Any?
            self.manager.connectEmbeddingInRemoteConfigValue(key: key, channelId: channelId, arguments: arguments, embeddingChannelId: embeddingChannelId, messenger: self.messenger)
            result("ok")
        case "dispatch":
            let name = call.arguments as! String
            self.manager.dispatch(name: name)
            result("ok")
        case "recordCrash":
            do {
                guard let errorData = call.arguments as? [String: Any] else {
                    throw NSError(domain: "com.nativebrik.flutter", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid error data"])
                }

                let exception = errorData["exception"] as? String ?? "Unknown Flutter Error"
                let stack = errorData["stack"] as? String ?? ""
                let library = errorData["library"] as? String ?? "flutter"
                let context = errorData["context"] as? String ?? ""
                let summary = errorData["summary"] as? String ?? ""

                // Create an NSException with the Flutter error information
                let userInfo: [String: Any] = [
                    "stack": stack,
                    "library": library,
                    "context": context,
                    "summary": summary
                ]

                let nsException = NSException(
                    name: NSExceptionName("FlutterException"),
                    reason: exception,
                    userInfo: userInfo
                )

                // Record the exception using the Nativebrik SDK
                self.manager.recordCrash(exception: nsException)
                result("ok")
            } catch {
                result(FlutterError(code: "CRASH_REPORT_ERROR", message: "Failed to record crash: \(error.localizedDescription)", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
