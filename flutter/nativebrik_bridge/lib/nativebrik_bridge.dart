import 'channel/nativebrik_bridge_platform_interface.dart';

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

  NativebrikBridge(this.projectId) {
    NativebrikBridgePlatform.instance.connectClient(projectId);
  }

  Future<String?> getNativebrikSDKVersion() {
    return NativebrikBridgePlatform.instance.getNativebrikSDKVersion();
  }
}
