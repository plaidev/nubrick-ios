import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:nativebrik_bridge/schema/generated.dart';

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
  Future<String?> connectClient(
      String projectId, NativebrikCachePolicy cachePolicy) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectClient',
      <String, dynamic>{
        'projectId': projectId,
        'cachePolicy': cachePolicy.toObject(),
      },
    );
    return result;
  }

  @override
  Future<String?> getUserId() async {
    final result = await methodChannel.invokeMethod<String>('getUserId');
    return result;
  }

  @override
  Future<void> setUserProperties(Map<String, String> properties) async {
    await methodChannel.invokeMethod<String>('setUserProperties', properties);
  }

  @override
  Future<Map<String, String>?> getUserProperties() async {
    final result = await methodChannel.invokeMethod('getUserProperties');
    return result?.cast<String, String>();
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
  Future<UIRootBlock?> connectTooltip(String name) async {
    final result = await methodChannel.invokeMethod<String>(
      'connectTooltip',
      name,
    );
    print("MethodChannelNativebrikBridge connectTooltip: $result");
    if (result == null) {
      return null;
    }
    if (result.startsWith("error")) {
      return null;
    }
    var decoded = UIRootBlock.decode(jsonDecode(result));
    print("MethodChannelNativebrikBridge connectTooltip: $decoded");
    return decoded;
  }

  @override
  Future<String?> connectTooltipEmbedding(
      String channelId, UIRootBlock rootBlock) async {
    var json = jsonEncode(rootBlock.encode());
    final result = await methodChannel.invokeMethod<String>(
      'connectTooltipEmbedding',
      <String, dynamic>{
        'channelId': channelId,
        'json': json,
      },
    );
    return result;
  }

  @override
  Future<void> callTooltipEmbeddingDispatch(
      String channelId, UIBlockEventDispatcher event) async {
    await methodChannel.invokeMethod<void>(
      'callTooltipEmbeddingDispatch',
      <String, dynamic>{
        'channelId': channelId,
        'event': jsonEncode(event.encode()),
      },
    );
  }

  @override
  Future<String?> disconnectTooltipEmbedding(String channelId) async {
    final result = await methodChannel.invokeMethod<String>(
      'disconnectTooltipEmbedding',
      channelId,
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

  @override
  Future<void> recordCrash(Map<String, dynamic> errorData) async {
    await methodChannel.invokeMethod<void>(
      'recordCrash',
      errorData,
    );
  }
}
