import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import './channel/nativebrik_bridge_platform_interface.dart';

String _generateRandomString(int len) {
  var r = Random();
  return String.fromCharCodes(
      List.generate(len, (index) => r.nextInt(33) + 89));
}

typedef EmbeddingBuilder = Widget Function(
    BuildContext context, EmbeddingPhase value, Widget child);

class Embedding extends StatefulWidget {
  final String id;
  final double? width;
  final double? height;
  final EmbeddingBuilder? builder;
  Embedding(this.id, {super.key, this.width, this.height, this.builder});

  @override
  _EmbeddingState createState() => _EmbeddingState();
}

enum EmbeddingPhase {
  loading,
  failed,
  notFound,
  completed,
}

class _EmbeddingState extends State<Embedding> {
  var _phase = EmbeddingPhase.loading;
  final _channelId = _generateRandomString(32);

  @override
  void initState() {
    super.initState();
    final MethodChannel channel =
        MethodChannel("Nativebrik/Embedding/$_channelId");
    channel.setMethodCallHandler(_handleMethod);
    NativebrikBridgePlatform.instance.connectEmbedding(widget.id, _channelId);
  }

  @override
  void dispose() {
    NativebrikBridgePlatform.instance.disconnectEmbedding(_channelId);
    super.dispose();
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case 'embedding-phase-update':
        String phase = call.arguments as String;
        setState(() {
          _phase = switch (phase) {
            "loading" => EmbeddingPhase.loading,
            "not-found" => EmbeddingPhase.notFound,
            "failed" => EmbeddingPhase.failed,
            "completed" => EmbeddingPhase.completed,
            _ => EmbeddingPhase.loading,
          };
        });
        return Future.value(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      width: widget.width,
      child: renderByPhase(context),
    );
  }

  Widget renderByPhase(BuildContext context) {
    switch (_phase) {
      case EmbeddingPhase.loading:
        return renderWithBuilder(
            context, const Center(child: CircularProgressIndicator()));
      case EmbeddingPhase.failed:
        return renderWithBuilder(
            context, const Center(child: Text("Failed to load embedding")));
      case EmbeddingPhase.notFound:
        return renderWithBuilder(
            context, const Center(child: Text("Embedding not found")));
      case EmbeddingPhase.completed:
        return renderWithBuilder(
            context, SizedBox(child: _BridgeView(_channelId)));
    }
  }

  Widget renderWithBuilder(BuildContext context, Widget child) {
    if (widget.builder != null) {
      return widget.builder!(context, _phase, child);
    }
    return child;
  }
}

class _BridgeView extends StatelessWidget {
  final String channelId;

  const _BridgeView(this.channelId);

  @override
  Widget build(BuildContext context) {
    const String viewType = "nativebrik-embedding-view";
    final Map<String, dynamic> creationParams = <String, dynamic>{
      "channelId": channelId,
    };
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );
      default:
        throw UnsupportedError("Unsupported platform view type");
    }
  }
}
