import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:nativebrik_bridge/nativebrik_bridge.dart';

void main() {
  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    NativebrikBridge("cgv3p3223akg00fod19g");
    FlutterError.onError = (errorDetails) {
      NativebrikCrashReport.instance.recordFlutterError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      NativebrikCrashReport.instance.recordPlatformError(error, stack);
      return true;
    };
    runApp(const MyApp());
  }, (error, stack) {
    NativebrikCrashReport.instance.recordPlatformError(error, stack);
  });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _message = "Not Found";
  String _userId = "None";
  String _prefecture = "None";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    final user = NativebrikUser();
    var userId = await user.getId();
    await user.setProperties({
      'prefecture': "Tokyo",
      'environment': const bool.fromEnvironment('dart.vm.product')
          ? 'production'
          : 'development',
    });
    var properties = await user.getProperties();

    var config = NativebrikRemoteConfig("cnoku4223akg00e5m630");
    var variant = await config.fetch();
    var message = await variant.get("message");

    setState(() {
      _message = message ?? "Not Found";
      _userId = userId ?? "Not Found";
      _prefecture = properties?['prefecture'] ?? "Not Found";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NativebrikProvider(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Plugin example app'),
          ),
          body: Column(
            children: [
              NativebrikEmbedding("TOP_COMPONENT", height: 270,
                  onEvent: (event) {
                print("Nativebrik Embedding Event: ${event.payload}");
              }),
              const NativebrikAnchor("TOOLTIP_1", child: Text("Tooltip 1")),
              const Text("Message:"),
              Text(_message),
              const Text("User ID:"),
              Text(_userId),
              const Text("Prefecture:"),
              Text(_prefecture),
              const NativebrikAnchor("TOOLTIP_2", child: Text("Tooltip 2")),
              ElevatedButton(
                onPressed: () {
                  NativebrikDispatcher()
                      .dispatch(NativebrikEvent("DEMO_ON_CLICK"));
                },
                child: const Text('dispatch custom event'),
              ),
              const SizedBox(height: 200),
              const NativebrikAnchor(
                "TOOLTIP_3",
                child: Text("Tooltip 3"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
