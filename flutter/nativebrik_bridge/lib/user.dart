import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

class NativebrikUser {
  Future<String?> getId() async {
    return await NativebrikBridgePlatform.instance.getUserId();
  }

  Future<void> set(Map<String, String> properties) async {
    await NativebrikBridgePlatform.instance.setUserProperties(properties);
  }
}
