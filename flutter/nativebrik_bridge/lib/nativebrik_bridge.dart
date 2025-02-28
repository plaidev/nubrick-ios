import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/embedding.dart';
import 'package:nativebrik_bridge/utils/parse_event.dart';
import 'channel/nativebrik_bridge_platform_interface.dart';

// Export public APIs
export 'package:nativebrik_bridge/crash_report.dart';
export 'package:nativebrik_bridge/dispatcher.dart';
export 'package:nativebrik_bridge/embedding.dart';
export 'package:nativebrik_bridge/provider.dart';
export 'package:nativebrik_bridge/remote_config.dart';
export 'package:nativebrik_bridge/user.dart';

/// A bridge client to the nativebrik SDK.
///
/// - Initialize the bridge with the project ID before using nativebrik SDK.
///
/// ```dart
/// class _YourAppStore extends State<YourApp> {
///   final nativebrik = NativebrikBridge("PROJECT ID");
/// }
/// ```
class NativebrikBridge {
  final String projectId;
  final List<EventHandler> _listeners = [];
  final MethodChannel _channel = const MethodChannel("nativebrik_bridge");

  NativebrikBridge(this.projectId) {
    NativebrikBridgePlatform.instance.connectClient(projectId);
    _channel.setMethodCallHandler(_handleMethod);
  }

  Future<String?> getNativebrikSDKVersion() {
    return NativebrikBridgePlatform.instance.getNativebrikSDKVersion();
  }

  addEventListener(EventHandler listener) {
    _listeners.add(listener);
  }

  removeEventListener(EventHandler listener) {
    _listeners.remove(listener);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'on-event':
        final event = parseEvent(call.arguments);
        for (var listener in _listeners) {
          listener(event);
        }
        return Future.value(true);
      default:
        return Future.value(true);
    }
  }
}
