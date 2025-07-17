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
export 'package:nativebrik_bridge/anchor/anchor.dart';

/// A bridge client to the nativebrik SDK.
///
/// - Initialize the bridge with the project ID before using nativebrik SDK.
///
/// reference: https://docs.nativebrik.com/reference/flutter/nativebrikbridge
///
/// Usage:
///
/// ```dart
/// // Setup Nativebrik SDK
/// void main() {
///   runZonedGuarded(() {
///     WidgetsFlutterBinding.ensureInitialized();
///     // Initialize the bridge with the project ID
///     NativebrikBridge("PROJECT ID");
///     // Set up global error handling
///     FlutterError.onError = (errorDetails) {
///       NativebrikCrashReport.instance.recordFlutterError(errorDetails);
///     };
///     // Set up platform dispatcher error handling
///     PlatformDispatcher.instance.onError = (error, stack) {
///       NativebrikCrashReport.instance.recordPlatformError(error, stack);
///       return true;
///     };
///     runApp(const YourApp());
///   }, (error, stack) {
///     // Record any unhandled errors
///     NativebrikCrashReport.instance.recordPlatformError(error, stack);
///   });
/// }
/// ```
class NativebrikBridge {
  static NativebrikBridge? instance;

  final String projectId;
  final NativebrikCachePolicy cachePolicy;
  final List<EventHandler> _listeners = [];
  final List<void Function(String)> _onDispatchListeners = [];
  final MethodChannel _channel = const MethodChannel("nativebrik_bridge");

  NativebrikBridge(this.projectId,
      {this.cachePolicy = const NativebrikCachePolicy()}) {
    NativebrikBridge.instance = this;
    NativebrikBridgePlatform.instance.connectClient(projectId, cachePolicy);
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

  void addOnDispatchListener(void Function(String) listener) {
    _onDispatchListeners.add(listener);
  }

  void removeOnDispatchListener(void Function(String) listener) {
    _onDispatchListeners.remove(listener);
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'on-event':
        final event = parseEvent(call.arguments);
        for (var listener in _listeners) {
          listener(event);
        }
        return Future.value(true);
      case 'on-dispatch':
        final name = call.arguments["name"] as String?;
        if (name != null) {
          for (var listener in _onDispatchListeners) {
            listener(name);
          }
        }
        return Future.value(true);
      default:
        return Future.value(true);
    }
  }
}

/// A policy for caching data from the nativebrik SDK.
///
/// - The cache time is the time to live for the cache. default is 1 day.
/// - The stale time is the time to live for the stale data. default is 0 seconds.
/// - The storage is the storage for the cache. default is inMemory.
///
/// ```dart
class NativebrikCachePolicy {
  final Duration cacheTime;
  final Duration staleTime;
  final CacheStorage storage;

  const NativebrikCachePolicy(
      {this.cacheTime = const Duration(days: 1),
      this.staleTime = const Duration(seconds: 0),
      this.storage = CacheStorage.inMemory});

  Map<String, dynamic> toObject() {
    return {
      'cacheTime': cacheTime.inSeconds,
      'staleTime': staleTime.inSeconds,
      'storage': storage.name,
    };
  }
}

enum CacheStorage {
  inMemory,
}
