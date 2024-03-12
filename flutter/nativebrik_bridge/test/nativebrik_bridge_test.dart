import 'package:flutter_test/flutter_test.dart';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_platform_interface.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockNativebrikBridgePlatform
    with MockPlatformInterfaceMixin
    implements NativebrikBridgePlatform {
  @override
  Future<String?> getNativebrikSDKVersion() => Future.value('42');

  @override
  Future<String?> connectClient(String projectId) {
    throw UnimplementedError('connectClient() has not been implemented.');
  }

  @override
  Future<String?> connectEmbedding(String id, String channelId) {
    throw UnimplementedError('connectEmbedding() has not been implemented.');
  }

  @override
  Future<String?> disconnectEmbedding(String channelId) {
    throw UnimplementedError('disconnectEmbedding() has not been implemented.');
  }
}

void main() {
  final NativebrikBridgePlatform initialPlatform =
      NativebrikBridgePlatform.instance;

  test('$MethodChannelNativebrikBridge is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelNativebrikBridge>());
  });

  test('getPlatformVersion', () async {
    NativebrikBridge nativebrikBridgePlugin = NativebrikBridge("projectId");
    MockNativebrikBridgePlatform fakePlatform = MockNativebrikBridgePlatform();
    NativebrikBridgePlatform.instance = fakePlatform;

    expect(await nativebrikBridgePlugin.getNativebrikSDKVersion(), '42');
  });
}
