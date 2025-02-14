import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';

class NativebrikUser {
  Future<String?> getId() async {
    return await NativebrikBridgePlatform.instance.getUserId();
  }

  Future<void> setProperties(Map<String, String> properties) async {
    await NativebrikBridgePlatform.instance.setUserProperties(properties);
  }

  Future<Map<String, String>?> getProperties() async {
    return await NativebrikBridgePlatform.instance.getUserProperties();
  }
}
