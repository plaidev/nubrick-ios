import 'package:flutter/material.dart';
import 'dart:async';

import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:nativebrik_bridge/embedding.dart';
import 'package:nativebrik_bridge/remote_config.dart';

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

    var config = RemoteConfig("cnoku4223akg00e5m630");
    var variant = await config.fetch();
    var message = await variant.get("message");

    setState(() {
      _message = message ?? "Not Found";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Column(
          children: [
            const Embedding("TOP_COMPONENT", height: 270),
            Text(_message),
            const Text("Text 2")
          ],
        ),
      ),
    );
  }
}
