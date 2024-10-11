import 'package:flutter/material.dart';

import 'package:nativebrik_bridge/nativebrik_bridge.dart';
import 'package:nativebrik_bridge/embedding.dart';
import 'package:nativebrik_bridge/remote_config.dart';
import 'package:nativebrik_bridge/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final nativebrik = NativebrikBridge("ckto7v223akg00ag3jsg");
  String _message = "Not Found";

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  Future<void> initPlatformState() async {
    if (!mounted) return;

    var config = NativebrikRemoteConfig("REMOTE_CONFIG_FOR_E2E");
    var variant = await config.fetch();
    var message = await variant.get("message");

    setState(() {
      _message = message ?? "Not Found";
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: NativebrikProvider(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('app for e2e '),
          ),
          body: Column(
            children: [
              const NativebrikEmbedding("EMBEDDING_FOR_E2E", height: 270),
              Text(_message),
            ],
          ),
        ),
      ),
    );
  }
}
