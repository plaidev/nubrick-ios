import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nativebrik_bridge/channel/nativebrik_bridge_method_channel.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  MethodChannelNativebrikBridge platform = MethodChannelNativebrikBridge();
  const MethodChannel channel = MethodChannel('nativebrik_bridge');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        return '42';
      },
    );
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getNativebrikSDKVersion', () async {
    expect(await platform.getNativebrikSDKVersion(), '42');
  });
}
