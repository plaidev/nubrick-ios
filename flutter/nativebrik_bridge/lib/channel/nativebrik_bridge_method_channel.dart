import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import './nativebrik_bridge_platform_interface.dart';

/// An implementation of [NativebrikBridgePlatform] that uses method channels.
class MethodChannelNativebrikBridge extends NativebrikBridgePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('nativebrik_bridge');

  @override
  Future<String?> getNativebrikSDKVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getNativebrikSDKVersion');
    return version;
  }

  @override
  Future<String?> connectClient(String projectId) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectClient',
      projectId,
    );
    return result;
  }

  @override
  Future<String?> connectEmbedding(String id, String channelId) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectEmbedding',
      <String, String>{
        'id': id,
        'channelId': channelId,
      },
    );
    return result;
  }

  @override
  Future<String?> disconnectEmbedding(String channelId) async {
    final result = await methodChannel.invokeMethod<String>(
      'disconnectEmbedding',
      channelId,
    );
    return result;
  }
}
