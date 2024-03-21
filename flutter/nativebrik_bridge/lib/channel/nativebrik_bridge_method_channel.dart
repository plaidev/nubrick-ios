import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/remote_config.dart';

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
  Future<String?> connectEmbedding(
      String id, String channelId, dynamic arguments) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectEmbedding',
      <String, dynamic>{
        'id': id,
        'channelId': channelId,
        'arguments': arguments,
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

  @override
  Future<RemoteConfigPhase?> connectRemoteConfig(
      String id, String channelId) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectRemoteConfig',
      <String, String>{
        'id': id,
        'channelId': channelId,
      },
    );
    switch (result) {
      case "completed":
        return RemoteConfigPhase.completed;
      case "not-found":
        return RemoteConfigPhase.notFound;
      case "failed":
        return RemoteConfigPhase.failed;
      default:
        return null;
    }
  }

  @override
  Future<String?> disconnectRemoteConfig(String channelId) async {
    final result = await methodChannel.invokeMethod<String>(
      'disconnectRemoteConfig',
      channelId,
    );
    return result;
  }

  @override
  Future<String?> getRemoteConfigValue(String channelId, String key) async {
    final result = await methodChannel.invokeMethod<String>(
      'getRemoteConfigValue',
      <String, String>{
        'key': key,
        'channelId': channelId,
      },
    );
    return result;
  }

  @override
  Future<String?> connectEmbeddingInRemoteConfigValue(String key,
      String channelId, String embeddingChannelId, dynamic arguments) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectEmbeddingInRemoteConfigValue',
      <String, dynamic>{
        'key': key,
        'channelId': channelId,
        'embeddingChannelId': embeddingChannelId,
        'arguments': arguments,
      },
    );
    return result;
  }

  @override
  Future<String?> dispatch(String name) async {
    final result = await methodChannel.invokeMethod<String>(
      'dispatch',
      name,
    );
    return result;
  }
}
