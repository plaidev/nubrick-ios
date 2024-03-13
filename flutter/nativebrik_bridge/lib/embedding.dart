import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nativebrik_bridge/remote_config.dart';
import 'package:nativebrik_bridge/utils/random.dart';
import './channel/nativebrik_bridge_platform_interface.dart';

typedef EmbeddingBuilder = Widget Function(
    BuildContext context, EmbeddingPhase phase, Widget child);

/// A widget that embeds an experiment.
///
/// - **NativebrikBridge** must be initialized before using this widget.
///
/// ```dart
/// // Embedding with default height
/// Embedding("ID OR CUSTOM ID", height: 300);
///
/// // Embedding with custom builder
/// Embedding("ID OR CUSTOM ID", builder: (context, phase, child) {
///  return phase == EmbeddingPhase.loading
///     ? const Center(child: CircularProgressIndicator())
///    : child;
/// });
///
/// // Embedding with remoteconfig.variant
/// var config = RemoteConfig("ID OR CUSTOM ID");
/// var variant = await config.fetch();
/// Embedding("Config Key", variant: variant);
/// ```
class Embedding extends StatefulWidget {
  final String id;
  final double? width;
  final double? height;
  final EmbeddingBuilder? builder;

  // this is used from remoteconfig.embed
  final RemoteConfigVariant? variant;

  const Embedding(this.id,
      {super.key, this.width, this.height, this.variant, this.builder});

  @override
  // ignore: library_private_types_in_public_api
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
  final _channelId = generateRandomString(32);

  @override
  void initState() {
    super.initState();
    final MethodChannel channel =
        MethodChannel("Nativebrik/Embedding/$_channelId");
    channel.setMethodCallHandler(_handleMethod);

    final variant = widget.variant;
    if (variant != null) {
      NativebrikBridgePlatform.instance.connectEmbeddingInRemoteConfigValue(
          widget.id, variant.channelId, _channelId);
    } else {
      NativebrikBridgePlatform.instance.connectEmbedding(widget.id, _channelId);
    }
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
      child: _renderByPhase(context),
    );
  }

  Widget _renderByPhase(BuildContext context) {
    switch (_phase) {
      case EmbeddingPhase.loading:
        return _renderWithBuilder(
            context, const Center(child: CircularProgressIndicator()));
      case EmbeddingPhase.failed:
        return _renderWithBuilder(
            context, const Center(child: Text("Failed to load embedding")));
      case EmbeddingPhase.notFound:
        return _renderWithBuilder(
            context, const Center(child: Text("Embedding not found")));
      case EmbeddingPhase.completed:
        return _renderWithBuilder(
            context, SizedBox(child: _BridgeView(_channelId)));
    }
  }

  Widget _renderWithBuilder(BuildContext context, Widget child) {
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
