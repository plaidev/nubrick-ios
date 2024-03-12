import 'channel/nativebrik_bridge_platform_interface.dart';

class NativebrikBridge {
  final String projectId;

  NativebrikBridge(this.projectId) {
    NativebrikBridgePlatform.instance.connectClient(projectId);
  }

  Future<String?> getNativebrikSDKVersion() {
    return NativebrikBridgePlatform.instance.getNativebrikSDKVersion();
  }
}
