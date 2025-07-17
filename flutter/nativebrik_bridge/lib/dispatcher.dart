import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

class NativebrikEvent {
  final String name;
  NativebrikEvent(this.name);
}

/// NativebrikDispatcher is the main dispatcher for the Nativebrik SDK.
///
/// reference: https://docs.nativebrik.com/reference/flutter/nativebrikdispatcher
///
/// Usage:
/// ```dart
/// NativebrikDispatcher.instance.dispatch(NativebrikEvent('event_name'));
/// ```
class NativebrikDispatcher {
  static final NativebrikDispatcher _instance = NativebrikDispatcher._();

  /// The singleton instance of [NativebrikDispatcher].
  static NativebrikDispatcher get instance => _instance;

  NativebrikDispatcher._();

  /// Creates a new instance of [NativebrikDispatcher].
  ///
  /// In most cases, you should use [NativebrikDispatcher.instance] instead.
  factory NativebrikDispatcher() => _instance;

  Future<void> dispatch(NativebrikEvent event) {
    return NativebrikBridgePlatform.instance.dispatch(event.name);
  }
}
