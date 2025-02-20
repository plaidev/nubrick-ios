import 'package:flutter/material.dart';
import 'dart:async';

import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:nativebrik_bridge/embedding.dart';
import 'package:nativebrik_bridge/remote_config.dart';
import 'package:nativebrik_bridge/provider.dart';
import 'package:nativebrik_bridge/user.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final nativebrik = NativebrikBridge("cgv3p3223akg00fod19g");
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

    nativebrik.addEventListener((event) {
      print("Nativebrik Global Embedding Event: $event");
    });

    final user = NativebrikUser();
    var userId = await user.getId();
    await user.setProperties({
      'prefecture': "Tokyo",
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
              const Text("Message:"),
              Text(_message),
              const Text("User ID:"),
              Text(_userId),
              const Text("Prefecture:"),
              Text(_prefecture),
              ElevatedButton(
                onPressed: () {
                  nativebrik.dispatch("my-event");
                },
                child: const Text('dispatch custom event'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
